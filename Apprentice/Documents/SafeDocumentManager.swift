//
//  SafeDocumentManager.swift
//  Apprentice
//
//  Layer 4: Core Services - Complete document management with RAG
//  FIXED: UTType issues and improved error handling
//

import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Vision
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class SafeDocumentManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var documents: [ProcessedDocument] = []
    @Published var isProcessing = false
    @Published var processingProgress = 0.0
    @Published var lastError: String?
    @Published var smartChunks: [SmartDocumentChunk] = []
    
    // MARK: - Private Properties
    
    private let documentsDirectory: URL
    private var realAIService: RealAIService?
    private var speechService: SpeechConversationService?
    private let apiKey = Config.OpenAI.apiKey
    private let maxChunkSize = 1500
    private let chunkOverlap = 200
    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    // MARK: - Initialization
    
    init(realAIService: RealAIService? = nil, speechService: SpeechConversationService? = nil) {
        self.realAIService = realAIService
        self.speechService = speechService
        
        // Documents directory setup
        let fileManager = FileManager.default
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProcessedDocuments")
        
        createDirectoryIfNeeded()
        loadDocuments()
        
        print("📄 [DOC] SafeDocumentManager initialized - \(documents.count) documents loaded")
    }
    
    // MARK: - Service Configuration Methods
    
    func setRealAIService(_ service: RealAIService) {
        self.realAIService = service
        print("[DOC] RealAIService configured")
    }
    
    func setSpeechService(_ service: SpeechConversationService) {
        self.speechService = service
        print("[DOC] SpeechService configured")
    }
    
    // MARK: - Public Methods
    
    func processDocument(url: URL) async throws -> ProcessedDocument {
        print("📄 [DOC] Starting document processing for: \(url.lastPathComponent)")
        
        // FIXED: Better file validation with security scoped resources
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            let errorMsg = "File not found at path: \(url.path)"
            print("❌ [DOC] \(errorMsg)")
            throw DocumentProcessingError.fileNotFound(errorMsg)
        }
        
        isProcessing = true
        processingProgress = 0.1
        lastError = nil
        
        defer {
            isProcessing = false
            processingProgress = 0.0
        }
        
        do {
            // Validate file
            try await validateFile(at: url)
            processingProgress = 0.2
            
            // Copy to local storage for processing
            let localURL = try await copyToLocalStorage(from: url)
            processingProgress = 0.3
            
            // Extract text
            let extractedText = try await extractText(from: localURL)
            processingProgress = 0.5
            
            // Get file metadata
            let fileSize = try self.fileSize(at: url)
            let originalName = url.lastPathComponent
            let title = url.deletingPathExtension().lastPathComponent
            
            // Analyze document (if AI service is available)
            var analysis = DocumentAnalysis(insights: [], actionItems: [])
            if realAIService != nil && !extractedText.isEmpty {
                analysis = try await analyzeDocument(text: extractedText, filename: originalName)
                processingProgress = 0.8
            }
            
            // Create processed document
            let processedDocument = ProcessedDocument(
                title: title,
                originalName: originalName,
                fileURL: localURL,
                fileSize: fileSize,
                extractedText: extractedText,
                businessInsights: analysis.insights,
                actionItems: analysis.actionItems,
                hasEmbedding: false, // Could be enhanced later
                chunkCount: 0,
                entityCount: 0
            )
            
            // Save to collection
            documents.append(processedDocument)
            saveDocuments()
            
            processingProgress = 1.0
            
            // Announce success if speech service is available
            await announceSuccess(document: processedDocument)
            
            print("✅ [DOC] Document processed successfully: \(processedDocument.title)")
            return processedDocument
            
        } catch {
            let errorMessage = "Document processing failed: \(error.localizedDescription)"
            lastError = errorMessage
            await announceError(errorMessage)
            print("❌ [DOC] Processing failed: \(error)")
            throw error
        }
    }
    
    func removeDocument(withId id: UUID) {
        documents.removeAll { $0.id == id }
        smartChunks.removeAll { $0.documentId == id }
        saveDocuments()
        print("🗑️ [DOC] Document removed: \(id)")
    }
    
    func removeAllDocuments() {
        documents.removeAll()
        smartChunks.removeAll()
        saveDocuments()
        print("🗑️ [DOC] All documents removed")
    }
    
    // MARK: - Private Document Processing
    
    private func validateFile(at url: URL) async throws {
        let fileSize = try self.fileSize(at: url)
        
        guard fileSize <= maxFileSize else {
            throw DocumentProcessingError.fileTooLarge("File too large: \(formatFileSize(fileSize)) > \(formatFileSize(maxFileSize))")
        }
        
        // FIXED: Use string extension instead of UTType.rawValue
        let fileExtension = url.pathExtension.lowercased()
        let supportedTypes = ["pdf", "txt", "md", "rtf"]
        
        guard supportedTypes.contains(fileExtension) else {
            throw DocumentProcessingError.unsupportedFormat("Unsupported file type: \(fileExtension)")
        }
        
        print("✅ [DOC] File validation passed: \(formatFileSize(fileSize)) \(fileExtension)")
    }
    
    private func copyToLocalStorage(from url: URL) async throws -> URL {
        let fileName = url.lastPathComponent
        let localURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        
        try FileManager.default.copyItem(at: url, to: localURL)
        print("📁 [DOC] File copied to local storage: \(localURL.lastPathComponent)")
        return localURL
    }
    
    private func extractText(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        
        let extractedText: String
        switch fileExtension {
        case "pdf":
            extractedText = try await extractTextFromPDF(url: url)
        case "txt", "md":
            extractedText = try String(contentsOf: url, encoding: .utf8)
        case "rtf":
            extractedText = try extractTextFromRTF(url: url)
        default:
            throw DocumentProcessingError.unsupportedFormat("Unsupported file type for text extraction: \(fileExtension)")
        }
        
        print("📖 [DOC] Text extracted: \(extractedText.count) characters")
        return extractedText
    }
    
    private func extractTextFromPDF(url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentProcessingError.processingFailed("Unable to load PDF document")
        }

        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                text += page.string ?? ""
                text += "\n"
            }
        }

        let layerText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Scanned / image-only PDFs (e.g. an IRS EIN confirmation letter) have no
        // text layer, so `page.string` is empty. Fall back to on-device OCR so the
        // content is still readable by Aria.
        if layerText.count < 24 {
            let ocr = await Self.ocrPDF(url: url)
            if !ocr.isEmpty {
                print("📖 [DOC] OCR recovered \(ocr.count) chars from a scanned PDF")
                return ocr
            }
        }
        return layerText
    }

    /// Vision OCR fallback for image-only PDFs — renders each page and recognizes
    /// text. Runs off the main actor (CPU-heavy). Returns "" if nothing is found.
    nonisolated private static func ocrPDF(url: URL) async -> String {
        await Task.detached(priority: .userInitiated) { () -> String in
            guard let pdf = PDFDocument(url: url) else { return "" }
            var out = ""
            for i in 0..<pdf.pageCount {
                guard let page = pdf.page(at: i) else { continue }
                #if canImport(UIKit)
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0
                let pixelSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
                guard let cg = page.thumbnail(of: pixelSize, for: .mediaBox).cgImage else { continue }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([request])
                    for obs in request.results ?? [] {
                        if let candidate = obs.topCandidates(1).first {
                            out += candidate.string + "\n"
                        }
                    }
                } catch {
                    // page OCR failed — skip this page
                }
                #endif
            }
            return out.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
    
    private func extractTextFromRTF(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let attributedString = try NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        return attributedString.string
    }
    
    private func analyzeDocument(text: String, filename: String) async throws -> DocumentAnalysis {
        guard let realAIService = realAIService else {
            print("⚠️ [DOC] No AI service available - skipping analysis")
            return DocumentAnalysis(insights: [], actionItems: [])
        }
        
        let prompt = """
        Analyze this business document and provide structured insights.
        
        Document: \(filename)
        Content: \(text.prefix(3000))
        
        Please provide:
        
        BUSINESS INSIGHTS:
        • [Insight 1]
        • [Insight 2]
        • [Insight 3]
        
        ACTION ITEMS:
        • [Action 1]
        • [Action 2]
        • [Action 3]
        
        Focus on business value, strategic implications, and actionable next steps.
        """
        
        do {
            let response = try await realAIService.generateCoachingResponse(prompt: prompt)
            return DocumentAnalysis(
                insights: parseInsightsFromResponse(response),
                actionItems: parseActionItemsFromResponse(response)
            )
        } catch {
            print("⚠️ [DOC] AI analysis failed: \(error)")
            return DocumentAnalysis(insights: [], actionItems: [])
        }
    }
    
    private func parseInsightsFromResponse(_ response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        var insights: [String] = []
        var inInsightsSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.uppercased().contains("INSIGHT") {
                inInsightsSection = true
                continue
            }
            
            if trimmed.uppercased().contains("ACTION") {
                inInsightsSection = false
            }
            
            if inInsightsSection && (trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*")) {
                let insight = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !insight.isEmpty {
                    insights.append(insight)
                }
            }
        }
        
        return insights
    }
    
    private func parseActionItemsFromResponse(_ response: String) -> [String] {
        let lines = response.components(separatedBy: .newlines)
        var actionItems: [String] = []
        var inActionSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.uppercased().contains("ACTION") {
                inActionSection = true
                continue
            }
            
            if inActionSection && (trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*")) {
                let actionItem = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                if !actionItem.isEmpty {
                    actionItems.append(actionItem)
                }
            }
        }
        
        return actionItems
    }
    
    // MARK: - Storage Management
    
    private func createDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: documentsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
                print("📁 [DOC] Created documents directory")
            } catch {
                print("❌ [DOC] Failed to create documents directory: \(error)")
            }
        }
    }
    
    private func saveDocuments() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(documents)
            let url = documentsDirectory.appendingPathComponent("processed_documents.json")
            try data.write(to: url)
            print("💾 [DOC] Successfully saved \(documents.count) documents")
        } catch {
            print("❌ [DOC] Failed to save documents: \(error)")
        }
    }
    
    // FIXED: Better error handling for first-run scenarios
    private func loadDocuments() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let url = documentsDirectory.appendingPathComponent("processed_documents.json")
            let data = try Data(contentsOf: url)
            documents = try decoder.decode([ProcessedDocument].self, from: data)
            print("📂 [DOC] Successfully loaded \(documents.count) documents")
        } catch {
            // Check if it's just a missing file (normal for first run)
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoSuchFileError {
                print("📂 [DOC] No existing documents file - starting fresh")
            } else {
                print("⚠️ [DOC] Failed to load documents (will start fresh): \(error)")
            }
            documents = []
        }
    }
    
    // MARK: - Helper Methods
    
    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func announceSuccess(document: ProcessedDocument) async {
        guard let speechService = speechService else { return }
        
        var message = "Document '\(document.title)' processed successfully."
        
        if !document.businessInsights.isEmpty {
            message += " Found \(document.businessInsights.count) business insights."
        }
        
        if !document.actionItems.isEmpty {
            message += " Identified \(document.actionItems.count) action items."
        }
        
        if document.hasEmbedding {
            message += " Document is now searchable."
        }
        
        print("📢 [DOC] Announcing: \(message)")
        
        do {
            try await speechService.speak(text: message)
        } catch {
            print("⚠️ [DOC] Failed to announce success: \(error)")
        }
    }
    
    private func announceError(_ message: String) async {
        guard let speechService = speechService else { return }
        
        print("📢 [DOC] Announcing error: \(message)")
        
        do {
            try await speechService.speak(text: message)
        } catch {
            print("⚠️ [DOC] Failed to announce error: \(error)")
        }
    }
}

