//
//  DocumentMemoryCoordinator.swift
//  Apprentice
//
//  Layer 5: Business Logic - Document-Memory Integration System
//  FIXED: ProcessedDocument references and CharacterSet import
//

import Foundation

// MARK: - Unified Document Context Model

struct UnifiedDocumentContext {
    let relevantDocuments: [BusinessDocument]
    let businessInsights: [String]
    let conversationContext: [String]
    let documentConnections: [String]
    let conversationConnections: [String]
    let totalDocuments: Int
    let totalConversations: Int
    let lastUpdated: Date
    
    init(relevantDocuments: [BusinessDocument], businessInsights: [String], conversationContext: [String], documentConnections: [String], conversationConnections: [String], totalDocuments: Int, totalConversations: Int, lastUpdated: Date) {
        self.relevantDocuments = relevantDocuments
        self.businessInsights = businessInsights
        self.conversationContext = conversationContext
        self.documentConnections = documentConnections
        self.conversationConnections = conversationConnections
        self.totalDocuments = totalDocuments
        self.totalConversations = totalConversations
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Document Memory Coordinator

@MainActor
class DocumentMemoryCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    
    private let sessionManager = SessionManager.shared
    private let safeDocumentManager = SafeDocumentManager()
    private let memoryCalculator = MemoryConnectionCalculator()
    private let conversationHistoryManager = ConversationHistoryManager()
    
    // MARK: - Published Properties
    
    @Published var documentInsights: [SimpleDocumentInsight] = []
    @Published var documentConnections: [SimpleDocumentConnection] = []
    @Published var isAnalyzing = false
    @Published var lastProcessedDocument: ProcessedDocument?
    
    // MARK: - Initialization
    
    init() {
        print("[DOC-MEMORY] Document Memory Coordinator initialized")
    }
    
    // MARK: - Main Integration Methods
    
    func processDocumentForUnifiedMemory(_ document: ProcessedDocument) async {
        print("[DOC-MEMORY] Processing document for unified memory integration: \(document.title)")
        
        isAnalyzing = true
        defer {
            isAnalyzing = false
            lastProcessedDocument = document
        }
        
        let documentInsight = extractBusinessIntelligence(from: document)
        documentInsights.append(documentInsight)
        
        let sessionConnections = await findSessionConnections(for: document, insight: documentInsight)
        documentConnections.append(contentsOf: sessionConnections)
        
        await triggerUnifiedMemoryRefresh()
        
        print("[DOC-MEMORY] Document processed and integrated into unified memory system")
    }
    
    func getUnifiedDocumentContext() -> UnifiedDocumentContext {
        let allDocuments = safeDocumentManager.documents
        let conversationTurns = conversationHistoryManager.conversationHistory
        
        var documentInsights: [String] = []
        var conversationContext: [String] = []
        var documentConnections: [String] = []
        var documentConversationConnections: [String] = []
        
        let relevantDocuments = Array(allDocuments
            .filter { $0.isAnalyzed }
            .sorted { $0.uploadDate > $1.uploadDate }
            .prefix(8))
        
        conversationContext = conversationTurns
            .suffix(10)
            .map { "Conversation: \($0.userInput) -> \($0.aiResponse.prefix(100))..." }
        
        for document in relevantDocuments {
            if !document.businessInsights.isEmpty {
                documentInsights.append(contentsOf: document.businessInsights)
            }
            
            if !document.actionItems.isEmpty {
                for actionItem in document.actionItems {
                    documentInsights.append("Action from \(document.title): \(actionItem)")
                }
            }
            
            if let extractedText = document.extractedText {
                documentInsights.append("Content from \(document.title): \(extractedText.prefix(300))...")
            }
        }
        
        return UnifiedDocumentContext(
            relevantDocuments: relevantDocuments.map { convertToBusinessDocument($0) },
            businessInsights: documentInsights,
            conversationContext: conversationContext,
            documentConnections: documentConnections,
            conversationConnections: documentConversationConnections,
            totalDocuments: allDocuments.count,
            totalConversations: conversationTurns.count,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Implementation Methods
    
    private func extractBusinessIntelligence(from document: ProcessedDocument) -> SimpleDocumentInsight {
        return SimpleDocumentInsight(
            id: UUID(),
            documentId: document.id,
            title: "Analysis of \(document.title)",
            insights: document.businessInsights,
            actionItems: document.actionItems,
            extractedAt: Date(),
            confidence: document.isAnalyzed ? 0.8 : 0.3
        )
    }
    
    private func findSessionConnections(for document: ProcessedDocument, insight: SimpleDocumentInsight) async -> [SimpleDocumentConnection] {
        let sessions = sessionManager.sessions
        var connections: [SimpleDocumentConnection] = []
        
        // Simple keyword-based connection detection
        let documentKeywords = extractKeywords(from: document)
        
        for session in sessions {
            let sessionKeywords = extractSessionKeywords(from: session)
            let similarity = calculateSimilarity(documentKeywords, sessionKeywords)
            
            if similarity > 0.3 {
                connections.append(SimpleDocumentConnection(
                    documentId: document.id,
                    sessionId: session.id,
                    connectionScore: similarity,
                    connectionType: "Keyword Similarity",
                    reasons: ["Shared topics: \(Array(Set(documentKeywords).intersection(Set(sessionKeywords))).joined(separator: ", "))"]
                ))
            }
        }
        
        return connections
    }
    
    private func extractKeywords(from document: ProcessedDocument) -> [String] {
        var keywords: [String] = []
        
        // Extract from title
        keywords.append(contentsOf: document.title.components(separatedBy: CharacterSet.whitespacesAndNewlines))
        
        // Extract from insights
        for insight in document.businessInsights {
            keywords.append(contentsOf: insight.components(separatedBy: CharacterSet.whitespacesAndNewlines))
        }
        
        // Extract from action items
        for actionItem in document.actionItems {
            keywords.append(contentsOf: actionItem.components(separatedBy: CharacterSet.whitespacesAndNewlines))
        }
        
        // Clean and filter keywords
        return keywords
            .map { $0.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters) }
            .filter { $0.count > 2 }
            .filter { !commonWords.contains($0) }
    }
    
    private func extractSessionKeywords(from session: ExecutiveSession) -> [String] {
        var keywords: [String] = []
        
        // Extract from session title
        keywords.append(contentsOf: session.title.components(separatedBy: CharacterSet.whitespacesAndNewlines))
        
        // Extract from notes
        for note in session.notes {
            keywords.append(contentsOf: note.title.components(separatedBy: CharacterSet.whitespacesAndNewlines))
            keywords.append(contentsOf: note.content.components(separatedBy: CharacterSet.whitespacesAndNewlines))
        }
        
        // Clean and filter keywords
        return keywords
            .map { $0.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters) }
            .filter { $0.count > 2 }
            .filter { !commonWords.contains($0) }
    }
    
    private func calculateSimilarity(_ keywords1: [String], _ keywords2: [String]) -> Double {
        let set1 = Set(keywords1)
        let set2 = Set(keywords2)
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func convertToBusinessDocument(_ processedDoc: ProcessedDocument) -> BusinessDocument {
        // Convert ProcessedDocument to BusinessDocument for compatibility
        return BusinessDocument(
            id: processedDoc.id,
            title: processedDoc.title,
            type: .pdf, // Simplified type assignment
            originalFileName: processedDoc.originalName,
            fileURL: processedDoc.fileURL,
            fileSize: processedDoc.fileSize,
            sessionId: nil,
            extractedText: processedDoc.extractedText,
            visionAnalysis: nil,
            thumbnailURL: nil,
            processingStatus: .completed,
            metadata: DocumentMetadata()
        )
    }
    
    private func triggerUnifiedMemoryRefresh() async {
        // Trigger memory system to refresh with new document context
        print("[DOC-MEMORY] Triggering unified memory refresh")
    }
    
    // MARK: - Common Words Filter
    
    private let commonWords = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by",
        "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did",
        "will", "would", "could", "should", "can", "may", "might", "this", "that", "these", "those"
    ]
}

// MARK: - Simplified Models

struct SimpleDocumentInsight: Identifiable {
    let id: UUID
    let documentId: UUID
    let title: String
    let insights: [String]
    let actionItems: [String]
    let extractedAt: Date
    let confidence: Double
}

struct SimpleDocumentConnection: Identifiable {
    let id = UUID()
    let documentId: UUID
    let sessionId: UUID
    let connectionScore: Double
    let connectionType: String
    let reasons: [String]
}
