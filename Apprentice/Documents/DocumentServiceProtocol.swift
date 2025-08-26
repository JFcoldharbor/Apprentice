//
//  DocumentServiceProtocol.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  DocumentServiceProtocol.swift
//  Apprentice
//
//  Created by James Garmon on 8/21/25.
//


//
//  DocumentProtocols.swift
//  Stitch Executive AI
//
//  Layer 2: Protocols - Document service contracts and abstractions
//  Defines interfaces for document management, vision analysis, and file processing
//

import Foundation

// MARK: - Document Service Protocol

protocol DocumentServiceProtocol {
    // Document Management
    func importDocument(_ request: DocumentImportRequest) async throws -> BusinessDocument
    func deleteDocument(_ document: BusinessDocument) async throws
    func updateDocument(_ document: BusinessDocument) async throws
    func getAllDocuments() async throws -> [BusinessDocument]
    func getDocument(id: UUID) async throws -> BusinessDocument?
    func searchDocuments(filter: DocumentFilter) async throws -> [BusinessDocument]
    
    // File Operations
    func generateThumbnail(for document: BusinessDocument) async throws -> URL
    func compressDocument(_ document: BusinessDocument, quality: Double) async throws -> URL
    func getDocumentURL(for document: BusinessDocument) -> URL
    
    // Collections
    func createCollection(_ collection: DocumentCollection) async throws
    func addDocumentToCollection(documentId: UUID, collectionId: UUID) async throws
    func removeDocumentFromCollection(documentId: UUID, collectionId: UUID) async throws
    func getCollections() async throws -> [DocumentCollection]
}

// MARK: - Vision Service Protocol

protocol VisionServiceProtocol {
    // Vision Analysis
    func analyzeImage(imageURL: URL) async throws -> VisionAnalysis
    func analyzePDF(pdfURL: URL) async throws -> VisionAnalysis
    func batchAnalyzeDocuments(_ documents: [BusinessDocument]) async throws -> [UUID: VisionAnalysis]
    
    // Text Extraction
    func extractTextFromImage(imageURL: URL) async throws -> String
    func extractTextFromPDF(pdfURL: URL) async throws -> String
    
    // Business Intelligence
    func extractBusinessInsights(from analysis: VisionAnalysis) async throws -> [String]
    func identifyActionItems(from analysis: VisionAnalysis) async throws -> [ActionItem]
    func detectCharts(in imageURL: URL) async throws -> [ChartElement]
    func extractTables(from analysis: VisionAnalysis) async throws -> [TableData]
}

// MARK: - File Processing Protocol

protocol FileProcessingProtocol {
    // File Validation
    func validateFile(at url: URL) async throws -> Bool
    func getFileMetadata(for url: URL) async throws -> DocumentMetadata
    func calculateFileSize(for url: URL) async throws -> Int64
    
    // File Conversion
    func convertToSupportedFormat(fileURL: URL) async throws -> URL
    func optimizeForVisionAPI(imageURL: URL) async throws -> URL
    func createThumbnail(from fileURL: URL, size: CGSize) async throws -> URL
    
    // Storage Management
    func moveToDocumentsDirectory(_ sourceURL: URL, filename: String) async throws -> URL
    func cleanupTemporaryFiles() async throws
    func getStorageUsage() async throws -> Int64
}

// MARK: - Document Analytics Protocol

protocol DocumentAnalyticsProtocol {
    // Usage Analytics
    func trackDocumentView(_ document: BusinessDocument) async
    func trackAnalysisRequest(_ document: BusinessDocument) async
    func getDocumentUsageStats() async throws -> DocumentUsageStats
    
    // Business Intelligence
    func analyzeDocumentPatterns(_ documents: [BusinessDocument]) async throws -> [DocumentPattern]
    func getDocumentInsights() async throws -> [DocumentInsight]
    func calculateROIFromDocuments() async throws -> DocumentROI
    
    // Trend Analysis
    func getUploadTrends(timeframe: AnalyticsTimeframe) async throws -> [TrendDataPoint]
    func getCategoryDistribution() async throws -> [CategoryData]
    func getProcessingPerformance() async throws -> ProcessingMetrics
}

// MARK: - Cloud Sync Protocol

protocol DocumentCloudSyncProtocol {
    // Sync Operations
    func syncDocumentToCloud(_ document: BusinessDocument) async throws
    func syncAnalysisToCloud(_ analysis: VisionAnalysis, documentId: UUID) async throws
    func downloadDocumentFromCloud(id: UUID) async throws -> BusinessDocument
    
    // Conflict Resolution
    func resolveDocumentConflicts() async throws -> [DocumentConflict]
    func applyConflictResolution(_ resolution: ConflictResolution) async throws
    
    // Offline Support
    func queueForOfflineSync(_ operation: SyncOperation) async
    func processOfflineQueue() async throws
    func getOfflineQueueStatus() async throws -> OfflineQueueStatus
}

