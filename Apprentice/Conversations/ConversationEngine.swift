//
//  ConversationEngine.swift
//  Stitch Executive AI
//
//  Layer 5: Business Logic - Complete conversation intelligence with MEMORY
//  Enhanced with DUAL-MODE: Assistant vs Mentor interaction types
//  FIXED: ProactiveInsight defined before class to fix scope issues
//

import Foundation

// MARK: - Supporting Models (MUST be defined before class that uses them)

struct ProactiveInsight: Codable, Identifiable {
    let id = UUID()
    let type: InsightType
    let message: String
    let priority: Priority
    let timestamp = Date()
    
    enum InsightType: String, Codable {
        case pattern = "Pattern Recognition"
        case opportunity = "Business Opportunity"
        case risk = "Risk Alert"
        case recommendation = "Strategic Recommendation"
    }
    
    enum Priority: String, Codable {
        case low, medium, high, urgent
    }
}

enum InteractionType {
    case assistant  // Direct, helpful, factual information delivery
    case mentor     // Challenging, expert, stern guidance and coaching
}

enum CoachingRelationshipLevel: String {
    case initial = "Initial Discovery (0-5 sessions)"
    case exploring = "Exploring Patterns (6-15 sessions)"
    case understanding = "Understanding Phase (16-30 sessions)"
    case intimate = "Intimate Partnership (31+ sessions)"
}

struct ConversationResult {
    let transcript: String
    let response: String
    let insights: [ProactiveInsight]
    let memoryConnections: [SessionConnection]
    let relatedSessions: [ExecutiveSession]
}

// MARK: - Memory Search Result

struct MemorySearchResult {
    let relatedSessions: [ExecutiveSession]
    let connections: [SessionConnection]
    let searchScore: Double
}

@MainActor
class ConversationEngine: ObservableObject {
    
    // MARK: - Dependencies
    
    private let realAIService: RealAIService
    private let documentManager: SafeDocumentManager
    private let profileManager: FounderProfileManager
    private let sessionManager: SessionManager
    private let memoryCalculator = MemoryConnectionCalculator() // Create internally
    
    // MARK: - Conversation State
    
    @Published var conversationHistory: [SimpleConversationTurn] = []
    @Published var currentContext: String = ""
    @Published var proactiveInsights: [ProactiveInsight] = [] // Now ProactiveInsight is in scope!
    
    // MARK: - Initialization State
    
    private var contextInitialized = false
    private var initializationTask: Task<Void, Never>?
    
    // MARK: - FIXED: Simplified Initialization (No async in init)
    
    init(
        realAIService: RealAIService,
        documentManager: SafeDocumentManager,
        profileManager: FounderProfileManager,
        sessionManager: SessionManager
    ) {
        self.realAIService = realAIService
        self.documentManager = documentManager
        self.profileManager = profileManager
        self.sessionManager = sessionManager
        
        print("🤖 [CONVERSATION] ConversationEngine initialized")
        // Context initialization will happen when first needed
    }
    
    deinit {
        initializationTask?.cancel()
    }
    
    // MARK: - Context Initialization (Lazy)
    
    private func ensureContextInitialized() async {
        guard !contextInitialized else { return }
        
        // Only allow one initialization at a time
        if let existingTask = initializationTask {
            await existingTask.value
            return
        }
        
        initializationTask = Task {
            await buildInitialContext()
            contextInitialized = true
            print("✅ [CONVERSATION] Context initialized")
        }
        
        await initializationTask!.value
    }
    
    // MARK: - Core Conversation Intelligence
    
    func generateProactiveWelcome() async -> String {
        print("🤖 [CONVERSATION] Generating proactive welcome with full context")
        
        // Ensure context is initialized before proceeding
        await ensureContextInitialized()
        
        guard let profile = profileManager.founderProfile else {
            return "Hello! I'm your executive AI coach. Let me learn about your business first so I can provide personalized guidance."
        }
        
        let context = await buildComprehensiveContext()
        return await buildContextualWelcome(profile: profile, context: context)
    }
    
    func processAudioInput(_ audioURL: URL) async throws -> ConversationResult {
        print("🤖 [CONVERSATION] Processing audio with memory integration")
        
        await ensureContextInitialized()
        
        // Step 1: Transcribe audio
        let transcript = try await realAIService.transcribeAudio(audioURL: audioURL)
        
        // Step 2: Use text processing with dual-mode detection
        return try await processTextInput(transcript)
    }
    
