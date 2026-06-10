//
//  NoteEnums.swift
//  Apprentice
//
//  Layer 1 (Models) — Codable enums for the SwiftData note stack.
//  Raw values intentionally mirror the legacy ExecutiveSession enums so
//  LegacyMigrator can map old records by rawValue. Foundation-only (no SwiftUI)
//  to keep L1 free of view concerns; colors live in the Views layer.
//

import Foundation

// MARK: - Note Type (was ExecutiveSession.MeetingType)

enum NoteType: String, Codable, CaseIterable, Identifiable {
    case oneOnOne = "1:1"
    case teamMeeting = "Team Meeting"
    case clientCall = "Client Call"
    case boardMeeting = "Board Meeting"
    case strategySession = "Strategy Session"
    case strategicPlanning = "Strategic Planning"
    case allHands = "All Hands"
    case interview = "Interview"
    case vendor = "Vendor Meeting"
    case coaching = "Coaching Session"
    case weekly = "Weekly Check-in"
    case problemSolving = "Problem Solving"
    case goalSetting = "Goal Setting"
    case general = "General"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .oneOnOne: return "person.2"
        case .teamMeeting: return "person.3"
        case .clientCall: return "phone"
        case .boardMeeting: return "building.columns"
        case .strategySession: return "lightbulb"
        case .strategicPlanning: return "map"
        case .allHands: return "person.3.sequence"
        case .interview: return "person.badge.plus"
        case .vendor: return "hands.sparkles"
        case .coaching: return "brain.head.profile"
        case .weekly: return "calendar"
        case .problemSolving: return "wrench.and.screwdriver"
        case .goalSetting: return "target"
        case .general: return "note.text"
        }
    }
}

// MARK: - Priority (was ExecutiveSession.Priority)

enum NotePriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    var iconName: String {
        switch self {
        case .low: return "minus.circle"
        case .medium: return "equal.circle"
        case .high: return "exclamationmark.circle"
        case .critical: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Note Status (was ExecutiveSession.SessionStatus)

enum NoteStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    case rescheduled = "Rescheduled"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .scheduled: return "calendar.badge.clock"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .rescheduled: return "arrow.clockwise.circle"
        }
    }
}

// MARK: - Action Status (was ActionItem.ActionStatus)

enum ActionStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "play.circle"
        case .blocked: return "exclamationmark.triangle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

// MARK: - Transcription Status (was RecordingChunk.TranscriptionState)

enum TranscriptionStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case processing
    case completed
    case failed
    case retryable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .retryable: return "Retryable"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock.circle"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .retryable: return "arrow.clockwise.circle"
        }
    }

    var isTerminal: Bool { self == .completed || self == .failed }
}

// MARK: - Note Category (was StructuredNote.NoteCategory)

enum NoteCategory: String, Codable, CaseIterable, Identifiable {
    case strategy = "Strategy"
    case execution = "Execution"
    case people = "People"
    case finance = "Finance"
    case product = "Product"
    case marketing = "Marketing"
    case operations = "Operations"
    case coaching = "Coaching"
    case general = "General"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .strategy: return "map"
        case .execution: return "play"
        case .people: return "person.3"
        case .finance: return "dollarsign.circle"
        case .product: return "cube"
        case .marketing: return "megaphone"
        case .operations: return "gearshape"
        case .coaching: return "brain.head.profile"
        case .general: return "note.text"
        }
    }
}
