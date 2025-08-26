//
//  SpeechConversationServiceProtocol.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  SpeechConversationService.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Speech Recognition and TTS with AI Integration
//  ENHANCED: Added voice commands for stopping and interrupting conversations
//

import Foundation
import Speech
import AVFoundation
import SwiftUI

// MARK: - Speech Conversation Protocol

protocol SpeechConversationServiceProtocol {
    func startListening() async throws
    func stopListening() async throws -> String
    func speak(text: String) async throws
    func requestPermissions() async throws
    var isListening: Bool { get }
    var isSpeaking: Bool { get }
    var hasPermissions: Bool { get }
}

// MARK: - Speech Conversation Errors

enum SpeechConversationError: Error, LocalizedError {
    case speechRecognitionNotAuthorized
    case speechRecognitionNotAvailable
    case audioSessionSetupFailed
    case recognitionTaskFailed
    case ttsNotAvailable
    case audioEngineError
    case microphonePermissionDenied
    case aiProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionNotAuthorized:
            return "Speech recognition not authorized"
        case .speechRecognitionNotAvailable:
            return "Speech recognition not available"
        case .audioSessionSetupFailed:
            return "Audio session setup failed"
        case .recognitionTaskFailed:
            return "Recognition task failed"
        case .ttsNotAvailable:
            return "Text-to-speech not available"
        case .audioEngineError:
            return "Audio engine error"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .aiProcessingFailed:
            return "AI processing failed"
        }
    }
}

// MARK: - Enhanced Speech Conversation Service with AI Integration

