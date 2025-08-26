//
//  BusinessDocument.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  BusinessDocument.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Document and Vision data models (Fixed DataPoint conflict)
//  Document upload, vision analysis, and file management models
//

import Foundation
import SwiftUI

// MARK: - Business Document

struct BusinessDocument: Identifiable, Codable {
    let id: UUID
    let title: String
    let type: DocumentType
    let originalFileName: String
    let fileURL: URL
    let fileSize: Int64
    let uploadDate: Date
    let sessionId: UUID? // Optional link to ExecutiveSession
    let extractedText: String?
    let visionAnalysis: VisionAnalysis?
    let thumbnailURL: URL?
    let processingStatus: ProcessingStatus
    let metadata: DocumentMetadata
    
    init(
        id: UUID = UUID(),
        title: String,
        type: DocumentType,
        originalFileName: String,
        fileURL: URL,
        fileSize: Int64,
        sessionId: UUID? = nil,
        extractedText: String? = nil,
        visionAnalysis: VisionAnalysis? = nil,
        thumbnailURL: URL? = nil,
        processingStatus: ProcessingStatus = .pending,
        metadata: DocumentMetadata = DocumentMetadata()
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.originalFileName = originalFileName
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.uploadDate = Date()
        self.sessionId = sessionId
        self.extractedText = extractedText
        self.visionAnalysis = visionAnalysis
        self.thumbnailURL = thumbnailURL
        self.processingStatus = processingStatus
        self.metadata = metadata
    }
    
    enum DocumentType: String, CaseIterable, Codable {
        case pdf = "PDF"
        case image = "Image"
        case presentation = "Presentation"
        case spreadsheet = "Spreadsheet"
        case document = "Document"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.richtext"
            case .image: return "photo"
            case .presentation: return "rectangle.on.rectangle"
            case .spreadsheet: return "tablecells"
            case .document: return "doc.text"
            case .unknown: return "doc"
            }
        }
        
        var supportedExtensions: [String] {
            switch self {
            case .pdf: return ["pdf"]
            case .image: return ["jpg", "jpeg", "png", "heic", "webp"]
            case .presentation: return ["ppt", "pptx", "key"]
            case .spreadsheet: return ["xls", "xlsx", "csv", "numbers"]
            case .document: return ["doc", "docx", "txt", "rtf", "pages"]
            case .unknown: return []
            }
        }
        
        static func from(fileExtension: String) -> DocumentType {
            let ext = fileExtension.lowercased()
            
            for type in DocumentType.allCases {
                if type.supportedExtensions.contains(ext) {
                    return type
                }
            }
            return .unknown
        }
    }
    
    enum ProcessingStatus: String, CaseIterable, Codable {
        case pending = "Pending"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
        case visionAnalysisOnly = "Vision Analysis Only"
        
        var color: Color {
            switch self {
            case .pending: return .orange
            case .processing: return .blue
            case .completed: return .green
            case .failed: return .red
            case .visionAnalysisOnly: return .purple
            }
        }
    }
}

// MARK: - Vision Analysis

struct VisionAnalysis: Identifiable, Codable {
    let id: UUID
    let textContent: String
    let businessInsights: [String]
    let actionItems: [ActionItem]
    let chartData: [ChartElement]?
    let tables: [TableData]?
    let confidence: Double
    let processingTime: TimeInterval
    let model: String
    let analysisDate: Date
    let detectedElements: [VisualElement]
    
    init(
        id: UUID = UUID(),
        textContent: String,
        businessInsights: [String] = [],
        actionItems: [ActionItem] = [],
        chartData: [ChartElement]? = nil,
        tables: [TableData]? = nil,
        confidence: Double,
        processingTime: TimeInterval = 0,
        model: String = "gpt-4-vision-preview",
        detectedElements: [VisualElement] = []
    ) {
        self.id = id
        self.textContent = textContent
        self.businessInsights = businessInsights
        self.actionItems = actionItems
        self.chartData = chartData
        self.tables = tables
        self.confidence = confidence
        self.processingTime = processingTime
        self.model = model
        self.analysisDate = Date()
        self.detectedElements = detectedElements
    }
}

// MARK: - Chart and Visual Elements

