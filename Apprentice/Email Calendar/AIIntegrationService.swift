//
//  AIIntegrationService.swift
//  Apprentice
//
//  FIXED: Removed duplicate declarations, using existing protocols
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

// MARK: - AI Integration Service
// Uses existing SpeechConversationServiceProtocol and SpeechConversationService

@MainActor
class AIIntegrationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var currentTranscript = ""
    @Published var errorMessage: String?
    @Published var hasPermissions = false
    
    // MARK: - Dependencies
    
    private let speechService: SpeechConversationService
    private let aiService = RealAIService()
    
    // MARK: - Initialization
    
    init() {
        self.speechService = SpeechConversationService()
        Task {
            await setupServices()
        }
    }
    
    // MARK: - Service Setup
    
    private func setupServices() async {
        do {
            try await speechService.requestPermissions()
            hasPermissions = true
            print("✅ [AI_INTEGRATION] Services initialized successfully")
        } catch {
            print("❌ [AI_INTEGRATION] Setup failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Public Interface
    
    func startListening() async throws {
        try await speechService.startListening()
    }
    
    func stopListening() async throws -> String {
        return try await speechService.stopListening()
    }
    
    func speak(text: String) async throws {
        try await speechService.speak(text: text)
    }
    
    func processUserInput(_ transcript: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Use the existing processWithAI method
            let response = try await speechService.processWithAI(transcript)
            return response
        } catch {
            print("❌ [AI_INTEGRATION] Processing failed: \(error)")
            errorMessage = error.localizedDescription
            return "I'm having trouble processing that right now."
        }
    }
}
    
