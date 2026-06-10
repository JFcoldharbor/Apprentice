//
//  SpeechRecognitionState.swift
//  Stitch Executive AI
//
//  Enhanced with continuous conversation and feedback loop prevention
//  FIXED: Process captured speech on timeout instead of discarding it
//

import Foundation
import Speech
import AVFoundation

// MARK: - Speech Recognition States

enum SpeechRecognitionState: Equatable {
    case idle
    case listening
    case processing
    case completed
    case timeout
    case failed(Error)
    
    static func == (lhs: SpeechRecognitionState, rhs: SpeechRecognitionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.listening, .listening), (.processing, .processing), (.completed, .completed), (.timeout, .timeout):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - Speech Recognition Protocol

protocol SpeechRecognitionServiceLogic {
    func requestPermissions() async -> Bool
    func start()
    func stop()
    var recognitionState: SpeechRecognitionState { get }
    var recognizedText: String { get }
    var finalRecognizedText: String { get }
}

// MARK: - Enhanced Speech Recognition Service with Voice Activity Detection

@MainActor
class SpeechRecognitionService: NSObject, ObservableObject, SpeechRecognitionServiceLogic {
    
    // MARK: - Published Properties
    
    @Published var recognitionState: SpeechRecognitionState = .idle
    @Published var speechConfidence: Float = 0.0
    @Published var recognizedText: String = ""
    @Published var finalRecognizedText: String = ""
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var isListening: Bool = false
    
    // MARK: - Voice Activity Detection Properties (Copilot-style)
    
    @Published var continuousMode: Bool = false
    @Published var isProcessing: Bool = false
    @Published var isPausedForTTS: Bool = false
    @Published var isUserSpeaking: Bool = false
    
    // MARK: - Voice Commands for Control
    
    private let wakeWords = ["hey boss", "hey bos", "a boss", "boss"]  // Multiple variants for recognition accuracy
    private let stopCommands = ["stop", "end chat", "that's all for now", "thank you", "goodbye", "end conversation", "pause", "stop listening"]
    private let interruptCommands = ["wait", "hold on", "stop talking", "quiet", "interrupt", "pause ai"]
    
    // MARK: - Wake Word Detection State
    
    @Published var isWakeWordListening = false
    @Published var conversationActive = false
    
    // MARK: - Dependencies
    
    private var speechService: SpeechConversationService?
    
    // MARK: - Private Properties
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var inputNode: AVAudioInputNode?
    
    // MARK: - Timing Configuration
    
    private let timeoutInterval: TimeInterval = 45.0 // Overall timeout
    private let silenceThreshold: TimeInterval = 2.5 // Silence detection
    private let minSpeechLength: Int = 3  // Minimum characters to process
    private let maxSpeechLength: Int = 1000 // Prevent processing overly long rambling
    
    // MARK: - Timer Management
    
    private var timeoutTimer: Timer?
    private var silenceTimer: Timer?
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Public Interface
    
    func setSpeechService(_ service: SpeechConversationService) {
        self.speechService = service
    }
    
    func requestPermissions() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self.permissionStatus = .authorized
                        continuation.resume(returning: true)
                    case .denied:
                        self.permissionStatus = .denied
                        continuation.resume(returning: false)
                    case .restricted:
                        self.permissionStatus = .restricted
                        continuation.resume(returning: false)
                    case .notDetermined:
                        self.permissionStatus = .notDetermined
                        continuation.resume(returning: false)
                    @unknown default:
                        self.permissionStatus = .denied
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Wake Word Listening (Optimized)
    
    func startWakeWordListening() {
        print("🔍 [RECOGNITION] Starting wake word listening...")
        isWakeWordListening = true
        conversationActive = false
        continuousMode = true
        start()
    }
    
    // MARK: - Continuous Conversation Mode
    
    func startContinuous(skipGreeting: Bool = false) {
        print("🎙️ [RECOGNITION] Starting continuous mode without duplicate greeting")
        continuousMode = true
        conversationActive = true
        isWakeWordListening = false
        
        start()
    }
    