struct ChartElement: Identifiable, Codable {
    let id: UUID
    let type: ChartType
    let title: String?
    let dataPoints: [DocumentDataPoint] // FIXED: Use DocumentDataPoint instead of DataPoint
    let insights: [String]
    let boundingBox: BoundingBox?
    
    init(
        id: UUID = UUID(),
        type: ChartType,
        title: String? = nil,
        dataPoints: [DocumentDataPoint] = [],
        insights: [String] = [],
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.dataPoints = dataPoints
        self.insights = insights
        self.boundingBox = boundingBox
    }
    
    enum ChartType: String, CaseIterable, Codable {
        case bar = "Bar Chart"
        case line = "Line Chart"
        case pie = "Pie Chart"
        case scatter = "Scatter Plot"
        case area = "Area Chart"
        case table = "Table"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .bar: return "chart.bar"
            case .line: return "chart.line.uptrend.xyaxis"
            case .pie: return "chart.pie"
            case .scatter: return "chart.dots.scatter"
            case .area: return "chart.area"
            case .table: return "tablecells"
            case .unknown: return "chart"
            }
        }
    }
}

// FIXED: Renamed to DocumentDataPoint to avoid conflicts
struct DocumentDataPoint: Codable {
    let label: String
    let value: Double
    let category: String?
    
    init(label: String, value: Double, category: String? = nil) {
        self.label = label
        self.value = value
        self.category = category
    }
}

struct TableData: Identifiable, Codable {
    let id: UUID
    let headers: [String]
    let rows: [[String]]
    let title: String?
    let insights: [String]
    let boundingBox: BoundingBox?
    
    init(
        id: UUID = UUID(),
        headers: [String],
        rows: [[String]],
        title: String? = nil,
        insights: [String] = [],
        boundingBox: BoundingBox? = nil
    ) {
        self.id = id
        self.headers = headers
        self.rows = rows
        self.title = title
        self.insights = insights
        self.boundingBox = boundingBox
    }
}

struct VisualElement: Identifiable, Codable {
    let id: UUID
    let type: ElementType
    let description: String
    let confidence: Double
    let boundingBox: BoundingBox?
    let businessRelevance: String?
    
    init(
        id: UUID = UUID(),
        type: ElementType,
        description: String,
        confidence: Double,
        boundingBox: BoundingBox? = nil,
        businessRelevance: String? = nil
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.businessRelevance = businessRelevance
    }
    
    enum ElementType: String, CaseIterable, Codable {
        case text = "Text"
        case chart = "Chart"
        case table = "Table"
        case logo = "Logo"
        case diagram = "Diagram"
        case signature = "Signature"
        case stamp = "Stamp"
        case photo = "Photo"
        case unknown = "Unknown"
    }
}

struct BoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - Document Metadata

struct DocumentMetadata: Codable {
    let creator: String?
    let creationDate: Date?
    let lastModified: Date?
    let pageCount: Int?
    let wordCount: Int?
    let tags: [String]
    let category: StructuredNote.BusinessCategory?
    let isConfidential: Bool
    let compressionRatio: Double?
    let originalFileSize: Int64?
    
    init(
        creator: String? = nil,
        creationDate: Date? = nil,
        lastModified: Date? = nil,
        pageCount: Int? = nil,
        wordCount: Int? = nil,
        tags: [String] = [],
        category: StructuredNote.BusinessCategory? = nil,
        isConfidential: Bool = false,
        compressionRatio: Double? = nil,
        originalFileSize: Int64? = nil
    ) {
        self.creator = creator
        self.creationDate = creationDate
        self.lastModified = lastModified
        self.pageCount = pageCount
        self.wordCount = wordCount
        self.tags = tags
        self.category = category
        self.isConfidential = isConfidential
        self.compressionRatio = compressionRatio
        self.originalFileSize = originalFileSize
    }
}

// MARK: - Document Collection

struct DocumentCollection: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let documents: [UUID] // Document IDs
    let createdDate: Date
    let tags: [String]
    let category: StructuredNote.BusinessCategory?
    let isPrivate: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        documents: [UUID] = [],
        tags: [String] = [],
        category: StructuredNote.BusinessCategory? = nil,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.documents = documents
        self.createdDate = Date()
        self.tags = tags
        self.category = category
        self.isPrivate = isPrivate
    }
}

