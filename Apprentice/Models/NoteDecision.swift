//
//  NoteDecision.swift
//  Apprentice
//
//  Layer 1 (Models) — a decision captured within a Note.
//  Replaces the legacy top-level `Decision` struct.
//

import Foundation
import SwiftData

@Model
final class NoteDecision {
    var id: UUID = UUID()

    var title: String = ""
    var detail: String = ""
    var decisionMaker: String = ""
    var rationale: String = ""
    var impact: String = ""
    var date: Date = Date()
    var followUpRequired: Bool = false
    var followUpDate: Date?

    /// True if produced by AI enrichment (so re-analysis can replace it without
    /// touching user-added items).
    var isAIGenerated: Bool = false

    /// Owning note (inverse of Note.decisions).
    var note: Note?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        decisionMaker: String = "",
        rationale: String = "",
        impact: String = "",
        date: Date = Date(),
        followUpRequired: Bool = false,
        followUpDate: Date? = nil,
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.decisionMaker = decisionMaker
        self.rationale = rationale
        self.impact = impact
        self.date = date
        self.followUpRequired = followUpRequired
        self.followUpDate = followUpDate
        self.isAIGenerated = isAIGenerated
    }
}
