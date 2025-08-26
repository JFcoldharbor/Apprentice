//
//  VisionDataPoint.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  VisionService.swift
//  Apprentice
//
//  Layer 4: Core Services - OpenAI Vision API integration
//  Minimal implementation that works with existing project types
//

import Foundation
import UIKit
import PDFKit

// MARK: - Private Helper Types (to avoid conflicts)

private struct VisionDataPoint: Codable {
    let label: String
    let value: Double
    let category: String?
}

private struct VisionActionItem: Codable {
    let title: String
    let description: String?
    let assignee: String?
}

private struct VisionChart: Codable {
    let type: String
    let title: String
    let dataPoints: [VisionDataPoint]?
    let insights: [String]?
}

private struct VisionTable: Codable {
    let headers: [String]
    let rows: [[String]]
    let title: String?
    let insights: [String]?
}

// MARK: - Configuration Extension (only if not already defined)

extension Config {
    struct VisionConfig {
        static let baseURL = "https://api.openai.com/v1/chat/completions"
        static let model = "gpt-4-vision-preview"
        static let maxTokens = 1000
        static let temperature: Float = 0.1
        static let timeoutInterval: TimeInterval = 60.0
        static let maxImageSize: Int64 = 20 * 1024 * 1024 // 20MB
        static let maxImageDimension: CGFloat = 2048
    }
}

// MARK: - Vision Service Implementation

