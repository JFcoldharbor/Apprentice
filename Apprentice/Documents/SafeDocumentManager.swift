//
//  SafeDocumentManager.swift
//  Stitch Executive AI
//
//  ENHANCED: Document upload with RAG vector embedding integration
//  UPDATED: Now stores documents as searchable embeddings for Claude-like recall
//

import Foundation
import UIKit
import PDFKit

@MainActor
class SafeDocumentManager: ObservableObject {
    
    @Published var documents: [ProcessedDocument] = []
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var lastProcessedDocument: ProcessedDocument?
    
    // MARK: - RAG Integration (Shared Instance)
    
    private var realAIService: RealAIService?
    private var speechService: SpeechConversationService?
    private let apiKey = Config.OpenAI.apiKey
    
    func setRealAIService(_ service: RealAIService) {
        self.realAIService = service
    }
    
    struct ProcessedDocument: Identifiable, Codable {
        let id = UUID()
        let title: String
        let originalName: String
        let fileURL: URL
        let uploadDate: Date
        let fileSize: Int64
        let extractedText: String?
        let businessInsights: [String]
        let actionItems: [String]
        let isAnalyzed: Bool
        let hasEmbedding: Bool // NEW: Track if document has vector embedding
        
        init(title: String, originalName: String, fileURL: URL, fileSize: Int64, extractedText: String? = nil, businessInsights: [String] = [], actionItems: [String] = [], hasEmbedding: Bool = false) {
            self.title = title
            self.originalName = originalName
            self.fileURL = fileURL
            self.uploadDate = Date()
            self.fileSize = fileSize
            self.extractedText = extractedText
            self.businessInsights = businessInsights
            self.actionItems = actionItems
            self.isAnalyzed = !businessInsights.isEmpty || extractedText != nil
            self.hasEmbedding = hasEmbedding
        }
    }
    
    private var documentsDirectory: URL {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("StitchDocuments")
    }
    
    init() {
        createDirectoryIfNeeded()
        loadDocuments()
    }
    
    func setSpeechService(_ service: SpeechConversationService) {
        self.speechService = service
    }
    
    // MARK: - Enhanced Document Upload with RAG Integration
    
    func addDocument(url: URL, title: String? = nil) {
        Task {
            do {
                try await processDocumentImmediately(url: url, customTitle: title)
                print("âœ… Document upload completed successfully")
            } catch {
                print("âŒ Document upload failed: \(error)")
                await announceError("Document upload failed. Please try again.")
            }
        }
    }
    
    // MARK: - Enhanced Document Processing with Vector Embeddings
    
