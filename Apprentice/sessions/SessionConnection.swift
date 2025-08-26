//
//  SessionConnection.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  SessionConnection.swift
//  Stitch Executive AI
//
//  Created by James Garmon on 8/21/25.
//


//
//  SessionConnection.swift
//  Stitch Executive AI
//
//  Created by James Garmon on 8/15/25.
//


//
//  MemoryConnectionModels.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Memory connection and relationship data models
//  Pure data structures for session relationship detection and analysis
//  Can import: NONE (Foundation layer)
//

import Foundation

// MARK: - Session Connection

struct SessionConnection: Identifiable, Codable {
    let id: UUID
    let sourceSessionId: UUID
    let targetSessionId: UUID
    let connectionType: ConnectionType
    let strength: ConnectionStrength
    let score: Double // 0.0 to 1.0
    let reasons: [ConnectionReason]
    let discoveredAt: Date
    let lastValidated: Date
    
    init(
        sourceSessionId: UUID,
        targetSessionId: UUID,
        connectionType: ConnectionType,
        strength: ConnectionStrength,
        score: Double,
        reasons: [ConnectionReason]
    ) {
        self.id = UUID()
        self.sourceSessionId = sourceSessionId
        self.targetSessionId = targetSessionId
        self.connectionType = connectionType
        self.strength = strength
        self.score = score
        self.reasons = reasons
        self.discoveredAt = Date()
        self.lastValidated = Date()
    }
}

// MARK: - Connection Type

enum ConnectionType: String, CaseIterable, Codable {
    case strategicThread = "Strategic Thread"
    case peopleNetwork = "People Network"
    case decisionChain = "Decision Chain"
    case followUp = "Follow-up"
    case projectCluster = "Project Cluster"
    case topicSimilarity = "Topic Similarity"
    case actionDependency = "Action Dependency"
    case insightEvolution = "Insight Evolution"
    
    var icon: String {
        switch self {
        case .strategicThread: return "arrow.triangle.branch"
        case .peopleNetwork: return "person.3.sequence.fill"
        case .decisionChain: return "link"
        case .followUp: return "arrow.right.circle"
        case .projectCluster: return "folder.badge.gearshape"
        case .topicSimilarity: return "bubble.left.and.bubble.right"
        case .actionDependency: return "checkmark.circle.trianglebadge.exclamationmark"
        case .insightEvolution: return "lightbulb.2"
        }
    }
    
    var color: String {
        switch self {
        case .strategicThread: return "purple"
        case .peopleNetwork: return "blue"
        case .decisionChain: return "orange"
        case .followUp: return "green"
        case .projectCluster: return "cyan"
        case .topicSimilarity: return "yellow"
        case .actionDependency: return "red"
        case .insightEvolution: return "pink"
        }
    }
    
    var description: String {
        switch self {
        case .strategicThread:
            return "Sessions discussing related strategic topics or themes"
        case .peopleNetwork:
            return "Sessions with overlapping attendees or stakeholders"
        case .decisionChain:
            return "Sessions where decisions build upon or reference previous decisions"
        case .followUp:
            return "Sessions that explicitly follow up on previous meetings"
        case .projectCluster:
            return "Sessions related to the same project or initiative"
        case .topicSimilarity:
            return "Sessions covering similar business topics or categories"
        case .actionDependency:
            return "Sessions with dependent or related action items"
        case .insightEvolution:
            return "Sessions where insights build upon previous discoveries"
        }
    }
}

// MARK: - Connection Strength

enum ConnectionStrength: String, CaseIterable, Codable {
    case weak = "Weak"
    case moderate = "Moderate"
    case strong = "Strong"
    case critical = "Critical"
    
    var scoreRange: ClosedRange<Double> {
        switch self {
        case .weak: return 0.0...0.3
        case .moderate: return 0.3...0.6
        case .strong: return 0.6...0.8
        case .critical: return 0.8...1.0
        }
    }
    
    var color: String {
        switch self {
        case .weak: return "gray"
        case .moderate: return "yellow"
        case .strong: return "orange"
        case .critical: return "red"
        }
    }
    
