//
//  CoachService.swift
//  Apprentice
//
//  Layer 3 (Services) — the conversational coach's persona + context renderer.
//  Mirrors the Librium/Maria construct: a static persona prompt plus a per-turn
//  context block built from the founder's actual notes and open action items.
//

import Foundation
import SwiftData

enum CoachPersona {
    // Static persona. Advisor register of James's voice texture: direct,
    // intelligent, dry/playful, respectful — never sycophantic or corporate.
    static let system = """
    You are the Apprentice coach — a sharp, candid business-growth advisor for the \
    founder using this app.

    VOICE: Direct, intelligent, a little dry and playful. Never sycophantic, never \
    corporate filler. You respect the founder enough to tell them the truth and to \
    push back when their thinking is sloppy. Confidence without arrogance; wit \
    without snark at their expense.

    WHAT YOU KNOW: Each turn includes the founder's relevant notes and open action \
    items below. Ground your advice in those and reference specific notes when it \
    helps. If the context doesn't contain something you'd need, say so plainly \
    rather than inventing it — never fabricate a note, number, or commitment.

    HOW YOU ANSWER: Specific and actionable over generic. Lead with the answer, \
    then the why. Keep it tight — a few sharp paragraphs or a short list, not an \
    essay. When you spot a risk or a better move they haven't considered, name it.
    """
}

@MainActor
enum CoachContext {

    /// Build the per-turn context block from the founder's notes + open actions,
    /// ranked by relevance to the query (keyword overlap) then recency.
    static func build(query: String, context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let notes = (try? context.fetch(descriptor)) ?? []

        var lines: [String] = []

        let relevant = Array(ranked(notes, query: query).prefix(4))
        if relevant.isEmpty {
            lines.append("RELEVANT NOTES: (none yet — the founder hasn't recorded any notes.)")
        } else {
            lines.append("RELEVANT NOTES:")
            for note in relevant {
                let body = note.aiSummary.isEmpty
                    ? String(note.fullTranscript.prefix(500))
                    : note.aiSummary
                lines.append("- \(note.title) (\(shortDate(note.createdAt))): \(body)")
            }
        }

        let openActions = notes
            .flatMap { $0.actions }
            .filter { $0.status != .completed && $0.status != .cancelled }
        if !openActions.isEmpty {
            lines.append("")
            lines.append("OPEN ACTION ITEMS:")
            for action in openActions.prefix(12) {
                lines.append("- \(action.title)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func ranked(_ notes: [Note], query: String) -> [Note] {
        let terms = Set(
            query.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 2 }
        )
        guard !terms.isEmpty else { return notes } // no usable terms → most recent

        func score(_ note: Note) -> Int {
            let hay = ([note.title, note.aiSummary, note.fullTranscript] + note.tags)
                .joined(separator: " ")
                .lowercased()
            return terms.reduce(0) { $0 + (hay.contains($1) ? 1 : 0) }
        }
        // Stable sort by score desc; notes already in recency order for ties.
        return notes.enumerated()
            .sorted { lhs, rhs in
                let a = score(lhs.element), b = score(rhs.element)
                return a != b ? a > b : lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
