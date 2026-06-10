//
//  NoteEnrichmentService.swift
//  Apprentice
//
//  Layer 3 (Services) — turns a finished transcript into intelligence.
//  Sends the transcript to Claude (via AIClient/proxy) with a constrained schema
//  and writes the summary, insights, action items, and decisions back onto the
//  SwiftData Note. This is the Phase 2 seam hung off note assembly.
//

import Foundation
import SwiftData

@MainActor
enum NoteEnrichmentService {

    // Analysis persona. Sharp business analyst — not the conversational coach
    // voice (that persona is for the chat feature).
    private static let persona = """
    You are the analysis engine inside Apprentice, an AI assistant for founders and \
    business operators. You are given the transcript of a meeting or voice note. \
    Produce a tight, business-focused analysis: a crisp executive summary, the key \
    strategic insights, concrete action items (with an owner if one is stated), and \
    any decisions that were made. Be specific and concise — no filler, and do not \
    restate the transcript. If the transcript is thin, return brief but honest \
    output rather than inventing detail. Suggest a short, specific title for the note.
    """

    // MARK: - Schema (kept in pieces so the type-checker stays happy)

    private static var schema: [String: Any] {
        let actionItem: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "detail": ["type": "string"],
                "assignee": ["type": "string"],
                "priority": ["type": "string", "enum": ["Low", "Medium", "High", "Critical"]],
            ],
            "required": ["title", "detail", "assignee", "priority"],
        ]
        let decision: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "rationale": ["type": "string"],
            ],
            "required": ["title", "rationale"],
        ]
        return [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "summary": ["type": "string"],
                "insights": ["type": "array", "items": ["type": "string"]],
                "actions": ["type": "array", "items": actionItem],
                "decisions": ["type": "array", "items": decision],
            ],
            "required": ["title", "summary", "insights", "actions", "decisions"],
        ]
    }

    // MARK: - Result DTO

    private struct Result: Decodable {
        let title: String
        let summary: String
        let insights: [String]
        let actions: [ActionDTO]
        let decisions: [DecisionDTO]

        struct ActionDTO: Decodable {
            let title: String
            let detail: String
            let assignee: String
            let priority: String
        }
        struct DecisionDTO: Decodable {
            let title: String
            let rationale: String
        }
    }

    // MARK: - Entry point

    /// Analyze a note's transcript and write results back. No-ops if there's no
    /// transcript, or if already enriched and `force` is false.
    @discardableResult
    static func enrich(_ note: Note, context: ModelContext, force: Bool = false) async -> Bool {
        let transcript = note.fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return false }
        if !force && !note.aiSummary.isEmpty { return false }

        do {
            let result = try await AIClient.shared.chatJSON(
                Result.self,
                system: persona,
                messages: [AIChatMessage(role: "user", content: "Transcript:\n\n\(transcript)")],
                schema: schema,
                tier: .standard
            )
            apply(result, to: note, context: context)
            return true
        } catch {
            print("⚠️ NoteEnrichmentService: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Write-back

    private static func apply(_ result: Result, to note: Note, context: ModelContext) {
        // Replace previously AI-generated children; keep anything the user added.
        for action in note.actions where action.isAIGenerated { context.delete(action) }
        for decision in note.decisions where decision.isAIGenerated { context.delete(decision) }

        note.aiSummary = result.summary
        note.insights = result.insights
        // Only adopt the AI title if the note still has the auto-generated name.
        if note.title.hasPrefix("Note · "), !result.title.isEmpty {
            note.title = result.title
        }

        for dto in result.actions {
            let action = NoteAction(
                title: dto.title,
                detail: dto.detail,
                assignee: dto.assignee,
                priority: NotePriority(rawValue: dto.priority) ?? .medium,
                isAIGenerated: true
            )
            action.note = note
            context.insert(action)
        }
        for dto in result.decisions {
            let decision = NoteDecision(
                title: dto.title,
                rationale: dto.rationale,
                isAIGenerated: true
            )
            decision.note = note
            context.insert(decision)
        }

        note.updatedAt = Date()
        try? context.save()
    }
}
