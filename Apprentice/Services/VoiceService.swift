//
//  VoiceService.swift
//  Apprentice
//
//  Layer 3 (Services) — the coach's voice. Sends text to the proxy /tts endpoint
//  (ElevenLabs Flash, streamed), plays the returned audio. v1 fetches the full
//  clip then plays via AVAudioPlayer (robust, low-latency on short replies);
//  a future upgrade streams Claude tokens straight into ElevenLabs over a
//  websocket for sentence-level playback.
//

import Foundation
import AVFoundation

@MainActor
final class VoiceService: NSObject, ObservableObject {

    static let shared = VoiceService()

    @Published private(set) var isSpeaking = false

    private var player: AVAudioPlayer?

    private override init() { super.init() }

    /// Speak `text`. No-ops if the proxy isn't configured or text is empty.
    func speak(_ text: String, voiceId: String? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ProxyConfig.isConfigured, !trimmed.isEmpty else { return }
        stop()
        do {
            let audio = try await fetchAudio(trimmed, voiceId: voiceId)
            try play(audio)
        } catch {
            print("⚠️ VoiceService: \(error.localizedDescription)")
            isSpeaking = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isSpeaking = false
    }

    // MARK: - Network

    private func fetchAudio(_ text: String, voiceId: String?) async throws -> Data {
        var body: [String: Any] = ["text": text]
        // Use the explicit voice, else the user's saved brand voice, else proxy default.
        let resolvedVoice = voiceId ?? UserDefaults.standard.string(forKey: "coach_voice_id")
        if let resolvedVoice, !resolvedVoice.isEmpty { body["voiceId"] = resolvedVoice }

        let url = URL(string: "\(ProxyConfig.baseURL)/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ProxyConfig.sharedSecret, forHTTPHeaderField: "x-proxy-secret")
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VoiceError.network("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw VoiceError.network("tts \(http.statusCode)")
        }
        return data
    }

    // MARK: - Playback

    private func play(_ data: Data) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)

        let newPlayer = try AVAudioPlayer(data: data)
        newPlayer.delegate = self
        player = newPlayer
        isSpeaking = true
        newPlayer.play()
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()
}

enum VoiceError: LocalizedError {
    case network(String)
    var errorDescription: String? {
        switch self {
        case .network(let message): return "Voice request failed: \(message)"
        }
    }
}

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
