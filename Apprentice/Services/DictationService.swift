//
//  DictationService.swift
//  Apprentice
//
//  Layer 3 (Services) — on-device voice input for the coach. Owns an
//  AVAudioEngine tap feeding SFSpeechRecognizer; publishes a live transcript the
//  UI binds into the message draft. Tap to start, tap to stop.
//
//  Turn-taking: SFSpeechRecognizer auto-finalizes after a brief (~1.5s) pause,
//  which cut the founder off when he paused to gather his thoughts. So we DON'T
//  let the recognizer's finalize end the turn — on each finalize we fold the text
//  into an accumulator and restart recognition to keep listening, and a 3-second
//  SILENCE TIMER (reset on every bit of speech) decides when the turn is actually
//  over. Tap still interrupts immediately.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class DictationService: ObservableObject {

    static let shared = DictationService()

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""

    /// How long the founder can pause (gather his thoughts) before the turn ends.
    var silenceInterval: TimeInterval = 3.0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var routeWatchdog: Timer?
    private var bufferSeen = false // did the audio tap deliver any buffer this start?
    private var accumulated = ""   // finalized text from earlier segments this turn
    private var ending = false     // true once the silence timer fires → real stop

    private init() {}

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        guard !isListening else { return }
        guard await Self.requestSpeechAuth(), await Self.requestMicAuth(),
              let recognizer, recognizer.isAvailable else { return }

        transcript = ""
        accumulated = ""
        ending = false
        bufferSeen = false

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            // Defensive: a lingering tap from a prior session would make this
            // installTap crash ("CreateRecordingTap: nullptr == Tap()").
            input.removeTap(onBus: 0)
            let format = input.outputFormat(forBus: 0)
            // `signalledBuffer` lives only on the audio render thread (the tap
            // closure), so it needs no synchronization; it flips `bufferSeen` on
            // main exactly once, the first time real audio arrives.
            var signalledBuffer = false
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
                if !signalledBuffer {
                    signalledBuffer = true
                    DispatchQueue.main.async { self?.bufferSeen = true }
                }
            }
            engine.prepare()
            try engine.start()
            isListening = true
            armRouteWatchdog()
            beginSegment()
        } catch {
            print("⚠️ DictationService: \(error.localizedDescription)")
            stop()
        }
    }

    /// Start (or restart) a recognition task on the already-running audio engine.
    /// Restarting on each finalize is what lets us listen ACROSS pauses.
    private func beginSegment() {
        guard isListening, !ending, let recognizer else { return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let segment = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                Task { @MainActor in
                    let combined = (self.accumulated + " " + segment).trimmingCharacters(in: .whitespaces)
                    self.transcript = combined
                    if !segment.trimmingCharacters(in: .whitespaces).isEmpty { self.armSilence() }
                    if isFinal {
                        // The recognizer ended this segment (a pause). Keep its text
                        // and start a fresh task so continued speech is still captured;
                        // the 3s silence timer — not this finalize — ends the turn.
                        self.accumulated = combined
                        self.task = nil
                        if self.isListening && !self.ending { self.beginSegment() }
                    }
                }
            } else if error != nil {
                // A genuine recognition error — end the turn rather than loop.
                Task { @MainActor in if self.isListening { self.endTurn() } }
            }
        }
    }

    /// If the audio tap delivers no buffers shortly after the engine starts, the
    /// input route never came up — a cold-start race right after the session
    /// switched category (e.g. just after Aria finished speaking, or the very
    /// first listen when the sheet opens). End the turn so the voice sheet
    /// re-kicks a fresh start on the now-warm route, instead of sitting in
    /// "Listening…" with a dead mic until the founder taps the orb.
    private func armRouteWatchdog() {
        routeWatchdog?.invalidate()
        routeWatchdog = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.checkRoute() }
        }
    }

    private func checkRoute() {
        guard isListening, !ending, !bufferSeen else { return }
        endTurn() // → stop() → isListening = false → the sheet schedules a fresh start
    }

    /// Reset the silence countdown; only true silence (no new speech for
    /// `silenceInterval`) ends the turn.
    private func armSilence() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.endTurn() }
        }
    }

    private func endTurn() {
        guard !ending else { return }
        ending = true
        stop() // → isListening = false → the voice sheet sends what was said
    }

    func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        routeWatchdog?.invalidate()
        routeWatchdog = nil
        ending = true
        if engine.isRunning {
            engine.stop()
        }
        // Always remove the tap (even if the engine never started) so a later
        // start() can't crash on a leftover tap.
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permissions

    static func requestSpeechAuth() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
    }

    static func requestMicAuth() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}