// MARK: - Connected sources (data room, Drive, …)

extension SafeDocumentManager {

    /// Pull every item from a connected source and fold it into the document
    /// store — the same store that builds Aria's DOCUMENT CONTEXT. Replaces any
    /// prior docs from this source (so a Refresh is idempotent), runs no per-doc
    /// AI analysis or per-doc voice announce (this is a bulk sync, not an upload),
    /// and announces a single summary at the end. Returns the count ingested.
    @discardableResult
    func syncSource(_ source: DocumentSource) async throws -> Int {
        isProcessing = true
        processingProgress = 0.05
        lastError = nil
        defer {
            isProcessing = false
            processingProgress = 0.0
        }

        let items: [SourceItem]
        do {
            items = try await source.fetch()
        } catch {
            lastError = "Could not reach \(source.displayName): \(error.localizedDescription)"
            await announceError(lastError!)
            throw error
        }

        // Idempotent refresh: drop this source's previous docs (+ their chunks).
        let staleIds = Set(documents.filter { $0.sourceId == source.id }.map { $0.id })
        documents.removeAll { $0.sourceId == source.id }
        smartChunks.removeAll { staleIds.contains($0.documentId) }

        var ingested = 0
        for (index, item) in items.enumerated() {
            do {
                let materialized = try await materialize(item, sourceId: source.id)
                documents.append(
                    ProcessedDocument(
                        title: item.title,
                        originalName: materialized.url.lastPathComponent,
                        fileURL: materialized.url,
                        fileSize: materialized.size,
                        extractedText: materialized.text,
                        sourceId: source.id
                    )
                )
                ingested += 1
            } catch {
                // One bad file shouldn't abort the whole sync.
                print("⚠️ [SOURCE] Skipped '\(item.title)': \(error.localizedDescription)")
            }
            processingProgress = 0.05 + 0.9 * Double(index + 1) / Double(max(items.count, 1))
        }

        saveDocuments()
        processingProgress = 1.0
        await announceSourceSync(source: source, count: ingested)
        print("✅ [SOURCE] Synced \(ingested)/\(items.count) items from \(source.displayName)")
        return ingested
    }