@MainActor
class VisionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAnalyzing = false
    @Published var currentProgress: Double = 0.0
    @Published var lastError: String?
    @Published var analysisHistory: [VisionAnalysis] = []
    
    // MARK: - Private Properties
    
    private let apiKey = Config.OpenAI.apiKey
    private let baseURL = Config.VisionConfig.baseURL
    private var currentAnalysisTask: Task<Void, Never>?
    
    // MARK: - URLSession Configuration
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Config.VisionConfig.timeoutInterval
        config.timeoutIntervalForResource = Config.VisionConfig.timeoutInterval * 2
        return URLSession(configuration: config)
    }()
    
    // MARK: - Vision Analysis Methods
    
    func analyzeImage(imageURL: URL) async throws -> VisionAnalysis {
        print("ðŸ” [VISION] Starting image analysis...")
        
        guard !apiKey.isEmpty else {
            throw NSError(domain: "VisionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw NSError(domain: "VisionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        
        await updateProgress(0.1)
        
        // Optimize image for Vision API
        let optimizedURL = try await optimizeImageForVisionAPI(imageURL)
        await updateProgress(0.3)
        
        // Convert to base64
        let base64Image = try convertImageToBase64(optimizedURL)
        await updateProgress(0.5)
        
        // Perform analysis
        let analysis = try await performVisionAnalysis(
            base64Image: base64Image,
            prompt: getBusinessVisionPrompt()
        )
        
        await updateProgress(1.0)
        
        // Clean up temporary files
        if optimizedURL != imageURL {
            try? FileManager.default.removeItem(at: optimizedURL)
        }
        
        // Add to history
        analysisHistory.append(analysis)
        
        print("âœ… [VISION] Image analysis completed")
        return analysis
    }
    
    func analyzePDF(pdfURL: URL) async throws -> VisionAnalysis {
        print("ðŸ“„ [VISION] Starting PDF analysis...")
        
        guard !apiKey.isEmpty else {
            throw NSError(domain: "VisionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw NSError(domain: "VisionService", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        
        await updateProgress(0.1)
        
        // Extract text from PDF
        let extractedText = await extractTextFromPDFSync(pdfURL: pdfURL) ?? ""
        await updateProgress(0.5)
        
        // Analyze the text content
        let analysis = try await performTextAnalysis(
            text: extractedText,
            prompt: getBusinessVisionPrompt()
        )
        
        await updateProgress(1.0)
        
        // Add to history
        analysisHistory.append(analysis)
        
        print("âœ… [VISION] PDF analysis completed")
        return analysis
    }
    
    func extractTextFromImage(imageURL: URL) async throws -> String {
        let analysis = try await analyzeImage(imageURL: imageURL)
        return analysis.textContent
    }
    
    func extractTextFromPDF(pdfURL: URL) async throws -> String {
        return await extractTextFromPDFSync(pdfURL: pdfURL) ?? ""
    }
    
    // MARK: - Private Helper Methods
    
    private func optimizeImageForVisionAPI(_ imageURL: URL) async throws -> URL {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw NSError(domain: "VisionService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid image file"])
        }
        
        // Check if optimization is needed
        let fileSize = try FileManager.default.attributesOfItem(atPath: imageURL.path)[.size] as? Int64 ?? 0
        let maxDimension = max(image.size.width, image.size.height)
        
        if fileSize <= Config.VisionConfig.maxImageSize && maxDimension <= Config.VisionConfig.maxImageDimension {
            return imageURL // No optimization needed
        }
        
        // Resize image
        let optimizedImage = image.resized(toMaxDimension: Config.VisionConfig.maxImageDimension)
        
        // Save optimized image
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        guard let jpegData = optimizedImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "VisionService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Image compression failed"])
        }
        
        try jpegData.write(to: tempURL)
        return tempURL
    }
    
    private func convertImageToBase64(_ imageURL: URL) throws -> String {
        let imageData = try Data(contentsOf: imageURL)
        let base64String = imageData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64String)"
    }
    
    private func performVisionAnalysis(base64Image: String, prompt: String) async throws -> VisionAnalysis {
        let startTime = Date()
        
        let payload = VisionRequest(
            model: Config.VisionConfig.model,
            messages: [
                VisionMessage(
                    role: "user",
                    content: [
                        .text(prompt),
                        .imageURL(base64Image)
                    ]
                )
            ],
            maxTokens: Config.VisionConfig.maxTokens,
            temperature: Config.VisionConfig.temperature
        )
        
        let request = try createVisionAPIRequest(payload: payload)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "VisionService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "VisionService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error \(httpResponse.statusCode): \(errorMessage)"])
        }
        
        let apiResponse = try JSONDecoder().decode(VisionAPIResponse.self, from: data)
        let content = apiResponse.choices.first?.message.content ?? ""
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return parseVisionResponse(content, processingTime: processingTime)
    }
    
    private func performTextAnalysis(text: String, prompt: String) async throws -> VisionAnalysis {
        let startTime = Date()
        
        let payload = TextAnalysisRequest(
            model: "gpt-4",
            messages: [
                TextMessage(role: "system", content: prompt),
                TextMessage(role: "user", content: text)
            ],
            maxTokens: Config.VisionConfig.maxTokens,
            temperature: Config.VisionConfig.temperature
        )
        
        let request = try createTextAPIRequest(payload: payload)
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "VisionService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "VisionService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error \(httpResponse.statusCode): \(errorMessage)"])
        }
        
        let apiResponse = try JSONDecoder().decode(TextAPIResponse.self, from: data)
        let content = apiResponse.choices.first?.message.content ?? ""
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return parseVisionResponse(content, processingTime: processingTime)
    }
    
    private func createVisionAPIRequest(payload: VisionRequest) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "VisionService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)
        
        return request
    }
    
    private func createTextAPIRequest(payload: TextAnalysisRequest) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "VisionService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)
        
        return request
    }
    
    private func parseVisionResponse(_ content: String, processingTime: TimeInterval) -> VisionAnalysis {
        // Try to parse as JSON first
        if let data = content.data(using: .utf8),
           let jsonResponse = try? JSONDecoder().decode(VisionJSONResponse.self, from: data) {
            return VisionAnalysis(
                textContent: jsonResponse.textContent ?? content,
                businessInsights: jsonResponse.insights ?? [],
                actionItems: jsonResponse.actionItems?.map { createActionItem(from: $0) } ?? [],
                chartData: jsonResponse.charts?.map { createChartElement(from: $0) },
                tables: jsonResponse.tables?.map { createTableData(from: $0) },
                confidence: jsonResponse.confidence ?? 0.8,
                processingTime: processingTime
            )
        }
        
        // Fallback: parse as plain text
        return VisionAnalysis(
            textContent: content,
            businessInsights: extractInsightsFromText(content),
            actionItems: extractActionItemsFromText(content),
            confidence: 0.6,
            processingTime: processingTime
        )
    }
    
    private func extractTextFromPDFSync(pdfURL: URL) async -> String? {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            return nil
        }
        
        var extractedText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                extractedText += pageText + "\n"
            }
        }
        
        return extractedText.isEmpty ? nil : extractedText
    }
    
    private func getBusinessVisionPrompt() -> String {
        return """
        Analyze this business document or image. Extract:
        1. All visible text content
        2. Business insights and key information
        3. Action items or tasks mentioned
        4. Any charts, graphs, or data tables
        5. Strategic implications or recommendations
        
        Focus on business-relevant information and provide actionable insights.
        """
    }
    
    private func updateProgress(_ progress: Double) async {
        currentProgress = progress
    }
    
    // MARK: - Text Analysis Helpers
    
    private func extractInsightsFromText(_ text: String) -> [String] {
        // Simple keyword-based insight extraction
        return []
    }
    
    private func extractActionItemsFromText(_ text: String) -> [ActionItem] {
        // Simple action item extraction
        return []
    }
    
    private func createActionItem(from json: VisionActionItem) -> ActionItem {
        return ActionItem(
            id: UUID(),
            title: json.title,
            description: json.description ?? "",
            assignee: json.assignee,
            dueDate: nil,
            priority: .medium,
            status: .pending,
            createdAt: Date()
        )
    }
    
    private func createChartElement(from json: VisionChart) -> ChartElement {
        // Use DocumentDataPoint which is what ChartElement expects
        let dataPoints = json.dataPoints?.map { point in
            DocumentDataPoint(label: point.label, value: point.value, category: point.category)
        } ?? []
        
        return ChartElement(
            id: UUID(),
            type: ChartElement.ChartType(rawValue: json.type) ?? .unknown,
            title: json.title ?? "",
            dataPoints: dataPoints,
            insights: json.insights ?? []
        )
    }
    
    private func createTableData(from json: VisionTable) -> TableData {
        return TableData(
            id: UUID(),
            headers: json.headers,
            rows: json.rows,
            title: json.title,
            insights: json.insights ?? []
        )
    }
}