// MARK: - Document Search & Filter

struct DocumentFilter {
    var types: Set<BusinessDocument.DocumentType>
    var categories: Set<StructuredNote.BusinessCategory>
    var dateRange: DateRange?
    var searchText: String
    var hasAnalysis: Bool?
    var sessionLinked: Bool?
    var tags: [String]
    
    init(
        types: Set<BusinessDocument.DocumentType> = Set(BusinessDocument.DocumentType.allCases),
        categories: Set<StructuredNote.BusinessCategory> = Set(StructuredNote.BusinessCategory.allCases),
        dateRange: DateRange? = nil,
        searchText: String = "",
        hasAnalysis: Bool? = nil,
        sessionLinked: Bool? = nil,
        tags: [String] = []
    ) {
        self.types = types
        self.categories = categories
        self.dateRange = dateRange
        self.searchText = searchText
        self.hasAnalysis = hasAnalysis
        self.sessionLinked = sessionLinked
        self.tags = tags
    }
}

struct DateRange {
    let startDate: Date
    let endDate: Date
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
}

// MARK: - Document Import Request

struct DocumentImportRequest {
    let sourceURL: URL
    let targetSession: UUID?
    let category: StructuredNote.BusinessCategory?
    let tags: [String]
    let isConfidential: Bool
    let customTitle: String?
    let autoAnalyze: Bool
    
    init(
        sourceURL: URL,
        targetSession: UUID? = nil,
        category: StructuredNote.BusinessCategory? = nil,
        tags: [String] = [],
        isConfidential: Bool = false,
        customTitle: String? = nil,
        autoAnalyze: Bool = true
    ) {
        self.sourceURL = sourceURL
        self.targetSession = targetSession
        self.category = category
        self.tags = tags
        self.isConfidential = isConfidential
        self.customTitle = customTitle
        self.autoAnalyze = autoAnalyze
    }
}

// MARK: - Document Processing Result

struct DocumentProcessingResult {
    let document: BusinessDocument
    let success: Bool
    let error: DocumentError?
    let processingTime: TimeInterval
    let warnings: [String]
    
    init(
        document: BusinessDocument,
        success: Bool,
        error: DocumentError? = nil,
        processingTime: TimeInterval = 0,
        warnings: [String] = []
    ) {
        self.document = document
        self.success = success
        self.error = error
        self.processingTime = processingTime
        self.warnings = warnings
    }
}

// MARK: - Document Errors

enum DocumentError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case fileTooLarge(maxSize: Int64)
    case processingFailed(String)
    case visionAnalysisFailed(String)
    case insufficientPermissions
    case networkError(String)
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Document file not found"
        case .unsupportedFormat:
            return "Document format not supported"
        case .fileTooLarge(let maxSize):
            return "File too large (max: \(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)))"
        case .processingFailed(let message):
            return "Document processing failed: \(message)"
        case .visionAnalysisFailed(let message):
            return "Vision analysis failed: \(message)"
        case .insufficientPermissions:
            return "Insufficient permissions to access document"
        case .networkError(let message):
            return "Network error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}

// MARK: - Extensions

extension BusinessDocument {
    var isImageType: Bool {
        type == .image
    }
    
    var canAnalyzeWithVision: Bool {
        type == .image || type == .pdf
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var hasAnalysis: Bool {
        visionAnalysis != nil || extractedText != nil
    }
    
    var analysisStatusText: String {
        switch processingStatus {
        case .pending: return "Waiting for analysis..."
        case .processing: return "Analyzing content..."
        case .completed: return "Analysis complete"
        case .failed: return "Analysis failed"
        case .visionAnalysisOnly: return "Vision analysis only"
        }
    }
}

extension VisionAnalysis {
    var hasBusinessValue: Bool {
        !businessInsights.isEmpty || !actionItems.isEmpty
    }
    
    var hasStructuredData: Bool {
        chartData != nil || tables != nil
    }
    
    var totalInsights: Int {
        businessInsights.count + actionItems.count
    }
    
    var formattedProcessingTime: String {
        String(format: "%.1fs", processingTime)
    }
}