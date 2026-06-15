//
//  CoachService.swift
//  Apprentice
//
//  Layer 3 (Services) — Aria's persona + the per-turn context renderer.
//  CoachContext is the SINGLE source of what Aria can "see": the founder profile,
//  every recorded session, every connected document (data room + uploads), and
//  open action items. Used by the voice orb (AriaVoiceSheet), the text chat
//  (CoachViewModel), and the legacy speech path — so enriching it here makes Aria
//  aware everywhere.
//

import Foundation
import SwiftData

enum CoachPersona {
    static let system = """
    You are Aria — a sharp, candid business-growth advisor for the founder using \
    this app.

    VOICE: Direct, intelligent, a little dry and playful. Never sycophantic, never \
    corporate filler. You respect the founder enough to tell them the truth and to \
    push back when their thinking is sloppy. Confidence without arrogance; wit \
    without snark at their expense. Spoken answers should be conversational and \
    concise — you're often heard out loud.

    WHAT YOU CAN SEE: Every turn the context below gives you the founder's profile, \
    their recorded sessions, their connected documents (investor data room + \
    uploads), and their open action items. This IS your memory of them — treat it \
    as things you already know. When they ask what you can see, summarize it. \
    Reference specific sessions and documents by name when it helps. Only if the \
    context is genuinely empty should you say you don't have anything yet — and \
    never fabricate a session, document, number, or commitment that isn't there.

    HOW YOU ANSWER: Specific and actionable over generic. Lead with the answer, \
    then the why. Keep it tight. When you spot a risk or a better move they haven't \
    considered, name it.
    """
}

@MainActor
enum CoachContext {

    /// Build the per-turn context block: profile + sessions + documents + open
    /// actions, ranked by relevance to the query.
    static func build(query: String, context: ModelContext) -> String {
        let blocks = [
            profileBlock(),
            sessionsBlock(query: query, context: context),
            documentsBlock(query: query),
            actionsBlock(context: context)
        ]
        return blocks.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    // MARK: - Profile

    private static func profileBlock() -> String {
        guard let p = FounderProfileManager.shared.founderProfile else {
            return "FOUNDER: (profile not set up yet)"
        }
        var lines = ["FOUNDER:"]
        lines.append("- Name: \(p.founderName)")
        if let biz = p.businessName, !biz.isEmpty { lines.append("- Business: \(biz)") }
        lines.append("- Industry: \(p.industry)")
        lines.append("- Stage: \(p.businessStage.rawValue)")
        if !p.founderRole.isEmpty { lines.append("- Role: \(p.founderRole)") }
        if !p.currentGoals.isEmpty { lines.append("- Goals: \(p.currentGoals.prefix(4).joined(separator: "; "))") }
        if !p.currentChallenges.isEmpty { lines.append("- Challenges: \(p.currentChallenges.prefix(4).joined(separator: "; "))") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Sessions

    private static func sessionsBlock(query: String, context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let notes = (try? context.fetch(descriptor)) ?? []
        guard !notes.isEmpty else { return "SESSIONS: none recorded yet." }

        var lines = ["SESSIONS (\(notes.count) recorded):"]

        // Top relevant get a summary; the rest are listed as a manifest so Aria
        // knows the full scope of the founder's activity.
        let relevant = Array(rank(notes, query: query, text: { [$0.title, $0.aiSummary, $0.fullTranscript] + $0.tags }).prefix(4))
        let relevantIDs = Set(relevant.map { $0.id })
        for note in relevant {
            let body = note.aiSummary.isEmpty ? String(note.fullTranscript.prefix(400)) : note.aiSummary
            lines.append("- \(note.title) (\(shortDate(note.createdAt))): \(body)")
        }
        let others = notes.filter { !relevantIDs.contains($0.id) }.prefix(10)
        if !others.isEmpty {
            lines.append("Other sessions: " + others.map { "\($0.title) (\(shortDate($0.createdAt)))" }.joined(separator: " · "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Documents

    private static func documentsBlock(query: String) -> String {
        let docs = loadDocuments()
        guard !docs.isEmpty else { return "DOCUMENTS: none connected yet." }

        var lines = ["DOCUMENTS (\(docs.count) in memory):"]

        let relevant = Array(rank(docs, query: query, text: {
            [$0.title, $0.originalName, $0.extractedText ?? ""] + $0.businessInsights
        }).prefix(4))
        let relevantIDs = Set(relevant.map { $0.id })
        for doc in relevant {
            // Prefer the document's actual text (so Aria can read specifics like an
            // EIN number), then any extracted insights, then just the title.
            if let text = doc.extractedText, !text.isEmpty {
                var body = String(text.prefix(1500))
                if !doc.businessInsights.isEmpty {
                    body += "\n  Insights: " + doc.businessInsights.prefix(3).joined(separator: "; ")
                }
                lines.append("- \(doc.title): \(body)")
            } else if !doc.businessInsights.isEmpty {
                lines.append("- \(doc.title): \(doc.businessInsights.prefix(3).joined(separator: "; "))")
            } else {
                lines.append("- \(doc.title)")
            }
        }
        let others = docs.filter { !relevantIDs.contains($0.id) }.prefix(30)
        if !others.isEmpty {
            lines.append("Also on file: " + others.map { $0.title }.joined(separator: " · "))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Open actions

    private static func actionsBlock(context: ModelContext) -> String {
        let descriptor = FetchDescriptor<NoteAction>()
        let open = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.status != .completed && $0.status != .cancelled }
        guard !open.isEmpty else { return "" }
        var lines = ["OPEN ACTION ITEMS:"]
        for a in open.prefix(15) { lines.append("- \(a.title)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Ranking

    private static func terms(_ query: String) -> Set<String> {
        Set(query.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 })
    }

    private static func rank<T>(_ items: [T], query: String, text: (T) -> [String]) -> [T] {
        let q = terms(query)
        guard !q.isEmpty else { return items } // no usable terms → keep given order (recency)
        func score(_ item: T) -> Int {
            let hay = text(item).joined(separator: " ").lowercased()
            return q.reduce(0) { $0 + (hay.contains($1) ? 1 : 0) }
        }
        return items.enumerated()
            .sorted { a, b in
                let sa = score(a.element), sb = score(b.element)
                return sa != sb ? sa > sb : a.offset < b.offset
            }
            .map { $0.element }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Document loading (cached by file modification date)

    private static var docCache: (mtime: Date, docs: [ProcessedDocument])?

    private static func loadDocuments() -> [ProcessedDocument] {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProcessedDocuments")
        let url = dir.appendingPathComponent("processed_documents.json")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let mtime = attrs[.modificationDate] as? Date else {
            return []
        }
        if let cache = docCache, cache.mtime == mtime { return cache.docs }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url),
              let docs = try? decoder.decode([ProcessedDocument].self, from: data) else {
            return []
        }
        docCache = (mtime, docs)
        return docs
    }
}