    /// Turn a SourceItem into a local file + extracted text. Narrative sections
    /// are written as .txt; remote files are downloaded then extracted with the
    /// same PDF/RTF path manual uploads use (CSV/unknown fall back to UTF-8).
    private func materialize(_ item: SourceItem, sourceId: String) async throws
        -> (url: URL, text: String, size: Int64) {
        switch item.payload {
        case .text(let body):
            let localURL = documentsDirectory.appendingPathComponent(
                sourceFileName(sourceId: sourceId, title: item.title, ext: "txt"))
            try body.data(using: .utf8)?.write(to: localURL)
            return (localURL, body, try fileSize(at: localURL))

        case .remoteFile(let remoteURL, let ext):
            let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw DocumentProcessingError.networkError("HTTP \(http.statusCode) downloading \(item.title)")
            }
            let localURL = documentsDirectory.appendingPathComponent(
                sourceFileName(sourceId: sourceId, title: item.title, ext: ext))
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: localURL)

            let lower = ext.lowercased()
            let text: String
            if ["pdf", "txt", "md", "rtf"].contains(lower) {
                text = try await extractText(from: localURL)
            } else {
                text = (try? String(contentsOf: localURL, encoding: .utf8)) ?? ""
            }
            return (localURL, text, try fileSize(at: localURL))
        }
    }

    /// Deterministic, collision-safe local filename namespaced by source.
    private func sourceFileName(sourceId: String, title: String, ext: String) -> String {
        let slug = title
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .lowercased()
        let safeSlug = slug.isEmpty ? "item" : String(slug.prefix(60))
        return "\(sourceId)__\(safeSlug).\(ext)"
    }

    private func announceSourceSync(source: DocumentSource, count: Int) async {
        guard let speechService = speechService else { return }
        let message = count > 0
            ? "Synced \(count) document\(count == 1 ? "" : "s") from the \(source.displayName)."
            : "I couldn't pull anything new from the \(source.displayName)."
        print("📢 [SOURCE] \(message)")
        try? await speechService.speak(text: message)
    }
}

