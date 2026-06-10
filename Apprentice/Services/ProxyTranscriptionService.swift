//
//  ProxyTranscriptionService.swift
//  Apprentice
//
//  Layer 3 (Services) — transcription via the Firebase key-proxy.
//  Posts the raw m4a chunk to POST /transcribe; the proxy adds the OpenAI key
//  and forwards to Whisper. Same TranscriptionService contract as the direct
//  WhisperTranscriptionService, so callers don't care which one is in use.
//

import Foundation

struct ProxyTranscriptionService: TranscriptionService {

    private let maxAttempts = 3

    func transcribe(fileURL: URL) async throws -> String {
        var attempt = 0
        var lastError: Error = TranscriptionError.decoding

        while attempt < maxAttempts {
            do {
                return try await performRequest(fileURL: fileURL)
            } catch let error as TranscriptionError where error.isTerminal {
                throw error
            } catch {
                lastError = error
                attempt += 1
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError
    }

    private func performRequest(fileURL: URL) async throws -> String {
        guard ProxyConfig.isConfigured else { throw TranscriptionError.missingAPIKey }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw TranscriptionError.fileNotFound }

        let audio = try Data(contentsOf: fileURL)
        guard !audio.isEmpty else { throw TranscriptionError.emptyFile }

        let url = URL(string: "\(ProxyConfig.baseURL)/transcribe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.setValue(ProxyConfig.sharedSecret, forHTTPHeaderField: "x-proxy-secret")
        request.setValue(fileURL.lastPathComponent, forHTTPHeaderField: "x-filename")
        // Preferred auth: Firebase ID token. Falls back to the shared secret above.
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = audio

        let (data, response) = try await Self.session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.http(-1, "Invalid response")
        }
        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.http(http.statusCode, message)
        }
        guard let decoded = try? JSONDecoder().decode(ProxyTranscriptResponse.self, from: data) else {
            throw TranscriptionError.decoding
        }
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
}

private struct ProxyTranscriptResponse: Decodable { let text: String }
