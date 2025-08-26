//
//  AudioRecorder.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Enhanced with 10-minute chunking system
//  UPDATED: Automatic chunking to prevent Whisper API transcription failures
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRecordingURL: URL?
    @Published var errorMessage: String?
    @Published var hasPermission = false
    
    // MARK: - NEW: Chunking System Properties
    
    @Published var currentChunk: Int = 1
    @Published var totalChunks: Int = 1
    @Published var chunkDuration: TimeInterval = 0
    @Published var recordingChunks: [RecordingChunk] = []
    @Published var isProcessingChunks = false
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var chunkTimer: Timer?
    private var startTime: Date?
    private var sessionStartTime: Date?
    
    // MARK: - Chunking Configuration
    
    private let chunkDurationMinutes: TimeInterval = 10.0 // 10-minute chunks
    private let chunkDurationSeconds: TimeInterval = 10.0 * 60.0 // 600 seconds
    private let maxFileSize: Int = 20_000_000 // 20MB safety limit (Whisper limit is 25MB)
    
    // MARK: - Computed Properties
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedChunkDuration: String {
        let minutes = Int(chunkDuration) / 60
        let seconds = Int(chunkDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedSessionDuration: String {
        guard let sessionStart = sessionStartTime else { return "00:00" }
        let sessionDuration = Date().timeIntervalSince(sessionStart)
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkPermissions()
        loadExistingChunks()
    }
    
    // MARK: - Permission Management

    func checkPermissions() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasPermission = true
        case .denied:
            hasPermission = false
        case .undetermined:
            Task {
                try? await requestPermission()
            }
        @unknown default:
            hasPermission = false
        }
    }

    func requestPermission() async throws {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    if !granted {
                        self?.errorMessage = "Microphone permission is required for recording"
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Enhanced Recording Methods with Chunking
    
    func startRecording() {
        guard hasPermission else {
            errorMessage = "Microphone permission required"
            return
        }
        
        guard !isRecording else {
            print("⚠️ Already recording")
            return
        }
        
        // Initialize session tracking
        sessionStartTime = Date()
        currentChunk = 1
        totalChunks = 1
        chunkDuration = 0
        recordingDuration = 0
        recordingChunks = []
        
        startNewChunk()
    }
    
    private func startNewChunk() {
        do {
            try setupAudioSession()
            try setupRecorder(chunkNumber: currentChunk)
            
            guard let recorder = audioRecorder else {
                throw RecordingError.setupFailed
            }
            
            if recorder.record() {
                isRecording = true
                startTime = Date()
                startTimers()
                errorMessage = nil
                
                print("🎤 Recording chunk \(currentChunk) started")
                print("📊 Total session duration: \(formattedSessionDuration)")
            } else {
                throw RecordingError.recordingFailed
            }
            
        } catch {
            handleError(error)
        }
    }
    
    private func finishCurrentChunk(startNext: Bool = true) {
        guard let recorder = audioRecorder,
              let chunkURL = currentRecordingURL else {
            print("⚠️ No active recorder to finish chunk")
            return
        }
        
        // Stop current recorder
        recorder.stop()
        stopTimers()
        
        // Create chunk record
        let chunk = RecordingChunk(
            number: currentChunk,
            url: chunkURL,
            duration: chunkDuration,
            fileSize: getFileSize(url: chunkURL),
            timestamp: Date()
        )
        recordingChunks.append(chunk)
        
        print("✅ Completed chunk \(currentChunk): \(chunk.formattedDuration)")
        print("📁 File size: \(chunk.formattedFileSize)")
        
        if startNext {
            // Prepare for next chunk
            currentChunk += 1
            totalChunks += 1
            chunkDuration = 0
            
            // Small delay to ensure clean transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startNewChunk()
            }
        } else {
            // Recording session complete
            isRecording = false
            print("🎉 Recording session completed with \(recordingChunks.count) chunks")
            print("📊 Total duration: \(formattedSessionDuration)")
        }
    }
    
    func stopRecording() {
        guard isRecording else {
            print("⚠️ Not currently recording")
            return
        }
        
        // Finish current chunk without starting next
        finishCurrentChunk(startNext: false)
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        print("🏁 Recording session stopped")
        saveChunksMetadata()
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Chunk Processing
    
    func processAllChunks() async -> [String] {
        guard !recordingChunks.isEmpty else {
            print("⚠️ No chunks to process")
            return []
        }
        
        isProcessingChunks = true
        var transcriptions: [String] = []
        
        print("🔄 Processing \(recordingChunks.count) audio chunks...")
        
        for (index, chunk) in recordingChunks.enumerated() {
            do {
                print("📝 Transcribing chunk \(chunk.number) (\(index + 1)/\(recordingChunks.count))...")
                
                // Use RealAIService for transcription
                let aiService = RealAIService()
                let transcription = try await aiService.transcribeAudio(audioURL: chunk.url)
                
                transcriptions.append(transcription)
                print("✅ Chunk \(chunk.number) transcribed: \(transcription.prefix(100))...")
                
            } catch {
                print("❌ Failed to transcribe chunk \(chunk.number): \(error)")
                transcriptions.append("[Transcription failed for chunk \(chunk.number)]")
            }
        }
        
        isProcessingChunks = false
        print("🎉 All chunks processed!")
        
        return transcriptions
    }
    
    func getCombinedTranscription() async -> String {
        let transcriptions = await processAllChunks()
        
        let combined = transcriptions.enumerated().map { index, text in
            let chunkNumber = index + 1
            return "--- Chunk \(chunkNumber) ---\n\(text)"
        }.joined(separator: "\n\n")
        
        return combined
    }
    
    // MARK: - Private Setup Methods
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        
        print("🔊 Audio session configured")
    }
    
    private func setupRecorder(chunkNumber: Int) throws {
        // Create unique filename for chunk
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())
        let filename = "chunk_\(chunkNumber)_\(timestamp).m4a"
        
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        currentRecordingURL = documentsPath.appendingPathComponent(filename)
        
        guard let url = currentRecordingURL else {
            throw RecordingError.fileCreationFailed
        }
        
        // Audio settings optimized for speech
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        
        print("📱 Recorder setup for chunk \(chunkNumber)")
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        // Main duration timer (updates every 0.1 seconds)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDurations()
        }
        
        // Chunk timer (triggers every 10 minutes)
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDurationSeconds, repeats: true) { [weak self] _ in
            self?.handleChunkTimeout()
        }
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        chunkTimer?.invalidate()
        chunkTimer = nil
    }
    
    private func updateDurations() {
        guard let startTime = startTime,
              let sessionStart = sessionStartTime else { return }
        
        chunkDuration = Date().timeIntervalSince(startTime)
        recordingDuration = Date().timeIntervalSince(sessionStart)
    }
    
    private func handleChunkTimeout() {
        print("⏰ Chunk timeout reached - switching to next chunk")
        finishCurrentChunk(startNext: true)
    }
    
    // MARK: - File Management
    
    private func getFileSize(url: URL) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    private func saveChunksMetadata() {
        // Save chunk metadata for potential recovery
        if let data = try? JSONEncoder().encode(recordingChunks) {
            let metadataURL = getDocumentsDirectory().appendingPathComponent("chunks_metadata.json")
            try? data.write(to: metadataURL)
            print("💾 Saved chunks metadata")
        }
    }
    
    private func loadExistingChunks() {
        let metadataURL = getDocumentsDirectory().appendingPathComponent("chunks_metadata.json")
        
        if let data = try? Data(contentsOf: metadataURL),
           let chunks = try? JSONDecoder().decode([RecordingChunk].self, from: data) {
            recordingChunks = chunks
            print("📂 Loaded \(chunks.count) existing chunks")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ Deleted recording: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete recording: \(error)")
        }
    }
    
    func deleteAllChunks() {
        for chunk in recordingChunks {
            deleteRecording(at: chunk.url)
        }
        recordingChunks.removeAll()
        
        // Delete metadata
        let metadataURL = getDocumentsDirectory().appendingPathComponent("chunks_metadata.json")
        try? FileManager.default.removeItem(at: metadataURL)
        
        print("🗑️ Deleted all recording chunks")
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        Task { @MainActor in
            isRecording = false
            stopTimers()
            
            if let recordingError = error as? RecordingError {
                errorMessage = recordingError.localizedDescription
            } else {
                errorMessage = "Recording failed: \(error.localizedDescription)"
            }
            
            print("❌ Recording error: \(error)")
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎤 Chunk recording finished successfully: \(flag)")
        
        if !flag {
            Task { @MainActor in
                self.errorMessage = "Chunk recording failed to complete"
            }
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recording encode error: \(error?.localizedDescription ?? "Unknown")")
        
        Task { @MainActor in
            self.handleError(error ?? RecordingError.encodingFailed)
        }
    }
}

// MARK: - Recording Chunk Model

struct RecordingChunk: Codable, Identifiable {
    let id = UUID()
    let number: Int
    let url: URL
    let duration: TimeInterval
    let fileSize: Int
    let timestamp: Date
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedFileSize: String {
        let mb = Double(fileSize) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
    
    var isValidSize: Bool {
        return fileSize < 20_000_000 // 20MB safety limit
    }
}

// MARK: - Recording Errors

enum RecordingError: Error, LocalizedError {
    case permissionDenied
    case setupFailed
    case fileCreationFailed
    case recordingFailed
    case encodingFailed
    case chunkSizeExceeded
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .setupFailed:
            return "Failed to setup audio recorder"
        case .fileCreationFailed:
            return "Failed to create recording file"
        case .recordingFailed:
            return "Recording failed to start"
        case .encodingFailed:
            return "Audio encoding failed"
        case .chunkSizeExceeded:
            return "Recording chunk exceeded size limit"
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