    // MARK: - FIXED: Text Input Processing with REAL Memory Integration
    
    func processTextInput(_ transcript: String) async throws -> ConversationResult {
        print("🤖 [CONVERSATION] Processing text input with memory search")
        print("📤 Input: '\(transcript)'")
        
        await ensureContextInitialized()
        
        // Step 1: Search for relevant memories FIRST
        let memoryResults = await searchMemoryForQuery(transcript)
        print("🧠 Found \(memoryResults.relatedSessions.count) related sessions and \(memoryResults.connections.count) memory connections")
        
        // Step 2: Detect interaction type
        let interactionType = detectInteractionType(transcript)
        print("🎯 Interaction type detected: \(interactionType)")
        
        // Step 3: Build comprehensive context WITH memory results
        let context = await buildComprehensiveContextWithMemory(memoryResults: memoryResults)
        let contextualPrompt = buildContextualPrompt(userInput: transcript, context: context, memoryResults: memoryResults)
        
        print("💬 Using \(interactionType == .assistant ? "ASSISTANT" : "MENTOR") mode")
        
        // Step 4: Generate response
        let response = try await realAIService.generateCoachingResponse(prompt: contextualPrompt)
        
        // Step 5: Update conversation history
        let turn = SimpleConversationTurn(
            userInput: transcript,
            aiResponse: response,
            sessionId: UUID().uuidString // Convert to string for compatibility
        )
        conversationHistory.append(turn)
        
        // Keep history manageable
        if conversationHistory.count > 50 {
            conversationHistory = Array(conversationHistory.suffix(40))
        }
        
        // Step 6: Generate insights
        let insights = await generateProactiveInsights(from: response, context: context)
        proactiveInsights = insights
        
        return ConversationResult(
            transcript: transcript,
            response: response,
            insights: insights,
            memoryConnections: memoryResults.connections,
            relatedSessions: memoryResults.relatedSessions
        )
    }
    
    // MARK: - Simple Processing for Fast Responses
    
    func processUserInputSimple(_ transcript: String) async throws -> String {
        print("🤖 [CONVERSATION] Simple processing for: '\(transcript)'")
        
        // Build minimal context for speed
        let quickContext = buildQuickContext()
        
        let prompt = """
        Context: \(quickContext)
        User input: "\(transcript)"
        
        Respond as an executive AI coach. Be direct and conversational. Keep responses under 60 words.
        Focus on being helpful and actionable.
        """
        
        return try await realAIService.generateCoachingResponse(prompt: prompt)
    }
    
    // MARK: - Memory Search and Analysis
    
    private func searchMemoryForQuery(_ query: String) async -> MemorySearchResult {
        // Extract key terms for memory search
        let searchTerms = extractKeyTerms(from: query)
        
        // Find related sessions
        let relatedSessions = sessionManager.sessions.filter { session in
            searchTerms.contains { term in
                session.title.localizedCaseInsensitiveContains(term) ||
                session.attendees.contains { $0.localizedCaseInsensitiveContains(term) } ||
                session.notes.contains { note in
                    note.content.localizedCaseInsensitiveContains(term)
                }
            }
        }
        
        // FIXED: Use the correct method name from the existing MemoryConnectionCalculator
        let connections = await memoryCalculator.analyzeConnections(sessions: relatedSessions)
        
        return MemorySearchResult(
            relatedSessions: Array(relatedSessions.prefix(5)), // Limit for performance
            connections: connections,
            searchScore: calculateAverageScore(for: connections)
        )
    }
    
    private func calculateAverageScore(for connections: [SessionConnection]) -> Double {
        guard !connections.isEmpty else { return 0.0 }
        return connections.reduce(0.0) { $0 + $1.score } / Double(connections.count)
    }
    
    // MARK: - Context Building (Simplified)
    
    private func buildInitialContext() async {
        currentContext = await buildComprehensiveContext()
        print("📋 [CONVERSATION] Initial context built: \(currentContext.count) characters")
    }
    
    private func buildComprehensiveContext() async -> String {
        var context = ""
        
        // Profile context
        if let profile = profileManager.founderProfile {
            context += buildProfileContext(profile)
            context += "\n\n"
        }
        
        // Document context
        if !documentManager.documents.isEmpty {
            context += await buildDocumentContext()
            context += "\n\n"
        }
        
        // Session context
        context += await buildSessionContext()
        
        return context
    }
    
