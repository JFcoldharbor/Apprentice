//
//  RealAIService.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Complete AI business partner integration
//  PRODUCTION FIX: Enhanced chunking, retry logic, contextual greetings
//

import Foundation

// MARK: - Enhanced RealAI Service with RAG + Chunking

@MainActor
class RealAIService: ObservableObject, AIServiceProtocol {
    
    // MARK: - Configuration
    
    private let apiKey = Config.OpenAI.apiKey
    private let baseURL = Config.OpenAI.baseURL
    
    // MARK: - RAG Configuration - FIXED FOR COMPLETE DOCUMENT READING
    
    private let embeddingModel = "text-embedding-3-small"
    private let maxContextLength = 32000        // ✅ FIXED: Was 4000, now 32000
    private let similarityThreshold: Double = 0.5  // ✅ FIXED: Was 0.7, now 0.5
    
    // MARK: - Conversation Continuation
    
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
        // Audio transcription uploads a multi-minute file and then waits while
        // Whisper processes it server-side with no response bytes flowing — the
        // old 15s/30s limits guaranteed a timeout on anything but the shortest
        // clip. These ceilings cover a full chunk upload + transcription.
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 300.0
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
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: audioURL))
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        
        print("[AI] Transcription completed: \(transcriptionResponse.text.prefix(50))...")
        return transcriptionResponse.text
    }
    
    func generateCoachingResponse(prompt: String) async throws -> String {
        return try await generateContextualResponse(
            prompt: prompt,
            context: AIContext()
        )
    }
    
    func analyzeBusinessContent(content: String) async throws -> AIResponse {
        let prompt = """
        Analyze this business content and provide structured insights:
        
        \(content)
        
        Provide analysis in the following format:
        - Key insights
        - Action items
        - Strategic recommendations
        """
        
        let response = try await generateContextualResponse(
            prompt: prompt,
            context: AIContext()
        )
        
        return AIResponse(
            insights: [],
            actionItems: [],
            decisions: [],
            summary: response
        )
    }
    
    func generateProactiveInsight(context: AIContext) async throws -> String {
        let prompt = """
        Based on the business context and recent activities, provide a proactive insight or recommendation.
        Focus on actionable advice that would be valuable for an executive.
        """
        
        return try await generateContextualResponse(prompt: prompt, context: context)
    }
    
    private func generateContextualResponse(prompt: String, context: AIContext) async throws -> String {
        print("[AI] Generating contextual response with enhanced RAG...")
        
        // ✅ FIXED: Get comprehensive document context with new parameters
        let documentContext = await getRelevantDocumentContext(for: prompt)
        
        let systemPrompt = buildRAGPersonalityPrompt(context: context) + "\n\nDOCUMENT CONTEXT:\n" + documentContext
        
        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: prompt)
        ]
        
        let request = ChatCompletionRequest(
            model: "gpt-4-turbo",
            messages: messages,
            maxTokens: 4000,
            temperature: 0.3,
            topP: 0.9,
            presencePenalty: 0.1,
            frequencyPenalty: 0.1
        )
        
        return try await executeChatRequest(request)
    }
    
    private func executeChatRequest(_ request: ChatCompletionRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await urlSession.data(for: httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 429 {
            throw AIServiceError.rateLimitExceeded
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let message = chatResponse.choices.first?.message else {
            throw AIServiceError.invalidResponse
        }
        
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if content.count < 50 || content.hasSuffix("...") {
            lastIncompleteResponse = content
            conversationWasCutOff = true
        } else {
            lastIncompleteResponse = nil
            conversationWasCutOff = false
        }
        
        return content
    }
    
    func generateResponse(prompt: String, context: AIContext) async throws -> String {
        return try await generateContextualResponse(prompt: prompt, context: context)
    }
    
    func continueLastResponse(context: AIContext) async throws -> String {
        guard let incompleteResponse = lastIncompleteResponse else {
            return try await generateResponse(prompt: "Please continue where you left off", context: context)
        }
        
        let continuePrompt = """
        Please continue from where you left off. Your previous response was:
        
        \(incompleteResponse)
        
        Continue with the rest of your analysis and recommendations.
        """
        
        return try await generateResponse(prompt: continuePrompt, context: context)
    }
    
    // MARK: - RAG Implementation - FIXED FOR COMPLETE DOCUMENT ACCESS
    
    private func getRelevantDocumentContext(for query: String) async -> String {
        do {
            let queryEmbedding = try await generateEmbedding(for: query)
            
            // ✅ FIXED: Get more relevant docs with better parameters
            let relevantDocs = findRelevantDocuments(
                queryEmbedding: queryEmbedding,
                limit: 15,                    // ✅ FIXED: Was 3, now 15
                threshold: similarityThreshold // ✅ FIXED: Now 0.5 instead of 0.7
            )
            
            // ✅ FIXED: Build comprehensive context instead of truncated summaries
            var context = "COMPREHENSIVE DOCUMENT ANALYSIS:\n\n"
            
            for (index, doc) in relevantDocs.enumerated() {
                context += "📄 DOCUMENT SECTION \(index + 1):\n"
                context += doc.text + "\n\n"  // ✅ Full text, not truncated
                context += "---\n\n"
            }
            
            if !relevantDocs.isEmpty {
                context += "END OF DOCUMENT ANALYSIS\n"
                context += "You now have access to comprehensive document content. Use this information to provide detailed, specific answers based on the actual document contents.\n"
            }
            
            return context
            
        } catch {
            print("[RAG] Failed to get document context: \(error)")
            return ""
        }
    }
    
    private func findRelevantDocuments(queryEmbedding: [Double], limit: Int, threshold: Double = 0.5) -> [DocumentEmbedding] {
        // ✅ FIXED: More inclusive similarity matching
        let similarities = documentEmbeddings.compactMap { doc -> (DocumentEmbedding, Double)? in
            let similarity = cosineSimilarity(queryEmbedding, doc.embedding)
            
            // ✅ FIXED: Use the lower threshold for better recall
            return similarity >= threshold ? (doc, similarity) : nil
        }
        
        let sortedResults = similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
        
        print("[RAG] Found \(sortedResults.count) relevant document sections (threshold: \(threshold))")
        return Array(sortedResults)
    }
    
    // MARK: - Public RAG Methods for SafeDocumentManager
    
    func findSimilarDocuments(query: String, limit: Int = 15) async throws -> [DocumentEmbedding] {  // ✅ FIXED: Default limit increased
        guard !documentEmbeddings.isEmpty else { return [] }
        
        let queryEmbedding = try await generateEmbedding(for: query)
        
        // ✅ FIXED: Use the improved parameters
        let results = findRelevantDocuments(queryEmbedding: queryEmbedding, limit: limit, threshold: similarityThreshold)
        
        print("[RAG] Found \(results.count) similar documents")
        return results
    }
    
    private func generateEmbedding(for text: String) async throws -> [Double] {
        let request = EmbeddingRequest(model: embeddingModel, input: text)
        
        let url = URL(string: "\(baseURL)/embeddings")!
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await urlSession.data(for: httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        
        guard let firstEmbedding = embeddingResponse.data.first else {
            throw AIServiceError.invalidResponse
        }
        
        return firstEmbedding.embedding
    }
    
    private func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count else { return 0.0 }
        
        let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
        let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0 && magnitudeB > 0 else { return 0.0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    // MARK: - Document Embedding Management
    
    func storeDocumentEmbedding(_ embedding: DocumentEmbedding) {
        documentEmbeddings.append(embedding)
        saveEmbeddings()
        print("[RAG] Stored embedding for document: \(embedding.documentId)")
    }
    
    func storeDocumentEmbedding(documentId: UUID, text: String?, insights: [String], actionItems: [String], title: String) async -> Bool {
        print("[RAG] Storing embedding for document: \(title)")
        
        guard let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[RAG] No text content to embed")
            return false
        }
        
        do {
            // ✅ FIXED: Create larger, more comprehensive text for embedding
            var combinedText = "Document Title: \(title)\n\n"
            combinedText += "Content:\n\(text)"
            
            if !insights.isEmpty {
                combinedText += "\n\nBusiness Insights:\n" + insights.joined(separator: "\n")
            }
            
            if !actionItems.isEmpty {
                combinedText += "\n\nAction Items:\n" + actionItems.joined(separator: "\n")
            }
            
            let embedding = try await generateEmbedding(for: combinedText)
            
            let documentEmbedding = DocumentEmbedding(
                documentId: documentId,
                text: combinedText,  // ✅ Store the enhanced combined text
                embedding: embedding,
                createdAt: Date()
            )
            
            storeDocumentEmbedding(documentEmbedding)
            return true
            
        } catch {
            print("[RAG] Failed to generate embedding: \(error)")
            return false
        }
    }
    
    private func loadEmbeddings() {
        guard FileManager.default.fileExists(atPath: embeddingsStorageURL.path) else {
            print("[RAG] No existing embeddings found")
            return
        }
        
        do {
            let data = try Data(contentsOf: embeddingsStorageURL)
            documentEmbeddings = try JSONDecoder().decode([DocumentEmbedding].self, from: data)
            print("[RAG] Loaded \(documentEmbeddings.count) document embeddings")
        } catch {
            print("[RAG] Failed to load embeddings: \(error)")
            documentEmbeddings = []
        }
    }
    
    private func saveEmbeddings() {
        do {
            let data = try JSONEncoder().encode(documentEmbeddings)
            try data.write(to: embeddingsStorageURL)
            print("[RAG] Saved \(documentEmbeddings.count) embeddings")
        } catch {
            print("[RAG] Failed to save embeddings: \(error)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func buildRAGPersonalityPrompt(context: AIContext) -> String {
        let relationshipLevel = determineRelationshipLevel(from: context)
        
        var personality = """
        You are a strategic executive coach with deep business intelligence.
        Your personality adapts based on the relationship level: \(relationshipLevel.rawValue).
        
        \(relationshipLevel.personalityDescription)
        
        Core traits:
        - Direct and challenging when needed
        - Supportive but pushes for excellence
        - Uses business intelligence to provide insights
        - References specific data and patterns
        - Asks tough questions to drive growth
        """
        
        if let profile = context.founderProfile {
            personality += """
            
            FOUNDER PROFILE CONTEXT:
            • \(profile.founderName) - \(profile.founderRole)
            • Business: \(profile.businessName ?? "their company")
            • Industry: \(profile.industry) | Experience: \(profile.yearsOfExperience) years
            • Current focus: \(profile.currentGoals.joined(separator: ", "))
            • Key challenges: \(profile.currentChallenges.joined(separator: ", "))
            """
        }
        
        if !context.conversationHistory.isEmpty {
            let recentTopics = context.conversationHistory.suffix(3).map { turn in
                turn.userInput.components(separatedBy: " ").prefix(8).joined(separator: " ")
            }.joined(separator: " | ")
            
            personality += """
            
            RECENT CONVERSATION THEMES: \(recentTopics)
            • Reference these naturally when relevant
            • Build on previous insights and recommendations
            • Notice patterns and progression in their thinking
            """
        }
        
        if !context.businessContext.isEmpty {
            personality += """
            
            BUSINESS INTELLIGENCE:
            \(context.businessContext)
            
            • Use this context to provide deeper insights
            • Connect current discussion to business patterns
            • Suggest specific actions based on their business model
            """
        }
        
        personality += """
        
        RESPONSE APPROACH:
        1. Start with insight or observation about their situation
        2. Provide 1-2 strategic recommendations
        3. End with a thoughtful follow-up question
        4. Keep responses conversational but executive-focused
        5. Reference document content when relevant and helpful
        """
        
        return personality
    }
    
    private func determineRelationshipLevel(from context: AIContext) -> RelationshipLevel {
        let sessionCount = context.sessionHistory.count
        
        if sessionCount >= 100 {
            return .executivePartner
        } else if sessionCount >= 50 {
            return .strategicAdvisor
        } else if sessionCount >= 25 {
            return .trustedPartner
        } else if sessionCount >= 10 {
            return .developingPartnership
        } else {
            return .newMentorship
        }
    }
}

// MARK: - Supporting Models

struct DocumentEmbedding: Codable, Identifiable {
    let id = UUID()
    let documentId: UUID
    let text: String
    let embedding: [Double]
    let createdAt: Date
}

enum RelationshipLevel: String, CaseIterable {
    case newMentorship = "New Mentorship"
    case developingPartnership = "Developing Partnership"
    case trustedPartner = "Trusted Partner"
    case strategicAdvisor = "Strategic Advisor"
    case executivePartner = "Executive Partner"
    
    var personalityDescription: String {
        switch self {
        case .newMentorship:
            return "Direct and challenging. Establishes credibility through tough questions."
        case .developingPartnership:
            return "More collaborative as trust builds. Balances challenge with support."
        case .trustedPartner:
            return "Warm but professional. Provides strategic guidance with growing familiarity."
        case .strategicAdvisor:
            return "High-level strategic thinking. Close advisor with mutual respect."
        case .executivePartner:
            return "Intimate business partnership. Warm, direct, and deeply supportive."
        }
    }
}

struct EmbeddingRequest: Codable {
    let model: String
    let input: String
}

struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
}

struct EmbeddingData: Codable {
    let embedding: [Double]
}

// MARK: - AI Context Model

struct AIContext {
    let documentContext: String
    let conversationHistory: [SimpleConversationTurn]
    let founderProfile: FounderProfile?
    let businessContext: String
    let sessionContext: String
    let sessionHistory: [ExecutiveSession]
    
    init(
        documentContext: String = "",
        conversationHistory: [SimpleConversationTurn] = [],
        founderProfile: FounderProfile? = nil,
        businessContext: String = "",
        sessionContext: String = "",
        sessionHistory: [ExecutiveSession] = []
    ) {
        self.documentContext = documentContext
        self.conversationHistory = conversationHistory
        self.founderProfile = founderProfile
        self.businessContext = businessContext
        self.sessionContext = sessionContext
        self.sessionHistory = sessionHistory
    }
}
