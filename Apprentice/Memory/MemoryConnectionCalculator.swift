//
//  ConversationSession.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  MemoryConnectionCalculator.swift
//  Stitch Executive AI
//
//  Layer 5: Business Logic - Enhanced with orb conversation integration
//  UPDATED: Adds unified analysis methods directly to existing struct
//

import Foundation

// MARK: - Conversation Session Model (for orb integration)

struct ConversationSession: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: Date
    let duration: TimeInterval
    let type: SessionType
    let conversationTurns: [SimpleConversationTurn]
    let extractedInsights: [String]
    let actionItems: [String]
    
    enum SessionType: String, CaseIterable, Codable {
        case coaching = "AI Coaching"
        case quickChat = "Quick Chat"
        case planning = "Planning Discussion"
        case brainstorming = "Brainstorming"
        case problemSolving = "Problem Solving"
        
        var icon: String {
            switch self {
            case .coaching: return "brain.head.profile"
            case .quickChat: return "message"
            case .planning: return "list.bullet.clipboard"
            case .brainstorming: return "lightbulb"
            case .problemSolving: return "wrench.and.screwdriver"
            }
        }
    }
    
    init(from turns: [SimpleConversationTurn], sessionId: UUID? = nil) {
        self.id = sessionId ?? UUID()
        self.date = turns.first?.timestamp ?? Date()
        self.duration = turns.last?.timestamp.timeIntervalSince(turns.first?.timestamp ?? Date()) ?? 0
        self.conversationTurns = turns
        
        // Auto-categorize based on conversation content
        self.type = Self.categorizeConversation(turns: turns)
        
        // Extract insights and action items from conversation
        let analysis = Self.analyzeConversationContent(turns: turns)
        self.extractedInsights = analysis.insights
        self.actionItems = analysis.actionItems
        
        // Generate title based on content
        self.title = Self.generateTitle(from: turns, type: type)
    }
    
    // MARK: - Content Analysis Methods
    
    private static func categorizeConversation(turns: [SimpleConversationTurn]) -> SessionType {
        let combinedText = turns.map { $0.userInput + " " + $0.aiResponse }.joined(separator: " ").lowercased()
        
        if combinedText.contains("coach") || combinedText.contains("advice") || combinedText.contains("guidance") {
            return .coaching
        } else if combinedText.contains("plan") || combinedText.contains("strategy") || combinedText.contains("roadmap") {
            return .planning
        } else if combinedText.contains("idea") || combinedText.contains("brainstorm") || combinedText.contains("creative") {
            return .brainstorming
        } else if combinedText.contains("problem") || combinedText.contains("issue") || combinedText.contains("challenge") {
            return .problemSolving
        } else {
            return .quickChat
        }
    }
    
    private static func analyzeConversationContent(turns: [SimpleConversationTurn]) -> (insights: [String], actionItems: [String]) {
        var insights: [String] = []
        var actionItems: [String] = []
        
        for turn in turns {
            let aiResponse = turn.aiResponse.lowercased()
            
            // Extract insights (AI conclusions, observations)
            if aiResponse.contains("insight") || aiResponse.contains("realize") || aiResponse.contains("understand") {
                insights.append(String(turn.aiResponse.prefix(100)))
            }
            
            // Extract action items (suggestions, recommendations)
            if aiResponse.contains("should") || aiResponse.contains("recommend") || aiResponse.contains("suggest") || aiResponse.contains("try") {
                actionItems.append(String(turn.aiResponse.prefix(100)))
            }
        }
        
        return (insights: Array(insights.prefix(3)), actionItems: Array(actionItems.prefix(3)))
    }
    
    private static func generateTitle(from turns: [SimpleConversationTurn], type: SessionType) -> String {
        guard let firstTurn = turns.first else { return "Conversation Session" }
        
        let userInput = firstTurn.userInput
        let keywords = extractTitleKeywords(from: userInput)
        
        if !keywords.isEmpty {
            return "\(type.rawValue): \(keywords.joined(separator: ", "))"
        } else {
            return "\(type.rawValue) Session"
        }
    }
    
    private static func extractTitleKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
            .filter { !["what", "how", "why", "when", "where", "could", "should", "would", "will", "can", "the", "and", "but", "for", "are", "you", "this", "that", "with"].contains($0) }
        
        return Array(words.prefix(3))
    }
}

