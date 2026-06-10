//
//  TranscriptionService.swift
//  Apprentice
//
//  Layer 3 (Services) — accurate speech-to-text for recorded chunks.
//  Protocol + OpenAI Whisper implementation with bounded retry and generous
//  timeouts (the legacy 15s request timeout truncated large uploads).
//

import Foundation

protocol TranscriptionService: Sendable {
    /// Transcribe an audio file to text. Throws on unrecoverable failure.
    func transcribe(fileURL: URL) async throws -> String
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case fileNotFound
    case emptyFile
    case http(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No OpenAI API key configured (set OPENAI_API_KEY)."
        case .fileNotFound: return "Audio file not found."
        case .emptyFile: return "Audio file is empty."
        case .http(let code, let message): return "Transcription failed (HTTP \(code)): \(message)"
        case .decoding: return "Could not read the transcription response."
        }
    }

    /// Client errors that should not be retried.
    var isTerminal: Bool {
        switch self {
        case .missingAPIKey, .fileNotFound, .emptyFile: return true
        case .http(let code, _): return (400..<500).contains(code) && code != 429
        case .decoding: return false
        }
    }
}

struct WhisperTranscriptionService: TranscriptionService {

    private let baseURL = "https://api.openai.com/v1"
    private let model = "whisper-1"
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
                    // Linear backoff: 1s, 2s.
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }
        throw lastError
    }

    // MARK: - Request

    private func performRequest(fileURL: URL) async throws -> String {
        let apiKey = Secrets.openAIKey
        guard !apiKey.isEmpty else { throw TranscriptionError.missingAPIKey }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw TranscriptionError.fileNotFound }

        let audioData = try Data(contentsOf: fileURL)
        guard !audioData.isEmpty else { throw TranscriptionError.emptyFile }

        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = fileURL.lastPathComponent
        body.appendField(boundary: boundary, name: "file", filename: filename,
                         contentType: "audio/m4a", fileData: audioData)
        body.appendField(boundary: boundary, name: "model", value: model)
        body.appendField(boundary: boundary, name: "response_format", value: "json")
        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await Self.session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.http(-1, "Invalid response")
        }
        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.http(http.statusCode, message)
        }
        guard let decoded = try? JSONDecoder().decode(WhisperResponse.self, from: data) else {
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

private struct WhisperResponse: Decodable { let text: String }

// MARK: - Multipart helpers

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }

    mutating func appendField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendField(boundary: String, name: String, filename: String,
                              contentType: String, fileData: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        append(fileData)
        append("\r\n")
    }
}