    private func buildQuickContext() -> String {
        var context = ""
        
        if let profile = profileManager.founderProfile {
            context += "Founder: \(profile.founderName), \(profile.founderRole)\n"
            context += "Business: \(profile.businessName ?? "Startup")\n"
            context += "Industry: \(profile.industry)\n"
        }
        
        return context
    }
    
    private func buildProfileContext(_ profile: FounderProfile) -> String {
        return """
        FOUNDER PROFILE:
        Name: \(profile.founderName)
        Role: \(profile.founderRole)
        Business: \(profile.businessName ?? "Startup")
        Industry: \(profile.industry)
        Stage: \(profile.businessStage.rawValue)
        Current Challenges: \(profile.currentChallenges.joined(separator: ", "))
        """
    }
    
    private func buildComprehensiveContextWithMemory(memoryResults: MemorySearchResult) async -> String {
        var baseContext = await buildComprehensiveContext()
        
        guard !memoryResults.relatedSessions.isEmpty else {
            return baseContext
        }
        
        var context = "🧠 RELEVANT PREVIOUS CONVERSATIONS:\n\n"
        
        for (index, session) in memoryResults.relatedSessions.enumerated() {
            context += "📋 SESSION \(index + 1): \(session.title)\n"
            context += "📅 Date: \(session.date.formatted(date: .abbreviated, time: .shortened))\n"
            
            if !session.attendees.isEmpty {
                context += "👥 Attendees: \(session.attendees.joined(separator: ", "))\n"
            }
            
            context += "📝 Type: \(session.type.rawValue)\n"
            
            // Include key notes and decisions
            if !session.notes.isEmpty {
                context += "💡 Key Points:\n"
                for note in session.notes.prefix(2) {
                    context += "  • \(note.title): \(note.content.prefix(100))...\n"
                }
            }
            
            // Include action items
            let actionItems = session.notes.flatMap { $0.actionItems }
            if !actionItems.isEmpty {
                context += "✅ Actions: \(actionItems.prefix(2).map { $0.title }.joined(separator: ", "))\n"
            }
            
            context += "\n"
        }
        
        // Include memory connections
        if !memoryResults.connections.isEmpty {
            context += "🔗 MEMORY CONNECTIONS:\n"
            for connection in memoryResults.connections.prefix(3) {
                context += "• \(connection.connectionType.rawValue): Connection between related sessions\n"
            }
            context += "\n"
        }
        
        context += "You have access to these conversations and can reference specific details from them.\n"
        return context
    }
    
    private func buildDocumentContext() async -> String {
        let recentDocs = Array(documentManager.documents.suffix(3))
        guard !recentDocs.isEmpty else {
            return "No documents available"
        }
        
        var context = "AVAILABLE DOCUMENTS:\n"
        
        for doc in recentDocs {
            context += "\n📄 \(doc.title):\n"
            
            if !doc.businessInsights.isEmpty {
                context += "💡 INSIGHTS:\n"
                for (index, insight) in doc.businessInsights.enumerated() {
                    context += "\(index + 1). \(insight)\n"
                }
                context += "\n"
            }
            
            if !doc.actionItems.isEmpty {
                context += "📋 ACTION ITEMS:\n"
                for (index, action) in doc.actionItems.enumerated() {
                    context += "\(index + 1). \(action)\n"
                }
                context += "\n"
            }
            
            if let extractedText = doc.extractedText, !extractedText.isEmpty {
                context += "📖 DOCUMENT CONTENT:\n\(extractedText.prefix(1500))\n\n"
            }
            
            context += "---\n\n"
        }
        
        context += "User can reference any specific insights, action items, or content from these documents.\n"
        return context
    }
    
    private func buildSessionContext() async -> String {
        let recentSessions = Array(sessionManager.sessions.suffix(3))
        guard !recentSessions.isEmpty else {
            return "No recent sessions"
        }
        
        var context = "RECENT SESSIONS:\n"
        for session in recentSessions {
            context += """
            📋 \(session.title) (\(session.type.rawValue)):
              Priority: \(session.priority.rawValue)
              Notes: \(session.notes.count) items
              Action Items: \(session.notes.flatMap { $0.actionItems }.count)
            
            """
        }
        return context
    }
    