// MARK: - Enhanced Memory Connection Calculator

struct MemoryConnectionCalculator {
    
    // MARK: - Configuration
    
    private let minimumConnectionScore: Double = 0.2
    private let strongConnectionThreshold: Double = 0.6
    private let criticalConnectionThreshold: Double = 0.8
    private let maxTimeGapDays: Int = 90
    private let keywordSimilarityThreshold: Double = 0.4
    
    // MARK: - Original Analysis Methods (unchanged)
    
    /// Analyzes all sessions and returns detected connections
    func analyzeConnections(sessions: [ExecutiveSession]) -> [SessionConnection] {
        var connections: [SessionConnection] = []
        
        // Generate all possible session pairs
        for i in 0..<sessions.count {
            for j in (i+1)..<sessions.count {
                let sessionA = sessions[i]
                let sessionB = sessions[j]
                
                if let connection = calculateConnection(from: sessionA, to: sessionB) {
                    connections.append(connection)
                }
            }
        }
        
        return connections.sorted { $0.score > $1.score }
    }
    
    /// Detects recurring patterns in sessions
    func detectPatterns(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        
        // Weekly standup pattern
        patterns.append(contentsOf: detectWeeklyStandupPattern(sessions: sessions))
        
        // Project cycle pattern
        patterns.append(contentsOf: detectProjectCyclePattern(sessions: sessions, connections: connections))
        
        // Client engagement pattern
        patterns.append(contentsOf: detectClientEngagementPattern(sessions: sessions))
        
        // Strategic review pattern
        patterns.append(contentsOf: detectStrategicReviewPattern(sessions: sessions))
        
        // Decision process pattern
        patterns.append(contentsOf: detectDecisionProcessPattern(sessions: sessions, connections: connections))
        
        return patterns.sorted { $0.strength > $1.strength }
    }
    
