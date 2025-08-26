//
//  OpenAIVoiceService.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - OpenAI TTS integration for executive coaching
//  FIXED: Removed text truncation to support full AI responses
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

// MARK: - OpenAI Voice Service

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
    
    // MARK: - Configuration
    
    private var apiKey: String {
        return Config.OpenAI.apiKey
    }
    
    private var baseURL: String {
        return Config.OpenAI.baseURL
    }
    
    // MARK: - Text-to-Speech Implementation
    
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
    
    // MARK: - Private TTS Implementation
    
    private func generateSpeech(text: String, voice: String) async throws -> Data {
        // FIXED: Support full responses without truncation
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
    
    // MARK: - FIXED: Text Processing for Complete Responses
    
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
    
    private func playSpeech(audioData: Data) async throws {
        // CRITICAL: More robust audio session handling to prevent conflicts
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // First try to deactivate current session cleanly
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Small delay to ensure clean transition
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Set up for playback with error handling
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: [])
            print("🔊 [OPENAI] Audio session configured for playback")
        } catch {
            // Fallback: Try with different options if first attempt fails
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: [])
                print("🔊 [OPENAI] Audio session configured with fallback settings")
            } catch {
                throw VoiceServiceError.playbackFailed("Audio session setup failed: \(error)")
            }
        }
        
        // Create audio player
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            guard let player = audioPlayer else {
                throw VoiceServiceError.playbackFailed("Failed to create audio player")
            }
            
            // Update state
            ttsState = .speaking
            isSpeaking = true
            speechProgress = 0.0
            
            // Start playback
            let success = player.play()
            guard success else {
                throw VoiceServiceError.playbackFailed("Failed to start audio playback")
            }
            
            // Start progress tracking
            startProgressTimer()
            
            print("🔊 [OPENAI] TTS playback started")
            
            // Wait for completion using proper continuation handling
            return await withCheckedContinuation { continuation in
                // Store continuation for proper cleanup
                self.playbackContinuation = continuation
            }
            
        } catch {
            throw VoiceServiceError.playbackFailed("Audio player creation failed: \(error)")
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
    
    private func handleTTSCompletion() {
        print("✅ [OPENAI] TTS completed")
        
        // Clean up
        progressTimer?.invalidate()
        progressTimer = nil
        isSpeaking = false
        speechProgress = 1.0
        ttsState = .completed
        
        // Resume the continuation if it exists
        if let continuation = playbackContinuation {
            playbackContinuation = nil
            continuation.resume()
        }
        
        // CRITICAL: More robust audio session restoration
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First deactivate cleanly
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Small delay for clean transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                do {
                    // Restore to recording mode with robust error handling
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                    try audioSession.setActive(true, options: [])
                    print("🎤 [OPENAI] Audio session restored to record mode")
                    
                    // Call completion callback after audio session is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.onTTSCompleted?()
                    }
                } catch {
                    print("⚠️ [OPENAI] Failed to restore audio session: \(error)")
                    // Still call completion callback even if restoration fails
                    self.onTTSCompleted?()
                }
            }
        } catch {
            print("⚠️ [OPENAI] Failed to deactivate audio session: \(error)")
            // Call completion callback anyway to prevent hanging
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.onTTSCompleted?()
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension OpenAIVoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                handleTTSCompletion()
            } else {
                print("❌ [OPENAI] TTS playback failed")
                ttsState = .failed(VoiceServiceError.playbackFailed("Playback interrupted"))
                isSpeaking = false
                progressTimer?.invalidate()
                progressTimer = nil
                
                // Resume continuation even on failure
                if let continuation = playbackContinuation {
                    playbackContinuation = nil
                    continuation.resume()
                }
                
                // Still call completion callback to resume recognition
                onTTSCompleted?()
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("❌ [OPENAI] TTS decode error: \(error?.localizedDescription ?? "Unknown")")
            ttsState = .failed(error ?? VoiceServiceError.playbackFailed("Decode error"))
            isSpeaking = false
            progressTimer?.invalidate()
            progressTimer = nil
            
            // Resume continuation even on error
            if let continuation = playbackContinuation {
                playbackContinuation = nil
                continuation.resume()
            }
            
            // Still call completion callback to resume recognition
            onTTSCompleted?()
        }
    }
}
