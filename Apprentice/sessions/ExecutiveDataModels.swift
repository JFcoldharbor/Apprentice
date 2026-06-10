//
//  ExecutiveDataModels.swift
//  Apprentice
//
//  Layer 1: Foundation - Complete executive session data models
//  FIXED: Complete struct with all enums properly nested
//

import Foundation
import SwiftUI

// MARK: - Executive Session

struct ExecutiveSession: Identifiable, Codable {
    let id: UUID
    var title: String
    let date: Date
    var duration: TimeInterval // in seconds
    var type: MeetingType
    var priority: Priority
    var notes: [StructuredNote]
    var attendees: [String]
    var transcript: String?
    var aiSummary: String?
    var status: SessionStatus
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        duration: TimeInterval = 0,
        type: MeetingType,
        priority: Priority = .medium,
        notes: [StructuredNote] = [],
        attendees: [String] = [],
        transcript: String? = nil,
        aiSummary: String? = nil,
        status: SessionStatus = .scheduled,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.type = type
        self.priority = priority
        self.notes = notes
        self.attendees = attendees
        self.transcript = transcript
        self.aiSummary = aiSummary
        self.status = status
        self.tags = tags
    }
    
    enum MeetingType: String, CaseIterable, Codable {
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
        
        var icon: String {
            switch self {
            case .oneOnOne: return "person.2"
            case .teamMeeting: return "person.3"
            case .clientCall: return "phone"
            case .boardMeeting: return "building.columns"
            case .strategySession: return "lightbulb"
            case .strategicPlanning: return "map"
            case .allHands: return "person.3.sequence"
            case .interview: return "person.badge.plus"
            case .vendor: return "handshake"
            case .coaching: return "brain.head.profile"
            case .weekly: return "calendar"
            case .problemSolving: return "wrench.and.screwdriver"
            case .goalSetting: return "target"
            }
        }
        
        var suggestedPrompt: String {
            switch self {
            case .oneOnOne: return "How can I support you and help remove any blockers?"
            case .teamMeeting: return "What are our key priorities and how can we align better?"
            case .clientCall: return "What are the client's main concerns and objectives?"
            case .boardMeeting: return "What strategic updates and decisions need board input?"
            case .strategySession: return "What strategic decisions and initiatives should we prioritize?"
            case .strategicPlanning: return "What are our long-term goals and how do we achieve them?"
            case .allHands: return "What key company updates should everyone know about?"
            case .interview: return "What qualities and experience are we looking for?"
            case .vendor: return "How can this partnership create mutual value?"
            case .coaching: return "What specific areas would you like to develop or improve?"
            case .weekly: return "How was your week? What challenges and wins did you have?"
            case .problemSolving: return "What specific challenge can I help you work through?"
            case .goalSetting: return "What goals would you like to set and how can we track progress?"
            }
        }
    }
    
    enum Priority: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .blue
            case .high: return .orange
            case .critical: return .red
            }
        }
        
        var sortOrder: Int {
            switch self {
            case .critical: return 4
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
    }
    
    enum SessionStatus: String, CaseIterable, Codable {
        case scheduled = "Scheduled"
        case inProgress = "In Progress"
        case completed = "Completed"
        case cancelled = "Cancelled"
        case rescheduled = "Rescheduled"
        
        var color: Color {
            switch self {
            case .scheduled: return .blue
            case .inProgress: return .green
            case .completed: return .gray
            case .cancelled: return .red
            case .rescheduled: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .scheduled: return "calendar.badge.clock"
            case .inProgress: return "play.circle"
            case .completed: return "checkmark.circle"
            case .cancelled: return "xmark.circle"
            case .rescheduled: return "arrow.clockwise.circle"
            }
        }
    }
} // CRITICAL: This closing brace was missing!

// MARK: - Structured Note

struct StructuredNote: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var category: NoteCategory
    var insights: [String]
    var actionItems: [ActionItem]
    var decisions: [Decision]
    let createdAt: Date
    var lastModified: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: NoteCategory,
        insights: [String] = [],
        actionItems: [ActionItem] = [],
        decisions: [Decision] = [],
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.insights = insights
        self.actionItems = actionItems
        self.decisions = decisions
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
    
    enum NoteCategory: String, CaseIterable, Codable {
        case strategy = "Strategy"
        case execution = "Execution"
        case people = "People"
        case finance = "Finance"
        case product = "Product"
        case marketing = "Marketing"
        case operations = "Operations"
        case coaching = "Coaching"
        case general = "General"
        
        var color: Color {
            switch self {
            case .strategy: return .purple
            case .execution: return .green
            case .people: return .blue
            case .finance: return .orange
            case .product: return .pink
            case .marketing: return .red
            case .operations: return .yellow
            case .coaching: return .cyan
            case .general: return .gray
            }
        }
        
        var icon: String {
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
    
    // MARK: - BusinessCategory Alias for Compatibility
    typealias BusinessCategory = NoteCategory
}

// MARK: - Action Item

struct ActionItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var assignee: String
    var dueDate: Date?
    var priority: ExecutiveSession.Priority
    var status: ActionStatus
    let createdAt: Date
    var completedAt: Date?
    var estimatedEffort: Int? // in hours
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        assignee: String,
        dueDate: Date? = nil,
        priority: ExecutiveSession.Priority = .medium,
        status: ActionStatus = .pending,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        estimatedEffort: Int? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.estimatedEffort = estimatedEffort
        self.tags = tags
    }
    
    enum ActionStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case inProgress = "In Progress"
        case blocked = "Blocked"
        case completed = "Completed"
        case cancelled = "Cancelled"
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .inProgress: return .blue
            case .blocked: return .red
            case .completed: return .green
            case .cancelled: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .inProgress: return "play.circle"
            case .blocked: return "exclamationmark.triangle"
            case .completed: return "checkmark.circle"
            case .cancelled: return "xmark.circle"
            }
        }
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && status != .completed
    }
    
    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return dueDate <= threeDaysFromNow && status != .completed
    }
}

// MARK: - Decision

struct Decision: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var decisionMaker: String
    var rationale: String
    var impact: String
    let date: Date
    var followUpRequired: Bool
    var followUpDate: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        decisionMaker: String,
        rationale: String,
        impact: String,
        date: Date = Date(),
        followUpRequired: Bool = false,
        followUpDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.decisionMaker = decisionMaker
        self.rationale = rationale
        self.impact = impact
        self.date = date
        self.followUpRequired = followUpRequired
        self.followUpDate = followUpDate
    }
}

// MARK: - Business Intelligence Models

struct BusinessInsight: Identifiable, Codable {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let actionable: Bool
    let priority: ExecutiveSession.Priority
    let generatedAt: Date
    
    enum InsightType: String, CaseIterable, Codable {
        case trend = "Trend"
        case opportunity = "Opportunity"
        case risk = "Risk"
        case efficiency = "Efficiency"
        case growth = "Growth"
        
        var icon: String {
            switch self {
            case .trend: return "chart.line.uptrend.xyaxis"
            case .opportunity: return "lightbulb"
            case .risk: return "exclamationmark.triangle"
            case .efficiency: return "speedometer"
            case .growth: return "arrow.up.right"
            }
        }
    }
}

// MARK: - Conversation Turn

struct ConversationTurn: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let speaker: Speaker
    let content: String
    let audioURL: String?
    
    enum Speaker: String, Codable {
        case user = "User"
        case ai = "AI Coach"
    }
}