    // MARK: - Core Recognition Methods
    
    func start() {
        guard !isListening else { return }
        guard speechRecognizer?.isAvailable == true else {
            print("❌ [RECOGNITION] Speech recognizer not available")
            recognitionState = .failed(SpeechConversationError.speechRecognitionNotAvailable)
            return
        }
        
        // Clean up any existing resources
        cleanupAudioEngine()
        
        do {
            try startAudioEngine()
            recognitionState = .listening
            isListening = true
            print("✅ [RECOGNITION] Started successfully")
        } catch {
            print("❌ [RECOGNITION] Failed to start: \(error)")
            recognitionState = .failed(error)
        }
    }
    
    func stop() {
        print("🛑 [RECOGNITION] Stopping...")
        
        isListening = false
        continuousMode = false
        conversationActive = false
        isWakeWordListening = false
        
        stopAllTimers()
        cleanupAudioEngine()
        
        recognitionState = .idle
        clearCurrentSpeech()
    }
    
    // MARK: - Audio Engine Setup
    
    private func startAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        self.inputNode = inputNode
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechConversationError.audioEngineError
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        recognitionRequest.requiresOnDeviceRecognition = false

        // Remove any existing tap first — a second tap on the same bus throws
        // 'nullptr == Tap()' and crashes the app.
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        recognitionState = .listening
    }
    
    // MARK: - Timer Management
    
