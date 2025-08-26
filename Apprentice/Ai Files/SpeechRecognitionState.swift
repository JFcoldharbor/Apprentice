//
//  SpeechRecognitionState.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  SpeechRecognitionState.swift
//  Stitch Executive AI
//
//  Enhanced with continuous conversation and feedback loop prevention
//  ENHANCED: Added voice commands for interrupting and stopping conversations
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
    
    // MARK: - Voice Activity Detection Configuration (Optimized for Speed)
    
    private let timeoutInterval: TimeInterval = 30.0
    private let silenceThreshold: TimeInterval = 1.5 // Reduced from 2.0 for faster response
    private let minSpeechLength: Int = 10 // Reduced from 15 for faster processing
    private let maxSpeechLength: Int = 300 // Reduced from 500 for faster responses
    
    private var timeoutTimer: Timer?
    private var silenceTimer: Timer?
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        updatePermissionStatus()
    }
    
    func setSpeechService(_ service: SpeechConversationService) {
        self.speechService = service
        
        // CRITICAL: Set up TTS completion callback to prevent feedback loop
        service.openAIVoice.onTTSCompleted = { [weak self] in
            Task { @MainActor in
                self?.resumeRecognition()
            }
        }
    }
    
    // MARK: - Wake Word Detection
    
    private func checkForWakeWord(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return wakeWords.contains { wakeWord in
            lowercased.contains(wakeWord) || lowercased == wakeWord
        }
    }
    
    private func handleWakeWordDetected(_ text: String) {
        print("ðŸ‘‹ [RECOGNITION] Wake word detected: '\(text)'")
        
        guard !conversationActive else {
            print("Conversation already active, ignoring wake word")
            return
        }
        
        conversationActive = true
        
        Task {
            await activateConversationMode()
        }
    }
    
    private func activateConversationMode() async {
        guard let speechService = speechService else { return }
        
        print("ðŸš€ [RECOGNITION] Activating conversation mode")
        
        // Provide wake word acknowledgment
        do {
            try await speechService.speak(text: "Yes? I'm listening.")
        } catch {
            print("Failed to acknowledge wake word: \(error)")
        }
        
        // Switch to full conversation mode
        if !continuousMode {
            await startContinuous()
        }
    }
    
    func startWakeWordListening() {
        print("ðŸ‘‚ [RECOGNITION] Starting wake word detection")
        isWakeWordListening = true
        conversationActive = false
        
        // Start lightweight listening for wake words only
        startRecognition(continuousMode: false)
    }
    
    // MARK: - Voice Command Detection
    
    private func checkForStopCommand(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return stopCommands.contains { command in
            lowercased.contains(command) || lowercased == command
        }
    }
    
    private func checkForInterruptCommand(_ text: String) -> Bool {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return interruptCommands.contains { command in
            lowercased.contains(command) || lowercased == command
        }
    }
    
    // MARK: - Public Interface
    
    func requestPermissions() async -> Bool {
        print("Requesting permissions...")
        
        let speechPermission = await requestSpeechPermission()
        let micPermission = await requestMicrophonePermission()
        
        let granted = speechPermission && micPermission
        permissionStatus = granted ? .authorized : .denied
        
        print("Permissions granted: \(granted)")
        return granted
    }
    
    func start() {
        startRecognition(continuousMode: false)
    }
    
    func startContinuous() async {
        guard let speechService = speechService else {
            print("Speech service not set")
            return
        }
        
        continuousMode = true
        
        // CRITICAL: Set up TTS completion callback BEFORE starting recognition
        speechService.openAIVoice.onTTSCompleted = { [weak self] in
            Task { @MainActor in
                self?.resumeRecognition()
            }
        }
        
        startRecognition(continuousMode: true)
        
        // Pause recognition for initial greeting
        pauseRecognition()
        
        // Optional greeting
        do {
            try await speechService.speak(text: "I'm ready to help. Just speak naturally and I'll respond when you're finished. Say 'stop' or 'end chat' to finish our conversation. You can also say 'Hey Boss' anytime to start a new conversation.")
            // TTS completion will automatically resume recognition
        } catch {
            print("Failed to play greeting: \(error)")
            // Resume recognition even if greeting fails
            resumeRecognition()
        }
    }
    
    func stop() {
        print("Stopping recognition...")
        
        // Clean up all audio engine resources
        cleanupAudioEngine()
        
        // Stop all timers
        stopAllTimers()
        
        // Preserve final text before cleanup
        if !recognizedText.isEmpty && finalRecognizedText.isEmpty {
            finalRecognizedText = recognizedText
            print("Preserved final text: \(finalRecognizedText)")
        }
        
        // Update state
        if recognitionState == .listening {
            recognitionState = continuousMode ? .idle : .completed
        }
        
        isListening = false
        continuousMode = false
        isProcessing = false
        isPausedForTTS = false
        isUserSpeaking = false
        
        print("Recognition stopped completely")
    }
    
    // MARK: - Core Recognition Logic with Command Detection
    
    private func startRecognition(continuousMode: Bool) {
        guard permissionStatus == .authorized else {
            print("Permissions not granted")
            recognitionState = .failed(SpeechRecognitionError.permissionDenied)
            return
        }
        
        guard !isListening else {
            print("Already listening")
            return
        }
        
        // Reset state
        recognizedText = ""
        finalRecognizedText = ""
        isUserSpeaking = false
        speechStartTime = nil
        lastSpeechTime = nil
        
        do {
            // Setup audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Setup recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                throw SpeechRecognitionError.setupFailed("Failed to create recognition request")
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false
            
            // Setup audio engine
            inputNode = audioEngine.inputNode
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            
            inputNode?.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            // Start recognition task with voice activity detection
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    self?.handleRecognitionResult(result: result, error: error)
                }
            }
            
            recognitionState = .listening
            isListening = true
            
            // Start timeout timer
            startTimeoutTimer()
            
            print("Recognition started - waiting for voice activity")
            
        } catch {
            print("Failed to start recognition: \(error)")
            recognitionState = .failed(SpeechRecognitionError.setupFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Voice Activity Detection with Wake Word and Command Processing
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        // Don't process speech if we're paused for TTS
        guard !isPausedForTTS else { return }
        
        if let result = result {
            let newText = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if newText != recognizedText && !newText.isEmpty {
                recognizedText = newText
                speechConfidence = result.bestTranscription.segments.last?.confidence ?? 0.0
                lastSpeechTime = Date()
                
                // Priority 1: Check for wake word when not in conversation mode
                if !conversationActive && checkForWakeWord(newText) {
                    handleWakeWordDetected(newText)
                    return
                }
                
                // Priority 2: Check for commands when in conversation mode
                if conversationActive {
                    if checkForInterruptCommand(newText) {
                        handleInterruptCommand(newText)
                        return
                    }
                    
                    if checkForStopCommand(newText) {
                        handleStopCommandDetected(newText)
                        return
                    }
                }
                
                // Only process normal speech if conversation is active
                if !conversationActive {
                    // In wake word mode, ignore regular speech
                    if isWakeWordListening {
                        return
                    }
                    // If not in wake word mode and not conversation active, still return
                    return
                }
                
                // Track when user starts speaking
                if !isUserSpeaking && newText.count > 3 {
                    isUserSpeaking = true
                    speechStartTime = Date()
                    print("User started speaking: \(newText)")
                }
                
                // Reset silence timer on new speech
                resetSilenceTimer()
            }
            
            // Handle final result for non-continuous mode
            if result.isFinal && !continuousMode {
                finalRecognizedText = newText
                print("Final result: \(finalRecognizedText)")
                recognitionState = .completed
                stop()
                return
            }
        }
        
        if let error = error {
            let nsError = error as NSError
            // Ignore "no speech detected" errors in continuous mode - they're normal
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 && continuousMode {
                return
            }
            if nsError.domain != "kLSRErrorDomain" || nsError.code != 301 {
                print("Recognition error: \(error)")
                if !continuousMode {
                    recognitionState = .failed(error)
                    stop()
                } else {
                    restartRecognitionIfNeeded()
                }
            }
        }
    }
    
    // MARK: - Command Handling
    
    private func handleInterruptCommand(_ text: String) {
        guard let speechService = speechService else { return }
        
        print("ðŸ›‘ [RECOGNITION] Interrupt command detected: '\(text)'")
        
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
        print("ðŸ›‘ [RECOGNITION] Stop command detected: '\(text)'")
        
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
        
        // Check if we have meaningful speech
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
        
        print("Silence detected, processing complete thought: '\(currentText)'")
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
            print("Processing with AI: '\(text)'")
            
            let aiResponse = try await speechService.processUserInput(text)
            
            if !aiResponse.isEmpty {
                print("AI responding: '\(aiResponse.prefix(50))...'")
                
                // Ensure recognition is completely paused before TTS
                ensureRecognitionPaused()
                
                try await speechService.speak(text: aiResponse)
                // TTS completion callback will resume recognition automatically
            } else {
                resumeRecognition()
            }
            
        } catch {
            print("AI processing failed: \(error)")
            resumeRecognition()
        }
        
        isProcessing = false
    }
    
    // MARK: - Optimized TTS Coordination (No Engine Destruction)
    
    private func pauseRecognition() {
        print("Pausing recognition for TTS")
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
        print("Pausing audio tap for TTS")
        
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
            print("Recognition task cancelled for TTS")
        }
    }
    
    private func resumeRecognition() {
        print("Resuming recognition after TTS")
        
        guard continuousMode else {
            print("Not in continuous mode, not resuming")
            return
        }
        
        // Always resume if we're in continuous mode
        isPausedForTTS = false
        
        // Resume with minimal delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.continuousMode {
                // Check if audio engine is still running (it should be)
                if !self.audioEngine.isRunning {
                    do {
                        // Only restart if engine actually stopped
                        try self.audioEngine.start()
                        print("Audio engine restarted")
                    } catch {
                        print("Failed to restart audio engine: \(error)")
                        self.restartRecognitionIfNeeded()
                        return
                    }
                }
                
                do {
                    try self.resumeAudioTap()
                    self.startTimeoutTimer()
                    print("Recognition resumed efficiently")
                } catch {
                    print("Failed to resume audio tap: \(error)")
                    self.restartRecognitionIfNeeded()
                }
            }
        }
    }
    
    private func resumeAudioTap() throws {
        // Ensure any existing tap is removed first
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.setupFailed("Failed to create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Reinstall tap on existing audio engine
        guard let inputNode = inputNode else {
            throw SpeechRecognitionError.setupFailed("No input node available")
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isPausedForTTS else { return }
            self.recognitionRequest?.append(buffer)
        }
        
        // Create new recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        recognitionState = .listening
        isListening = true
        print("Audio tap resumed without engine restart")
    }
    
    // MARK: - Audio Engine Cleanup (Only for full stop)
    
    private func cleanupAudioEngine() {
        print("Cleaning up audio engine")
        
        // Cancel any existing recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // End any existing recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Stop audio engine and remove all taps
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // CRITICAL: Remove tap before resetting to prevent crash
        if let inputNode = inputNode {
            inputNode.removeTap(onBus: 0)
        }
        
        // Reset the entire audio engine to clear all state
        audioEngine.reset()
        
        print("Audio engine cleaned up")
    }
    
    // MARK: - Timer Management
    
    private func startTimeoutTimer() {
        // Stop any existing timer first
        timeoutTimer?.invalidate()
        
        // In continuous mode, use a longer timeout for better user experience
        let timeout = continuousMode ? 45.0 : timeoutInterval
        
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }
        
        print("Timeout timer started: \(timeout)s")
    }
    
    private func stopAllTimers() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private func handleTimeout() {
        print("Recognition timeout")
        
        if continuousMode {
            // In continuous mode, timeout means extended silence - just restart recognition
            print("Restarting recognition after timeout in continuous mode")
            
            // Reset state and restart recognition
            clearCurrentSpeech()
            
            // Restart recognition engine
            if !audioEngine.isRunning {
                do {
                    try restartRecognitionEngine()
                    print("Recognition restarted after timeout")
                } catch {
                    print("Failed to restart after timeout: \(error)")
                    restartRecognitionIfNeeded()
                }
            } else {
                // Just restart the timeout timer
                startTimeoutTimer()
                print("Recognition timeout timer restarted")
            }
        } else {
            if !recognizedText.isEmpty {
                finalRecognizedText = recognizedText
                recognitionState = .completed
            } else {
                recognitionState = .timeout
            }
            stop()
        }
    }
    
    private func restartRecognitionIfNeeded() {
        guard continuousMode else { return }
        
        print("Restarting recognition due to interruption")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.continuousMode && !self.isPausedForTTS {
                do {
                    try self.restartRecognitionEngine()
                    print("Recognition restarted successfully")
                } catch {
                    print("Recognition restart failed: \(error)")
                    // Try again after a longer delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.continuousMode && !self.isPausedForTTS {
                            self.restartRecognitionIfNeeded()
                        }
                    }
                }
            }
        }
    }
    
    private func restartRecognitionEngine() throws {
        // CRITICAL: Completely clean up existing taps and engine state first
        cleanupAudioEngine()
        
        // Configure audio session for recording with proper sample rate
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: [])
        
        // Create new recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.setupFailed("Failed to create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Setup audio engine with proper format handling
        inputNode = audioEngine.inputNode
        
        // CRITICAL: Use the hardware's native format to prevent format mismatch
        let inputFormat = inputNode!.outputFormat(forBus: 0)
        print("Input format: \(inputFormat)")
        
        // Install tap with the native format - ensure no existing tap
        inputNode?.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isPausedForTTS else { return }
            self.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start the engine
        audioEngine.prepare()
        try audioEngine.start()
        
        print("Audio engine restarted with format: \(inputFormat)")
        
        // Start recognition task with voice activity detection
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        recognitionState = .listening
        isListening = true
    }
    
    // MARK: - Setup and Permissions
    
    private func setupSpeechRecognizer() {
        speechRecognizer?.delegate = self
        guard speechRecognizer?.isAvailable == true else {
            print("Speech recognizer not available")
            recognitionState = .failed(SpeechRecognitionError.unavailable)
            return
        }
    }
    
    private func updatePermissionStatus() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch (speechStatus, micStatus) {
        case (.authorized, .granted):
            permissionStatus = .authorized
        case (.denied, _), (_, .denied):
            permissionStatus = .denied
        case (.restricted, _), (_, .undetermined):
            permissionStatus = .restricted
        default:
            permissionStatus = .notDetermined
        }
    }
    
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && (recognitionState == .listening || continuousMode) {
                print("Speech recognizer became unavailable")
                if continuousMode {
                    restartRecognitionIfNeeded()
                } else {
                    recognitionState = .failed(SpeechRecognitionError.unavailable)
                    stop()
                }
            }
        }
    }
}

// MARK: - Speech Recognition Errors

enum SpeechRecognitionError: Error, LocalizedError {
    case permissionDenied
    case unavailable
    case timeout
    case setupFailed(String)
    case audioSessionFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone and speech recognition permissions are required"
        case .unavailable:
            return "Speech recognition is not available on this device"
        case .timeout:
            return "Speech recognition timed out"
        case .setupFailed(let reason):
            return "Speech recognition setup failed: \(reason)"
        case .audioSessionFailed:
            return "Audio session configuration failed"
        case .networkError:
            return "Network connection required for speech recognition"
        }
    }
}