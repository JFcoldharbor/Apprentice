//
//  SpeechConversationServiceProtocol.swift
//  Stitch Executive AI
//
//  FIXED: Complete speech service with memory integration and proper greeting/processing
//

import Foundation
import Speech
import AVFoundation
import SwiftUI
import EventKit

// MARK: - Speech Conversation Protocol (Fixed for Swift 6)

protocol SpeechConversationServiceProtocol: Sendable {
    func startListening() async throws
    func stopListening() async throws -> String
    func speak(text: String) async throws
    func requestPermissions() async throws
    
    // Swift 6 Fix: Make protocol properties @MainActor isolated
    @MainActor var isListening: Bool { get }
    @MainActor var isSpeaking: Bool { get }
    @MainActor var hasPermissions: Bool { get }
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
    
    // MARK: - Active Listening Configuration
    
    @Published var isActiveListening = false
    @Published var skipInstructionMessages = false // FIXED: Changed to false for greetings
    
    // Simple wake words for basic functionality
    private let wakeWords = ["hey boss", "hey coach", "aria"]
    private let interruptWords = ["stop", "wait", "hold on", "pause"]
    
    // MARK: - Speech Recognition Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - AI Service Integration
    
    private let aiService = RealAIService()
    let openAIVoice = OpenAIVoiceService()
    
    // MARK: - Calendar Integration for Smart Greetings
    
    private let eventStore = EKEventStore()
    private var calendarEvents: [EKEvent] = []
    
    // MARK: - Document Context Integration
    
    private var safeDocumentManager: SafeDocumentManager?
    
    func setSafeDocumentManager(_ manager: SafeDocumentManager) {
        self.safeDocumentManager = manager
    }
    
    func setDocumentManager(_ manager: SafeDocumentManager) {
        self.safeDocumentManager = manager
    }
    
    // MARK: - FIXED: Simple Active Listening with Greeting
    
    func startActiveListening() async {
        print("🎤 [ACTIVE] Starting simple active listening mode...")
        isActiveListening = true
        
        // FIXED: Always give greeting (ignore skipInstructionMessages for active listening)
        if !isSpeaking {
            let greeting = await generateContextualWelcomeMessage()
            print("👋 [SPEECH] Playing greeting: '\(greeting)'")
            do {
                try await speak(text: greeting)
                // Small delay after greeting before starting to listen
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            } catch {
                print("❌ [SPEECH] Failed to play greeting: \(error)")
            }
        }
        
        try? await startListening()
    }
    
    // MARK: - ENHANCED: Smart Contextual Greeting System with Personal Insights
    
    private func generateContextualWelcomeMessage() async -> String {
        // Get founder profile for personalization
        if let profile = FounderProfileManager.shared.founderProfile {
            return await generateSmartPersonalizedWelcome(profile: profile)
        } else {
            return await generateSmartWelcome()
        }
    }
    
    private func generateSmartPersonalizedWelcome(profile: FounderProfile) async -> String {
        let timeOfDay = getTimeOfDayGreeting()
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Load calendar events for context
        await loadRecentCalendarEvents()
        
        // Generate contextual greeting based on time and data
        let greeting = await buildContextualGreeting(
            profile: profile,
            timeOfDay: timeOfDay,
            hour: hour
        )
        
        return greeting
    }
    
