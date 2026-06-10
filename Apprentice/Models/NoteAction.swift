//
//  NoteAction.swift
//  Apprentice
//
//  Layer 1 (Models) — an action item extracted from (or added to) a Note.
//  Replaces the legacy top-level `ActionItem` struct.
//

import Foundation
import SwiftData

@Model
final class NoteAction {
    var id: UUID = UUID()

    var title: String = ""
    var detail: String = ""
    var assignee: String = ""
    var dueDate: Date?

    var priority: NotePriority = NotePriority.medium
    var status: ActionStatus = ActionStatus.pending

    var createdAt: Date = Date()
    var completedAt: Date?
    var estimatedEffortHours: Int?
    var tags: [String] = []

    /// True if produced by AI enrichment (so re-analysis can replace it without
    /// touching user-added items).
    var isAIGenerated: Bool = false

    /// Owning note (inverse of Note.actions).
    var note: Note?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        assignee: String = "",
        dueDate: Date? = nil,
        priority: NotePriority = .medium,
        status: ActionStatus = .pending,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        estimatedEffortHours: Int? = nil,
        tags: [String] = [],
        isAIGenerated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.estimatedEffortHours = estimatedEffortHours
        self.tags = tags
        self.isAIGenerated = isAIGenerated
    }

    // MARK: Convenience

    var isComplete: Bool { status == .completed }

    var isOverdue: Bool {
        guard let dueDate else { return false }
        return dueDate < Date() && status != .completed && status != .cancelled
    }

    var isDueSoon: Bool {
        guard let dueDate,
              let threeDays = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        else { return false }
        return dueDate <= threeDays && status != .completed && status != .cancelled
    }
}
