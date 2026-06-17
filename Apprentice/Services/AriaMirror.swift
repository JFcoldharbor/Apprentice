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

    /// Mirror a note's FULL debrief — summary + insights + decisions + action
    /// items — so web Aria can actually debrief the meeting, not just see a line.
    /// Idempotent (upsert by note id); used both on enrichment and on the launch
    /// backfill that heals any session whose mirror was previously missed.
    @MainActor
    func mirrorNote(from note: Note) {
        let summary = note.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { return }
        let actions = note.actions.map { ["title": $0.title, "detail": $0.detail, "assignee": $0.assignee] }
        let decisions = note.decisions.map { ["title": $0.title, "rationale": $0.rationale] }
        let when = ISO8601DateFormatter().string(from: note.scheduledFor ?? note.createdAt)
        Task {
            await post([
                "kind": "note",
                "noteId": note.id.uuidString,
                "title": note.title,
                "summary": summary,
                "insights": note.insights,
                "actions": actions,
                "decisions": decisions,
                "attendees": note.attendees,   // the meeting's name log
                "date": when,                  // when it happened
            ])
        }
    }

    /// Remove a note (session) from the shared memory — called when the founder
    /// deletes a mistakenly-recorded note on the phone, so Aria forgets it too.
    func deleteNote(noteId: String) {
        guard !noteId.isEmpty else { return }
        Task { await post(["kind": "delete-note", "noteId": noteId]) }
    }

    // MARK: - Scheduled sessions (shared upcoming list, phone + web)

    /// Stage / update an upcoming session in the shared list.
    func upsertScheduledSession(id: String, title: String, type: String, attendees: [String], scheduledFor: Date) {
        let iso = ISO8601DateFormatter().string(from: scheduledFor)
        Task {
            await post(path: "/scheduledSessions", [
                "action": "upsert", "id": id, "title": title, "type": type,
                "attendees": attendees, "scheduledFor": iso,
            ])
        }
    }

    /// Remove an upcoming session from the shared list (started or cancelled).
    func deleteScheduledSession(id: String) {
        guard !id.isEmpty else { return }
        Task { await post(path: "/scheduledSessions", ["action": "delete", "id": id]) }
    }

    /// Pull the shared upcoming list. Returns [] on any error.
    func fetchScheduledSessions() async -> [RemoteScheduled] {
        guard ProxyConfig.isConfigured,
              let url = URL(string: "\(ProxyConfig.baseURL)/scheduledSessions") else { return [] }
        var request = URLRequest(url: url) // GET
        request.setValue(ProxyConfig.sharedSecret, forHTTPHeaderField: "x-proxy-secret")
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(ScheduledResponse.self, from: data)
            let parser = ISO8601DateFormatter()
            return decoded.sessions.compactMap { s -> RemoteScheduled? in
                guard let when = parser.date(from: s.scheduledFor) else { return nil }
                return RemoteScheduled(id: s.id, title: s.title, type: s.type, attendees: s.attendees, scheduledFor: when)
            }
        } catch {
            return []
        }
    }
    struct RemoteScheduled { let id: String; let title: String; let type: String; let attendees: [String]; let scheduledFor: Date }
    private struct ScheduledResponse: Decodable {
        let sessions: [Item]
        struct Item: Decodable { let id: String; let title: String; let type: String; let attendees: [String]; let scheduledFor: String }
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

    private func post(path: String = "/mirror", _ body: [String: Any]) async {
        guard ProxyConfig.isConfigured, let url = URL(string: "\(ProxyConfig.baseURL)\(path)") else { return }
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
