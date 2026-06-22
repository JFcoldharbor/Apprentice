//
//  CoachViewModel.swift
//  Apprentice
//
//  Layer 4 (ViewModels) — drives the coach chat. Persists each turn to SwiftData
//  (the view renders them via @Query), builds the per-turn context, and calls
//  Claude through AIClient. Reads are reactive; this is the send/command path.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class CoachViewModel: ObservableObject {

    @Published var draft = ""
    @Published private(set) var isSending = false
    @Published var errorMessage: String?
    @Published var autoSpeak: Bool = UserDefaults.standard.bool(forKey: "coach_autospeak") {
        didSet { UserDefaults.standard.set(autoSpeak, forKey: "coach_autospeak") }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        draft = ""

        let userMessage = CoachMessage(role: "user", text: text)
        context.insert(userMessage)
        try? context.save()
        AriaMirror.shared.mirrorTurn(role: "user", content: text) // → shared web/phone thread

        isSending = true
        Task { await respond(to: text) }
    }

    private func respond(to text: String) async {
        defer { isSending = false }

        let system = await CoachContext.buildSystemPrompt(query: text, context: context)

        // Prefer the SHARED thread (web War Room + phone) so Aria continues the
        // same cross-device conversation; fall back to local history if offline.
        var history = await AriaMirror.shared.fetchThread()
        if history.isEmpty { history = recentHistory() }
        // Ensure this turn is the final user message (it may not have mirrored yet).
        if history.last?.role != "user" || history.last?.content != text {
            history.append(AIChatMessage(role: "user", content: text))
        }
        while let first = history.first, first.role != "user" { history.removeFirst() }

        do {
            let result = try await AIClient.shared.coachChat(
                system: system,
                messages: history,
                maxTokens: 1500
            )
            let reply = result.text
            // If Aria staged a session this turn, mirror it into the local Sessions
            // list (same id as the shared record) so it shows up immediately.
            if let s = result.scheduled, let when = ISO8601DateFormatter().date(from: s.scheduledFor) {
                SessionManager.shared.ingestScheduled(
                    id: s.id, title: s.title, type: s.type, attendees: s.attendees, scheduledFor: when
                )
            }
            context.insert(CoachMessage(role: "assistant", text: reply))
            try? context.save()
            AriaMirror.shared.mirrorTurn(role: "assistant", content: reply) // → shared thread
            if autoSpeak {
                Task { await VoiceService.shared.speak(reply) }
            }
        } catch {
            errorMessage = error.localizedDescription
            context.insert(CoachMessage(role: "assistant",
                                       text: "⚠️ I couldn't reach the coach — \(error.localizedDescription)"))
            try? context.save()
        }
    }

    /// The last `limit` turns as Claude messages, trimmed so the window starts on
    /// a user turn (the API requires messages[0] to be `user`).
    private func recentHistory(limit: Int = 12) -> [AIChatMessage] {
        var descriptor = FetchDescriptor<CoachMessage>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let recent = ((try? context.fetch(descriptor)) ?? []).reversed()

        var messages = recent.map { AIChatMessage(role: $0.role, content: $0.text) }
        while let first = messages.first, first.role != "user" {
            messages.removeFirst()
        }
        return messages
    }

    func clearConversation() {
        let all = (try? context.fetch(FetchDescriptor<CoachMessage>())) ?? []
        for message in all { context.delete(message) }
        try? context.save()
    }
}
