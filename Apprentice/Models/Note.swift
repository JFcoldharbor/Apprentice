//
//  Note.swift
//  Apprentice
//
//  Layer 1 (Models) — the core capture record. A Note is what a recording
//  becomes: stitched transcript + AI summary + extracted actions/decisions,
//  with its source AudioChunks retained (never deleted) so it can be
//  re-transcribed or played back.
//
//  SwiftData gives every record a stable persistent identity, which structurally
//  fixes the legacy `let id = UUID()`-regenerates-on-decode bug.
//

import Foundation
import SwiftData

@Model
final class Note {
    // Stable identity (own UUID kept for export / cross-store mapping)
    var id: UUID = UUID()

    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var type: NoteType = NoteType.general
    var priority: NotePriority = NotePriority.medium
    var status: NoteStatus = NoteStatus.completed

    /// Total recorded duration in seconds.
    var duration: TimeInterval = 0

    /// For a pre-staged (status == .scheduled) session: when the meeting is set
    /// to happen. nil for recorded notes (which use `createdAt`).
    var scheduledFor: Date? = nil

    var tags: [String] = []
    var attendees: [String] = []

    /// Stitched transcript across all chunks.
    var fullTranscript: String = ""
    /// AI-generated summary (filled in Phase 2; empty until then).
    var aiSummary: String = ""
    /// Short bullet insights.
    var insights: [String] = []

    // MARK: Relationships (cascade: deleting a Note removes its children)

    @Relationship(deleteRule: .cascade, inverse: \AudioChunk.note)
    var chunks: [AudioChunk] = []

    @Relationship(deleteRule: .cascade, inverse: \NoteAction.note)
    var actions: [NoteAction] = []

    @Relationship(deleteRule: .cascade, inverse: \NoteDecision.note)
    var decisions: [NoteDecision] = []

    init(
        id: UUID = UUID(),
        title: String = "",
        createdAt: Date = Date(),
        type: NoteType = .general,
        priority: NotePriority = .medium,
        status: NoteStatus = .completed,
        duration: TimeInterval = 0,
        tags: [String] = [],
        attendees: [String] = [],
        fullTranscript: String = "",
        aiSummary: String = "",
        insights: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.type = type
        self.priority = priority
        self.status = status
        self.duration = duration
        self.tags = tags
        self.attendees = attendees
        self.fullTranscript = fullTranscript
        self.aiSummary = aiSummary
        self.insights = insights
    }

    // MARK: Convenience

    /// Chunks in recording order.
    var orderedChunks: [AudioChunk] {
        chunks.sorted { $0.index < $1.index }
    }

    var formattedDuration: String {
        let total = Int(duration)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// True while any chunk is still transcribing.
    var isTranscribing: Bool {
        chunks.contains { $0.status == .pending || $0.status == .processing }
    }

    var openActionCount: Int {
        actions.filter { $0.status != .completed && $0.status != .cancelled }.count
    }
}