    private func buildContextualGreeting(profile: FounderProfile, timeOfDay: String, hour: Int) async -> String {
        let name = profile.founderName
        
        // MORNING GREETINGS (5 AM - 12 PM)
        if hour >= 5 && hour < 12 {
            let morningGreetings = [
                "Hey \(name), good morning! How did you sleep?",
                "Good morning, \(name). Not sure if you're a big coffee person - have you had your morning brew?",
                "Morning, \(name)! I see you're an early riser. Ready to tackle the day?",
                "Hey \(name), good morning! How are you feeling about today's priorities?",
                "Good morning, \(name). Coffee first or straight to business today?"
            ]
            
            // Add calendar-specific morning context
            if let nextMeeting = getNextMeeting() {
                let timeUntil = getTimeUntilEvent(nextMeeting)
                if timeUntil <= 120 { // Within 2 hours
                    return "Good morning, \(name)! I see you have \(nextMeeting.title) coming up in \(timeUntil) minutes. How are you feeling about it?"
                }
            }
            
            return morningGreetings.randomElement() ?? "Good morning, \(name)!"
        }
        
        // LUNCH TIME GREETINGS (12 PM - 2 PM)
        else if hour >= 12 && hour < 14 {
            let lunchGreetings = [
                "Hey \(name), it's around lunch time I see. Have you had lunch yet?",
                "Good afternoon, \(name)! Taking a lunch break or powering through?",
                "Afternoon, \(name)! How's your energy level - need a lunch recharge?",
                "Hey \(name), lunch time! Are you one of those founders who forgets to eat?",
                "Good afternoon, \(name). Grabbing lunch or too busy saving the world?"
            ]
            
            return lunchGreetings.randomElement() ?? "Good afternoon, \(name)!"
        }
        
        // AFTERNOON GREETINGS (2 PM - 6 PM)
        else if hour >= 14 && hour < 18 {
            // Check for recent meetings to reference
            if let recentMeeting = getRecentMeeting() {
                let meetingGreetings = [
                    "Good afternoon, \(name)! Based on your calendar, how did that \(formatMeetingTime(recentMeeting)) meeting with \(extractMeetingContact(recentMeeting)) go?",
                    "Afternoon, \(name)! I see you just wrapped up \(recentMeeting.title). How did it go?",
                    "Hey \(name), how was that \(formatMeetingTime(recentMeeting)) call? Worth your time?",
                    "Good afternoon, \(name)! Just saw you finished \(recentMeeting.title) - any breakthroughs?"
                ]
                
                return meetingGreetings.randomElement() ?? "Good afternoon, \(name)!"
            }
            
            let afternoonGreetings = [
                "Good afternoon, \(name)! How's your energy holding up?",
                "Afternoon, \(name)! What's been the highlight of your day so far?",
                "Hey \(name), afternoon check-in - how are we doing?",
                "Good afternoon, \(name)! Ready for the afternoon push?"
            ]
            
            return afternoonGreetings.randomElement() ?? "Good afternoon, \(name)!"
        }
        
        // EVENING GREETINGS (6 PM - 10 PM)
        else if hour >= 18 && hour < 22 {
            let eveningGreetings = [
                "Good evening, \(name)! How was your day? Any wins to celebrate?",
                "Evening, \(name)! Winding down or still in work mode?",
                "Hey \(name), good evening! Time to decompress or one more sprint?",
                "Good evening, \(name). How are you feeling about today's progress?",
                "Evening, \(name)! Ready to shift gears or still grinding?"
            ]
            
            return eveningGreetings.randomElement() ?? "Good evening, \(name)!"
        }
        
        // LATE NIGHT/EARLY MORNING (10 PM - 5 AM)
        else {
            let lateGreetings = [
                "Hey \(name), burning the midnight oil? What's keeping you up?",
                "Late night, \(name)! Everything okay or just can't turn off the founder brain?",
                "Hey \(name), night owl mode activated? What's on your mind?",
                "Working late, \(name)? Sometimes the best ideas come after hours.",
                "Hey \(name), still up? Must be something important brewing."
            ]
            
            return lateGreetings.randomElement() ?? "Hey \(name)!"
        }
    }
    
    // MARK: - Calendar Integration Helper Methods
    