    static func from(score: Double) -> ConnectionStrength {
        switch score {
        case 0.0...0.3: return .weak
        case 0.3...0.6: return .moderate
        case 0.6...0.8: return .strong
        default: return .critical
        }
    }
}

// MARK: - Connection Reason

struct ConnectionReason: Identifiable, Codable {
    let id: UUID
    let type: ReasonType
    let description: String
    let confidence: Double // 0.0 to 1.0
    let evidence: [String] // Supporting evidence (keywords, phrases, etc.)
    
    init(type: ReasonType, description: String, confidence: Double, evidence: [String] = []) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.confidence = confidence
        self.evidence = evidence
    }
}

enum ReasonType: String, CaseIterable, Codable {
    case sharedAttendees = "Shared Attendees"
    case keywordSimilarity = "Keyword Similarity"
    case topicOverlap = "Topic Overlap"
    case decisionReference = "Decision Reference"
    case actionItemLink = "Action Item Link"
    case timeProximity = "Time Proximity"
    case categoryMatch = "Category Match"
    case insightContinuation = "Insight Continuation"
    case meetingTypePattern = "Meeting Type Pattern"
    case businessStageAlignment = "Business Stage Alignment"
    
    var weight: Double {
        switch self {
        case .sharedAttendees: return 0.8
        case .keywordSimilarity: return 0.6
        case .topicOverlap: return 0.7
        case .decisionReference: return 0.9
        case .actionItemLink: return 0.8
        case .timeProximity: return 0.4
        case .categoryMatch: return 0.5
        case .insightContinuation: return 0.7
        case .meetingTypePattern: return 0.3
        case .businessStageAlignment: return 0.6
        }
    }
}

// MARK: - Memory Pattern

struct MemoryPattern: Identifiable, Codable {
    let id: UUID
    let patternType: PatternType
    let sessions: [UUID] // Session IDs in the pattern
    let strength: Double // 0.0 to 1.0
    let frequency: Int // How often this pattern occurs
    let description: String
    let insights: [String] // Business insights from this pattern
    let discoveredAt: Date
    let lastSeen: Date
    
    init(
        patternType: PatternType,
        sessions: [UUID],
        strength: Double,
        frequency: Int,
        description: String,
        insights: [String]
    ) {
        self.id = UUID()
        self.patternType = patternType
        self.sessions = sessions
        self.strength = strength
        self.frequency = frequency
        self.description = description
        self.insights = insights
        self.discoveredAt = Date()
        self.lastSeen = Date()
    }
}

enum PatternType: String, CaseIterable, Codable {
    case weeklyStandup = "Weekly Standup"
    case projectCycle = "Project Cycle"
    case clientEngagement = "Client Engagement"
    case strategicReview = "Strategic Review"
    case decisionProcess = "Decision Process"
    case problemSolving = "Problem Solving"
    case teamDevelopment = "Team Development"
    case customerFeedback = "Customer Feedback"
    