    private func startTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }
        print("Timeout timer started: \(timeoutInterval)s")
    }
    
    // MARK: - FIXED: Process speech on timeout instead of discarding
    
    private func handleTimeout() {
        print("⏰ [RECOGNITION] Recognition timeout")
        
        // CRITICAL FIX: Process any captured speech before timeout
        let currentText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !currentText.isEmpty && currentText.count >= minSpeechLength {
            print("📝 [RECOGNITION] Processing captured speech on timeout: '\(currentText.prefix(50))...'")
            processUserSpeech(currentText)
            return
        }
        
        if continuousMode {
            // In continuous mode, just reset and keep listening
            print("🔄 [RECOGNITION] Resetting for continuous mode")
            clearCurrentSpeech()
            startTimeoutTimer() // Restart timeout
        } else {
            recognitionState = .timeout
            stop()
        }
    }
    
    private func stopAllTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    // MARK: - Audio Engine Management
    
    private func cleanupAudioEngine() {
        print("🧹 [RECOGNITION] Cleaning up audio engine resources")
        
        // Stop recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Remove audio taps
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        inputNode = nil
    }
    
    // MARK: - Wake Word Detection
    
    private func checkForWakeWord(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        return wakeWords.contains { lowercaseText.contains($0) }
    }
    
    private func handleWakeWordDetected(_ text: String) {
        print("👋 [RECOGNITION] Wake word detected: '\(text)'")
        
        Task {
            guard let speechService = speechService else { return }
            
            // Switch to conversation mode
            conversationActive = true
            isWakeWordListening = false
            
            // Provide greeting
            let greeting = generatePersonalizedGreeting()
            try await speechService.speak(text: greeting)
            
            // Switch to continuous conversation mode after greeting
            startContinuous(skipGreeting: true)
        }
    }
    
    private func generatePersonalizedGreeting() -> String {
        let greetings = [
            "Good to see you! What's on your mind?",
            "Hello! How can I help you today?",
            "I'm here. What would you like to discuss?",
            "Ready to chat. What's happening?"
        ]
        return greetings.randomElement() ?? "Hello! How can I help?"
    }
    
    // MARK: - Command Detection
    
    private func checkForStopCommand(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        return stopCommands.contains { lowercaseText.contains($0) }
    }
    
    private func checkForInterruptCommand(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        return interruptCommands.contains { lowercaseText.contains($0) }
    }
    
    // MARK: - Recognition Result Handling
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Don't process speech if we're paused for TTS
        guard !isPausedForTTS else { return }
        
        if let result = result {
            let newText = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if newText != recognizedText && !newText.isEmpty {
                recognizedText = newText
                speechConfidence = result.bestTranscription.segments.last?.confidence ?? 0.0
                
                // Track speech activity for voice activity detection
                if !isUserSpeaking {
                    isUserSpeaking = true
                    speechStartTime = Date()
                    print("🎙️ User started speaking: '\(newText.prefix(30))...'")
                }
                
                lastSpeechTime = Date()
                
                // Check for wake words if in wake word listening mode
                if isWakeWordListening && checkForWakeWord(newText) {
                    handleWakeWordDetected(newText)
                    return
                }
                
                // Reset silence timer whenever we get new speech
                resetSilenceTimer()
            }
            
            // Handle final results immediately for better responsiveness
            if result.isFinal {
                silenceTimer?.invalidate()
                handleSilenceDetected()
            }
        }
        
        // FIXED: Handle recognition errors without aggressive restart
        if let error = error {
            let nsError = error as NSError
            
            // Ignore common "no speech detected" errors - these are NORMAL
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                print("ℹ️ [RECOGNITION] No speech timeout (normal)")
                // In continuous mode, just reset and continue - don't restart
                if continuousMode {
                    clearCurrentSpeech()
                    startTimeoutTimer() // Reset timeout
                }
                return
            }
            
            // Ignore cancellation errors (these happen during normal operation)
            if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                print("ℹ️ [RECOGNITION] Task cancelled (normal)")
                return
            }
            
            // For ANY other error, just stop - don't restart
            print("❌ [RECOGNITION] Unhandled error, stopping: \(error)")
            stop()
        }
    }
    
    // MARK: - Command Handling
    
    private func handleInterruptCommand(_ text: String) {
        guard let speechService = speechService else { return }
        
        print("⚡ [RECOGNITION] Interrupt command detected: '\(text)'")
        
        Task {
            // Immediately stop any AI speech
            await speechService.stopSpeaking()
            
            // Clear current processing
            clearCurrentSpeech()
            
            // Resume listening for next input
            if continuousMode {
                resumeRecognition()
            }
        }
    }
    
    private func handleStopCommandDetected(_ text: String) {
        print("⚡ [RECOGNITION] Stop command detected: '\(text)'")
        
        Task {
            let stopResponse = "Understood. I'm here whenever you need me."
            
            // Stop listening and provide acknowledgment
            if let speechService = speechService {
                do {
                    _ = try await speechService.stopListening()
                    try await speechService.speak(text: stopResponse)
                } catch {
                    print("Error in stop command handling: \(error)")
                }
            }
        }
        
        // End conversation mode and return to wake word listening
        conversationActive = false
        continuousMode = false
        stop()
        
        // Automatically return to wake word listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startWakeWordListening()
        }
    }
    
    private func resetSilenceTimer() {
        guard !isPausedForTTS else { return }
        
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSilenceDetected()
            }
        }
    }
    
    private func handleSilenceDetected() {
        guard continuousMode && isUserSpeaking && !isPausedForTTS && conversationActive else {
            // If not in conversation mode, don't process silence as meaningful speech
            if !conversationActive {
                clearCurrentSpeech()
            }
            return
        }
        
        let currentText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for commands before processing with AI
        if checkForStopCommand(currentText) {
            handleStopCommandDetected(currentText)
            return
        }
        
        if checkForInterruptCommand(currentText) {
            handleInterruptCommand(currentText)
            return
        }
        
        // FIXED: Lower minimum speech length for better responsiveness
        guard currentText.count >= minSpeechLength else {
            print("Speech too short, ignoring: '\(currentText)'")
            clearCurrentSpeech()
            return
        }
        
        // Prevent processing overly long rambling
        if currentText.count > maxSpeechLength {
            let truncated = String(currentText.prefix(maxSpeechLength))
            print("Speech too long, truncating")
            processUserSpeech(truncated)
            return
        }
        
        print("🔇 [RECOGNITION] Silence detected, processing complete thought: '\(currentText.prefix(50))...'")
        processUserSpeech(currentText)
    }
    
    private func processUserSpeech(_ text: String) {
        guard let speechService = speechService else { return }
        guard !isProcessing && !isPausedForTTS else { return }
        
        finalRecognizedText = text
        isUserSpeaking = false
        
        Task {
            await processWithAI(text, speechService: speechService)
        }
        
        clearCurrentSpeech()
    }
    
    private func clearCurrentSpeech() {
        recognizedText = ""
        isUserSpeaking = false
        speechStartTime = nil
        lastSpeechTime = nil
    }
    
    private func processWithAI(_ text: String, speechService: SpeechConversationService) async {
        isProcessing = true
        
        // CRITICAL: Pause recognition completely before AI processing
        pauseRecognition()
        
        // Lightweight pause: just remove tap, keep engine running
        stopAudioEngineTemporarily()
        
        do {
            print("🤖 [RECOGNITION] Processing with AI: '\(text.prefix(50))...'")
            
            let aiResponse = try await speechService.processUserInput(text)
            
            if !aiResponse.isEmpty {
                print("🗣️ [RECOGNITION] AI responding: '\(aiResponse.prefix(50))...'")
                
                // Ensure recognition is completely paused before TTS
                ensureRecognitionPaused()
                
                try await speechService.speak(text: aiResponse)
                // TTS completion callback will resume recognition automatically
            } else {
                resumeRecognition()
            }
            
        } catch {
            print("❌ [RECOGNITION] AI processing failed: \(error)")
            resumeRecognition()
        }
        
        isProcessing = false
    }
    
    // MARK: - Optimized TTS Coordination (No Engine Destruction)
    
    private func pauseRecognition() {
        print("⏸️ [RECOGNITION] Pausing recognition for TTS")
        isPausedForTTS = true
        
        // Stop all timers immediately
        silenceTimer?.invalidate()
        silenceTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        // Clear any current speech to prevent processing TTS audio
        clearCurrentSpeech()
        
        // Important: Don't process any new audio input
        recognizedText = ""
        isUserSpeaking = false
    }
    
    private func stopAudioEngineTemporarily() {
        // Lightweight pause: just remove tap, keep engine running
        print("🎤 [RECOGNITION] Pausing audio tap for TTS")
        
        // Remove tap but keep engine alive
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        // Cancel recognition task temporarily
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // End current request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }
    
    private func ensureRecognitionPaused() {
        // Double-check that recognition is completely paused
        isPausedForTTS = true
        recognizedText = ""
        isUserSpeaking = false
        
        // Cancel any ongoing recognition task temporarily
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
            print("🛑 [RECOGNITION] Recognition task cancelled for TTS")
        }
    }
    
    private func resumeRecognition() {
        print("▶️ [RECOGNITION] Resuming recognition after TTS")
        
        guard continuousMode else {
            print("❌ [RECOGNITION] Not in continuous mode, not resuming")
            return
        }
        
        // Always resume if we're in continuous mode
        isPausedForTTS = false
        
        // Resume with minimal delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.continuousMode {
                // Check if audio engine is still running
                if !self.audioEngine.isRunning {
                    print("🔄 [RECOGNITION] Audio engine stopped, restarting for continuous mode")
                    self.start()
                } else {
                    print("✅ [RECOGNITION] Recognition resumed efficiently")
                    // Just restart the recognition components
                    do {
                        try self.startAudioEngine()
                        self.startTimeoutTimer()
                    } catch {
                        print("❌ [RECOGNITION] Failed to resume: \(error)")
                        // Fallback: full restart
                        self.start()
                    }
                }
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("Speech recognizer availability changed: \(available)")
        if !available && isListening {
            stop()
        }
    }
}
