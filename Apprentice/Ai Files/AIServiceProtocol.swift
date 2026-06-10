//
//  AIServiceProtocol.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  OpenAIModels.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - OpenAI API data models and error types
//  COMPLETE VERSION - All API models for RealAIService
//

import Foundation

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    func transcribeAudio(audioURL: URL) async throws -> String
    func generateCoachingResponse(prompt: String) async throws -> String
    func analyzeBusinessContent(content: String) async throws -> AIResponse
    func generateProactiveInsight(context: AIContext) async throws -> String
    func generateResponse(prompt: String, context: AIContext) async throws -> String
}

// MARK: - AI Service Errors

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case networkError(String)
    case invalidResponse
    case transcriptionFailed
    case rateLimitExceeded
    case tokenLimitExceeded
    case audioProcessingFailed
    case jsonDecodingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing or invalid"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .transcriptionFailed:
            return "Audio transcription failed"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .tokenLimitExceeded:
            return "Token limit exceeded"
        case .audioProcessingFailed:
            return "Audio processing failed"
        case .jsonDecodingFailed:
            return "Failed to decode JSON response"
        }
    }
}

// MARK: - Chat Models

struct ChatMessage: Codable {
    let role: String
    let content: String
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double
    let topP: Double?
    let presencePenalty: Double?
    let frequencyPenalty: Double?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case presencePenalty = "presence_penalty"
        case frequencyPenalty = "frequency_penalty"
    }
    
    init(model: String, messages: [ChatMessage], maxTokens: Int, temperature: Double, topP: Double? = nil, presencePenalty: Double? = nil, frequencyPenalty: Double? = nil) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.presencePenalty = presencePenalty
        self.frequencyPenalty = frequencyPenalty
    }
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChatChoice]
    let usage: Usage?
    
    struct ChatChoice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - Transcription Models

struct TranscriptionResponse: Codable {
    let text: String
}

// MARK: - AI Response Model

struct AIResponse: Codable {
    let insights: [String]
    let actionItems: [String]
    let decisions: [String]
    let summary: String
    
    init(insights: [String] = [], actionItems: [String] = [], decisions: [String] = [], summary: String = "") {
        self.insights = insights
        self.actionItems = actionItems
        self.decisions = decisions
        self.summary = summary
    }
}

// MARK: - Simple Conversation Turn (Already exists but ensure compatibility)

struct SimpleConversationTurn: Codable, Equatable, Identifiable {
    let id = UUID()
    let userInput: String
    let aiResponse: String
    let timestamp: Date
    let sessionId: String?
    
    init(userInput: String, aiResponse: String, sessionId: String? = nil) {
        self.userInput = userInput
        self.aiResponse = aiResponse
        self.timestamp = Date()
        self.sessionId = sessionId
    }
    
    static func == (lhs: SimpleConversationTurn, rhs: SimpleConversationTurn) -> Bool {
        return lhs.userInput == rhs.userInput &&
               lhs.aiResponse == rhs.aiResponse &&
               lhs.timestamp == rhs.timestamp &&
               lhs.sessionId == rhs.sessionId
    }
}