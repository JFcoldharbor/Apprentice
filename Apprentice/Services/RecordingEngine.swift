//
//  RecordingEngine.swift
//  Apprentice
//
//  Layer 3 (Services) — the unified audio capture engine.
//
//  A single AVAudioEngine mic tap drives everything:
//    • converts input to 16 kHz mono PCM,
//    • writes compact AAC (.m4a) chunk files to AudioFileStore (never deleted),
//    • forwards the converted buffers to live on-device transcription,
//    • emits an audio level for the waveform,
//    • rolls over to a new chunk on a frame-accurate boundary.
//
//  One tap means no dual-pipeline audio-session conflict (the legacy app's bug),
//  and chunks are flushed to disk as they complete, so a crash mid-recording
//  loses at most the in-flight chunk.
//

import Foundation
import AVFoundation

final class RecordingEngine: NSObject, ObservableObject {

    struct FinalizedChunk {
        let index: Int
        let url: URL
        let relativePath: String
        let duration: TimeInterval
        let fileSize: Int
    }

    // MARK: Published state (main thread)

    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var currentChunkIndex = 0

    /// Seconds of audio per chunk before rollover (kept modest so transcription
    /// starts flowing well before a long recording ends). 3 min keeps each
    /// proxy/Whisper upload comfortably inside the transcription timeout —
    /// longer chunks were timing out on the legacy path.
    var chunkDuration: TimeInterval = 180

    /// Emitted on the main thread when a chunk file is finalized.
    var onChunkFinalized: ((FinalizedChunk) -> Void)?
    /// Converted 16 kHz mono buffers for live transcription. Invoked on the audio thread.
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?

    // MARK: Audio plumbing

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var processingFormat: AVAudioFormat?

    // MARK: Mutable capture state (guarded by stateLock)

    private let stateLock = NSLock()
    private var audioFile: AVAudioFile?
    private var currentURL: URL?
    private var currentRelativePath = ""
    private var framesInChunk: AVAudioFrameCount = 0
    private var totalFrames: AVAudioFrameCount = 0
    private var chunkThresholdFrames: AVAudioFrameCount = 0
    private var indexCounter = 0
    private var noteID = UUID()
    private var paused = false

    // MARK: - Lifecycle

    func start(noteID: UUID) throws {
        guard !isRecording else { return }
        self.noteID = noteID

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0 else { throw RecordingError.setupFailed }

        // Reset counters and open the first chunk file (its processingFormat
        // defines the converter target so buffer/file formats always match).
        stateLock.lock()
        indexCounter = 0
        totalFrames = 0
        stateLock.unlock()
        paused = false

        try openNewChunkFile(index: 0)
        guard let procFormat = processingFormat else { throw RecordingError.setupFailed }

        converter = AVAudioConverter(from: inFormat, to: procFormat)
        chunkThresholdFrames = AVAudioFrameCount(chunkDuration * procFormat.sampleRate)

        input.removeTap(onBus: 0) // defensive: avoid CreateRecordingTap crash on a leftover tap
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        try engine.start()
        registerAudioNotifications() // survive calls/texts/route changes mid-recording

        DispatchQueue.main.async {
            self.isRecording = true
            self.isPaused = false
            self.currentChunkIndex = 0
            self.elapsed = 0
            self.audioLevel = 0
        }
    }

    func pause() {
        guard isRecording, !paused else { return }
        paused = true
        engine.pause()
        DispatchQueue.main.async { self.isPaused = true }
    }

    func resume() {
        guard isRecording, paused else { return }
        do {
            try engine.start()
            paused = false
            DispatchQueue.main.async { self.isPaused = false }
        } catch {
            print("⚠️ RecordingEngine.resume failed: \(error)")
        }
    }

    // MARK: - Interruptions & route changes
    //
    // A phone call, a text/notification tone, Siri, or a headphone/Bluetooth
    // disconnect all interrupt the audio session — the system stops our engine and
    // (without this) the recording silently dies. We pause on .began and bring the
    // SAME recording back on .ended, so capture continues into the current chunk.

