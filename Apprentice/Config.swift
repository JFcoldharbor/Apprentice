//
//  Config.swift
//  Apprentice
//
//  Layer 1: Foundation - Complete app configuration (UPDATED)
//  Added missing document processing constants for NotebookLM-style functionality
//

import Foundation
import AVFoundation

// MARK: - App Configuration

struct Config {
    
    // MARK: - OpenAI Configuration (Secure Integration)

    struct OpenAI {
        static var apiKey: String {
            // Read from config (env var or Info.plist OPENAI_API_KEY) — not hardcoded.
            Secrets.openAIKey
        }

        static let baseURL = "https://api.openai.com/v1"
        static let organization: String? = nil

        struct Prompt {
            static var id: String {
                // Try environment variable first, fallback to hardcoded for development
                ProcessInfo.processInfo.environment["OPENAI_PROMPT_ID"] ??
                "pmpt_689421179cc88196bcf771e8e5aaf1c70eb96f4c3826712c"
            }

            static var version: String {
                ProcessInfo.processInfo.environment["OPENAI_PROMPT_VERSION"] ?? "1"
            }
        }

        struct Whisper {
            static let model = "whisper-1"
            static let responseFormat = "json"
            static let temperature: Double = 0.0
            static let language: String? = nil
            static let prompt: String? = nil
        }

        struct TTS {
            static let model = "tts-1"
            static let voice = "nova"
            static let responseFormat = "mp3"
            static let speed: Double = 1.0
        }

        struct GPT {
            static let model = "gpt-4"
            static let maxTokens = 4000
            static let temperature: Double = 0.7
            static let topP: Double = 1.0
            static let presencePenalty: Double = 0.0
            static let frequencyPenalty: Double = 0.0
            static let enableFunctionCalling = true
        }

        struct Embeddings {
            static let model = "text-embedding-3-small"
            static let dimensions: Int? = nil
            static let encodingFormat = "float"
            static let batchSize = 100
        }
    }

    // MARK: - App Information
    
    struct App {
        static let name = "Apprentice"
        static let displayName = "Apprentice AI"
        static let description = "Executive AI Coach for Business Leaders"
        
        static let version: String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        }()
        
        static let buildNumber: String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        }()
        
        static let bundleID: String = {
            Bundle.main.bundleIdentifier ?? "com.stitchai.executive"
        }()
    }
    
    // MARK: - Feature Flags
    
    struct Features {
        static let enableVoiceCoaching = true
        static let enableBusinessIntelligence = true
        static let enableRealTimeTranscription = true
        static let enableContextualMemory = true
        static let enableAutomaticInsights = true
        static let enableActionItemPrioritization = true
        static let enableSessionPatternDetection = true
        static let enableFounderProfiling = true
        
        static let enableAdvancedAnalytics = false
        static let enableTeamCollaboration = false
        static let enableCalendarIntegration = false
        
        static let enableDocumentUpload = true
        static let enableVisionAnalysis = true
        static let enableDocumentSearch = true
        static let enableDocumentCollections = true
        static let enableDocumentSharing = false
        
        static let enableAdvancedVision = true
        static let enableDocumentOCR = true
        static let enableSmartCategories = true
        static let enableDocumentInsights = true
        static let enableBatchProcessing = true
        
        static let enableDocumentChat = false
        static let enableDocumentSummaries = false
        static let enableCollaborativeAnnotation = false
    }
    
    // MARK: - Debug Configuration
    
    struct Debug {
        static let enableLogging = true
        static let logLevel: LogLevel = .info
        static let enablePerformanceMetrics = true
        static let enableCrashReporting = false
        
        enum LogLevel: String, CaseIterable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
            
            var priority: Int {
                switch self {
                case .debug: return 0
                case .info: return 1
                case .warning: return 2
                case .error: return 3
                }
            }
        }
    }
    
    // MARK: - Document Management (UPDATED)
    
    struct Documents {
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
        static let maxConcurrentProcessing = 3
        static let enableAutoThumbnails = true
        static let thumbnailSize = CGSize(width: 300, height: 400)
        static let compressionQuality: CGFloat = 0.8
        static let retentionPeriod: TimeInterval = 365 * 24 * 60 * 60 // 1 year
        
        static let supportedImageFormats = ["jpg", "jpeg", "png", "heic", "webp"]
        static let supportedDocumentFormats = ["pdf", "doc", "docx", "txt", "rtf"]
        static let supportedSpreadsheetFormats = ["xls", "xlsx", "csv"]
        static let supportedPresentationFormats = ["ppt", "pptx", "key"]
        
        static var allSupportedFormats: [String] {
            supportedImageFormats + supportedDocumentFormats +
            supportedSpreadsheetFormats + supportedPresentationFormats
        }
        
        static let imageSizeLimit: Int64 = 20 * 1024 * 1024 // 20MB
        static let documentSizeLimit: Int64 = 50 * 1024 * 1024 // 50MB
        static let visionAPISizeLimit: Int64 = 10 * 1024 * 1024 // 10MB for Vision API
        
        static let documentsDirectory = "BusinessDocuments"
        static let thumbnailsDirectory = "DocumentThumbnails"
        static let processedDirectory = "ProcessedDocuments"
        static let tempDirectory = "TempDocuments"
        
        // ADDED: Missing properties for SafeDocumentManager compatibility
        static let maxChunkSize = 1500
        static let chunkOverlap = 200
        static let maxFileSizeBytes = maxFileSize
        static let supportedTypes = allSupportedFormats
    }
    
    // MARK: - Vision API Configuration
    
    struct Vision {
        static let baseURL = "https://api.openai.com/v1/chat/completions"
        static let model = "gpt-4-vision-preview"
        static let maxTokens = 1500
        static let temperature: Float = 0.3
        static let detail: VisionDetail = .high
        static let timeoutInterval: TimeInterval = 60.0
        
        static let maxImageDimension: CGFloat = 2048
        static let compressionQuality: CGFloat = 0.85
        static let visionAPISizeLimit: Int64 = 10 * 1024 * 1024 // 10MB for Vision API
        static let enableBatchProcessing = true
        static let maxBatchSize = 5
        
        static let enableBusinessInsights = true
        static let enableActionItemExtraction = true
        static let enableChartDetection = true
        static let enableTableExtraction = true
        static let confidenceThreshold: Double = 0.7
        
        enum VisionDetail: String, CaseIterable {
            case low = "low"
            case high = "high"
            case auto = "auto"
        }
        
        static let businessAnalysisPrompt = """
        Analyze this business document and extract:
        1. Key business insights and findings
        2. Specific action items that should be taken
        3. Important decisions or recommendations
        4. Any charts, graphs, or data visualizations
        5. Tables with structured data
        
        Focus on actionable business intelligence that an executive would find valuable.
        Respond in JSON format with clear structure.
        """
        
        static let chartAnalysisPrompt = """
        Analyze the charts and data visualizations in this image:
        1. Identify chart types and titles
        2. Extract key data points and trends
        3. Provide business insights from the data
        4. Note any concerning or positive trends
        
        Be specific about numbers and percentages where visible.
        """
        
        static let documentStructurePrompt = """
        Analyze the structure and content of this document:
        1. Extract all text content accurately
        2. Identify sections, headers, and organization
        3. Find tables and structured data
        4. Note any forms, signatures, or special elements
        5. Summarize the document's purpose and key points
        """
    }
    
    // MARK: - Processing Configuration
    
    struct Processing {
        static let enableParallelProcessing = true
        static let maxConcurrentAnalyses = 3
        static let retryAttempts = 3
        static let retryDelay: TimeInterval = 2.0
        static let enableProgressTracking = true
        static let enableOfflineQueue = true
        static let maxOfflineOperations = 50
        
        static let minimumImageResolution: CGFloat = 300
        static let maximumImageResolution: CGFloat = 4096
        static let textConfidenceThreshold: Double = 0.8
        static let businessInsightThreshold: Double = 0.6
        
        static let enableImageOptimization = true
        static let enableSmartCropping = true
        static let enableNoiseReduction = false
        static let cacheProcessedResults = true
        static let cacheDuration: TimeInterval = 7 * 24 * 60 * 60 // 1 week
    }
}