// MARK: - Private API Models

private struct VisionRequest: Codable {
    let model: String
    let messages: [VisionMessage]
    let maxTokens: Int
    let temperature: Float
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct VisionMessage: Codable {
    let role: String
    let content: [VisionContent]
}

private enum VisionContent: Codable {
    case text(String)
    case imageURL(String)
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            try container.encode(["url": url], forKey: .imageURL)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageData = try container.decode([String: String].self, forKey: .imageURL)
            let url = imageData["url"] ?? ""
            self = .imageURL(url)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type")
        }
    }
}

private struct VisionAPIResponse: Codable {
    let choices: [VisionChoice]
}

private struct VisionChoice: Codable {
    let message: VisionResponseMessage
}

private struct VisionResponseMessage: Codable {
    let content: String
}

// Text Analysis Models
private struct TextAnalysisRequest: Codable {
    let model: String
    let messages: [TextMessage]
    let maxTokens: Int
    let temperature: Float
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct TextMessage: Codable {
    let role: String
    let content: String
}

private struct TextAPIResponse: Codable {
    let choices: [TextChoice]
}

private struct TextChoice: Codable {
    let message: TextMessage
}

// JSON Response Models
private struct VisionJSONResponse: Codable {
    let textContent: String?
    let insights: [String]?
    let actionItems: [VisionActionItem]?
    let charts: [VisionChart]?
    let tables: [VisionTable]?
    let confidence: Double?
}

// MARK: - UIImage Extension

private extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        if ratio >= 1 {
            return self
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
}