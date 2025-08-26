//
//  ExecutiveSession.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  ExecutiveSession.swift
//  Stitch Executive AI
//
//  Created by James Garmon on 8/21/25.
//


//
//  ExecutiveDataModels.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Core business data models
//  SIMPLE VERSION - Essential models only for UI testing
//

import Foundation

// MARK: - Executive Session

struct ExecutiveSession: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    let duration: TimeInterval
    let type: MeetingType
    let priority: Priority
    var notes: [StructuredNote]
    let attendees: [String]
    
    enum MeetingType: String, CaseIterable, Codable {
        case teamMeeting = "Team Meeting"
        case clientCall = "Client Call"
        case strategySession = "Strategy Session"
        case oneOnOne = "1:1 Meeting"
        case boardMeeting = "Board Meeting"
        case coaching = "AI Coaching"
        
        var icon: String {
            switch self {
            case .teamMeeting: return "person.3"
            case .clientCall: return "phone"
            case .strategySession: return "lightbulb"
            case .oneOnOne: return "person.2"
            case .boardMeeting: return "building.2"
            case .coaching: return "brain.head.profile"
            }
        }
    }
    
    enum Priority: String, CaseIterable, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
}

// MARK: - Structured Note

struct StructuredNote: Identifiable, Codable {
    let id: UUID
    let title: String
    let content: String
    let category: BusinessCategory
    let insights: [String]
    let actionItems: [ActionItem]
    let decisions: [Decision]
    let createdAt: Date
    
    enum BusinessCategory: String, CaseIterable, Codable {
        case strategy = "Strategy"
        case finance = "Finance"
        case marketing = "Marketing"
        case operations = "Operations"
        case people = "People"
        case product = "Product"
        case goals = "Goals"
        case coaching = "Coaching"
        case general = "General"
        
        var icon: String {
            switch self {
            case .strategy: return "target"
            case .finance: return "dollarsign.circle"
            case .marketing: return "megaphone"
            case .operations: return "gearshape"
            case .people: return "person.3"
            case .product: return "cube.box"
            case .goals: return "flag"
            case .coaching: return "brain.head.profile"
            case .general: return "doc.text"
            }
        }
    }
}

// MARK: - Action Item

struct ActionItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let assignee: String?
    let dueDate: Date?
    let priority: ExecutiveSession.Priority
    var status: ActionStatus
    let createdAt: Date
    
    enum ActionStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case inProgress = "In Progress"
        case completed = "Completed"
        case blocked = "Blocked"
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .inProgress: return "arrow.right.circle"
            case .completed: return "checkmark.circle.fill"
            case .blocked: return "exclamationmark.triangle"
            }
        }
    }
}

// MARK: - Decision

struct Decision: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let decisionMaker: String
    let rationale: String
    let impact: String
    let date: Date
}

// MARK: - Founder Profile (Basic)

struct FounderProfile: Identifiable, Codable {
    let id: UUID
    let founderName: String
    let businessName: String?
    let businessStage: BusinessStage
    let industry: String
    let founderRole: String
    let yearsOfExperience: Int
    let currentChallenges: [String]
    let currentGoals: [String]
    let keyMetrics: [String: String]
    let createdAt: Date
    let lastUpdated: Date
    
    enum BusinessStage: String, CaseIterable, Codable {
        case idea = "Idea Stage"
        case validation = "Validation"
        case earlyStage = "Early Stage"
        case growth = "Growth Stage"
        case scale = "Scale Stage"
        case mature = "Mature"
        
        var description: String {
            switch self {
            case .idea: return "Developing initial concept"
            case .validation: return "Testing market fit"
            case .earlyStage: return "Building first version"
            case .growth: return "Scaling operations"
            case .scale: return "Expanding rapidly"
            case .mature: return "Established business"
            }
        }
    }
}

// MARK: - AI Coaching Session

struct AICoachingSession: Identifiable, Codable {
    let id: UUID
    let sessionType: SessionType
    let startTime: Date
    let endTime: Date?
    let conversation: [ConversationTurn]
    var insights: [String]
    var actionItems: [ActionItem]
    
    enum SessionType: String, CaseIterable, Codable {
        case onboarding = "Onboarding"
        case weekly = "Weekly Check-in"
        case problemSolving = "Problem Solving"
        case strategicPlanning = "Strategic Planning"
        case goalSetting = "Goal Setting"
        
        var prompt: String {
            switch self {
            case .onboarding: return "Let's get to know your business and set up your founder profile."
            case .weekly: return "How was your week? What challenges and wins did you have?"
            case .problemSolving: return "What specific challenge can I help you work through?"
            case .strategicPlanning: return "Let's think about your long-term strategy and objectives."
            case .goalSetting: return "What goals would you like to set and how can we track progress?"
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

// MARK: - Mock Data for Testing

extension ExecutiveSession {
    static let mockSessions: [ExecutiveSession] = [
        ExecutiveSession(
            id: UUID(),
            title: "Weekly Team Standup",
            date: Date().addingTimeInterval(-86400), // Yesterday
            duration: 1800, // 30 minutes
            type: .teamMeeting,
            priority: .medium,
            notes: [StructuredNote.mockNote],
            attendees: ["John Doe", "Jane Smith", "Mike Johnson"]
        ),
        ExecutiveSession(
            id: UUID(),
            title: "Client Discovery Call",
            date: Date().addingTimeInterval(-172800), // 2 days ago
            duration: 3600, // 1 hour
            type: .clientCall,
            priority: .high,
            notes: [StructuredNote.mockNote],
            attendees: ["Sarah Wilson", "Tech Lead"]
        )
    ]
}

extension StructuredNote {
    static let mockNote = StructuredNote(
        id: UUID(),
        title: "Product Roadmap Discussion",
        content: "Discussed Q4 product priorities and resource allocation...",
        category: .strategy,
        insights: ["Need to prioritize mobile features", "Consider user feedback integration"],
        actionItems: [ActionItem.mockAction],
        decisions: [Decision.mockDecision],
        createdAt: Date()
    )
}

extension ActionItem {
    static let mockAction = ActionItem(
        id: UUID(),
        title: "Update product roadmap",
        description: "Incorporate customer feedback into Q4 roadmap",
        assignee: "Product Manager",
        dueDate: Date().addingTimeInterval(604800), // 1 week from now
        priority: .high,
        status: .pending,
        createdAt: Date()
    )
}

extension Decision {
    static let mockDecision = Decision(
        id: UUID(),
        title: "Hire additional developer",
        description: "Decision to expand engineering team",
        decisionMaker: "CEO",
        rationale: "Need more capacity for Q4 features",
        impact: "Accelerate product development timeline",
        date: Date()
    )
}

extension FounderProfile {
    static let mockProfile = FounderProfile(
        id: UUID(),
        founderName: "Alex Thompson",
        businessName: "InnovateTech Solutions",
        businessStage: .growth,
        industry: "SaaS Technology",
        founderRole: "CEO & Founder",
        yearsOfExperience: 8,
        currentChallenges: ["Scaling team", "Market expansion", "Product-market fit"],
        currentGoals: ["Reach $1M ARR", "Hire 10 employees", "Launch mobile app"],
        keyMetrics: [
            "Monthly Revenue": "$75K",
            "Customers": "150",
            "Team Size": "8",
            "Runway": "18 months"
        ],
        createdAt: Date().addingTimeInterval(-2592000), // 30 days ago
        lastUpdated: Date()
    )
}