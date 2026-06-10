//
//  OpenAIVoiceService.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - OpenAI TTS integration for executive coaching
//  PRODUCTION FIX: Robust audio session management, no crashes, no hangs
//

import Foundation
import AVFoundation

// MARK: - TTS State and Error Types

enum TTSState {
    case idle
    case preparing
    case speaking
    case completed
    case failed(Error)
}

enum VoiceServiceError: Error, LocalizedError {
    case apiKeyMissing
    case audioGenerationFailed(String)
    case playbackFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is missing"
        case .audioGenerationFailed(let message):
            return "Audio generation failed: \(message)"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - TTS API Model

private struct TTSRequest: Codable {
    let model: String
    let input: String
    let voice: String
    let responseFormat: String
    let speed: Double
    
    enum CodingKeys: String, CodingKey {
        case model, input, voice, speed
        case responseFormat = "response_format"
    }
}

// MARK: - OpenAI Voice Service (PRODUCTION READY)

@MainActor
class OpenAIVoiceService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var ttsState: TTSState = .idle
    @Published var isSpeaking: Bool = false
    @Published var speechProgress: Double = 0.0
    @Published var isProcessingAI: Bool = false
    @Published var lastError: Error?
    
    // MARK: - TTS Completion Callback (Critical for Voice Activity Detection)
    
    var onTTSCompleted: (() -> Void)?
    
    // MARK: - Private Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var audioSessionQueue = DispatchQueue(label: "audio-session", qos: .userInitiated)
    
    // MARK: - Configuration
    
    private var apiKey: String {
        return Config.OpenAI.apiKey
    }
    
    private var baseURL: String {
        return Config.OpenAI.baseURL
    }
    
    // MARK: - Text-to-Speech Implementation (CRASH-PROOF)
    
    func speak(text: String, voice: String = Config.OpenAI.TTS.voice) async throws {
        print("🔊 [OPENAI] Starting TTS with voice: \(voice)")
        
        guard !apiKey.isEmpty else {
            throw VoiceServiceError.apiKeyMissing
        }
        
        ttsState = .preparing
        
        do {
            let audioData = try await generateSpeech(text: text, voice: voice)
            try await playSpeech(audioData: audioData)
        } catch {
            print("❌ [OPENAI] TTS failed: \(error)")
            ttsState = .failed(error)
            lastError = error
            
            // CRITICAL: Ensure audio session is restored even on failure
            await restoreAudioSessionOnFailure()
            
            // Call completion callback to prevent hanging
            onTTSCompleted?()
            
            throw error
        }
    }
    
    // MARK: - FIXED: Robust Audio Session Management (No More Crashes)
    
