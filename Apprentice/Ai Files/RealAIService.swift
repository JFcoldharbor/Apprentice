// MARK: - NEW: Contextual Greeting Generation System
    
    func generateContextualGreeting(context: AIContext) async throws -> String {
        print("[AI] Generating contextual greeting with full analysis...")
        
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        
        let greetingContext = buildGreetingContext(context: context)
        let systemPrompt = """
        You are an AI business coach generating a contextual greeting that feels natural and relevant.
        
        GREETING RULES:
        1. NEVER say generic greetings like "Good morning" unless it's the very first interaction of the day
        2. Reference specific previous conversations or patterns you've observed
        3. Be proactive - raise concerns, observations, or opportunities
        4. Tailor to time of day and business context
        5. Keep it conversational and direct (2-3 sentences max)
        
        GREETING TYPES:
        - If returning after days: Reference last conversation topic
        - If same day return: Comment on progress or follow up on earlier discussion  
        - If new week: Analyze week's patterns and provide insight
        - If goal deadline approaching: Address urgency and progress
        - If long pause in conversation: Bring up unfinished business or new concerns
        
        BE DIRECT AND SPECIFIC - not generic coaching speak.
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: greetingContext)
        ]
        
        let greeting = try await sendChatCompletion(messages: messages, maxTokens: 200)
        
        print("[AI] Contextual greeting generated")
        return greeting
    }
    
    private func buildGreetingContext(context: AIContext) -> String {
        var greetingContext = "Generate a contextual greeting based on:\n\n"
        
        // Time Analysis
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        
        greetingContext += "CURRENT TIME CONTEXT:\n"
        greetingContext += "Time: \(hour):00 on \(getDayName(dayOfWeek))\n"
        
        // Conversation History Analysis
        if let lastConversation = context.conversationHistory.last {
            let timeSinceLastInteraction = now.timeIntervalSince(lastConversation.timestamp)
            let daysSince = Int(timeSinceLastInteraction / 86400)
            let hoursSince = Int(timeSinceLastInteraction / 3600)
            
            greetingContext += "\nLAST INTERACTION:\n"
            if daysSince > 0 {
                greetingContext += "- \(daysSince) days ago\n"
            } else if hoursSince > 0 {
                greetingContext += "- \(hoursSince) hours ago\n"
            } else {
                greetingContext += "- Less than an hour ago\n"
            }
            
            greetingContext += "- Last topic: \(lastConversation.userInput)\n"
            greetingContext += "- AI response was about: \(String(lastConversation.aiResponse.prefix(100)))\n"
            
            // Conversation Patterns
            let patterns = analyzeConversationPatterns(context.conversationHistory)
            if !patterns.isEmpty {
                greetingContext += "- Observed patterns: \(patterns.joined(separator: ", "))\n"
            }
        } else {
            greetingContext += "\nFIRST INTERACTION: This is the first conversation today\n"
        }
        
        // Business Context
        if let profile = context.founderProfile {
            greetingContext += "\nFOUNDER CONTEXT:\n"
            greetingContext += "- \(profile.founderName), \(profile.founderRole)\n"
            greetingContext += "- Company: \(profile.businessName ?? "their business")\n"
            greetingContext += "- Industry: \(profile.industry)\n"
            greetingContext += "- Stage: \(profile.businessStage.rawValue)\n"
            
            if !profile.currentGoals.isEmpty {
                greetingContext += "- Current goals: \(profile.currentGoals.joined(separator: ", "))\n"
                
                // Goal urgency analysis
                let urgentGoals = profile.currentGoals.filter { goal in
                    goal.lowercased().contains("q1") || goal.lowercased().contains("q2") ||
                    goal.lowercased().contains("month") || goal.lowercased().contains("week")
                }
                
                if !urgentGoals.isEmpty {
                    greetingContext += "- Time-sensitive goals: \(urgentGoals.joined(separator: ", "))\n"
                }
            }
            
            if !profile.currentChallenges.isEmpty {
                greetingContext += "- Current challenges: \(profile.currentChallenges.joined(separator: ", "))\n"
            }
        }
        
        // Recent Sessions Analysis
        let recentSessions = Array(sessionManager.sessions.suffix(5))
        if !recentSessions.isEmpty {
            greetingContext += "\nRECENT BUSINESS ACTIVITY:\n"
            greetingContext += "- \(recentSessions.count) sessions in recent history\n"
            
            let sessionTypes = recentSessions.map { $0.type.rawValue }
            let mostCommonType = mostFrequentElement(in: sessionTypes)
            greetingContext += "- Most frequent session type: \(mostCommonType ?? "Mixed")\n"
            
            let highPrioritySessions = recentSessions.filter { $0.priority == .high || $0.priority == .critical }
            if !highPrioritySessions.isEmpty {
                greetingContext += "- \(highPrioritySessions.count) high-priority sessions recently\n"
            }
        }
        
        // Document Context
        if !context.documentContext.isEmpty {
            greetingContext += "\nDOCUMENT ACTIVITY:\n"
            greetingContext += "- Recent documents available for discussion\n"
        }
        
        greetingContext += "\nGREETING REQUIREMENTS:\n"
        greetingContext += "- Be specific and reference actual context above\n"
        greetingContext += "- Don't use generic time-based greetings\n"
        greetingContext += "- Be proactive and insightful\n"
        greetingContext += "- Focus on business value and next steps\n"
        
        return greetingContext
    }
    
    private func analyzeConversationPatterns(_ history: [SimpleConversationTurn]) -> [String] {
        guard history.count >= 3 else { return [] }
        
        var patterns: [String] = []
        let recentInputs = history.suffix(5).map { $0.userInput.lowercased() }
        let recentResponses = history.suffix(5).map { $0.aiResponse.lowercased() }
        
        // Decision-making pattern
        let decisionWords = ["should", "choose", "decide", "which", "better"]
        if recentInputs.flatMap({ input in decisionWords.filter { input.contains($0) } }).count >= 2 {
            patterns.append("seeks guidance on decisions")
        }
        
        // Challenge discussion pattern
        let challengeWords = ["problem", "issue", "challenge", "stuck", "difficult"]
        if recentInputs.flatMap({ input in challengeWords.filter { input.contains($0) } }).count >= 2 {
            patterns.append("openly discusses challenges")
        }
        
        // Strategic thinking pattern
        let strategyWords = ["strategy", "plan", "future", "growth", "scale"]
        if recentInputs.flatMap({ input in strategyWords.filter { input.contains($0) } }).count >= 2 {
            patterns.append("focuses on strategic planning")
        }
        
        // Team/people pattern
        let teamWords = ["team", "hire", "employee", "staff", "people"]
        if recentInputs.flatMap({ input in teamWords.filter { input.contains($0) } }).count >= 2 {
            patterns.append("concerned with team dynamics")
        }
        
        // Implementation pattern
        let actionWords = ["implement", "execute", "do", "start", "begin"]
        if recentInputs.flatMap({ input in actionWords.filter { input.contains($0) } }).count >= 2 {
            patterns.append("action-oriented discussions")
        }
        
        return patterns
    }
    
    private func getDayName(_ weekday: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[weekday - 1]
    }
    
    private func mostFrequentElement<T: Hashable>(in array: [T]) -> T? {
        let counts = Dictionary(grouping: array, by: { $0 }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }//
//  RealAIService.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Consolidated AI business partner integration
//  ENHANCED: Added vector embeddings and RAG capabilities for document recall
//  UPDATED: Added semantic search for Claude-like document memory
//

import Foundation

// MARK: - Vector Embedding Models

struct DocumentEmbedding: Codable {
    let documentId: UUID
    let text: String
    let embedding: [Double]
    let createdAt: Date
}

struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
    
    struct EmbeddingData: Codable {
        let embedding: [Double]
    }
}

struct EmbeddingRequest: Codable {
    let model: String
    let input: String
}

// MARK: - AI Context Model

struct AIContext {
    let documentContext: String
    let conversationHistory: [SimpleConversationTurn]
    let founderProfile: FounderProfile?
    let businessContext: String
    let sessionContext: String
    let personalityInsights: PersonalityInsights?
    
    init(documentContext: String = "", conversationHistory: [SimpleConversationTurn] = [], founderProfile: FounderProfile? = nil, businessContext: String = "", sessionContext: String = "", personalityInsights: PersonalityInsights? = nil) {
        self.documentContext = documentContext
        self.conversationHistory = conversationHistory
        self.founderProfile = founderProfile
        self.businessContext = businessContext
        self.sessionContext = sessionContext
        self.personalityInsights = personalityInsights
    }
}

// MARK: - Enhanced RealAI Service with RAG

@MainActor
class RealAIService: ObservableObject, AIServiceProtocol {
    
    // MARK: - Configuration
    
    private let apiKey = Config.OpenAI.apiKey
    private let baseURL = Config.OpenAI.baseURL
    
    // MARK: - RAG Configuration
    
    private let embeddingModel = "text-embedding-3-small"
    private let maxContextLength = 4000
    private let similarityThreshold: Double = 0.7
    
    // MARK: - Conversation Continuation (NEW)
    
    @Published var lastIncompleteResponse: String?
    @Published var conversationWasCutOff = false
    private var lastResponseWasComplete = true
    
    // MARK: - Vector Storage
    
    @Published var documentEmbeddings: [DocumentEmbedding] = []
    private let embeddingsStorageURL: URL
    
    // MARK: - Business Intelligence Dependencies
    
    private var sessionManager = SessionManager.shared
    private var profileManager = FounderProfileManager.shared
    
    // MARK: - Optimized URLSession
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()
    
    // MARK: - Initialization
    
    init() {
        // Initialize embeddings storage
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        embeddingsStorageURL = documentsURL.appendingPathComponent("document_embeddings.json")
        
        // Load existing embeddings
        loadEmbeddings()
    }
    
    // MARK: - AI Service Protocol Methods
    
    func transcribeAudio(audioURL: URL) async throws -> String {
        print("[AI] Starting audio transcription...")
        
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AIServiceError.transcriptionFailed
        }
        
        let url = URL(string: "\(baseURL)/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let audioData = try Data(contentsOf: audioURL)
        let httpBody = createMultipartBody(boundary: boundary, audioData: audioData, filename: audioURL.lastPathComponent)
        request.httpBody = httpBody
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        
        print("[AI] Transcription successful")
        return transcriptionResponse.text
    }
    
    // MARK: - NEW: Vector Embeddings for RAG
    
    func generateEmbedding(for text: String) async throws -> [Double] {
        print("[RAG] Generating embedding for text: \(text.prefix(100))...")
        
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        
        let url = URL(string: "\(baseURL)/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = EmbeddingRequest(
            model: embeddingModel,
            input: text
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        
        guard let embedding = embeddingResponse.data.first?.embedding else {
            throw AIServiceError.invalidResponse
        }
        
        print("[RAG] Embedding generated successfully")
        return embedding
    }
    
    func storeDocumentEmbedding(documentId: UUID, text: String) async throws {
        print("[RAG] Storing document embedding for document: \(documentId)")
        
        let embedding = try await generateEmbedding(for: text)
        
        let documentEmbedding = DocumentEmbedding(
            documentId: documentId,
            text: text,
            embedding: embedding,
            createdAt: Date()
        )
        
        documentEmbeddings.append(documentEmbedding)
        saveEmbeddings()
        
        print("[RAG] Document embedding stored successfully")
    }
    
    func findSimilarDocuments(query: String, limit: Int = 3) async throws -> [DocumentEmbedding] {
        print("[RAG] Finding similar documents for query: \(query)")
        
        guard !documentEmbeddings.isEmpty else {
            print("[RAG] No document embeddings available")
            return []
        }
        
        let queryEmbedding = try await generateEmbedding(for: query)
        
        var similarities: [(DocumentEmbedding, Double)] = []
        
        for docEmbedding in documentEmbeddings {
            let similarity = cosineSimilarity(queryEmbedding, docEmbedding.embedding)
            if similarity > similarityThreshold {
                similarities.append((docEmbedding, similarity))
            }
        }
        
        // Sort by similarity score (highest first) and limit results
        let topResults = similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
        
        print("[RAG] Found \(topResults.count) similar documents")
        return Array(topResults)
    }
    
    // MARK: - Context-Aware Response Generation with RAG
    
    func generateResponse(prompt: String, context: AIContext) async throws -> String {
        print("[AI] Generating RAG-enhanced response...")
        
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        
        // Check if this is a continuation request
        let isContinuationRequest = prompt.lowercased().contains("continue") ||
                                   prompt.lowercased().contains("finish") ||
                                   prompt.lowercased().contains("didn't finish") ||
                                   conversationWasCutOff
        
        if isContinuationRequest && lastIncompleteResponse != nil {
            return try await continueLastResponse(context: context)
        }
        
        // Find relevant documents using semantic search
        let relevantDocs = try await findSimilarDocuments(query: prompt)
        
        // Build enhanced context with retrieved documents
        let ragContext = buildRAGContext(from: relevantDocs, originalContext: context)
        let enhancedPrompt = buildEnhancedPrompt(prompt: prompt, context: ragContext)
        let systemPrompt = await createBusinessPartnerPersonality(context: ragContext)
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: enhancedPrompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages, maxTokens: 500) // Increased from 250
        
        // Track if response might be incomplete
        trackResponseCompleteness(response)
        
        print("[AI] RAG-enhanced response generated")
        return response
    }
    
    // MARK: - NEW: Conversation Continuation Methods
    
    private func continueLastResponse(context: AIContext) async throws -> String {
        print("[AI] Continuing previous incomplete response...")
        
        guard let incompleteResponse = lastIncompleteResponse else {
            throw AIServiceError.invalidResponse
        }
        
        let continuationPrompt = """
        You were providing a response but it was cut off. Here's what you said so far:
        
        "\(incompleteResponse)"
        
        Please continue from where you left off, picking up mid-sentence if necessary. 
        Don't repeat what you already said, just continue the thought.
        """
        
        let systemPrompt = await createBusinessPartnerPersonality(context: context)
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: continuationPrompt)
        ]
        
        let continuation = try await sendChatCompletion(messages: messages, maxTokens: 400)
        
        // Combine responses and clear continuation state
        let fullResponse = incompleteResponse + " " + continuation
        clearContinuationState()
        
        print("[AI] Continued response successfully")
        return continuation // Return only the continuation part
    }
    
    private func trackResponseCompleteness(_ response: String) {
        // Check if response ends abruptly (incomplete sentence)
        let endsWithPeriod = response.hasSuffix(".")
        let endsWithExclamation = response.hasSuffix("!")
        let endsWithQuestion = response.hasSuffix("?")
        let endsWithColon = response.hasSuffix(":")
        let endsWithIncompleteWord = response.last?.isLetter == true
        
        let seemsComplete = endsWithPeriod || endsWithExclamation || endsWithQuestion
        let seemsIncomplete = endsWithColon || endsWithIncompleteWord ||
                             response.split(separator: " ").last?.count ?? 0 < 3
        
        if seemsIncomplete || (!seemsComplete && response.count > 400) {
            // Likely cut off due to token limit
            lastIncompleteResponse = response
            conversationWasCutOff = true
            lastResponseWasComplete = false
            print("[AI] ⚠️ Response appears incomplete, saved for continuation")
        } else {
            clearContinuationState()
            lastResponseWasComplete = true
        }
    }
    
    private func clearContinuationState() {
        lastIncompleteResponse = nil
        conversationWasCutOff = false
        lastResponseWasComplete = true
    }
    
    // MARK: - Proactive Insight Generation
    
    func generateProactiveInsight(context: AIContext) async throws -> String {
        print("[AI] Generating proactive insight...")
        
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        
        let proactivePrompt = buildProactivePrompt(context: context)
        let systemPrompt = """
        You're a proactive business coach. Start conversations by:
        1. Referencing specific previous discussions
        2. Identifying patterns you've observed
        3. Raising concerns before they ask
        4. Being direct about what needs attention
        
        Be concise but impactful - 2-3 sentences maximum.
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: proactivePrompt)
        ]
        
        let response = try await sendChatCompletion(messages: messages, maxTokens: 150)
        return response
    }
    
    func generateCoachingResponse(prompt: String) async throws -> String {
        print("[AI] Generating coaching response...")
        
        // Check for continuation request first
        if (prompt.lowercased().contains("continue") ||
            prompt.lowercased().contains("finish") ||
            prompt.lowercased().contains("didn't finish")) &&
            conversationWasCutOff {
            let context = AIContext()
            return try await continueLastResponse(context: context)
        }
        
        // Use RAG-enhanced response generation
        let context = AIContext()
        return try await generateResponse(prompt: prompt, context: context)
    }
    
    func analyzeBusinessContent(content: String) async throws -> AIResponse {
        print("[AI] Analyzing business content...")
        
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        
        let systemPrompt = """
        You are an expert business analyst. Analyze the content and provide:
        1. Key business insights (3-5 points)
        2. Actionable items (3-5 specific actions)
        3. Strategic decisions (2-3 recommendations)
        4. Executive summary (2-3 sentences)
        
        Focus on actionable insights that align with their goals and challenges.
        
        Respond in JSON format:
        {
            "insights": ["insight1", "insight2"],
            "actionItems": ["action1", "action2"],
            "decisions": ["decision1", "decision2"],
            "summary": "brief summary"
        }
        """
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: content)
        ]
        
        let responseText = try await sendChatCompletion(messages: messages, maxTokens: 600)
        
        // Parse JSON response
        guard let responseData = responseText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }
        
        return AIResponse(
            insights: json["insights"] as? [String] ?? [],
            actionItems: json["actionItems"] as? [String] ?? [],
            decisions: json["decisions"] as? [String] ?? [],
            summary: json["summary"] as? String ?? responseText
        )
    }
    
    // MARK: - RAG Helper Methods
    
    private func buildRAGContext(from documents: [DocumentEmbedding], originalContext: AIContext) -> AIContext {
        var enhancedDocumentContext = originalContext.documentContext
        
        if !documents.isEmpty {
            enhancedDocumentContext += "\n\nRelevant Documents:\n"
            for doc in documents {
                enhancedDocumentContext += "- \(doc.text.prefix(500))\n"
            }
        }
        
        return AIContext(
            documentContext: enhancedDocumentContext,
            conversationHistory: originalContext.conversationHistory,
            founderProfile: originalContext.founderProfile,
            businessContext: originalContext.businessContext,
            sessionContext: originalContext.sessionContext,
            personalityInsights: originalContext.personalityInsights
        )
    }
    
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA != 0 && magnitudeB != 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    // MARK: - Embeddings Storage
    
    private func saveEmbeddings() {
        do {
            let data = try JSONEncoder().encode(documentEmbeddings)
            try data.write(to: embeddingsStorageURL)
        } catch {
            print("[RAG] Failed to save embeddings: \(error)")
        }
    }
    
    private func loadEmbeddings() {
        guard FileManager.default.fileExists(atPath: embeddingsStorageURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: embeddingsStorageURL)
            documentEmbeddings = try JSONDecoder().decode([DocumentEmbedding].self, from: data)
            print("[RAG] Loaded \(documentEmbeddings.count) document embeddings")
        } catch {
            print("[RAG] Failed to load embeddings: \(error)")
        }
    }
    
    // MARK: - Original Helper Methods (unchanged)
    
    private func buildEnhancedPrompt(prompt: String, context: AIContext) -> String {
        var enhancedPrompt = ""
        
        if let profile = context.founderProfile {
            enhancedPrompt += "Founder Context: \(profile.industry) founder with \(profile.yearsOfExperience) years experience. "
            enhancedPrompt += "Goals: \(profile.currentGoals.joined(separator: ", ")). "
            enhancedPrompt += "Challenges: \(profile.currentChallenges.joined(separator: ", ")). "
        }
        
        if !context.documentContext.isEmpty {
            enhancedPrompt += "\n\nDocument Context:\n\(context.documentContext)"
        }
        
        if !context.conversationHistory.isEmpty {
            enhancedPrompt += "\n\nRecent Conversations:\n"
            let recentTurns = context.conversationHistory.suffix(3)
            for turn in recentTurns {
                enhancedPrompt += "User: \(turn.userInput)\nAI: \(turn.aiResponse)\n"
            }
        }
        
        if !context.businessContext.isEmpty {
            enhancedPrompt += "\n\nBusiness Context: \(context.businessContext)"
        }
        
        enhancedPrompt += "\n\nCurrent Query: \(prompt)"
        
        return enhancedPrompt
    }
    
    private func buildProactivePrompt(context: AIContext) -> String {
        var proactivePrompt = "Generate a proactive coaching insight based on:"
        
        if let profile = context.founderProfile {
            proactivePrompt += "\nBusiness: \(profile.industry)"
            proactivePrompt += "\nChallenges: \(profile.currentChallenges.joined(separator: ", "))"
            proactivePrompt += "\nGoals: \(profile.currentGoals.joined(separator: ", "))"
        }
        
        if !context.conversationHistory.isEmpty {
            proactivePrompt += "\nRecent discussions: \(context.conversationHistory.suffix(2).map { $0.userInput }.joined(separator: "; "))"
        }
        
        proactivePrompt += "\n\nProvide a specific, actionable insight that addresses potential blind spots or opportunities."
        
        return proactivePrompt
    }
    
    private func createBusinessPartnerPersonality(context: AIContext) async -> String {
        let relationshipLevel = determineRelationshipLevel(from: context)
        
        var personality = """
        You are an experienced business coach and strategic advisor. Your approach:
        
        PERSONALITY:
        • Direct, insightful, and action-oriented
        • Reference specific past conversations when relevant
        • Challenge assumptions while remaining supportive
        • Focus on practical implementation over theory
        
        RELATIONSHIP LEVEL: \(relationshipLevel.description)
        """
        
        if let profile = context.founderProfile {
            personality += """
            
            FOUNDER PROFILE:
            • Business: \(profile.industry)
            • Experience: \(profile.yearsOfExperience) years
            • Current Focus: \(profile.currentGoals.joined(separator: ", "))
            • Key Challenges: \(profile.currentChallenges.joined(separator: ", "))
            """
        }
        
        personality += """
        
        RESPONSE STYLE:
        • Keep responses under 200 words unless asked for detail
        • Lead with the most important insight
        • Include 1-2 specific next steps when relevant
        • Reference documents and previous conversations naturally
        """
        
        return personality
    }
    
    private func determineRelationshipLevel(from context: AIContext) -> RAGRelationshipLevel {
        let conversationCount = context.conversationHistory.count
        
        if conversationCount >= 10 {
            return .established
        } else if conversationCount >= 3 {
            return .developing
        } else {
            return .new
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let difference = Date().timeIntervalSince(date)
        
        if difference < 60 {
            return "just now"
        } else if difference < 3600 {
            let minutes = Int(difference / 60)
            return "\(minutes)m ago"
        } else if difference < 86400 {
            let hours = Int(difference / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(difference / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Network Communication
    
    private func sendChatCompletion(messages: [ChatMessage], maxTokens: Int) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: messages,
            maxTokens: maxTokens,
            temperature: 0.7
        )
        
        let requestData = try JSONEncoder().encode(requestBody)
        request.httpBody = requestData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let firstChoice = chatResponse.choices.first else {
            throw AIServiceError.invalidResponse
        }
        
        let responseText = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[AI] Response generated: \(responseText.prefix(100))...")
        return responseText
    }
    
    private func createMultipartBody(boundary: String, audioData: Data, filename: String) -> Data {
        var data = Data()
        
        // Model parameter
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        data.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Response format parameter
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        data.append("json\r\n".data(using: .utf8)!)
        
        // Temperature parameter
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        data.append("0.0\r\n".data(using: .utf8)!)
        
        // File parameter
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        data.append(audioData)
        data.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return data
    }
}

// MARK: - RAG-Specific Supporting Types

enum RAGRelationshipLevel {
    case new
    case developing
    case established
    
    var description: String {
        switch self {
        case .new:
            return "New coaching relationship, building rapport and understanding business context"
        case .developing:
            return "Developing coaching relationship with growing understanding of business needs"
        case .established:
            return "Established coaching partnership with deep understanding of business and personal style"
        }
    }
}
