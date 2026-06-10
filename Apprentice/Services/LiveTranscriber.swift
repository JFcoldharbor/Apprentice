//
//  LiveTranscriber.swift
//  Apprentice
//
//  Layer 3 (Services) — on-device live transcript while recording.
//  Consumes the same converted buffers the RecordingEngine writes to disk, so
//  the user sees words appear as they speak. This is a draft view only; the
//  authoritative transcript is the per-chunk Whisper pass. Requires
//  NSSpeechRecognitionUsageDescription in Info.plist.
//

import Foundation
import Speech
import AVFoundation

final class LiveTranscriber: ObservableObject {

    @Published private(set) var transcript = ""
    @Published private(set) var isAvailable = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Ask for speech-recognition authorization. Mic permission is requested elsewhere.
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func start() {
        guard let recognizer, recognizer.isAvailable,
              SFSpeechRecognizer.authorizationStatus() == .authorized else {
            DispatchQueue.main.async { self.isAvailable = false }
            return
        }

        stop()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        DispatchQueue.main.async {
            self.transcript = ""
            self.isAvailable = true
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.transcript = text }
            }
            if error != nil {
                self.stop()
            }
        }
    }

    /// Feed a converted PCM buffer (called from the audio thread).
    func feed(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stop() {
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }
}
