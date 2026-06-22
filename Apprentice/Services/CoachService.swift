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

    /// Full system prompt for a turn: persona + context, with on-demand document
    /// retrieval. A cheap Haiku router reads the document catalog + the founder's
    /// message and decides which docs Aria needs in FULL; those are injected
    /// whole (budget-capped), the rest stay as a one-line manifest. This is the
    /// async entry point both live paths (voice + text chat) call.
    static func buildSystemPrompt(query: String, context: ModelContext) async -> String {
        let docs = loadDocuments()
        let selected = await selectDocuments(query: query, docs: docs)
        let body = [
            profileBlock(),
            sessionsBlock(query: query, context: context),
            documentsBlock(query: query, docs: docs, fullTextIdx: selected),
            actionsBlock(context: context)
        ].filter { !$0.isEmpty }.joined(separator: "\n\n")
        return CoachPersona.system + "\n\n" + body
    }

    /// Synchronous context block (no document router) — kept for legacy callers.
    /// Documents fall back to relevance-window excerpts of the top-ranked items.
    static func build(query: String, context: ModelContext) -> String {
        let blocks = [
            profileBlock(),
            sessionsBlock(query: query, context: context),
            documentsBlock(query: query, docs: loadDocuments(), fullTextIdx: []),
            actionsBlock(context: context)
        ]
        return blocks.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    // MARK: - Document router (on-demand full-text retrieval)

    private struct DocSelection: Decodable { let ids: [String] }

    /// Cheap Haiku pass: given the document catalog + the founder's message, return
    /// the indices of docs whose FULL text is needed. Gated — skipped for small
    /// catalogs (≤3 docs) where the manifest + excerpts already suffice — and
    /// best-effort: any failure falls back to windowed excerpts (empty set).
    private static func selectDocuments(query: String, docs: [ProcessedDocument]) async -> Set<Int> {
        guard docs.count > 3, ProxyConfig.isConfigured else { return [] }
        let catalog = docs.enumerated()
            .map { manifestLine($0.offset, $0.element) }
            .joined(separator: "\n")
        let sys = """
        You are a retrieval router for an AI business advisor. Below is a catalog of \
        the founder's documents, each tagged with an ID like [D3]. Given the \
        founder's message, return ONLY the IDs whose FULL text is needed to answer \
        accurately and specifically. Prefer 0–3 IDs. Return an empty list if the \
        catalog lines already give enough, or if nothing is relevant. Do not explain.
        """
        let user = "CATALOG:\n\(catalog)\n\nFOUNDER MESSAGE:\n\(query)"
        let schema: [String: Any] = [
            "type": "object",
            "properties": ["ids": ["type": "array", "items": ["type": "string"]]],
            "required": ["ids"]
        ]
        do {
            let sel = try await AIClient.shared.chatJSON(
                DocSelection.self,
                system: sys,
                messages: [AIChatMessage(role: "user", content: user)],
                schema: schema,
                tier: .classifier,
                maxTokens: 200)
            var out = Set<Int>()
            for id in sel.ids {
                if let n = Int(id.filter(\.isNumber)), n >= 1, n <= docs.count { out.insert(n - 1) }
            }
            return out
        } catch {
            return []
        }
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

    /// Per-doc full-text caps (chars). Total full-text across selected docs is held
    /// under `fullTextBudget` so a few large PDFs can't flood the window.
    private static let perDocFullCap = 6000
    private static let fullTextBudget = 12000
    private static let windowWidth = 1200

    /// `fullTextIdx` = indices (into `docs`) the router chose to inject in full.
    /// When non-empty, those docs appear whole (budget-capped) and everything else
    /// is a one-line manifest. When empty, the top-ranked docs get relevance-window
    /// excerpts (the passage around the query hit, not the head) + a manifest.
    private static func documentsBlock(query: String, docs: [ProcessedDocument], fullTextIdx: Set<Int>) -> String {
        guard !docs.isEmpty else { return "DOCUMENTS: none connected yet." }

        var lines = ["DOCUMENTS (\(docs.count) connected) — full text is shown for ★ items; the rest are a catalog you can ask me to open:"]
        var expandedIdx = Set<Int>()

        if !fullTextIdx.isEmpty {
            // Router picked specific docs — inject them whole, within budget.
            var budget = fullTextBudget
            for i in fullTextIdx.sorted() where docs.indices.contains(i) {
                let doc = docs[i]
                guard let text = doc.extractedText, !text.isEmpty, budget > 0 else { continue }
                let body = String(text.prefix(min(perDocFullCap, budget)))
                budget -= body.count
                expandedIdx.insert(i)
                lines.append("★ [\(handle(i))] \(doc.title) — \(sourceLabel(doc.sourceId)) — full text:\n\(body)")
            }
        } else {
            // No explicit selection — relevance-window the top-ranked docs.
            let ranked = rank(Array(docs.enumerated()), query: query, text: {
                [$0.element.title, $0.element.originalName, $0.element.extractedText ?? ""] + $0.element.businessInsights
            }).prefix(4)
            for entry in ranked {
                let doc = entry.element
                guard let text = doc.extractedText, !text.isEmpty else {
                    if !doc.businessInsights.isEmpty {
                        lines.append("★ [\(handle(entry.offset))] \(doc.title): \(doc.businessInsights.prefix(3).joined(separator: "; "))")
                        expandedIdx.insert(entry.offset)
                    }
                    continue
                }
                var body = excerpt(text, query: query, width: windowWidth)
                if !doc.businessInsights.isEmpty {
                    body += "\n  Insights: " + doc.businessInsights.prefix(3).joined(separator: "; ")
                }
                lines.append("★ [\(handle(entry.offset))] \(doc.title) — \(sourceLabel(doc.sourceId)):\n\(body)")
                expandedIdx.insert(entry.offset)
            }
        }

        // Manifest of everything not expanded above, so Aria always knows the full
        // catalog (and can say "ask me to open X").
        let manifest = docs.enumerated()
            .filter { !expandedIdx.contains($0.offset) }
            .prefix(60)
            .map { manifestLine($0.offset, $0.element) }
        if !manifest.isEmpty {
            lines.append("CATALOG (ask to open any of these):")
            lines.append(contentsOf: manifest)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Document helpers

    private static func handle(_ i: Int) -> String { "D\(i + 1)" }

    private static func sourceLabel(_ sourceId: String?) -> String {
        switch sourceId {
        case "stitch-dataroom": return "Investor Data Room"
        case .some(let s) where !s.isEmpty: return s
        default: return "Upload"
        }
    }

    /// One catalog line: ID · title · source · size · short descriptor.
    private static func manifestLine(_ i: Int, _ doc: ProcessedDocument) -> String {
        let kb = max(1, doc.fileSize / 1024)
        let base = "[\(handle(i))] \(doc.title) · \(sourceLabel(doc.sourceId)) · \(kb)KB"
        let desc = descriptor(doc)
        return desc.isEmpty ? base : base + " — " + desc
    }

    /// A short hint of what a doc contains: first insight, else its first line.
    private static func descriptor(_ doc: ProcessedDocument) -> String {
        if let first = doc.businessInsights.first, !first.isEmpty { return String(first.prefix(100)) }
        if let text = doc.extractedText {
            let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return String(trimmed.prefix(100)) }
        }
        return ""
    }

    /// Return a `width`-char window of `text` centered on the first query-term hit
    /// (case-insensitive), with ellipses where it's clipped. No hit → the head.
    private static func excerpt(_ text: String, query: String, width: Int) -> String {
        let qterms = terms(query)
        var firstHit: String.Index?
        for term in qterms {
            if let r = text.range(of: term, options: .caseInsensitive) {
                if firstHit == nil || r.lowerBound < firstHit! { firstHit = r.lowerBound }
            }
        }
        guard let hit = firstHit else { return String(text.prefix(width)) }
        let hitOffset = text.distance(from: text.startIndex, to: hit)
        let startOffset = max(0, hitOffset - width / 3)
        let startIdx = text.index(text.startIndex, offsetBy: startOffset, limitedBy: text.endIndex) ?? text.startIndex
        let endIdx = text.index(startIdx, offsetBy: width, limitedBy: text.endIndex) ?? text.endIndex
        var slice = String(text[startIdx..<endIdx])
        if startOffset > 0 { slice = "…" + slice }
        if endIdx < text.endIndex { slice += "…" }
        return slice
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
        // Primary: distinct query terms matched. Tiebreak: term density (matches per
        // 1k chars) so a short on-point doc beats a long one that merely happens to
        // contain the same terms — kills the long-document bias. Then recency.
        func metrics(_ item: T) -> (matched: Int, density: Double) {
            let hay = text(item).joined(separator: " ").lowercased()
            let matched = q.reduce(0) { $0 + (hay.contains($1) ? 1 : 0) }
            let density = hay.isEmpty ? 0 : Double(matched) / Double(hay.count) * 1000
            return (matched, density)
        }
        return items.enumerated()
            .map { (offset: $0.offset, item: $0.element, m: metrics($0.element)) }
            .sorted { a, b in
                if a.m.matched != b.m.matched { return a.m.matched > b.m.matched }
                if a.m.density != b.m.density { return a.m.density > b.m.density }
                return a.offset < b.offset
            }
            .map { $0.item }
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
