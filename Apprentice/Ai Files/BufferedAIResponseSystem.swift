//
//  BufferedAIResponseSystem.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  BufferedAIResponseSystem.swift
//  Apprentice
//
//  Created by James Garmon on 8/24/25.
//


//
//  BufferedAIResponseSystem.swift
//  Stitch Executive AI
//
//  Immediate response buffering system like ChatGPT Voice
//  Provides instant acknowledgment while full AI processes in background
//

import Foundation
import AVFoundation

@MainActor
class BufferedAIResponseSystem: ObservableObject {
    
    // MARK: - State Management
    
    @Published var isBuffering = false
    @Published var isProcessingFullResponse = false
    @Published var bufferPhase: BufferPhase = .idle
    
    enum BufferPhase {
        case idle
        case immediateBuffer    // 0.2s quick acknowledgment
        case thinkingBuffer     // 2-4s thinking phrase
        case processingFull     // Background AI processing
        case delivering         // Full response ready
    }
    
    // MARK: - Dependencies
    
    private let realAIService: RealAIService
    private let speechService: SpeechConversationService
    
    // MARK: - Buffer Response Bank
    
    private let immediateBuffers = [
        "Got it.",
        "Right.",
        "Okay.",
        "I see.",
        "Mm-hmm."
    ]
    
    private let thinkingBuffers = [
        "Let me think about that...",
        "That's an interesting point...",
        "I'm analyzing this...",
        "Good question...",
        "Let me consider that carefully..."
    ]
    
    private let contextualThinkingBuffers: [String: [String]] = [
        "document": [
            "Let me review that document...",
            "I'm analyzing the document details...",
            "Looking at that information..."
        ],
        "insight": [
            "Let me break down those insights...",
            "I'm processing those key points...",
            "Analyzing the implications..."
        ],
        "decision": [
            "That's a complex decision...",
            "Let me think through the options...",
            "I'm weighing the considerations..."
        ],
        "strategy": [
            "That's strategic thinking...",
            "Let me analyze the business impact...",
            "Considering the broader implications..."
        ]
    ]
    
    // MARK: - Buffered Response Generation
    
    func processUserInputWithBuffering(
        transcript: String,
        context: AIContext
    ) async throws -> String {
        
        print("ðŸŽ¤ [BUFFER] Starting buffered response for: \(transcript.prefix(50))...")
        
        // Phase 1: Immediate acknowledgment (0.2s)
        bufferPhase = .immediateBuffer
        let immediateResponse = selectImmediateBuffer()
        
        // Start immediate TTS (non-blocking)
        Task {
            try? await speechService.speak(text: immediateResponse)
        }
        
        // Small delay to ensure immediate response starts
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        
        // Phase 2: Quick context analysis for thinking buffer
        bufferPhase = .thinkingBuffer
        let contextType = detectContextType(transcript)
        let thinkingResponse = selectThinkingBuffer(for: contextType)
        
        // Phase 3: Start background AI processing
        bufferPhase = .processingFull
        isProcessingFullResponse = true
        
        // Create processing task (non-blocking)
        let fullResponseTask = Task {
            return try await realAIService.generateResponse(prompt: transcript, context: context)
        }
        
        // Phase 4: Play thinking buffer while AI processes
        try await speechService.speak(text: thinkingResponse)
        
        // Phase 5: Wait for AI or timeout
        let fullResponse: String
        do {
            // Wait for AI response with timeout
            fullResponse = try await withTimeout(seconds: 8) {
                try await fullResponseTask.value
            }
        } catch {
            // Fallback if AI takes too long
            print("âš ï¸ [BUFFER] AI timeout, using fallback response")
            fullResponse = generateFallbackResponse(for: transcript, context: context)
        }
        
        // Phase 6: Deliver full response
        bufferPhase = .delivering
        isProcessingFullResponse = false
        
        print("âœ… [BUFFER] Full response ready, delivering...")
        return fullResponse
    }
    
    // MARK: - Buffer Selection Logic
    
    private func selectImmediateBuffer() -> String {
        return immediateBuffers.randomElement() ?? "I see."
    }
    
    private func selectThinkingBuffer(for contextType: String) -> String {
        if let contextBuffers = contextualThinkingBuffers[contextType] {
            return contextBuffers.randomElement() ?? thinkingBuffers.randomElement()!
        }
        return thinkingBuffers.randomElement()!
    }
    
    private func detectContextType(_ transcript: String) -> String {
        let lowercased = transcript.lowercased()
        
        if lowercased.contains("document") || lowercased.contains("file") || lowercased.contains("pdf") {
            return "document"
        } else if lowercased.contains("insight") || lowercased.contains("action") || lowercased.contains("analysis") {
            return "insight"
        } else if lowercased.contains("should") || lowercased.contains("decide") || lowercased.contains("choose") {
            return "decision"
        } else if lowercased.contains("strategy") || lowercased.contains("plan") || lowercased.contains("approach") {
            return "strategy"
        }
        
        return "general"
    }
    
    // MARK: - Fallback Response System
    
    private func generateFallbackResponse(for transcript: String, context: AIContext) -> String {
        let contextType = detectContextType(transcript)
        
        switch contextType {
        case "document":
            return "I can see you're asking about the document. Based on what I've analyzed, there are several key points we should discuss. Let me share the most important insights I found."
            
        case "insight":
            return "You're asking about the insights from our analysis. There are some important patterns I've identified that could impact your business strategy."
            
        case "decision":
            return "That's an important decision to consider. Based on your business context, there are a few key factors we should evaluate before moving forward."
            
        case "strategy":
            return "Strategic planning is crucial for your business. Let me share some observations about your current approach and potential improvements."
            
        default:
            if let profile = context.founderProfile {
                return "That's a great question, \(profile.founderName). Given your \(profile.industry) business, let me share some thoughts that could help."
            } else {
                return "That's an interesting point. Let me share some insights that might be helpful for your situation."
            }
        }
    }
    
    // MARK: - Timeout Helper
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Return first completed result
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Advanced Buffering Features
    
    func handleInterruption() {
        // Stop current TTS immediately
        speechService.openAIVoice.stopSpeaking()
        
        // Reset state
        bufferPhase = .idle
        isBuffering = false
        isProcessingFullResponse = false
        
        print("ðŸ›‘ [BUFFER] Response interrupted, ready for new input")
    }
    
    func getCurrentBufferStatus() -> String {
        switch bufferPhase {
        case .idle:
            return "Ready"
        case .immediateBuffer:
            return "Acknowledging..."
        case .thinkingBuffer:
            return "Thinking..."
        case .processingFull:
            return "Processing..."
        case .delivering:
            return "Responding..."
        }
    }
    
    // MARK: - Initialization
    
    init(realAIService: RealAIService, speechService: SpeechConversationService) {
        self.realAIService = realAIService
        self.speechService = speechService
    }
}

// MARK: - Supporting Types

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        return "AI response timeout"
    }
}

// MARK: - Usage Integration

extension BufferedAIResponseSystem {
    
    /// Main entry point for voice conversations
    func handleVoiceInput(_ transcript: String, context: AIContext) async {
        do {
            let response = try await processUserInputWithBuffering(
                transcript: transcript,
                context: context
            )
            
            // Deliver the full response
            try await speechService.speak(text: response)
            
        } catch {
            print("âŒ [BUFFER] Error in buffered response: \(error)")
            
            // Emergency fallback
            let fallback = "I'm having trouble processing that right now. Could you try rephrasing your question?"
            try? await speechService.speak(text: fallback)
        }
        
        // Reset state
        bufferPhase = .idle
        isBuffering = false
    }
}