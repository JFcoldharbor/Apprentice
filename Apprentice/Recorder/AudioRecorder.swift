//
//  AudioRecorder.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Complete recording system with ChunkStorageManager integration
//  COMPLETE: All methods, chunking system, immediate processing, and storage integration
//

import Foundation
import SwiftUI
import AVFoundation

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var recordingChunks: [RecordingChunk] = []
    @Published var processingProgress: Double = 0.0
    @Published var completedChunks = 0
    @Published var errorMessage: String?
    
    // MARK: - ChunkStorageManager Integration
    private let chunkStorageManager = ChunkStorageManager()
    
    // MARK: - Recording State
    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    
    // Session tracking
    private var sessionStartTime: Date?
    private var startTime: Date?
    private var recordingTimer: Timer?
    private var chunkTimer: Timer?
    
    // Chunk management
    @Published var currentChunk = 1
    @Published var totalChunks = 1
    @Published var chunkDuration: TimeInterval = 0
    @Published var recordingDuration: TimeInterval = 0
    
    // Configuration
    private let chunkDurationSeconds: TimeInterval = 600 // 10 minutes
    
    // MARK: - Initialization
    override init() {
        super.init()
        Task {
            await checkPermissions()
            await loadExistingChunks()
        }
    }
    
    // MARK: - Load Existing Chunks from ChunkStorageManager
    private func loadExistingChunks() async {
        let existingChunks = await chunkStorageManager.loadAllChunks()
        
        await MainActor.run {
            recordingChunks = existingChunks
            print("🔄 Loaded \(existingChunks.count) chunks from ChunkStorageManager")
        }
        
        // Update progress tracking
        let completed = existingChunks.filter { $0.transcriptionState == .completed }.count
        await MainActor.run {
            completedChunks = completed
            processingProgress = recordingChunks.isEmpty ? 0.0 : Double(completed) / Double(recordingChunks.count)
        }
    }
    
    // MARK: - Permission Management
    private func checkPermissions() async {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasPermission = true
        case .denied:
            hasPermission = false
        case .undetermined:
            do {
                try await requestPermission()
            } catch {
                hasPermission = false
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
    
    // MARK: - Recording Control
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
    
    func stopRecording() {
        guard isRecording else {
            print("⚠️ Not currently recording")
            return
        }
        
        // Finish current chunk without starting next
        finishCurrentChunk(startNext: false)
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        print("🛑 Recording session stopped")
        
        // Save to ChunkStorageManager
        saveChunksToStorage()
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Chunk Management with Storage Integration
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
        
        // Immediate processing with storage integration
        Task {
            await processChunkImmediately(chunk)
        }
        
        // Save to storage immediately
        saveChunksToStorage()
        
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
        }
    }
    
    // MARK: - Immediate Chunk Processing with Storage Integration
    private func processChunkImmediately(_ chunk: RecordingChunk) async {
        print("🔥 Starting immediate transcription for chunk \(chunk.number)")
        
        // Mark as processing in storage
        await chunkStorageManager.markChunkAsProcessing(chunkId: chunk.id)
        
        // Update local state
        await MainActor.run {
            if let index = recordingChunks.firstIndex(where: { $0.id == chunk.id }) {
                recordingChunks[index].transcriptionState = .processing
            }
        }
        
        do {
            // Use RealAIService for transcription
            let aiService = RealAIService()
            let transcription = try await aiService.transcribeAudio(audioURL: chunk.url)
            
            // Save completed state to storage
            await chunkStorageManager.markChunkAsCompleted(chunkId: chunk.id, transcription: transcription)
            
            // Update local state
            await MainActor.run {
                if let index = recordingChunks.firstIndex(where: { $0.id == chunk.id }) {
                    recordingChunks[index].transcriptionState = .completed
                    recordingChunks[index].transcriptionText = transcription
                    recordingChunks[index].processedAt = Date()
                    completedChunks += 1
                    processingProgress = Double(completedChunks) / Double(recordingChunks.count)
                }
            }
            
            print("✅ Chunk \(chunk.number) transcribed and saved to storage")
            
        } catch {
            print("❌ Immediate transcription failed for chunk \(chunk.number): \(error)")
            
            // Save failed state to storage
            await chunkStorageManager.markChunkAsFailed(chunkId: chunk.id, error: error.localizedDescription)
            
            // Update local state
            await MainActor.run {
                if let index = recordingChunks.firstIndex(where: { $0.id == chunk.id }) {
                    recordingChunks[index].transcriptionState = .failed
                    recordingChunks[index].lastError = error.localizedDescription
                    recordingChunks[index].retryCount += 1
                }
            }
        }
    }
    
    // MARK: - Save Chunks using ChunkStorageManager
    private func saveChunksToStorage() {
        Task {
            await chunkStorageManager.saveAllChunks(recordingChunks)
            print("💾 All chunks saved to ChunkStorageManager")
        }
    }
    
    // MARK: - Processing Methods
    func processAllChunks() async -> [String] {
        var transcriptions: [String] = []
        
        print("📊 Processing \(recordingChunks.count) chunks...")
        
        for chunk in recordingChunks.sorted(by: { $0.number < $1.number }) {
            if chunk.transcriptionState == .completed, let transcription = chunk.transcriptionText {
                transcriptions.append(transcription)
            } else if chunk.transcriptionState == .pending || chunk.transcriptionState == .failed {
                // Try to process this chunk
                do {
                    let aiService = RealAIService()
                    let transcription = try await aiService.transcribeAudio(audioURL: chunk.url)
                    transcriptions.append(transcription)
                    
                    // Update chunk state
                    await MainActor.run {
                        if let index = recordingChunks.firstIndex(where: { $0.id == chunk.id }) {
                            recordingChunks[index].transcriptionState = .completed
                            recordingChunks[index].transcriptionText = transcription
                            recordingChunks[index].processedAt = Date()
                        }
                    }
                } catch {
                    transcriptions.append("[Transcription failed for chunk \(chunk.number): \(error.localizedDescription)]")
                }
            } else {
                transcriptions.append("[Chunk \(chunk.number) in processing state]")
            }
        }
        
        print("🎉 Processed \(transcriptions.count) transcriptions!")
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
    
    // MARK: - Recovery Functions using ChunkStorageManager
    func recoverFailedChunks() async {
        let failedChunks = await chunkStorageManager.loadFailedChunks()
        
        print("🔄 Found \(failedChunks.count) failed chunks to recover")
        
        for chunk in failedChunks {
            // Retry transcription
            await processChunkImmediately(chunk)
        }
        
        // Reload all chunks after recovery
        await loadExistingChunks()
    }
    
    func getChunkStorageStats() async -> String {
        return await chunkStorageManager.exportChunksForDebug()
    }
    
    // MARK: - Cleanup Methods
    func deleteAllChunks() {
        for chunk in recordingChunks {
            do {
                try FileManager.default.removeItem(at: chunk.url)
                print("🗑️ Deleted chunk file: \(chunk.url.lastPathComponent)")
            } catch {
                print("⚠️ Failed to delete chunk file: \(error)")
            }
        }
        
        recordingChunks.removeAll()
        currentChunk = 1
        totalChunks = 1
        completedChunks = 0
        processingProgress = 0.0
        
        // Clear from storage
        Task {
            await chunkStorageManager.clearAllChunks()
        }
        
        print("🗑️ All chunks deleted and reset")
    }
    
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("🗑️ Deleted recording: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete recording: \(error)")
        }
    }
    
    // MARK: - Audio Setup Methods
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        print("📻 Audio session configured")
    }
    
    private func setupRecorder(chunkNumber: Int) throws {
        let timestamp = DateFormatter.fileTimestamp.string(from: Date())
        let filename = "chunk_\(chunkNumber)_\(timestamp).m4a"
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        currentRecordingURL = documentsPath.appendingPathComponent(filename)
        
        guard let url = currentRecordingURL else {
            throw RecordingError.fileCreationFailed
        }
        
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
        
        print("🔱 Recorder setup for chunk \(chunkNumber)")
    }
    
    // MARK: - Timer Management
    private func startTimers() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDurations()
        }
        
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDurationSeconds, repeats: true) { [weak self] _ in
            self?.finishCurrentChunk(startNext: true)
        }
        
        print("⏱️ Timers started")
    }
    
    private func stopTimers() {
        recordingTimer?.invalidate()
        chunkTimer?.invalidate()
        recordingTimer = nil
        chunkTimer = nil
        
        print("⏹️ Timers stopped")
    }
    
    private func updateDurations() {
        guard let startTime = startTime else { return }
        
        chunkDuration = Date().timeIntervalSince(startTime)
        
        if let sessionStart = sessionStartTime {
            recordingDuration = Date().timeIntervalSince(sessionStart)
        }
    }
    
    // MARK: - Helper Methods
    private func getFileSize(url: URL) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        isRecording = false
        print("❌ Recording error: \(error)")
    }
    
    // MARK: - Computed Properties
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
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AudioRecorder Delegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎤 Chunk recording finished successfully: \(flag)")
        
        if !flag {
            errorMessage = "Chunk recording failed to complete"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recording encode error: \(error?.localizedDescription ?? "Unknown")")
        
        if let error = error {
            handleError(error)
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        return formatter
    }()
}
