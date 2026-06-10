//
//  AIClient.swift
//  Apprentice
//
//  Layer 3 (Services) — the app's gateway to Claude, via the Firebase key-proxy
//  (POST /chat). Provider-agnostic to the rest of the app: callers pass system +
//  messages + tier and get text, or pass a JSON schema and get a decoded value.
//
//  Tier maps to a Claude model server-side:
//    .classifier → claude-haiku-4-5   (cheap routing)
//    .standard   → claude-sonnet-4-6  (default work, e.g. note enrichment)
//    .synthesis  → claude-opus-4-8    (heavy cross-note strategy)
//

import Foundation

struct AIChatMessage: Codable {
    let role: String   // "user" | "assistant"
    let content: String
}

enum AITier: String {
    case classifier
    case standard = "default"
    case synthesis
}

enum AIError: LocalizedError {
    case notConfigured
    case http(Int, String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI proxy not configured (set PROXY_BASE_URL)."
        case .http(let code, let message): return "AI request failed (\(code)): \(message)"
        case .decoding: return "Could not read the AI response."
        }
    }
}

struct AIClient {

    static let shared = AIClient()

    /// Free-text completion.
    func chatText(system: String?,
                  messages: [AIChatMessage],
                  tier: AITier = .standard,
                  maxTokens: Int = 4096) async throws -> String {
        try await post(system: system, messages: messages, tier: tier, maxTokens: maxTokens, schema: nil).text
    }

    /// Structured completion — the proxy constrains Claude's output to `schema`,
    /// and the returned JSON text is decoded into `T`.
    func chatJSON<T: Decodable>(_ type: T.Type,
                                system: String?,
                                messages: [AIChatMessage],
                                schema: [String: Any],
                                tier: AITier = .standard,
                                maxTokens: Int = 4096) async throws -> T {
        let response = try await post(system: system, messages: messages, tier: tier, maxTokens: maxTokens, schema: schema)
        guard let jsonData = response.text.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(T.self, from: jsonData) else {
            throw AIError.decoding
        }
        return decoded
    }

    // MARK: - Transport

    private struct ChatResponse: Decodable { let text: String }

    private func post(system: String?,
                      messages: [AIChatMessage],
                      tier: AITier,
                      maxTokens: Int,
                      schema: [String: Any]?) async throws -> ChatResponse {
        guard ProxyConfig.isConfigured else { throw AIError.notConfigured }

        var body: [String: Any] = [
            "tier": tier.rawValue,
            "max_tokens": maxTokens,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        if let system, !system.isEmpty { body["system"] = system }
        if let schema { body["response_format"] = ["type": "json_schema", "schema": schema] }

        let url = URL(string: "\(ProxyConfig.baseURL)/chat")!
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
            throw AIError.http(-1, "Invalid response")
        }
        guard http.statusCode == 200 else {
            throw AIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw AIError.decoding
        }
        return decoded
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