@MainActor
class SpeechConversationService: NSObject, ObservableObject, SpeechConversationServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var currentTranscript = ""
    @Published var errorMessage: String?
    @Published var hasPermissions = false
    @Published var isProcessingAI = false
    
    // MARK: - Voice Commands for Control
    
    private let stopCommands = ["stop", "end chat", "that's all for now", "thank you", "goodbye", "end conversation", "pause", "stop listening"]
    private let interruptCommands = ["wait", "hold on", "stop talking", "quiet", "interrupt", "pause ai"]
    
    // MARK: - Speech Recognition Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - AI Service Integration
    
    private let aiService = RealAIService()
    let openAIVoice = OpenAIVoiceService()
    
    // MARK: - Document Context Integration - FIXED for SafeDocumentManager
    
    private var safeDocumentManager: SafeDocumentManager?
    
    // FIXED: Added missing methods
    func setSafeDocumentManager(_ manager: SafeDocumentManager) {
        self.safeDocumentManager = manager
    }
    
    func setDocumentManager(_ manager: SafeDocumentManager) {
        self.safeDocumentManager = manager
    }
    
    // MARK: - Voice Command Detection
    
    func checkForStopCommand(_ transcript: String) -> Bool {
        let lowercased = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return stopCommands.contains { command in
            lowercased.contains(command) || lowercased == command
        }
    }
    
    func checkForInterruptCommand(_ transcript: String) -> Bool {
        let lowercased = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return interruptCommands.contains { command in
            lowercased.contains(command) || lowercased == command
        }
    }
    
    // MARK: - Enhanced Stop Speaking with User Interrupt
    
    func stopSpeaking() async {
        openAIVoice.stopSpeaking()
        isSpeaking = false
        currentTranscript = ""
        print("ðŸ›‘ [SPEECH] AI interrupted by user")
    }
    
    func immediateStop() async {
        // Stop all AI processing and speech immediately
        await stopSpeaking()
        
        // Clean stop of listening
        try? await stopListening()
        
        print("ðŸ›‘ [SPEECH] Conversation stopped immediately")
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        
        // Update permissions status
        updatePermissionsStatus()
    }
    
    // MARK: - Permission Management
    
    func requestPermissions() async throws {
        print("ðŸ“‹ [SPEECH] Requesting permissions...")
        
        // Request speech recognition permission
        let speechPermission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechPermission else {
            throw SpeechConversationError.speechRecognitionNotAuthorized
        }
        
        // Request microphone permission
        let micPermission = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard micPermission else {
            throw SpeechConversationError.microphonePermissionDenied
        }
        
        hasPermissions = true
        print("âœ… [SPEECH] All permissions granted")
    }
    
    private func updatePermissionsStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        hasPermissions = speechStatus == .authorized && micStatus == .granted
    }
    
    // MARK: - Speech Recognition with Command Detection
    
    func startListening() async throws {
        guard hasPermissions else {
            try await requestPermissions()
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechConversationError.speechRecognitionNotAvailable
        }
        
        guard !isListening else {
            print("âš ï¸ [SPEECH] Already listening")
            return
        }
        
        // Setup audio session
        try setupAudioSession()
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { result, error in
            Task { @MainActor in
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.currentTranscript = transcript
                    
                    // Check for voice commands during recognition
                    await self.handleTranscriptCommands(transcript)
                }
                
                if let error = error {
                    print("Recognition error: \(error)")
                    self.errorMessage = error.localizedDescription
                    try? await self.stopListening()
                }
            }
        }
        
        isListening = true
        print("ðŸŽ¤ [SPEECH] Started listening")
    }
    
    private func handleTranscriptCommands(_ transcript: String) async {
        // Check for interrupt commands first (highest priority)
        if checkForInterruptCommand(transcript) && isSpeaking {
            print("ðŸ›‘ [SPEECH] Interrupt command detected: '\(transcript)'")
            await immediateStop()
            return
        }
        
        // Check for stop commands
        if checkForStopCommand(transcript) {
            print("ðŸ›‘ [SPEECH] Stop command detected: '\(transcript)'")
            await handleStopCommand(transcript)
            return
        }
    }
    
    private func handleStopCommand(_ transcript: String) async {
        // Provide polite acknowledgment
        let stopResponse = "Understood. I'm here whenever you need me."
        
        do {
            // Stop listening first
            _ = try await stopListening()
            
            // Provide acknowledgment
            try await speak(text: stopResponse)
            
            // Clean shutdown
            try await cleanup()
            
            print("âœ… [SPEECH] Conversation ended cleanly")
        } catch {
            print("âš ï¸ [SPEECH] Error during stop command: \(error)")
            try? await cleanup()
        }
    }
    
    func stopListening() async throws -> String {
        guard isListening else {
            return currentTranscript
        }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        
        let transcript = currentTranscript
        print("ðŸ›‘ [SPEECH] Stopped listening. Transcript: \(transcript)")
        
        return transcript
    }
    
    // MARK: - Text-to-Speech with Interrupt Support
    
    func speak(text: String) async throws {
        guard !text.isEmpty else { return }
        
        isSpeaking = true
        currentTranscript = text
        
        do {
            try await openAIVoice.speak(text: text, voice: Config.OpenAI.TTS.voice)
            print("âœ… [SPEECH] OpenAI TTS completed")
        } catch {
            print("âŒ [SPEECH] OpenAI TTS failed: \(error)")
            throw SpeechConversationError.ttsNotAvailable
        }
        
        isSpeaking = false
        currentTranscript = ""
    }
    
    // MARK: - AI Processing with Full Document Context
    
    func processUserInput(_ transcript: String) async throws -> String {
        // Check for commands before AI processing
        if checkForStopCommand(transcript) {
            return "Understood. I'll stop here."
        }
        
        if checkForInterruptCommand(transcript) {
            return "Of course."
        }
        
        // Build context including full document analysis
        do {
            let context = buildAIContext(for: transcript)
            let response = try await aiService.generateResponse(prompt: transcript, context: context)
            return response
        } catch {
            print("AI processing failed: \(error)")
            // Fallback to basic coaching response
            return try await aiService.generateCoachingResponse(prompt: transcript)
        }
    }
    
    private func buildAIContext(for transcript: String) -> AIContext {
        var documentContext = ""
        
        // Add comprehensive document context with analysis
        if let docManager = safeDocumentManager {
            let recentDocs = Array(docManager.documents.suffix(5))
            if !recentDocs.isEmpty {
                documentContext += "Available documents for reference:\n"
                
                for doc in recentDocs {
                    let fileType = doc.fileURL.pathExtension.uppercased()
                    documentContext += "\nðŸ“„ Document: \(doc.title) (\(fileType))\n"
                    
                    // Include extracted text content
                    if let extractedText = doc.extractedText, !extractedText.isEmpty {
                        documentContext += "Text Content: \(extractedText.prefix(1000))\n"
                    }
                    
                    // Include business insights
                    if !doc.businessInsights.isEmpty {
                        documentContext += "Business Insights: \(doc.businessInsights.joined(separator: "; "))\n"
                    }
                    
                    // Include action items
                    if !doc.actionItems.isEmpty {
                        documentContext += "Action Items: \(doc.actionItems.joined(separator: "; "))\n"
                    }
                    
                    documentContext += "---\n"
                }
                
                documentContext += "\nUser can ask specific questions about any of these documents and their content.\n\n"
            }
        }
        
        return AIContext(
            documentContext: documentContext,
            conversationHistory: [],
            founderProfile: nil,
            businessContext: "",
            sessionContext: "",
            personalityInsights: nil
        )
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Cleanup
    
    func cleanup() async throws {
        try await stopListening()
        await stopSpeaking()
        isSpeaking = false
        isListening = false
        isProcessingAI = false
    }
    
    nonisolated func cleanupSync() {
        Task { @MainActor in
            try? await self.cleanup()
        }
    }
    
    deinit {
        cleanupSync()
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechConversationService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                print("âš ï¸ [SPEECH] Speech recognizer became unavailable")
                errorMessage = "Speech recognition is temporarily unavailable"
            }
        }
    }
}