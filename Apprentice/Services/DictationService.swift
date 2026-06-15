//
//  DictationService.swift
//  Apprentice
//
//  Layer 3 (Services) — on-device voice input for the coach. Owns an
//  AVAudioEngine tap feeding SFSpeechRecognizer; publishes a live transcript the
//  UI binds into the message draft. Tap to start, tap to stop.
//

import Foundation
import Speech
import AVFoundation

@MainActor
final class DictationService: ObservableObject {

    static let shared = DictationService()

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private init() {}

    func toggle() async {
        if isListening { stop() } else { await start() }
    }

    func start() async {
        guard !isListening else { return }
        guard await Self.requestSpeechAuth(), await Self.requestMicAuth(),
              let recognizer, recognizer.isAvailable else { return }

        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            // Defensive: a lingering tap from a prior session would make this
            // installTap crash ("CreateRecordingTap: nullptr == Tap()").
            input.removeTap(onBus: 0)
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isListening = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    Task { @MainActor in self.transcript = text }
                }
                if error != nil || (result?.isFinal ?? false) {
                    Task { @MainActor in self.stop() }
                }
            }
        } catch {
            print("⚠️ DictationService: \(error.localizedDescription)")
            stop()
        }
    }

    func stop() {
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