    private func buildContextualWelcome(profile: FounderProfile, context: String) async -> String {
        let contextPrompt = """
        Generate a personalized welcome message for:
        - \(profile.founderName), \(profile.founderRole) at \(profile.businessName ?? "their company")
        - Industry: \(profile.industry)
        - Stage: \(profile.businessStage.rawValue)
        - Current challenges: \(profile.currentChallenges.joined(separator: ", "))
        
        Be proactive and reference their specific business context. Ask about their most pressing current priority.
        Keep it under 3 sentences and be direct.
        """
        
        do {
            return try await realAIService.generateCoachingResponse(prompt: contextPrompt)
        } catch {
            return "Hello \(profile.founderName). What's the most critical business challenge you're facing right now?"
        }
    }
    
    // MARK: - DUAL-MODE Contextual Prompt Building (ENHANCED with Memory)
    
    private func buildContextualPrompt(userInput: String, context: String, memoryResults: MemorySearchResult) -> String {
        
        // Detect interaction type
        let interactionType = detectInteractionType(userInput)
        let relationshipLevel = calculateCurrentRelationshipLevel()
        
        let basePrompt = """
        You are an executive AI coach with deep knowledge of this founder's business context:
        
        \(context)
        
        CONVERSATION HISTORY (Last 3 turns):
        \(conversationHistory.suffix(3).map { "User: \($0.userInput)\nAI: \($0.aiResponse)" }.joined(separator: "\n\n"))
        
        RELATIONSHIP LEVEL: \(relationshipLevel.rawValue)
        USER INPUT: "\(userInput)"
        """
        
        // Switch response mode based on request type
        switch interactionType {
        case .assistant:
            return basePrompt + """
            
            📋 ASSISTANT MODE: Direct information delivery requested.
            Provide factual, structured information with specific recommendations.
            Include relevant data points and actionable next steps.
            Keep response under 150 words, well-organized with bullet points if helpful.
            """
            
        case .mentor:
            return basePrompt + """
            
            🎯 MENTOR MODE: Coaching and guidance requested.
            Ask probing questions to understand the deeper situation.
            Provide strategic perspective and help them think through challenges.
            Be supportive but challenge their thinking when appropriate.
            Keep response conversational, under 100 words.
            """
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateProactiveInsights(from turn: SimpleConversationTurn) async {
        print("🤖 [CONVERSATION] Updating proactive insights from latest turn")
        
        let insight = ProactiveInsight( // Now in scope!
            type: .recommendation,
            message: "New conversation pattern detected from recent interaction",
            priority: .medium
        )
        proactiveInsights.append(insight)
    }
    
    private func detectInteractionType(_ input: String) -> InteractionType {
        let lower = input.lowercased()
        
        // Assistant triggers - direct information requests
        if lower.contains("what is") || lower.contains("how do") || lower.contains("show me") ||
           lower.contains("list") || lower.contains("find") || lower.contains("search") ||
           lower.contains("calculate") || lower.contains("analyze") {
            return .assistant
        }
        
        // Mentor triggers - guidance and coaching requests
        if lower.contains("should i") || lower.contains("help me") || lower.contains("advice") ||
           lower.contains("what would you do") || lower.contains("stuck") || lower.contains("challenge") {
            return .mentor
        }
        
        // Default to mentor for relationship building
        return .mentor
    }
    
    private func calculateCurrentRelationshipLevel() -> CoachingRelationshipLevel {
        let turnCount = conversationHistory.count
        
        switch turnCount {
        case 0...5: return .initial
        case 6...15: return .exploring
        case 16...30: return .understanding
        default: return .intimate
        }
    }
    
    private func extractKeyTerms(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 3 }
            .filter { !["that", "this", "with", "have", "been", "will", "from", "they"].contains($0) }
        
        return Array(Set(words)) // Remove duplicates
    }
    
    private func generateProactiveInsights(from response: String, context: String) async -> [ProactiveInsight] {
        // Generate insights based on the conversation
        var insights: [ProactiveInsight] = []
        
        if response.contains("action") {
            insights.append(ProactiveInsight( // Now in scope!
                type: .recommendation,
                message: "Consider documenting this action item for follow-up",
                priority: .medium
            ))
        }
        
        if response.contains("meeting") || response.contains("discuss") {
            insights.append(ProactiveInsight( // Now in scope!
                type: .recommendation,
                message: "This might benefit from a structured agenda",
                priority: .medium
            ))
        }
        
        return insights
    }
    
    private func MybuildInitialContext() async {
        currentContext = await buildComprehensiveContext()
        print("🤖 [CONVERSATION] Initial context built")
    }
}
