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
    
    // MARK: - PUBLIC: Conversation-to-Session Conversion (CHANGED FROM PRIVATE)
    
    public func convertToExecutiveSession(_ conversationSession: ConversationSession) -> ExecutiveSession {
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
                    assignee: nil,
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
    
    // MARK: - Core Connection Analysis
    
    private func calculateConnection(from sessionA: ExecutiveSession, to sessionB: ExecutiveSession) -> SessionConnection? {
        var reasons: [ConnectionReason] = []
        var totalScore: Double = 0
        
        // Time proximity analysis
        let timeScore = calculateTimeProximityScore(sessionA: sessionA, sessionB: sessionB)
        if timeScore.score > 0 {
            reasons.append(timeScore.reason)
            totalScore += timeScore.score * 0.3
        }
        
        // Topic similarity analysis
        let topicScore = calculateTopicSimilarityScore(sessionA: sessionA, sessionB: sessionB)
        if topicScore.score > 0 {
            reasons.append(topicScore.reason)
            totalScore += topicScore.score * 0.4
        }
        
        // Attendee overlap analysis
        let attendeeScore = calculateAttendeeOverlapScore(sessionA: sessionA, sessionB: sessionB)
        if attendeeScore.score > 0 {
            reasons.append(attendeeScore.reason)
            totalScore += attendeeScore.score * 0.2
        }
        
        // Action item continuity
        let actionScore = calculateActionItemContinuity(sessionA: sessionA, sessionB: sessionB)
        if actionScore.score > 0 {
            reasons.append(actionScore.reason)
            totalScore += actionScore.score * 0.1
        }
        
        guard totalScore > minimumConnectionScore && !reasons.isEmpty else { return nil }
        
        let connectionType = determineConnectionType(sessionA: sessionA, sessionB: sessionB, score: totalScore)
        
        return SessionConnection(
            sourceSessionId: sessionA.id,
            targetSessionId: sessionB.id,
            connectionType: connectionType,
            strength: ConnectionStrength.from(score: totalScore),
            score: totalScore,
            reasons: reasons
        )
    }
    
    // MARK: - Scoring Helper Methods
    
    private func calculateTimeProximityScore(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        let timeDiff = abs(sessionA.date.timeIntervalSince(sessionB.date))
        let daysDiff = timeDiff / (24 * 3600)
        
        let score = max(0, 1.0 - (daysDiff / Double(maxTimeGapDays)))
        
        let reason = ConnectionReason(
            type: .timeProximity,
            description: "Sessions occurred \(Int(daysDiff)) days apart",
            confidence: score,
            evidence: ["Time gap: \(Int(daysDiff)) days"]
        )
        
        return (score: score > 0.1 ? score : 0, reason: reason)
    }
    
    private func calculateTopicSimilarityScore(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        let keywordsA = Set(extractKeywords(from: sessionA))
        let keywordsB = Set(extractKeywords(from: sessionB))
        
        let intersection = keywordsA.intersection(keywordsB)
        let union = keywordsA.union(keywordsB)
        
        let score = union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
        
        let reason = ConnectionReason(
            type: .topicOverlap,
            description: "Shared \(intersection.count) common topics: \(Array(intersection).prefix(3).joined(separator: ", "))",
            confidence: score,
            evidence: Array(intersection).map { "Topic: \($0)" }
        )
        
        return (score: score > keywordSimilarityThreshold ? score : 0, reason: reason)
    }
    
    private func calculateAttendeeOverlapScore(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        let attendeesA = Set(sessionA.attendees)
        let attendeesB = Set(sessionB.attendees)
        
        let intersection = attendeesA.intersection(attendeesB)
        let union = attendeesA.union(attendeesB)
        
        let score = union.isEmpty ? 0 : Double(intersection.count) / Double(union.count)
        
        let reason = ConnectionReason(
            type: .sharedAttendees,
            description: "Shared \(intersection.count) attendees: \(Array(intersection).joined(separator: ", "))",
            confidence: score,
            evidence: Array(intersection).map { "Attendee: \($0)" }
        )
        
        return (score: score > 0.3 ? score : 0, reason: reason)
    }
    
    private func calculateActionItemContinuity(sessionA: ExecutiveSession, sessionB: ExecutiveSession) -> (score: Double, reason: ConnectionReason) {
        let actionsA = Set(sessionA.notes.flatMap { $0.actionItems.map { $0.title.lowercased() } })
        let actionsB = Set(sessionB.notes.flatMap { $0.actionItems.map { $0.title.lowercased() } })
        
        let continuityScore = actionsA.isEmpty ? 0 : Double(actionsA.intersection(actionsB).count) / Double(actionsA.count)
        
        let reason = ConnectionReason(
            type: .actionItemLink,
            description: "Action items continue across sessions",
            confidence: continuityScore,
            evidence: ["Continuing actions detected"]
        )
        
        return (score: continuityScore > 0.2 ? continuityScore : 0, reason: reason)
    }
    
    // MARK: - Helper Methods
    
    private func extractKeywords(from session: ExecutiveSession) -> [String] {
        var keywords: [String] = []
        
        // Extract from title
        keywords.append(contentsOf: session.title.components(separatedBy: .whitespaces))
        
        // Extract from notes
        for note in session.notes {
            keywords.append(contentsOf: note.content.components(separatedBy: .whitespaces))
            keywords.append(contentsOf: note.insights)
        }
        
        // Clean and filter keywords
        return keywords
            .map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 3 }
            .filter { !["this", "that", "with", "from", "they", "were", "been", "have", "will", "would", "could", "should"].contains($0) }
    }
    
    private func determineConnectionType(sessionA: ExecutiveSession, sessionB: ExecutiveSession, score: Double) -> ConnectionType {
        if score > criticalConnectionThreshold {
            return .followUp
        } else if score > strongConnectionThreshold {
            return .strategicThread
        } else {
            return .topicSimilarity
        }
    }
    
    private func buildCluster(startingFrom session: ExecutiveSession, sessions: [ExecutiveSession], connections: [SessionConnection]) -> SessionCluster {
        var clusterSessions: Set<UUID> = [session.id]
        var queue: [UUID] = [session.id]
        
        while !queue.isEmpty {
            let currentId = queue.removeFirst()
            
            // Find connections from this session
            let relatedConnections = connections.filter {
                ($0.sourceSessionId == currentId || $0.targetSessionId == currentId) &&
                $0.score > strongConnectionThreshold
            }
            
            for connection in relatedConnections {
                let relatedId = connection.sourceSessionId == currentId ? connection.targetSessionId : connection.sourceSessionId
                
                if !clusterSessions.contains(relatedId) {
                    clusterSessions.insert(relatedId)
                    queue.append(relatedId)
                }
            }
        }
        
        let clusterSessionObjects = sessions.filter { clusterSessions.contains($0.id) }
        let relevantConnections = connections.filter {
            clusterSessions.contains($0.sourceSessionId) && clusterSessions.contains($0.targetSessionId)
        }
        
        // Calculate cluster metrics
        let averageDate = Date(timeIntervalSince1970: clusterSessionObjects.map { $0.date.timeIntervalSince1970 }.reduce(0, +) / Double(clusterSessionObjects.count))
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
    
    // MARK: - Conversation Pattern Analysis
    
    private func analyzeConversationPatterns(conversationSessions: [ExecutiveSession]) -> [MemoryInsight] {
        guard conversationSessions.count >= 3 else { return [] }
        
        // Analyze conversation frequency
        let conversationDates = conversationSessions.map { $0.date }.sorted()
        let intervals = zip(conversationDates.dropFirst(), conversationDates).map { $0.0.timeIntervalSince($0.1) }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        
        let frequency = averageInterval < 86400 ? "daily" : averageInterval < 604800 ? "weekly" : "monthly"
        
        return [MemoryInsight(
            id: UUID(),
            title: "AI Coaching Engagement Pattern",
            description: "User engages in AI coaching conversations \(frequency) with \(conversationSessions.count) sessions analyzed.",
            insightType: .strategicAlignment,
            confidence: 0.8,
            relevantSessions: conversationSessions.map { $0.id },
            relevantConnections: [],
            actionableRecommendations: [
                "Continue regular coaching engagement",
                "Track conversation themes for patterns",
                "Consider deeper strategic discussions"
            ],
            businessValue: .medium,
            createdAt: Date()
        )]
    }
    
    private func analyzeCoachingEffectiveness(conversationSessions: [ExecutiveSession], businessSessions: [ExecutiveSession]) -> [MemoryInsight] {
        // Find business sessions that occurred after coaching conversations
        let coachingDates = conversationSessions.map { $0.date }
        let sessionsAfterCoaching = businessSessions.filter { session in
            coachingDates.contains { coachingDate in
                session.date > coachingDate && session.date.timeIntervalSince(coachingDate) < 604800 // Within a week
            }
        }
        
        if sessionsAfterCoaching.count >= 2 {
            let effectiveness = Double(sessionsAfterCoaching.count) / Double(conversationSessions.count)
            
            return [MemoryInsight(
                id: UUID(),
                title: "Coaching-to-Action Effectiveness",
                description: "AI coaching conversations led to \(sessionsAfterCoaching.count) follow-up business sessions within a week, indicating \(Int(effectiveness * 100))% coaching effectiveness.",
                insightType: .strategicAlignment,
                confidence: min(effectiveness, 0.9),
                relevantSessions: conversationSessions.map { $0.id } + sessionsAfterCoaching.map { $0.id },
                relevantConnections: [],
                actionableRecommendations: [
                    "Document successful coaching-to-action patterns",
                    "Identify topics that lead to quick implementation",
                    "Schedule follow-up sessions for complex discussions"
                ],
                businessValue: effectiveness > 0.5 ? .high : .medium,
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
            businessValue: .high,
            createdAt: Date()
        )]
    }
    
    // MARK: - Stub implementations for pattern detection methods
    
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