    private func registerAudioNotifications() {
        let nc = NotificationCenter.default
        nc.removeObserver(self) // avoid duplicate registrations across start/stop
        nc.addObserver(self, selector: #selector(handleInterruption(_:)),
                       name: AVAudioSession.interruptionNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleRouteChange(_:)),
                       name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard isRecording,
              let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            // The system took the mic (call/Siri/etc.) and stopped our engine.
            paused = true
            DispatchQueue.main.async { self.isPaused = true }
        case .ended:
            // Interruption over — resume so the recording CONTINUES (a recorder
            // should always come back, regardless of the .shouldResume hint).
            resumeAfterInterruption()
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard isRecording, !paused,
              let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        // A device dropping (headphones/Bluetooth unplugged) can stall the engine.
        if (reason == .oldDeviceUnavailable || reason == .newDeviceAvailable), !engine.isRunning {
            resumeAfterInterruption()
        }
    }

    private func resumeAfterInterruption() {
        guard isRecording else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            paused = false
            DispatchQueue.main.async { self.isPaused = false }
        } catch {
            print("⚠️ RecordingEngine: couldn't resume after interruption — \(error)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func stop() {
        guard isRecording else { return }
        NotificationCenter.default.removeObserver(self)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        paused = false

        // Finalize the last chunk without starting another.
        rolloverChunk(startNext: false)

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.audioLevel = 0
        }
    }

    // MARK: - Chunk files

    private func openNewChunkFile(index: Int) throws {
        let (url, relativePath) = AudioFileStore.shared.newChunkFile(noteID: noteID, index: index)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)

        stateLock.lock()
        audioFile = file
        currentURL = url
        currentRelativePath = relativePath
        framesInChunk = 0
        processingFormat = file.processingFormat
        stateLock.unlock()
    }

    // MARK: - Audio thread

    private func process(_ inBuffer: AVAudioPCMBuffer) {
        if paused { return }
        guard let converter, let procFormat = processingFormat else { return }

        let ratio = procFormat.sampleRate / inBuffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: procFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var convError: NSError?
        let status = converter.convert(to: outBuffer, error: &convError) { _, inStatus in
            if consumed { inStatus.pointee = .noDataNow; return nil }
            consumed = true
            inStatus.pointee = .haveData
            return inBuffer
        }
        guard status != .error, outBuffer.frameLength > 0 else { return }

        // Live transcription feed (SFSpeech append is safe off the main thread).
        onAudioBuffer?(outBuffer)

        let level = Self.rms(outBuffer)

        stateLock.lock()
        try? audioFile?.write(from: outBuffer)
        framesInChunk += outBuffer.frameLength
        totalFrames += outBuffer.frameLength
        let crossed = framesInChunk >= chunkThresholdFrames
        let totalSeconds = Double(totalFrames) / procFormat.sampleRate
        stateLock.unlock()

        DispatchQueue.main.async {
            self.audioLevel = level
            self.elapsed = totalSeconds
        }

        if crossed {
            rolloverChunk(startNext: true)
        }
    }

    private func rolloverChunk(startNext: Bool) {
        stateLock.lock()
        let url = currentURL
        let relativePath = currentRelativePath
        let frames = framesInChunk
        let index = indexCounter
        audioFile = nil // releasing the writer finalizes the AAC file
        stateLock.unlock()

        guard let url else { return }
        let rate = processingFormat?.sampleRate ?? 16000
        let duration = Double(frames) / rate
        let size = AudioFileStore.shared.fileSize(at: url)

        // Skip empty/near-empty trailing chunks.
        if frames > 0 {
            let finalized = FinalizedChunk(index: index, url: url, relativePath: relativePath,
                                           duration: duration, fileSize: size)
            DispatchQueue.main.async { self.onChunkFinalized?(finalized) }
        }

        if startNext {
            let nextIndex = index + 1
            stateLock.lock()
            indexCounter = nextIndex
            stateLock.unlock()
            try? openNewChunkFile(index: nextIndex)
            DispatchQueue.main.async { self.currentChunkIndex = nextIndex }
        }
    }

    // MARK: - Metering

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count {
            let sample = channel[i]
            sum += sample * sample
        }
        let rms = (sum / Float(count)).squareRoot()
        // Map typical speech RMS (~0..0.3) into a 0..1 display range.
        return min(1, rms * 6)
    }
}