    /// Groups related sessions into clusters
    func createSessionClusters(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [SessionCluster] {
        var clusters: [SessionCluster] = []
        var processedSessions: Set<UUID> = []
        
        for session in sessions {
            if processedSessions.contains(session.id) { continue }
            
            let cluster = buildCluster(startingFrom: session, sessions: sessions, connections: connections)
            if cluster.sessions.count > 1 {
                clusters.append(cluster)
                cluster.sessions.forEach { processedSessions.insert($0) }
            }
        }
        
        return clusters.sorted { $0.cohesion > $1.cohesion }
    }
    
    /// Generates business insights from memory analysis
    func generateInsights(sessions: [ExecutiveSession], connections: [SessionConnection], patterns: [MemoryPattern]) -> [MemoryInsight] {
        var insights: [MemoryInsight] = []
        
        // Communication pattern insights
        insights.append(contentsOf: analyzeCommunicationPatterns(sessions: sessions, connections: connections))
        
        // Decision bottleneck insights
        insights.append(contentsOf: analyzeDecisionBottlenecks(sessions: sessions, connections: connections))
        
        // Collaboration opportunity insights
        insights.append(contentsOf: analyzeCollaborationOpportunities(sessions: sessions, connections: connections))
        
        // Strategic alignment insights
        insights.append(contentsOf: analyzeStrategicAlignment(sessions: sessions, patterns: patterns))
        
        return insights.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - NEW: Unified Analysis Methods
    
    /// Analyzes both sessions and conversations together
    func analyzeUnifiedConnections(sessions: [ExecutiveSession], conversationTurns: [SimpleConversationTurn]) -> [SessionConnection] {
        // Convert conversations to session format
        let conversationSessions = convertConversationsToSessions(conversationTurns)
        
        // Combine all sessions
        let allSessions = sessions + conversationSessions
        
        // Analyze connections including conversation-to-meeting links
        var connections = analyzeConnections(sessions: allSessions)
        
        // Add specialized conversation-to-session connections
        connections.append(contentsOf: analyzeConversationToSessionConnections(
            conversations: conversationSessions,
            businessSessions: sessions
        ))
        
        return connections.sorted { $0.score > $1.score }
    }
    
    /// Generates insights including conversation patterns
    func generateUnifiedInsights(sessions: [ExecutiveSession], conversationTurns: [SimpleConversationTurn], connections: [SessionConnection]) -> [MemoryInsight] {
        let conversationSessions = convertConversationsToSessions(conversationTurns)
        let allSessions = sessions + conversationSessions
        
        var insights = generateInsights(sessions: allSessions, connections: connections, patterns: [])
        
        // Add conversation-specific insights
        insights.append(contentsOf: analyzeConversationPatterns(conversationSessions: conversationSessions))
        insights.append(contentsOf: analyzeCoachingEffectiveness(conversationSessions: conversationSessions, businessSessions: sessions))
        insights.append(contentsOf: analyzeIdeaEvolution(conversations: conversationSessions, sessions: sessions, connections: connections))
        
        return insights.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Conversation Conversion Methods
    
    private func convertConversationsToSessions(_ turns: [SimpleConversationTurn]) -> [ExecutiveSession] {
        // Group turns by session ID or time proximity
        let groupedTurns = groupConversationTurns(turns)
        
        return groupedTurns.map { group in
            let conversationSession = ConversationSession(from: group)
            return convertToExecutiveSession(conversationSession)
        }
    }
    
    private func groupConversationTurns(_ turns: [SimpleConversationTurn]) -> [[SimpleConversationTurn]] {
        var groups: [[SimpleConversationTurn]] = []
        var currentGroup: [SimpleConversationTurn] = []
        
        let sortedTurns = turns.sorted { $0.timestamp < $1.timestamp }
        
        for turn in sortedTurns {
            if let lastTurn = currentGroup.last {
                // If more than 30 minutes apart, start new group
                if turn.timestamp.timeIntervalSince(lastTurn.timestamp) > 1800 {
                    if !currentGroup.isEmpty {
                        groups.append(currentGroup)
                    }
                    currentGroup = [turn]
                } else {
                    currentGroup.append(turn)
                }
            } else {
                currentGroup.append(turn)
            }
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    private func convertToExecutiveSession(_ conversationSession: ConversationSession) -> ExecutiveSession {
        // Create structured note from conversation
        let note = StructuredNote(
            id: UUID(),
            title: conversationSession.title,
            content: conversationSession.conversationTurns.map { "User: \($0.userInput)\nAI: \($0.aiResponse)" }.joined(separator: "\n\n"),
            category: .coaching,
            insights: conversationSession.extractedInsights,
            actionItems: conversationSession.actionItems.map {
                ActionItem(
                    id: UUID(),
                    title: String($0.prefix(50)),
                    description: $0,
                    assignee: "AI Coach",  // ✅ FIXED: Provide default assignee
                    dueDate: nil,
                    priority: .medium,
                    status: .pending,
                    createdAt: Date()
                )
            },
            decisions: [],
            createdAt: conversationSession.date
        )
        
        return ExecutiveSession(
            id: conversationSession.id,
            title: conversationSession.title,
            date: conversationSession.date,
            duration: conversationSession.duration,
            type: .coaching,
            priority: .medium,
            notes: [note],
            attendees: ["AI Coach"]
        )
    }
    
    // MARK: - Specialized Connection Analysis
    
    private func analyzeConversationToSessionConnections(conversations: [ExecutiveSession], businessSessions: [ExecutiveSession]) -> [SessionConnection] {
        var connections: [SessionConnection] = []
        
        for conversation in conversations {
            for session in businessSessions {
                if let connection = calculateConversationToSessionConnection(conversation: conversation, session: session) {
                    connections.append(connection)
                }
            }
        }
        
        return connections
    }
    
    private func calculateConversationToSessionConnection(conversation: ExecutiveSession, session: ExecutiveSession) -> SessionConnection? {
        var reasons: [ConnectionReason] = []
        var totalScore: Double = 0
        
        // Time proximity (conversation before session suggests preparation)
        let timeDiff = session.date.timeIntervalSince(conversation.date)
        if timeDiff > 0 && timeDiff < 86400 * 7 { // Within a week after conversation
            let proximityScore = max(0.8 - (timeDiff / (86400 * 7)), 0.1)
            reasons.append(ConnectionReason(
                type: .timeProximity,
                description: "Conversation occurred \(Int(timeDiff / 86400)) days before session",
                confidence: proximityScore,
                evidence: ["Time gap: \(Int(timeDiff / 86400)) days"]
            ))
            totalScore += proximityScore * 0.4
        }
        
        // Topic similarity
        let topicScore = calculateTopicSimilarityScore(sessionA: conversation, sessionB: session)
        if topicScore.score > 0.3 {
            reasons.append(topicScore.reason)
            totalScore += topicScore.score * 0.6
        }
        
        // Action item progression (conversation leads to action)
        let actionScore = calculateActionItemProgression(conversation: conversation, session: session)
        if actionScore > 0 {
            reasons.append(ConnectionReason(
                type: .actionItemLink,
                description: "Conversation insights led to session actions",
                confidence: actionScore,
                evidence: ["Action item progression detected"]
            ))
            totalScore += actionScore * 0.5
        }
        
        guard totalScore > minimumConnectionScore && !reasons.isEmpty else { return nil }
        
        return SessionConnection(
            sourceSessionId: conversation.id,
            targetSessionId: session.id,
            connectionType: .insightEvolution,
            strength: ConnectionStrength.from(score: totalScore),
            score: totalScore,
            reasons: reasons
        )
    }
    
    private func calculateActionItemProgression(conversation: ExecutiveSession, session: ExecutiveSession) -> Double {
        let conversationActions = Set(conversation.notes.flatMap { $0.actionItems.map { $0.title.lowercased() } })
        let sessionTopics = Set(session.notes.flatMap { $0.content.lowercased().components(separatedBy: .whitespacesAndNewlines) })
        
        let matchingConcepts = conversationActions.filter { action in
            sessionTopics.contains { $0.contains(action) || action.contains($0) }
        }
        
        return conversationActions.isEmpty ? 0 : Double(matchingConcepts.count) / Double(conversationActions.count)
    }
    
    // MARK: - Conversation-Specific Insights
    
    private func analyzeConversationPatterns(conversationSessions: [ExecutiveSession]) -> [MemoryInsight] {
        guard !conversationSessions.isEmpty else { return [] }
        
        // Analyze coaching frequency
        let dailyCoaching = Dictionary(grouping: conversationSessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
        
        let averageSessionsPerDay = Double(conversationSessions.count) / Double(dailyCoaching.count)
        
        if averageSessionsPerDay > 2 {
            return [MemoryInsight(
                id: UUID(),
                title: "High Coaching Engagement",
                description: "Averaging \(String(format: "%.1f", averageSessionsPerDay)) coaching sessions per day shows strong commitment to development.",
                insightType: .strategicAlignment,
                confidence: 0.8,
                relevantSessions: conversationSessions.map { $0.id },
                relevantConnections: [],
                actionableRecommendations: [
                    "Continue current coaching momentum",
                    "Consider documenting key insights for team sharing",
                    "Schedule regular review of coaching outcomes"
                ],
                businessValue: BusinessImpact.high,
                createdAt: Date()
            )]
        }
        
        return []
    }
    
    private func analyzeCoachingEffectiveness(conversationSessions: [ExecutiveSession], businessSessions: [ExecutiveSession]) -> [MemoryInsight] {
        // Find sessions that happened after coaching conversations
        let coachingDates = Set(conversationSessions.map { Calendar.current.startOfDay(for: $0.date) })
        let sessionsAfterCoaching = businessSessions.filter { session in
            coachingDates.contains { coachingDate in
                let sessionDate = Calendar.current.startOfDay(for: session.date)
                return sessionDate > coachingDate && sessionDate.timeIntervalSince(coachingDate) < 86400 * 3
            }
        }
        
        if !sessionsAfterCoaching.isEmpty {
            let effectiveness = Double(sessionsAfterCoaching.count) / Double(conversationSessions.count)
            
            return [MemoryInsight(
                id: UUID(),
                title: "Coaching Implementation Success",
                description: "\(sessionsAfterCoaching.count) business sessions occurred within 3 days of coaching conversations, showing \(Int(effectiveness * 100))% implementation rate.",
                insightType: .strategicAlignment,
                confidence: min(effectiveness, 0.9),
                relevantSessions: conversationSessions.map { $0.id } + sessionsAfterCoaching.map { $0.id },
                relevantConnections: [],
                actionableRecommendations: [
                    "Document successful coaching-to-action patterns",
                    "Identify topics that lead to quick implementation",
                    "Schedule follow-up sessions for complex discussions"
                ],
                businessValue: effectiveness > 0.5 ? BusinessImpact.high : BusinessImpact.medium,
                createdAt: Date()
            )]
        }
        
        return []
    }
    
    private func analyzeIdeaEvolution(conversations: [ExecutiveSession], sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryInsight] {
        let evolutionConnections = connections.filter { $0.connectionType == .insightEvolution }
        
        guard !evolutionConnections.isEmpty else { return [] }
        
        return [MemoryInsight(
            id: UUID(),
            title: "Idea Evolution Pathway",
            description: "Detected \(evolutionConnections.count) clear progressions from coaching conversations to business implementation.",
            insightType: .strategicAlignment,
            confidence: 0.75,
            relevantSessions: Array(Set(evolutionConnections.flatMap { [$0.sourceSessionId, $0.targetSessionId] })),
            relevantConnections: evolutionConnections.map { $0.id },
            actionableRecommendations: [
                "Track idea-to-implementation success rate",
                "Identify most effective conversation topics",
                "Create templates for successful coaching patterns"
            ],
            businessValue: BusinessImpact.high,
            createdAt: Date()
        )]
    }
    
    // MARK: - Original Helper Methods (need to be included)
    
    private func calculateConnection(from sessionA: ExecutiveSession, to sessionB: ExecutiveSession) -> SessionConnection? {
        var reasons: [ConnectionReason] = []
        var totalScore: Double = 0
        
        // Time proximity check
        let timeDifference = abs(sessionA.date.timeIntervalSince(sessionB.date))
        let daysDifference = timeDifference / (24 * 60 * 60)
        
        guard daysDifference <= Double(maxTimeGapDays) else { return nil }
        
        // Calculate different types of connections
        let attendeeScore = calculateAttendeeOverlapScore(sessionA: sessionA, sessionB: sessionB)
        if attendeeScore.score > 0 {
            reasons.append(attendeeScore.reason)
            totalScore += attendeeScore.score * 0.3
        }
        
        let topicScore = calculateTopicSimilarityScore(sessionA: sessionA, sessionB: sessionB)
        if topicScore.score > keywordSimilarityThreshold {
            reasons.append(topicScore.reason)
            totalScore += topicScore.score * 0.4
        }
        
        let actionScore = calculateActionItemConnectionScore(sessionA: sessionA, sessionB: sessionB)
        if actionScore.score > 0 {
            reasons.append(actionScore.reason)
            totalScore += actionScore.score * 0.3
        }
        
        guard totalScore >= minimumConnectionScore && !reasons.isEmpty else { return nil }
        
        let connectionType = determineConnectionType(reasons: reasons)
        let strength = ConnectionStrength.from(score: totalScore)
        
        return SessionConnection(
            sourceSessionId: sessionA.id,
            targetSessionId: sessionB.id,
            connectionType: connectionType,
            strength: strength,
            score: totalScore,
            reasons: reasons
        )
    }
    
    private func calculateAttendeeOverlapScore(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        let attendeesA = Set(sessionA.attendees)
        let attendeesB = Set(sessionB.attendees)
        let commonAttendees = attendeesA.intersection(attendeesB)
        let totalUniqueAttendees = attendeesA.union(attendeesB).count
        
        guard !commonAttendees.isEmpty && totalUniqueAttendees > 0 else {
            return (0, ConnectionReason(type: .sharedAttendees, description: "No shared attendees", confidence: 0))
        }
        
        let score = Double(commonAttendees.count) / Double(totalUniqueAttendees)
        let attendeeList = Array(commonAttendees).joined(separator: ", ")
        
        return (
            score,
            ConnectionReason(
                type: .sharedAttendees,
                description: "Shared attendees: \(attendeeList)",
                confidence: score,
                evidence: Array(commonAttendees)
            )
        )
    }
    
    private func calculateTopicSimilarityScore(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        // Extract keywords from session content
        let keywordsA = extractKeywords(from: sessionA)
        let keywordsB = extractKeywords(from: sessionB)
        
        let commonKeywords = Set(keywordsA).intersection(Set(keywordsB))
        let totalKeywords = Set(keywordsA).union(Set(keywordsB)).count
        
        guard !commonKeywords.isEmpty && totalKeywords > 0 else {
            return (0, ConnectionReason(type: .keywordSimilarity, description: "No common topics", confidence: 0))
        }
        
        let score = Double(commonKeywords.count) / Double(totalKeywords)
        
        // Category matching bonus
        let categoryBonus = sessionA.notes.contains { noteA in
            sessionB.notes.contains { noteB in
                noteA.category == noteB.category
            }
        } ? 0.1 : 0
        
        return (
            score + categoryBonus,
            ConnectionReason(
                type: .keywordSimilarity,
                description: "Common topics: \(Array(commonKeywords).prefix(3).joined(separator: ", "))",
                confidence: score,
                evidence: Array(commonKeywords)
            )
        )
    }
    
    private func calculateActionItemConnectionScore(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        let actionsA = sessionA.notes.flatMap { $0.actionItems }
        let actionsB = sessionB.notes.flatMap { $0.actionItems }
        
        guard !actionsA.isEmpty || !actionsB.isEmpty else {
            return (0, ConnectionReason(type: .actionItemLink, description: "No action items", confidence: 0))
        }
        
        // Look for related action items (similar titles or descriptions)
        var matchingActions = 0
        for actionA in actionsA {
            for actionB in actionsB {
                let titleSimilarity = calculateTextSimilarity(actionA.title, actionB.title)
                let descSimilarity = calculateTextSimilarity(actionA.description, actionB.description)
                
                if titleSimilarity > 0.5 || descSimilarity > 0.5 {
                    matchingActions += 1
                }
            }
        }
        
        let totalActions = actionsA.count + actionsB.count
        let score = totalActions > 0 ? Double(matchingActions) / Double(totalActions) : 0
        
        return (
            score,
            ConnectionReason(
                type: .actionItemLink,
                description: "\(matchingActions) related action items found",
                confidence: score,
                evidence: ["Related actions: \(matchingActions)/\(totalActions)"]
            )
        )
    }
    
    private func extractKeywords(from session: ExecutiveSession) -> [String] {
        let allText = ([session.title] + session.notes.map { $0.content }).joined(separator: " ")
        return extractBusinessKeywords(from: allText)
    }
    
    private func extractBusinessKeywords(from content: String) -> [String] {
        let businessTerms = [
            "strategy", "revenue", "growth", "market", "customer", "product", "team",
            "funding", "investment", "profit", "sales", "marketing", "operations",
            "technology", "innovation", "competition", "partnership", "expansion",
            "leadership", "management", "culture", "hiring", "retention", "performance"
        ]
        
        let words = tokenize(content).map { $0.lowercased() }
        return words.filter { word in
            businessTerms.contains(word) || word.count > 5
        }
    }
    
    private func extractStrategicKeywords(from content: String) -> [String] {
        let strategicTerms = [
            "strategy", "vision", "mission", "goals", "objectives", "market", "competition",
            "growth", "expansion", "innovation", "transformation", "disruption", "opportunity",
            "positioning", "advantage", "revenue", "profit", "investment", "acquisition"
        ]
        
        let words = tokenize(content).map { $0.lowercased() }
        return words.filter { strategicTerms.contains($0) }
    }
    
    private func tokenize(_ text: String) -> [String] {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(tokenize(text1.lowercased()))
        let words2 = Set(tokenize(text2.lowercased()))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0 }
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private func determineConnectionType(reasons: [ConnectionReason]) -> ConnectionType {
        if reasons.contains(where: { $0.type == .actionItemLink }) {
            return .actionDependency
        } else if reasons.contains(where: { $0.type == .sharedAttendees }) {
            return .peopleNetwork
        } else if reasons.contains(where: { $0.type == .keywordSimilarity || $0.type == .topicOverlap }) {
            return .topicSimilarity
        } else {
            return .followUp
        }
    }
    
    private func buildCluster(startingFrom session: ExecutiveSession, sessions: [ExecutiveSession], connections: [SessionConnection]) -> SessionCluster {
        var clusterSessions: Set<UUID> = [session.id]
        var toProcess: [UUID] = [session.id]
        
        // Breadth-first search to find connected sessions
        while !toProcess.isEmpty {
            let currentSessionId = toProcess.removeFirst()
            
            let relatedConnections = connections.filter { connection in
                (connection.sourceSessionId == currentSessionId || connection.targetSessionId == currentSessionId) &&
                connection.strength.scoreRange.upperBound >= strongConnectionThreshold
            }
            
            for connection in relatedConnections {
                let otherSessionId = connection.sourceSessionId == currentSessionId ? connection.targetSessionId : connection.sourceSessionId
                
                if !clusterSessions.contains(otherSessionId) {
                    clusterSessions.insert(otherSessionId)
                    toProcess.append(otherSessionId)
                }
            }
        }
        
        let clusterSessionObjects = sessions.filter { clusterSessions.contains($0.id) }
        let averageDate = Date(timeIntervalSince1970: clusterSessionObjects.map { $0.date.timeIntervalSince1970 }.reduce(0, +) / Double(clusterSessionObjects.count))
        
        // Calculate cohesion based on connection strengths
        let relevantConnections = connections.filter { connection in
            clusterSessions.contains(connection.sourceSessionId) && clusterSessions.contains(connection.targetSessionId)
        }
        let averageConnectionStrength = relevantConnections.isEmpty ? 0 : relevantConnections.map { $0.score }.reduce(0, +) / Double(relevantConnections.count)
        
        // Extract dominant topics
        let allKeywords = clusterSessionObjects.flatMap { extractKeywords(from: $0) }
        let keywordCounts = Dictionary(grouping: allKeywords) { $0 }.mapValues { $0.count }
        let dominantTopics = keywordCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        // Extract key attendees
        let allAttendees = clusterSessionObjects.flatMap { $0.attendees }
        let attendeeCounts = Dictionary(grouping: allAttendees) { $0 }.mapValues { $0.count }
        let keyAttendees = attendeeCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        return SessionCluster(
            name: "Cluster: \(dominantTopics.first ?? "Sessions")",
            sessions: Array(clusterSessions),
            centerOfMass: averageDate,
            cohesion: averageConnectionStrength,
            dominantTopics: Array(dominantTopics),
            keyAttendees: Array(keyAttendees),
            businessImpact: averageConnectionStrength > 0.8 ? .high : averageConnectionStrength > 0.6 ? .medium : .low
        )
    }
    
    // Stub implementations for pattern detection methods
    private func detectWeeklyStandupPattern(sessions: [ExecutiveSession]) -> [MemoryPattern] {
        return []
    }
    
    private func detectProjectCyclePattern(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryPattern] {
        return []
    }
    
    private func detectClientEngagementPattern(sessions: [ExecutiveSession]) -> [MemoryPattern] {
        return []
    }
    
    private func detectStrategicReviewPattern(sessions: [ExecutiveSession]) -> [MemoryPattern] {
        return []
    }
    
    private func detectDecisionProcessPattern(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryPattern] {
        return []
    }
    
    private func analyzeCommunicationPatterns(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryInsight] {
        return []
    }
    
    private func analyzeDecisionBottlenecks(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryInsight] {
        return []
    }
    
    private func analyzeCollaborationOpportunities(sessions: [ExecutiveSession], connections: [SessionConnection]) -> [MemoryInsight] {
        return []
    }
    
    private func analyzeStrategicAlignment(sessions: [ExecutiveSession], patterns: [MemoryPattern]) -> [MemoryInsight] {
        return []
    }
}