// MARK: - Error Types

enum DocumentProcessingError: LocalizedError {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case fileTooLarge(String)
    case processingFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let message): return message
        case .unsupportedFormat(let message): return message
        case .fileTooLarge(let message): return message
        case .processingFailed(let message): return message
        case .networkError(let message): return message
        }
    }
}

// MARK: - Supporting Models (from original file)

struct DocumentAnalysis {
    let insights: [String]
    let actionItems: [String]
}

struct SmartDocumentChunk: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let chunkIndex: Int
    let content: String
    let embedding: [Double]
    
    // Enhanced Metadata for Intelligence
    let title: String?
    let sectionHeading: String?
    let pageNumber: Int?
    let chunkType: ChunkType
    let keyPhrases: [String]
    let namedEntities: [String]
    let businessRelevance: Double
    let wordCount: Int
    
    enum ChunkType: String, Codable {
        case document = "document"
        case section = "section"
        case paragraph = "paragraph"
        case list = "list"
        case table = "table"
        case conclusion = "conclusion"
    }
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
    let hasEmbedding: Bool
    let chunkCount: Int
    let entityCount: Int
    /// Identifies the connected source this doc came from (e.g. "stitch-dataroom"),
    /// or nil for a manually-uploaded file. Optional so older persisted docs decode.
    let sourceId: String?

    init(
        title: String,
        originalName: String,
        fileURL: URL,
        fileSize: Int64,
        extractedText: String? = nil,
        businessInsights: [String] = [],
        actionItems: [String] = [],
        hasEmbedding: Bool = false,
        chunkCount: Int = 0,
        entityCount: Int = 0,
        sourceId: String? = nil
    ) {
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
        self.chunkCount = chunkCount
        self.entityCount = entityCount
        self.sourceId = sourceId
    }
}