    private func processDocumentImmediately(url: URL, customTitle: String?) async throws {
        print("ðŸ“„ [DOC] Starting document processing for: \(url.lastPathComponent)")
        
        // Start security scoped access
        guard url.startAccessingSecurityScopedResource() else {
            throw DocumentError.insufficientPermissions
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        isProcessing = true
        processingProgress = 0.0
        
        // Step 1: Read file data immediately (0.1)
        processingProgress = 0.1
        let fileData = try Data(contentsOf: url)
        let originalName = url.lastPathComponent
        let cleanName = originalName.replacingOccurrences(of: ".pdf.pdf", with: ".pdf")
        print("âœ… [DOC] Read \(fileData.count) bytes from \(cleanName)")
        
        // Step 2: Save to permanent location (0.2)
        processingProgress = 0.2
        let permanentURL = try saveToDocuments(data: fileData, filename: cleanName)
        print("âœ… [DOC] Saved to: \(permanentURL.lastPathComponent)")
        
        // Step 3: Extract text content (0.4)
        processingProgress = 0.4
        let extractedText = await extractTextFromData(fileData, fileExtension: url.pathExtension)
        print("âœ… [DOC] Text extraction: \(extractedText?.count ?? 0) characters")
        
        // Step 4: AI Analysis with OpenAI Vision (0.6)
        processingProgress = 0.6
        let analysis = await analyzeWithOpenAI(fileData: fileData, filename: cleanName, extractedText: extractedText)
        print("âœ… [DOC] AI Analysis: \(analysis.insights.count) insights, \(analysis.actionItems.count) actions")
        
        // Step 5: NEW - Generate and Store Vector Embedding (0.8)
        processingProgress = 0.8
        let hasEmbedding = await storeDocumentEmbedding(
            documentId: UUID(),
            text: extractedText,
            insights: analysis.insights,
            actionItems: analysis.actionItems,
            title: customTitle ?? cleanName
        )
        print("âœ… [DOC] Vector embedding: \(hasEmbedding ? "Generated" : "Skipped")")
        
        // Step 6: Create final document (1.0)
        processingProgress = 1.0
        let document = ProcessedDocument(
            title: customTitle ?? cleanName.replacingOccurrences(of: ".\(url.pathExtension)", with: ""),
            originalName: cleanName,
            fileURL: permanentURL,
            fileSize: Int64(fileData.count),
            extractedText: extractedText,
            businessInsights: analysis.insights,
            actionItems: analysis.actionItems,
            hasEmbedding: hasEmbedding
        )
        
        documents.append(document)
        lastProcessedDocument = document
        saveDocuments()
        
        isProcessing = false
        processingProgress = 0.0
        
        // Announce success
        await announceSuccess(document: document)
        print("ðŸŽ‰ [DOC] Document processing complete with RAG integration!")
    }
    
  
    
    // MARK: - NEW: Semantic Document Search for AI Conversations
    
    func searchDocumentsByQuery(_ query: String) async -> [ProcessedDocument] {
        print("ðŸ” [RAG] Searching documents for query: \(query)")
        
        guard let realAIService = realAIService else {
            print("âŒ [RAG] No RealAIService available for search")
            return []
        }
        
        do {
            let similarEmbeddings = try await realAIService.findSimilarDocuments(query: query, limit: 5)
            
            let relevantDocuments = documents.filter { document in
                similarEmbeddings.contains { embedding in
                    embedding.documentId == document.id
                }
            }
            
            print("ðŸŽ¯ [RAG] Found \(relevantDocuments.count) relevant documents")
            return relevantDocuments
            
        } catch {
            print("âŒ [RAG] Document search failed: \(error)")
            return []
        }
    }
    
    // MARK: - Enhanced Document Context for AI (RAG-Powered)
    
    func getRAGEnhancedContext(for query: String) async -> String {
        print("ðŸ§  [RAG] Building enhanced context for query: \(query)")
        
        let relevantDocs = await searchDocumentsByQuery(query)
        
        guard !relevantDocs.isEmpty else {
            return getBasicDocumentContext(for: query)
        }
        
        var context = "Relevant documents found for your query:\n\n"
        
        for doc in relevantDocs.prefix(3) {
            context += "ðŸ“„ **\(doc.title)**\n"
            
            if let text = doc.extractedText {
                // Include relevant excerpt
                context += "Excerpt: \(text.prefix(800))...\n"
            }
            
            if !doc.businessInsights.isEmpty {
                context += "Key Insights: \(doc.businessInsights.joined(separator: "; "))\n"
            }
            
            if !doc.actionItems.isEmpty {
                context += "Action Items: \(doc.actionItems.joined(separator: "; "))\n"
            }
            
            context += "\n---\n\n"
        }
        
        context += "You can reference these documents directly in your response and provide specific insights.\n"
        
        print("âœ… [RAG] Enhanced context built with \(relevantDocs.count) documents")
        return context
    }
    
    // MARK: - File Management (unchanged)
    
    private func saveToDocuments(data: Data, filename: String) throws -> URL {
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func deleteDocument(_ document: ProcessedDocument) {
        documents.removeAll { $0.id == document.id }
        saveDocuments()
        
        // Clean up file
        try? FileManager.default.removeItem(at: document.fileURL)
    }
    
    // MARK: - Text Extraction (unchanged)
    
    private func extractTextFromData(_ data: Data, fileExtension: String) async -> String? {
        switch fileExtension.lowercased() {
        case "pdf":
            return await extractTextFromPDFData(data)
        case "txt":
            return String(data: data, encoding: .utf8)
        default:
            return nil // Images processed by Vision API
        }
    }
    
    private func extractTextFromPDFData(_ data: Data) async -> String? {
        guard let pdfDocument = PDFDocument(data: data) else { return nil }
        
        var extractedText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageContent = page.string {
                extractedText += pageContent + "\n"
            }
        }
        
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }
    
    // MARK: - OpenAI Analysis (unchanged)
    
    private func analyzeWithOpenAI(fileData: Data, filename: String, extractedText: String?) async -> DocumentAnalysis {
        guard !apiKey.isEmpty else {
            print("âš ï¸ [DOC] OpenAI API key not found, skipping AI analysis")
            return DocumentAnalysis(insights: [], actionItems: [])
        }
        
        do {
            let insights = await generateBusinessInsights(fileData: fileData, filename: filename, text: extractedText)
            let actionItems = await generateActionItems(fileData: fileData, filename: filename, text: extractedText)
            
            return DocumentAnalysis(
                insights: insights,
                actionItems: actionItems
            )
        } catch {
            print("âŒ [DOC] OpenAI analysis failed: \(error)")
            return DocumentAnalysis(insights: [], actionItems: [])
        }
    }
    
    private func generateBusinessInsights(fileData: Data, filename: String, text: String?) async -> [String] {
        let prompt = buildInsightPrompt(filename: filename, text: text)
        
        do {
            let response = try await callOpenAIGPT4(prompt: prompt)
            return parseInsightsFromResponse(response)
        } catch {
            print("âŒ [DOC] Insights generation failed: \(error)")
            return []
        }
    }
    
    private func generateActionItems(fileData: Data, filename: String, text: String?) async -> [String] {
        let prompt = buildActionItemPrompt(filename: filename, text: text)
        
        do {
            let response = try await callOpenAIGPT4(prompt: prompt)
            return parseActionItemsFromResponse(response)
        } catch {
            print("âŒ [DOC] Action items generation failed: \(error)")
            return []
        }
    }
    
    // MARK: - OpenAI API Calls (unchanged)
    
    private func callOpenAIGPT4(prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert business analyst. Provide clear, actionable insights."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw DocumentError.processingFailed("OpenAI API call failed")
        }
        
        return content
    }
    