// MARK: - Helper Extensions

extension Config {
    
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    static func appSupportDirectory() -> URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[0].appendingPathComponent(App.bundleID)
        
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        
        return appSupportURL
    }
    
    static func validateOpenAIConfig() -> Bool {
        return !OpenAI.apiKey.isEmpty && OpenAI.apiKey != "your-openai-api-key-here"
    }
    
    static func storageURL(for directory: String) -> URL {
        let baseURL = documentsDirectory()
        let directoryURL = baseURL.appendingPathComponent(directory)
        
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        
        return directoryURL
    }
    
    static func documentStorageURL(for directory: String) -> URL {
        let baseURL = documentsDirectory()
        // Simplified: Use direct subdirectories instead of nested Documents/subdirectory structure
        let directoryURL = baseURL.appendingPathComponent(directory)
        
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("📁 Created directory: \(directoryURL.lastPathComponent)")
        } catch {
            print("❌ Failed to create directory: \(directoryURL.lastPathComponent) - \(error)")
            // Return the base URL as fallback to prevent crashes
            return baseURL
        }
        
        return directoryURL
    }
    
    static func validateDocumentConfig() -> Bool {
        return !OpenAI.apiKey.isEmpty &&
               Documents.maxFileSize > 0 &&
               Vision.maxTokens > 0
    }
    
    static func isFileFormatSupported(_ fileExtension: String) -> Bool {
        return Documents.allSupportedFormats.contains(fileExtension.lowercased())
    }
    
    static func getSizeLimit(for fileExtension: String) -> Int64 {
        let ext = fileExtension.lowercased()
        
        if Documents.supportedImageFormats.contains(ext) {
            return Documents.imageSizeLimit
        } else {
            return Documents.documentSizeLimit
        }
    }
    
    static func getVisionPrompt(for analysisType: VisionAnalysisType) -> String {
        switch analysisType {
        case .business:
            return Vision.businessAnalysisPrompt
        case .chart:
            return Vision.chartAnalysisPrompt
        case .document:
            return Vision.documentStructurePrompt
        case .custom(let prompt):
            return prompt
        }
    }
    
    enum VisionAnalysisType {
        case business
        case chart
        case document
        case custom(String)
    }
}

// MARK: - Logging Helper

extension Config.Debug {
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard enableLogging && level.priority >= logLevel.priority else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        
        print("[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)")
    }
}

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - VisionConfig compatibility handled in VisionDataPoint.swift
// Note: VisionConfig is already defined in VisionDataPoint.swift to avoid conflicts