    private func loadRecentCalendarEvents() async {
        do {
            // Request calendar permissions if needed
            let status = await requestCalendarPermissions()
            guard status == .authorized else { return }
            
            // Load today's events
            let startDate = Calendar.current.startOfDay(for: Date())
            guard let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) else { return }
            
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            calendarEvents = eventStore.events(matching: predicate)
            
            print("📅 Loaded \(calendarEvents.count) upcoming meetings")
            
        } catch {
            print("Failed to load calendar events: \(error)")
        }
    }
    
    private func requestCalendarPermissions() async -> EKAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { granted, _ in
                    let status: EKAuthorizationStatus = granted ? .authorized : .denied
                    continuation.resume(returning: status)
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, _ in
                    // iOS 16 fallback
                    let status: EKAuthorizationStatus = granted ? .authorized : .denied
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    private func getNextMeeting() -> EKEvent? {
        let now = Date()
        return calendarEvents
            .filter { $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
    
    private func getRecentMeeting() -> EKEvent? {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200) // 2 hours ago
        
        return calendarEvents
            .filter { $0.endDate > twoHoursAgo && $0.endDate < now }
            .sorted { $0.endDate > $1.endDate }
            .first
    }
    
    private func getTimeUntilEvent(_ event: EKEvent) -> Int {
        let timeInterval = event.startDate.timeIntervalSinceNow
        return max(0, Int(timeInterval / 60)) // Convert to minutes
    }
    
    private func formatMeetingTime(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: event.startDate)
    }
    
    private func extractMeetingContact(_ event: EKEvent) -> String {
        // Try to extract a name from the title or attendees
        let title = event.title ?? ""
        
        // Look for "with [name]" pattern
        if let range = title.range(of: "with ", options: .caseInsensitive) {
            let afterWith = String(title[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = afterWith.components(separatedBy: " ").first ?? "them"
            return name
        }
        
        // Look for attendees
        if let attendees = event.attendees, !attendees.isEmpty {
            if let firstAttendee = attendees.first {
                return firstAttendee.name ?? "your contact"
            }
        }
        
        // Fallback to generic
        return "your contact"
    }
    
    private func generateSmartWelcome() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Contextual greetings for non-profiled users
        if hour >= 5 && hour < 12 {
            return "Good morning! How did you sleep?"
        } else if hour >= 12 && hour < 14 {
            return "Good afternoon! Have you had lunch yet?"
        } else if hour >= 14 && hour < 18 {
            return "Good afternoon! How's your day going?"
        } else if hour >= 18 && hour < 22 {
            return "Good evening! How was your day?"
        } else {
            return "Hey there! Working late tonight?"
        }
    }
    
    private func getTimeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Hey" // Late night/early morning
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Permission Handling (Fixed iOS 17 deprecations)
    
    func requestPermissions() async throws {
        // Request speech recognition permission (Fixed iOS 17)
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            throw SpeechConversationError.speechRecognitionNotAuthorized
        }
        
        // Request microphone permission (Fixed iOS 17)
        let microphonePermission = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        guard microphonePermission else {
            throw SpeechConversationError.microphonePermissionDenied
        }
        
        hasPermissions = true
    }
    
    // MARK: - Core Speech Recognition
    
    func startListening() async throws {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Cancel previous recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechConversationError.speechRecognitionNotAvailable
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechConversationError.recognitionTaskFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Remove any existing tap first — installing a second tap on the same
        // bus throws 'nullptr == Tap()' and crashes the app.
        inputNode.removeTap(onBus: 0)

        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
        currentTranscript = ""
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        print("🎤 [SPEECH] Started listening...")
    }
    
    // MARK: - Speech Processing Timer
    private var speechProcessingTimer: Timer?
    private var lastTranscriptTime: Date?
    private let speechTimeoutInterval: TimeInterval = 3.0 // 3 seconds of silence
    
    // MARK: - FIXED: Recognition Result Handling with Manual Timeout
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            let nsError = error as NSError
            
            // Ignore common "No speech detected" errors - these are NORMAL
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                print("ℹ️ [SPEECH] No speech timeout (normal)")
                return
            }
            
            // Ignore cancellation errors (normal during cleanup)
            if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                print("ℹ️ [SPEECH] Task cancelled (normal)")
                return
            }
            
            print("❌ [SPEECH] Recognition error: \(error)")
            errorMessage = error.localizedDescription
            return
        }
        
        guard let result = result else { return }
        
        let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousTranscript = currentTranscript
        currentTranscript = transcript
        
        print("🗣️ [SPEECH] Transcript: '\(transcript)'")
        
        // Update last transcript time for manual timeout
        if transcript != previousTranscript && !transcript.isEmpty {
            lastTranscriptTime = Date()
            startSpeechProcessingTimer()
        }
        
        // FIXED: Process final results immediately and properly
        if result.isFinal && !transcript.isEmpty {
            print("✅ [SPEECH] Final result received, processing: '\(transcript)'")
            cancelSpeechProcessingTimer()
            processTranscript(transcript)
        }
    }
    
    // MARK: - Manual Speech Processing Timer
    
    private func startSpeechProcessingTimer() {
        // Cancel existing timer
        speechProcessingTimer?.invalidate()
        
        // Start new timer for manual timeout
        speechProcessingTimer = Timer.scheduledTimer(withTimeInterval: speechTimeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleSpeechTimeout()
            }
        }
    }
    
    private func cancelSpeechProcessingTimer() {
        speechProcessingTimer?.invalidate()
        speechProcessingTimer = nil
    }
    
    private func handleSpeechTimeout() {
        let transcript = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !transcript.isEmpty {
            print("⏰ [SPEECH] Manual timeout triggered, processing: '\(transcript.prefix(50))...'")
            processTranscript(transcript)
        }
    }
    
    // MARK: - Unified Transcript Processing
    
    private func processTranscript(_ transcript: String) {
        Task {
            // Stop listening first
            do {
                _ = try await stopListening()
                print("🛑 [SPEECH] Stopped listening, now processing with AI")
                
                // Process with enhanced AI (memory integration)
                let response = await processUserInputWithMemory(transcript)
                
                // Speak the response
                if !response.isEmpty {
                    print("🎤 [SPEECH] AI Response: '\(response.prefix(50))...'")
                    try await speak(text: response)
                } else {
                    print("❌ [SPEECH] Empty response from AI")
                }
                
                // FIXED: Restart listening after response for continuous conversation
                if isActiveListening {
                    print("🔄 [SPEECH] Restarting listening for continuous conversation")
                    try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
                    try await startListening()
                }
                
            } catch {
                print("❌ [SPEECH] Error in processing: \(error)")
                // Fallback: just restart listening
                if isActiveListening {
                    try? await startListening()
                }
            }
        }
    }
    
    func stopListening() async throws -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
        
        let transcript = currentTranscript
        currentTranscript = ""
        
        print("🛑 [SPEECH] Stopped listening. Transcript: '\(transcript)'")
        
        return transcript
    }
    
    // MARK: - Simple AI Speaking
    
    func speak(text: String) async throws {
        guard !text.isEmpty else { return }
        
        isSpeaking = true
        
        print("🔊 [SPEECH] Speaking: '\(text.prefix(50))...'")
        
        do {
            try await openAIVoice.speak(text: text)
            print("✅ [SPEECH] Finished speaking")
        } catch {
            print("❌ [SPEECH] TTS error: \(error)")
            throw error
        }
        
        isSpeaking = false
    }
    
    // MARK: - OPTIMIZED: Fast processUserInput with Smart Fallback
    
    func processUserInputWithMemory(_ transcript: String) async -> String {
        print("🤖 [AI] Processing user input with memory: '\(transcript)'")
        
        isProcessingAI = true
        
        // Handle stop commands immediately
        if checkForStopCommand(transcript) {
            isProcessingAI = false
            isActiveListening = false
            if let profile = FounderProfileManager.shared.founderProfile {
                return "Thanks, \(profile.founderName). I'm here whenever you need me."
            } else {
                return "Thanks. I'm here whenever you need me."
            }
        }
        
        // Handle interruption commands immediately
        if checkForInterruptCommand(transcript) {
            isProcessingAI = false
            return "Yes, what can I help you with?"
        }
        
        // Brain repoint: every turn now goes through Claude (via the Firebase
        // proxy) grounded in the founder's REAL note memory (CoachContext) — not
        // the legacy empty-context OpenAI path. The orb's STT/TTS and visuals are
        // unchanged; only the response generator is upgraded.
        return await processWithCoachBrain(transcript)
    }

    // MARK: - Coach Brain (Claude + note memory)

    private func processWithCoachBrain(_ transcript: String) async -> String {
        do {
            var system = CoachPersona.system

            // Founder profile (mirrors the legacy fast-prompt fields).
            if let profile = FounderProfileManager.shared.founderProfile {
                system += """


                FOUNDER:
                - Name: \(profile.founderName)
                - Business: \(profile.businessName ?? "Startup")
                - Industry: \(profile.industry)
                """
            }

            // Relevance-ranked context from the founder's actual notes + open actions.
            let memory = CoachContext.build(query: transcript, context: NoteStore.mainContext)
            system += "\n\n" + memory

            let reply = try await AIClient.shared.chatText(
                system: system,
                messages: [AIChatMessage(role: "user", content: transcript)],
                tier: .standard
            )

            isProcessingAI = false
            print("✅ [AI] Coach-brain response generated: '\(reply.prefix(50))...'")
            return reply.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("❌ [AI] Coach-brain failed: \(error)")
            isProcessingAI = false
            return generateQuickFallbackResponse(for: transcript)
        }
    }
    
    // MARK: - Fast Processing with Document Context
    
    private func processWithFastResponse(_ transcript: String) async -> String {
        do {
            // FIXED: Include document context in fast processing
            let prompt = await buildFastPromptWithDocuments(transcript)
            let response = try await RealAIService().generateCoachingResponse(prompt: prompt)
            
            isProcessingAI = false
            print("✅ [AI] Fast response with documents generated: '\(response.prefix(50))...'")
            return response
            
        } catch {
            print("❌ [AI] Fast processing failed: \(error)")
            isProcessingAI = false
            return generateQuickFallbackResponse(for: transcript)
        }
    }
    
    // MARK: - Enhanced Fast Prompts with Document Integration
    
    private func buildFastPromptWithDocuments(_ transcript: String) async -> String {
        var context = ""
        
        // Add founder profile context
        if let profile = FounderProfileManager.shared.founderProfile {
            context += """
            Founder: \(profile.founderName)
            Business: \(profile.businessName ?? "Startup")
            Industry: \(profile.industry)
            
            """
        }
        
        // FIXED: Add document context for fast processing
        if let documentManager = safeDocumentManager, !documentManager.documents.isEmpty {
            // Use basic document context (non-async) for speed
            let docContext = buildQuickDocumentContext(from: documentManager.documents)
            if !docContext.isEmpty {
                context += "\nDOCUMENTS AVAILABLE:\n\(docContext)\n"
            }
        }
        
        return """
        Context: \(context)
        User input: "\(transcript)"
        
        Respond as an executive AI coach. Be direct and conversational. Keep responses under 60 words.
        If the user mentions documents, reference the document information above.
        Focus on being helpful and actionable.
        """
    }
    
    private func buildQuickDocumentContext(from documents: [ProcessedDocument]) -> String {
        let recentDocs = Array(documents.suffix(2)) // Only latest 2 docs for speed
        guard !recentDocs.isEmpty else { return "" }
        
        var context = ""
        for doc in recentDocs {
            context += "📄 \(doc.title): "
            
            if !doc.businessInsights.isEmpty {
                context += "Key insights - \(doc.businessInsights.prefix(2).joined(separator: "; ")). "
            }
            
            if !doc.actionItems.isEmpty {
                context += "Actions - \(doc.actionItems.prefix(2).joined(separator: "; ")). "
            }
            
            context += "\n"
        }
        
        return context.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Full Memory Processing for Complex Queries
    
    private func processWithFullMemory(_ transcript: String) async -> String {
        do {
            let sessionManager = SessionManager.shared
            let profileManager = FounderProfileManager.shared
            let documentManager = safeDocumentManager ?? SafeDocumentManager()
            let realAIService = RealAIService()
            
            let conversationEngine = ConversationEngine(
                realAIService: realAIService,
                documentManager: documentManager,
                profileManager: profileManager,
                sessionManager: sessionManager
            )
            
            // Add timeout for memory processing
            let response = try await withTimeout(seconds: 8.0) {
                try await conversationEngine.processUserInputSimple(transcript)
            }
            
            isProcessingAI = false
            print("✅ [AI] Memory-enhanced response generated: '\(response.prefix(50))...'")
            return response
            
        } catch {
            print("❌ [AI] Memory processing failed or timed out: \(error)")
            isProcessingAI = false
            
            // Fallback to fast processing
            return await processWithFastResponse(transcript)
        }
    }
    
    // MARK: - Enhanced Fallback Responses
    
    private func generateQuickFallbackResponse(for transcript: String) -> String {
        let lower = transcript.lowercased()
        
        // Check for document-related queries
        if lower.contains("document") || lower.contains("file") || lower.contains("upload") {
            let docCount = safeDocumentManager?.documents.count ?? 0
            if docCount > 0 {
                return "I have \(docCount) documents available. What would you like to know about them?"
            } else {
                return "I don't see any documents uploaded yet. Would you like to upload some for analysis?"
            }
        }
        
        if lower.contains("email") {
            return "Email management is crucial for productivity. What specific email challenge are you facing?"
        } else if lower.contains("typical") || lower.contains("understand") {
            return "I understand. What would you like to focus on or discuss further?"
        } else if lower.contains("check") || lower.contains("look") {
            return "That sounds like a good approach. What are you hoping to find or accomplish?"
        } else {
            return "I'm here to help. What's your main priority right now?"
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
                throw SpeechConversationError.aiProcessingFailed
            }
            
            // Return first completed result
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Keep existing processUserInput for backward compatibility
    
    func processUserInput(_ transcript: String) async -> String {
        // Route to the enhanced version with memory
        return await processUserInputWithMemory(transcript)
    }
    
    // MARK: - FIXED: Fallback Processing
    
    private func processWithFallback(_ transcript: String) async -> String {
        print("🔄 [AI] Using fallback processing for: '\(transcript)'")
        
        do {
            let realAIService = RealAIService()
            let prompt = buildSimplePrompt(transcript)
            let response = try await realAIService.generateCoachingResponse(prompt: prompt)
            print("✅ [AI] Fallback response: '\(response.prefix(50))...'")
            return response
        } catch {
            print("❌ [AI] Fallback failed: \(error)")
            
            // Last resort - contextual response
            if transcript.lowercased().contains("aria") || transcript.lowercased().contains("hey") {
                return "Yes, I'm here. What would you like to discuss?"
            } else if transcript.lowercased().contains("graham") || transcript.lowercased().contains("meeting") {
                return "I'm searching my memory for information about that meeting. Can you give me more details about what you'd like to know?"
            } else {
                return "I heard you say '\(transcript.prefix(20))...'. How can I help you with that?"
            }
        }
    }
    
    private func buildSimplePrompt(_ transcript: String) -> String {
        var context = ""
        
        // Add founder profile context
        if let profile = FounderProfileManager.shared.founderProfile {
            context += """
            Founder: \(profile.founderName)
            Business: \(profile.businessName ?? "Startup")
            Industry: \(profile.industry)
            Stage: \(profile.businessStage.rawValue)
            
            """
        }
        
        // Add session context for memory-like responses
        let recentSessions = SessionManager.shared.sessions
        if !recentSessions.isEmpty {
            context += "Recent Sessions: \(recentSessions.count) executive sessions recorded\n"
            
            // Add some recent session titles for context
            let recentTitles = recentSessions.suffix(3).map { $0.title }
            if !recentTitles.isEmpty {
                context += "Recent topics: \(recentTitles.joined(separator: ", "))\n"
            }
        }
        
        return """
        Context: \(context)
        User input: "\(transcript)"
        
        Respond as an executive AI coach. Be direct and actionable. Keep responses under 100 words.
        If the user is asking about previous meetings or conversations, reference the session context above and provide helpful information.
        If asking about specific people or meetings, acknowledge the request and provide any relevant details from the context.
        """
    }
    
    // MARK: - BACKWARD COMPATIBILITY: Legacy processWithAI method
    
    func processWithAI(_ transcript: String) async throws -> String {
        print("🤖 [AI] Legacy processWithAI called: '\(transcript)'")
        
        // Route to the new enhanced method
        let response = await processUserInputWithMemory(transcript)
        
        // Convert to throwing function (the old version was throwing)
        if response.isEmpty {
            throw SpeechConversationError.aiProcessingFailed
        }
        
        return response
    }
    
    // MARK: - Voice Commands for Control
    
    private let stopCommands = ["stop", "end chat", "that's all for now", "thank you", "goodbye", "end conversation", "pause", "stop listening"]
    
    func checkForStopCommand(_ transcript: String) -> Bool {
        let lowercased = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return stopCommands.contains { command in
            lowercased.contains(command) || lowercased == command
        }
    }
    
    func checkForInterruptCommand(_ transcript: String) -> Bool {
        return checkForInterruptionWords(transcript.lowercased())
    }
    
    private func checkForInterruptionWords(_ lowerText: String) -> Bool {
        return interruptWords.contains { word in
            lowerText.contains(word) || lowerText == word
        }
    }
    
    // MARK: - Simple Stop Speaking
    
    func stopSpeaking() async {
        openAIVoice.stopSpeaking()
        isSpeaking = false
        currentTranscript = ""
        print("🎙️ [SPEECH] AI stopped")
    }
    
    func immediateStop() async {
        // Stop all AI processing and speech immediately
        await stopSpeaking()
        
        // Clean stop of listening
        _ = try? await stopListening()
        
        isActiveListening = false
        
        print("⏹️ [SPEECH] Immediate stop completed")
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        do {
            // Cancel speech processing timer
            cancelSpeechProcessingTimer()
            
            if isListening {
                _ = try await stopListening()
            }
            if isSpeaking {
                await stopSpeaking()
            }
        } catch {
            print("❌ [SPEECH] Cleanup failed: \(error)")
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate (Fixed Swift 6)

extension SpeechConversationService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                print("⚠️ [SPEECH] Speech recognizer became unavailable")
                errorMessage = "Speech recognition is temporarily unavailable"
            }
        }
    }
}