    var icon: String {
        switch self {
        case .weeklyStandup: return "calendar.badge.clock"
        case .projectCycle: return "arrow.clockwise"
        case .clientEngagement: return "person.2.badge.key"
        case .strategicReview: return "chart.line.uptrend.xyaxis"
        case .decisionProcess: return "arrow.branch"
        case .problemSolving: return "wrench.and.screwdriver"
        case .teamDevelopment: return "person.3.sequence"
        case .customerFeedback: return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - Session Cluster

struct SessionCluster: Identifiable, Codable {
    let id: UUID
    let name: String
    let sessions: [UUID] // Session IDs in cluster
    let centerOfMass: Date // Average date of sessions in cluster
    let cohesion: Double // How tightly connected the sessions are (0.0 to 1.0)
    let dominantTopics: [String] // Most common topics in cluster
    let keyAttendees: [String] // Most frequent attendees
    let businessImpact: BusinessImpact
    let createdAt: Date
    
    init(
        name: String,
        sessions: [UUID],
        centerOfMass: Date,
        cohesion: Double,
        dominantTopics: [String],
        keyAttendees: [String],
        businessImpact: BusinessImpact
    ) {
        self.id = UUID()
        self.name = name
        self.sessions = sessions
        self.centerOfMass = centerOfMass
        self.cohesion = cohesion
        self.dominantTopics = dominantTopics
        self.keyAttendees = keyAttendees
        self.businessImpact = businessImpact
        self.createdAt = Date()
    }
}

enum BusinessImpact: String, CaseIterable, Codable {
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
    
    var weight: Double {
        switch self {
        case .low: return 0.25
        case .medium: return 0.5
        case .high: return 0.75
        case .critical: return 1.0
        }
    }
}

// MARK: - Memory Graph

struct MemoryGraph: Codable {
    let nodes: [GraphNode] // Sessions as nodes
    let edges: [GraphEdge] // Connections as edges
    let clusters: [SessionCluster]
    let patterns: [MemoryPattern]
    let lastUpdated: Date
    let analysisMetrics: AnalysisMetrics
    
    init(
        nodes: [GraphNode],
        edges: [GraphEdge],
        clusters: [SessionCluster],
        patterns: [MemoryPattern],
        analysisMetrics: AnalysisMetrics
    ) {
        self.nodes = nodes
        self.edges = edges
        self.clusters = clusters
        self.patterns = patterns
        self.lastUpdated = Date()
        self.analysisMetrics = analysisMetrics
    }
}

struct GraphNode: Identifiable, Codable {
    let id: UUID // Session ID
    let title: String // Session title
    let date: Date
    let type: String // Meeting type
    let importance: Double // 0.0 to 1.0 based on connections
    let position: GraphPosition? // For visualization
}

struct GraphEdge: Identifiable, Codable {
    let id: UUID
    let source: UUID // Source session ID
    let target: UUID // Target session ID
    let weight: Double // Connection strength
    let connectionType: ConnectionType
    let bidirectional: Bool
}

struct GraphPosition: Codable {
    let x: Double
    let y: Double
    let z: Double? // For 3D visualization
}

struct AnalysisMetrics: Codable {
    let totalConnections: Int
    let averageConnectionStrength: Double
    let strongestConnection: Double
    let clusterCount: Int
    let patternCount: Int
    let analysisDepth: Int // Number of sessions analyzed
    let computationTime: TimeInterval
    let lastFullAnalysis: Date
}

// MARK: - Search and Filtering

struct MemorySearchCriteria: Codable {
    let connectionTypes: [ConnectionType]
    let minimumStrength: ConnectionStrength
    let timeRange: DateInterval?
    let includedSessionIds: [UUID]?
    let excludedSessionIds: [UUID]?
    let attendeeFilter: [String]?
    let topicFilter: [String]?
}

struct MemoryInsight: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let insightType: InsightType
    let confidence: Double
    let relevantSessions: [UUID]
    let relevantConnections: [UUID]
    let actionableRecommendations: [String]
    let businessValue: BusinessImpact
    let createdAt: Date
}

enum InsightType: String, CaseIterable, Codable {
    case communicationPattern = "Communication Pattern"
    case decisionBottleneck = "Decision Bottleneck"
    case knowledgeGap = "Knowledge Gap"
    case collaborationOpportunity = "Collaboration Opportunity"
    case processImprovement = "Process Improvement"
    case strategicAlignment = "Strategic Alignment"
    case riskIdentification = "Risk Identification"
    case efficiencyGain = "Efficiency Gain"
    
    var icon: String {
        switch self {
        case .communicationPattern: return "bubble.left.and.bubble.right.fill"
        case .decisionBottleneck: return "exclamationmark.triangle.fill"
        case .knowledgeGap: return "brain.head.profile"
        case .collaborationOpportunity: return "person.3.sequence.fill"
        case .processImprovement: return "gearshape.2.fill"
        case .strategicAlignment: return "target"
        case .riskIdentification: return "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .efficiencyGain: return "speedometer"
        }
    }
}