    // MARK: - Prompt Building (unchanged)
    
    private func buildInsightPrompt(filename: String, text: String?) -> String {
        var prompt = "Analyze this document: \(filename)\n\n"
        
        if let text = text {
            prompt += "Content:\n\(text.prefix(2000))\n\n"
        }
        
        prompt += """
        Provide 3-5 key business insights in this format:
        1. [Insight 1]
        2. [Insight 2]
        3. [Insight 3]
        
        Focus on strategic implications, opportunities, and important findings.
        """
        
        return prompt
    }
    
    private func buildActionItemPrompt(filename: String, text: String?) -> String {
        var prompt = "Analyze this document: \(filename)\n\n"
        
        if let text = text {
            prompt += "Content:\n\(text.prefix(2000))\n\n"
        }
        
        prompt += """
        Extract 3-5 specific action items in this format:
        1. [Action Item 1]
        2. [Action Item 2]
        3. [Action Item 3]
        
        Focus on concrete next steps and decisions that need to be made.
        """
        
        return prompt
    }
    
    // MARK: - Response Parsing (unchanged)
    
    private func parseInsightsFromResponse(_ response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.starts(with: "1.") || trimmed.starts(with: "2.") ||
               trimmed.starts(with: "3.") || trimmed.starts(with: "4.") ||
               trimmed.starts(with: "5.") {
                return String(trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        }
    }
    
    private func parseActionItemsFromResponse(_ response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.starts(with: "1.") || trimmed.starts(with: "2.") ||
               trimmed.starts(with: "3.") || trimmed.starts(with: "4.") ||
               trimmed.starts(with: "5.") {
                return String(trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        }
    }
    
    // MARK: - Speech Announcements (unchanged)
    
    private func announceSuccess(document: ProcessedDocument) async {
        guard let speechService = speechService else { return }
        
        var message = "Document \(document.title) processed successfully."
        
        if !document.businessInsights.isEmpty {
            message += " Found \(document.businessInsights.count) business insights."
        }
        
        if !document.actionItems.isEmpty {
            message += " Identified \(document.actionItems.count) action items."
        }
        
        if document.hasEmbedding {
            message += " Document is now searchable."
        }
        
        print("ðŸ“Š [DOC] Announcing: \(message)")
        
        do {
            try await speechService.speak(text: message)
        } catch {
            print("âŒ [DOC] Failed to announce success: \(error)")
        }
    }
    
    private func announceError(_ message: String) async {
        guard let speechService = speechService else { return }
        
        print("ðŸ“Š [DOC] Announcing error: \(message)")
        
        do {
            try await speechService.speak(text: message)
        } catch {
            print("âŒ [DOC] Failed to announce error: \(error)")
        }
    }
    
    // MARK: - Legacy Document Context (for backward compatibility)
    
    private func getBasicDocumentContext(for query: String) -> String {
        guard !documents.isEmpty else { return "" }
        
        let recentDocs = Array(documents.suffix(3))
        var context = "Available documents for discussion:\n\n"
        
        for doc in recentDocs {
            context += "ðŸ“„ **\(doc.title)**\n"
            
            if let text = doc.extractedText {
                context += "Content: \(text.prefix(1000))\n"
            }
            
            if !doc.businessInsights.isEmpty {
                context += "Business Insights: \(doc.businessInsights.joined(separator: "; "))\n"
            }
            
            if !doc.actionItems.isEmpty {
                context += "Action Items: \(doc.actionItems.joined(separator: "; "))\n"
            }
            
            context += "\n---\n\n"
        }
        
        context += "User can ask specific questions about any of these documents and their content.\n"
        return context
    }
    
    // MARK: - Backward Compatibility Method
    
    func getDocumentContext(for query: String) -> String {
        // Use enhanced RAG context in async context, fall back to basic for sync calls
        return getBasicDocumentContext(for: query)
    }
    
    // MARK: - Storage Management (unchanged)
    
    private func createDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create documents directory: \(error)")
        }
    }
    
    private func loadDocuments() {
        do {
            let documentsFile = documentsDirectory.appendingPathComponent("processed_documents.json")
            guard FileManager.default.fileExists(atPath: documentsFile.path) else { return }
            
            let data = try Data(contentsOf: documentsFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            documents = try decoder.decode([ProcessedDocument].self, from: data)
            print("ðŸ“š [DOC] Loaded \(documents.count) processed documents")
        } catch {
            print("âŒ [DOC] Failed to load documents: \(error)")
        }
    }
    
    private func saveDocuments() {
        do {
            let documentsFile = documentsDirectory.appendingPathComponent("processed_documents.json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(documents)
            try data.write(to: documentsFile)
            print("ðŸ’¾ [DOC] Saved \(documents.count) documents to storage")
        } catch {
            print("âŒ [DOC] Failed to save documents: \(error)")
        }
    }
}

// MARK: - Supporting Models (unchanged)

struct DocumentAnalysis {
    let insights: [String]
    let actionItems: [String]
}
