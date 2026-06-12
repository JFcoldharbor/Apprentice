//
//  NoteSessionProjection.swift
//  Apprentice
//
//  Bridges the SwiftData note stack (Note / NoteAction / NoteDecision) to the
//  legacy ExecutiveSession value types the original UI binds to. SessionManager
//  projects each Note into an ExecutiveSession so the original screens render
//  REAL, enriched, retained note data without any view changes.
//
//  Mappers are @MainActor because they read SwiftData relationships. Enum raw
//  values were intentionally kept identical across the two stacks (see
//  NoteEnums.swift), so type/priority/status map 1:1.
//

import Foundation

// File-scope alias so the reverse mappers (which live inside `extension
// ActionItem`, whose nested `ActionStatus` would otherwise shadow it) can name
// the note stack's top-level ActionStatus unambiguously.
private typealias NoteActionStatus = ActionStatus

// MARK: - Note → ExecutiveSession (read projection)

@MainActor
extension Note {

    /// Read-only projection of this Note as a legacy ExecutiveSession.
    func asExecutiveSession() -> ExecutiveSession {
        ExecutiveSession(
            id: id,                                   // stable — keeps memory-clustering IDs steady
            title: title,
            date: createdAt,
            duration: duration,
            type: ExecutiveSession.MeetingType(rawValue: type.rawValue) ?? .strategySession,
            priority: ExecutiveSession.Priority(rawValue: priority.rawValue) ?? .medium,
            notes: [projectedStructuredNote()],
            attendees: attendees,
            transcript: fullTranscript.isEmpty ? nil : fullTranscript,
            aiSummary: aiSummary.isEmpty ? nil : aiSummary,
            status: ExecutiveSession.SessionStatus(rawValue: status.rawValue) ?? .completed,
            tags: tags
        )
    }

    /// One synthesized StructuredNote carrying the note body + extracted items.
    /// Load-bearing: MemoryConnectionCalculator and the list/detail screens read
    /// `session.notes[].content / .actionItems / .decisions / .insights`.
    private func projectedStructuredNote() -> StructuredNote {
        StructuredNote(
            id: id,
            title: title,
            content: fullTranscript.isEmpty ? aiSummary : fullTranscript,
            category: .general,
            insights: insights,
            actionItems: actions.map { $0.asActionItem() },
            decisions: decisions.map { $0.asDecision() },
            createdAt: createdAt,
            lastModified: updatedAt
        )
    }
}

@MainActor
extension NoteAction {
    func asActionItem() -> ActionItem {
        ActionItem(
            id: id,
            title: title,
            description: detail,
            assignee: assignee,
            dueDate: dueDate,
            priority: ExecutiveSession.Priority(rawValue: priority.rawValue) ?? .medium,
            status: ActionItem.ActionStatus(rawValue: status.rawValue) ?? .pending,
            createdAt: createdAt,
            completedAt: completedAt,
            estimatedEffort: estimatedEffortHours,
            tags: tags
        )
    }
}

@MainActor
extension NoteDecision {
    func asDecision() -> Decision {
        Decision(
            id: id,
            title: title,
            description: detail,
            decisionMaker: decisionMaker,
            rationale: rationale,
            impact: impact,
            date: date,
            followUpRequired: followUpRequired,
            followUpDate: followUpDate
        )
    }
}

// MARK: - ExecutiveSession → Note (reverse, for legacy callers)
//
// Recording creates a Note directly via the capture pipeline and does NOT use
// this. These exist only for the few callers that still hand SessionManager an
// ExecutiveSession (calendar entries, notification-created sessions).

@MainActor
extension ExecutiveSession {
    func makeNote() -> Note {
        let note = Note(
            id: id,
            title: title,
            createdAt: date,
            type: NoteType(rawValue: type.rawValue) ?? .general,
            priority: NotePriority(rawValue: priority.rawValue) ?? .medium,
            status: NoteStatus(rawValue: status.rawValue) ?? .scheduled,
            duration: duration,
            tags: tags,
            attendees: attendees,
            fullTranscript: transcript ?? "",
            aiSummary: aiSummary ?? "",
            insights: notes.flatMap { $0.insights }
        )
        note.actions = notes.flatMap { $0.actionItems.map { $0.makeNoteAction() } }
        note.decisions = notes.flatMap { $0.decisions.map { $0.makeNoteDecision() } }
        return note
    }
}

@MainActor
extension ActionItem {
    func makeNoteAction() -> NoteAction {
        NoteAction(
            id: id,
            title: title,
            detail: description,
            assignee: assignee,
            dueDate: dueDate,
            priority: NotePriority(rawValue: priority.rawValue) ?? .medium,
            status: NoteActionStatus(rawValue: status.rawValue) ?? .pending,
            createdAt: createdAt,
            completedAt: completedAt,
            estimatedEffortHours: estimatedEffort,
            tags: tags
        )
    }
}

@MainActor
extension Decision {
    func makeNoteDecision() -> NoteDecision {
        NoteDecision(
            id: id,
            title: title,
            detail: description,
            decisionMaker: decisionMaker,
            rationale: rationale,
            impact: impact,
            date: date,
            followUpRequired: followUpRequired,
            followUpDate: followUpDate
        )
    }
}