// MARK: - Supporting Data Models

struct DocumentUsageStats {
    let totalDocuments: Int
    let totalAnalyses: Int
    let averageProcessingTime: TimeInterval
    let mostUsedCategory: StructuredNote.BusinessCategory
    let totalStorageUsed: Int64
    let lastUpdated: Date
}

struct DocumentPattern: Identifiable {
    let id = UUID()
    let type: PatternType
    let description: String
    let confidence: Double
    let affectedDocuments: [UUID]
    let discoveredDate: Date
    
    enum PatternType: String, CaseIterable {
        case frequentCategory = "Frequent Category"
        case timeBasedUploads = "Time-Based Uploads"
        case similarContent = "Similar Content"
        case processingBottleneck = "Processing Bottleneck"
        case qualityIssues = "Quality Issues"
    }
}

struct DocumentInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: InsightCategory
    let actionRecommendation: String
    let businessImpact: String
    let priority: Priority
    
    enum InsightCategory: String, CaseIterable {
        case efficiency = "Efficiency"
        case organization = "Organization"
        case quality = "Quality"
        case usage = "Usage"
        case storage = "Storage"
    }
    
    enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }
}

struct DocumentROI {
    let timeSaved: TimeInterval
    let insightsGenerated: Int
    let actionItemsCreated: Int
    let documentsProcessed: Int
    let estimatedValueCreated: Double
    let calculationDate: Date
}

enum AnalyticsTimeframe: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
}

struct TrendDataPoint {
    let date: Date
    let value: Double
    let label: String
}

struct CategoryData {
    let category: StructuredNote.BusinessCategory
    let count: Int
    let percentage: Double
}

struct ProcessingMetrics {
    let averageAnalysisTime: TimeInterval
    let successRate: Double
    let failureReasons: [String: Int]
    let totalProcessed: Int
    let lastWeekPerformance: Double
}

struct DocumentConflict: Identifiable {
    let id = UUID()
    let documentId: UUID
    let conflictType: ConflictType
    let localVersion: BusinessDocument
    let cloudVersion: BusinessDocument
    let detectedDate: Date
    
    enum ConflictType: String, CaseIterable {
        case contentMismatch = "Content Mismatch"
        case metadataDifference = "Metadata Difference"
        case analysisConflict = "Analysis Conflict"
        case fileVersionConflict = "File Version Conflict"
    }
}

struct ConflictResolution {
    let conflictId: UUID
    let resolution: ResolutionType
    let selectedVersion: VersionChoice
    let mergeStrategy: MergeStrategy?
    
    enum ResolutionType: String, CaseIterable {
        case useLocal = "Use Local"
        case useCloud = "Use Cloud"
        case merge = "Merge"
        case duplicate = "Create Duplicate"
    }
    
    enum VersionChoice: String, CaseIterable {
        case local = "Local Version"
        case cloud = "Cloud Version"
        case both = "Keep Both"
    }
    
    enum MergeStrategy: String, CaseIterable {
        case combineAnalysis = "Combine Analysis"
        case newestMetadata = "Use Newest Metadata"
        case manualReview = "Manual Review Required"
    }
}

struct SyncOperation {
    let id = UUID()
    let type: OperationType
    let documentId: UUID
    let createdDate: Date
    let retryCount: Int
    let lastError: String?
    
    enum OperationType: String, CaseIterable {
        case upload = "Upload"
        case download = "Download"
        case update = "Update"
        case delete = "Delete"
        case syncAnalysis = "Sync Analysis"
    }
}

struct OfflineQueueStatus {
    let pendingOperations: Int
    let failedOperations: Int
    let lastSyncDate: Date?
    let isOnline: Bool
    let storageUsed: Int64
}

// MARK: - Delegate Protocols

protocol DocumentProcessingDelegate: AnyObject {
    func documentProcessingStarted(_ document: BusinessDocument)
    func documentProcessingProgress(_ document: BusinessDocument, progress: Double)
    func documentProcessingCompleted(_ document: BusinessDocument, result: DocumentProcessingResult)
    func documentProcessingFailed(_ document: BusinessDocument, error: DocumentError)
}

protocol VisionAnalysisDelegate: AnyObject {
    func visionAnalysisStarted(for documentId: UUID)
    func visionAnalysisProgress(for documentId: UUID, progress: Double)
    func visionAnalysisCompleted(for documentId: UUID, analysis: VisionAnalysis)
    func visionAnalysisFailed(for documentId: UUID, error: DocumentError)
}

// MARK: - Configuration Protocols

protocol DocumentConfigurationProtocol {
    var maxFileSize: Int64 { get }
    var supportedFormats: [String] { get }
    var enableVisionAnalysis: Bool { get }
    var autoGenerateThumbnails: Bool { get }
    var compressionQuality: Double { get }
    var maxConcurrentProcessing: Int { get }
    var retentionPeriod: TimeInterval { get }
    var enableCloudSync: Bool { get }
}