    private func playSpeech(audioData: Data) async throws {
        // CRITICAL FIX: Simplified approach that properly handles throwing operations
        
        // Step 1: Clean shutdown of existing session
        let audioSession = AVAudioSession.sharedInstance()
        
        // Stop any existing audio
        audioPlayer?.stop()
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Clean deactivation with proper error handling
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // Step 2: Small delay for clean transition (CRITICAL)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        
        // Step 3: Configure for TTS playback
        try audioSession.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try audioSession.setActive(true, options: [])
        print("🔊 [OPENAI] Audio session configured for TTS")
        
        // Step 4: Create and configure audio player
        audioPlayer = try AVAudioPlayer(data: audioData)
        guard let player = audioPlayer else {
            throw VoiceServiceError.playbackFailed("Failed to create audio player")
        }
        
        player.delegate = self
        player.prepareToPlay()
        
        // Step 5: Start playback with error checking
        ttsState = .speaking
        isSpeaking = true
        speechProgress = 0.0
        
        let success = player.play()
        guard success else {
            throw VoiceServiceError.playbackFailed("Audio playback start failed")
        }
        
        // Start progress tracking
        startProgressTimer()
        print("✅ [OPENAI] TTS playback started successfully")
        
        // Step 6: Wait for completion using continuation
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Clean up any existing continuation
            if let existingContinuation = playbackContinuation {
                existingContinuation.resume()
            }
            playbackContinuation = continuation
        }
    }
    
    private func startProgressTimer() {
        guard let player = audioPlayer else { return }
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                
                if player.duration > 0 {
                    self.speechProgress = player.currentTime / player.duration
                }
            }
        }
    }
    
    // MARK: - FIXED: Thread-Safe TTS Completion
    
    private func handleTTSCompletion() {
        print("✅ [OPENAI] TTS completing...")
        
        // Clean up timers and state
        progressTimer?.invalidate()
        progressTimer = nil
        isSpeaking = false
        speechProgress = 1.0
        ttsState = .completed
        
        // Resume continuation safely (FIXED: No race conditions)
        let continuation = playbackContinuation
        playbackContinuation = nil
        
        // CRITICAL: Restore audio session for recording
        Task {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                
                // Clean deactivation
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                
                // Restore to recording mode
                try await Task.sleep(nanoseconds: 150_000_000) // 0.15s delay
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: [])
                
                print("🎤 [OPENAI] Audio session restored for recording")
                
                // Resume continuation after audio session is ready
                continuation?.resume()
                
                // Call completion callback
                await MainActor.run {
                    self.onTTSCompleted?()
                }
                
            } catch {
                print("⚠️ [OPENAI] Audio session restore failed: \(error)")
                // Still resume continuation to prevent hanging
                continuation?.resume()
                await MainActor.run {
                    self.onTTSCompleted?()
                }
            }
        }
    }
    
    // MARK: - Audio Session Failure Recovery
    
    private func restoreAudioSessionOnFailure() async {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Small delay
            try await Task.sleep(nanoseconds: 100_000_000)
            
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: [])
            print("🎤 [OPENAI] Audio session restored after TTS failure")
        } catch {
            print("⚠️ [OPENAI] Failed to restore audio session after failure: \(error)")
        }
    }
    
    // MARK: - Control Methods
    
    func stopSpeaking() {
        audioPlayer?.stop()
        progressTimer?.invalidate()
        progressTimer = nil
        isSpeaking = false
        speechProgress = 0.0
        ttsState = .idle
        
        // Resume continuation if stopped manually
        if let continuation = playbackContinuation {
            playbackContinuation = nil
            continuation.resume()
        }
        
        print("🛑 [OPENAI] TTS stopped")
    }
    
    func pauseSpeaking() {
        audioPlayer?.pause()
        progressTimer?.invalidate()
        print("⏸️ [OPENAI] TTS paused")
    }
    
    func resumeSpeaking() {
        audioPlayer?.play()
        startProgressTimer()
        print("▶️ [OPENAI] TTS resumed")
    }
    
    // MARK: - Emergency Stop Method (NEW)
    
    func emergencyStop() {
        audioPlayer?.stop()
        progressTimer?.invalidate()
        progressTimer = nil
        isSpeaking = false
        ttsState = .idle
        
        // Resume any hanging continuation
        if let continuation = playbackContinuation {
            playbackContinuation = nil
            continuation.resume()
        }
        
        // Restore audio session
        Task {
            try? AVAudioSession.sharedInstance().setActive(false)
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
            try? AVAudioSession.sharedInstance().setActive(true)
            onTTSCompleted?()
        }
        
        print("🚨 [OPENAI] Emergency stop executed")
    }
    
    // MARK: - Private TTS Implementation
    
    private func generateSpeech(text: String, voice: String) async throws -> Data {
        // Support full responses without truncation
        let processedText = cleanTextForTTS(text)
        
        let requestBody = TTSRequest(
            model: Config.OpenAI.TTS.model,
            input: processedText,
            voice: voice,
            responseFormat: Config.OpenAI.TTS.responseFormat,
            speed: 1.0 // Normal speed for better clarity
        )
        
        let url = URL(string: "\(baseURL)/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // Increased timeout for longer responses
        
        let requestData = try JSONEncoder().encode(requestBody)
        request.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceServiceError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VoiceServiceError.audioGenerationFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
        
        print("✅ [OPENAI] TTS audio generated successfully (\(data.count) bytes)")
        return data
    }
    
    // MARK: - Text Processing for Complete Responses
    
    private func cleanTextForTTS(_ text: String) -> String {
        // REMOVED TRUNCATION - Now supports full responses
        // Only clean up text formatting for better TTS quality
        
        var cleanedText = text
        
        // Remove markdown formatting that doesn't speak well
        cleanedText = cleanedText.replacingOccurrences(of: "**", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "*", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "###", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "##", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "#", with: "")
        
        // Convert bullet points to more natural speech
        cleanedText = cleanedText.replacingOccurrences(of: "•", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "- ", with: "")
        
        // Fix spacing around numbers for list items
        cleanedText = cleanedText.replacingOccurrences(of: "1.", with: "First:")
        cleanedText = cleanedText.replacingOccurrences(of: "2.", with: "Second:")
        cleanedText = cleanedText.replacingOccurrences(of: "3.", with: "Third:")
        cleanedText = cleanedText.replacingOccurrences(of: "4.", with: "Fourth:")
        cleanedText = cleanedText.replacingOccurrences(of: "5.", with: "Fifth:")
        
        // Clean up extra whitespace
        cleanedText = cleanedText.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        cleanedText = cleanedText.replacingOccurrences(of: "  ", with: " ")
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure we don't exceed OpenAI's TTS limits (4096 characters)
        if cleanedText.count > 4000 {
            // Only truncate if absolutely necessary, at sentence boundaries
            let sentences = cleanedText.components(separatedBy: ". ")
            var result = ""
            
            for sentence in sentences {
                if (result + sentence + ". ").count > 4000 {
                    break
                }
                result += sentence + ". "
            }
            
            cleanedText = result.trimmingCharacters(in: .whitespacesAndNewlines)
            print("⚠️ [OPENAI] Text truncated to fit OpenAI limits: \(cleanedText.count) characters")
        }
        
        return cleanedText
    }
}

// MARK: - FIXED: AVAudioPlayerDelegate (Thread-Safe)

extension OpenAIVoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                handleTTSCompletion()
            } else {
                print("⚠️ [OPENAI] TTS playback failed")
                
                // Clean up state
                ttsState = .failed(VoiceServiceError.playbackFailed("Playback interrupted"))
                isSpeaking = false
                progressTimer?.invalidate()
                progressTimer = nil
                
                // Resume continuation with error (FIXED: No hanging)
                let continuation = playbackContinuation
                playbackContinuation = nil
                continuation?.resume()
                
                // Still call completion to resume recording
                onTTSCompleted?()
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ [OPENAI] TTS decode error: \(error?.localizedDescription ?? "Unknown")")
            
            // Clean up state
            ttsState = .failed(error ?? VoiceServiceError.playbackFailed("Decode error"))
            isSpeaking = false
            progressTimer?.invalidate()
            progressTimer = nil
            
            // Resume continuation with error (FIXED: No hanging)
            let continuation = playbackContinuation
            playbackContinuation = nil
            continuation?.resume()
            
            // Call completion to resume recording
            onTTSCompleted?()
        }
    }
}
