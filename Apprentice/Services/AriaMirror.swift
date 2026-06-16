//
//  AriaMirror.swift
//  Apprentice
//
//  Layer 3 (Services) — mirrors what the founder captures on the phone into the
//  SHARED Aria memory (POST /mirror on the proxy), so the web War Room's Aria
//  sees it too. Write-only, fire-and-forget, best-effort: a failure here must
//  never disrupt the local SwiftData flow.
//
//    coach turns → aria/founder/conversation  (one continuous thread, web + phone)
//    note summaries → aria/founder/notes       (founder's voice notes as memory)
//
//  Same transport as AIClient: proxy base URL + shared-secret + Firebase ID token.
//

import Foundation

struct AriaMirror {

    static let shared = AriaMirror()

    /// Mirror one coach turn into the shared conversation thread.
    func mirrorTurn(role: String, content: String) {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task { await post(["kind": "turn", "role": role, "content": text]) }
    }

    /// Mirror a note's title + AI summary (upserted by note id, so re-enrichment
    /// updates rather than duplicates).
    func mirrorNote(noteId: String, title: String, summary: String) {
        let s = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        Task { await post(["kind": "note", "noteId": noteId, "title": title, "summary": s]) }
    }

    /// Fetch the SHARED conversation thread (web War Room + phone) so the coach
    /// can continue the same conversation across devices. Returns [] on any error.
    func fetchThread() async -> [AIChatMessage] {
        guard ProxyConfig.isConfigured, let url = URL(string: "\(ProxyConfig.baseURL)/mirror") else { return [] }
        var request = URLRequest(url: url) // GET
        request.setValue(ProxyConfig.sharedSecret, forHTTPHeaderField: "x-proxy-secret")
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(ThreadResponse.self, from: data)
            return decoded.turns.map { AIChatMessage(role: $0.role, content: $0.content) }
        } catch {
            return []
        }
    }
    private struct ThreadResponse: Decodable {
        let turns: [Turn]
        struct Turn: Decodable { let role: String; let content: String }
    }

    // MARK: - Transport (mirrors AIClient)

    private func post(_ body: [String: Any]) async {
        guard ProxyConfig.isConfigured, let url = URL(string: "\(ProxyConfig.baseURL)/mirror") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ProxyConfig.sharedSecret, forHTTPHeaderField: "x-proxy-secret")
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request) // best-effort; ignore result
    }
}
