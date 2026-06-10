//
//  ChunkStorageManager.swift
//  Apprentice
//
//  Created by James Garmon on 8/28/25.
//


//
//  ChunkStorageManager.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Persistent storage for recording chunks
//  Handles chunk state persistence, recovery, and cleanup
//

import Foundation
import SwiftUI

// MARK: - Chunk Storage Manager

actor ChunkStorageManager {
    
    // MARK: - Storage Configuration
    
    private let chunksKey = "RecordingChunks_v3"
    private let sessionsKey = "RecordingSessions_v1"
    private let documentsDirectory: URL
    private let chunksDirectory: URL
    
    // MARK: - Initialization
    
    init() {
        // Setup storage directories
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        chunksDirectory = documentsDirectory.appendingPathComponent("RecordingChunks")
        
        // Create chunks directory if needed
        if !FileManager.default.fileExists(atPath: chunksDirectory.path) {
            try? FileManager.default.createDirectory(at: chunksDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Chunk State Persistence
    
    func saveChunkState(_ chunk: RecordingChunk) async {
        var chunks = await loadAllChunks()
        
        // Update existing chunk or add new one
        if let index = chunks.firstIndex(where: { $0.id == chunk.id }) {
            chunks[index] = chunk
        } else {
            chunks.append(chunk)
        }
        
        // Save updated chunks to UserDefaults
        if let encoded = try? JSONEncoder().encode(chunks) {
            UserDefaults.standard.set(encoded, forKey: chunksKey)
        }
        
        print("💾 Saved chunk \(chunk.number) state: \(chunk.transcriptionState.displayName)")
    }
    
    func saveAllChunks(_ chunks: [RecordingChunk]) async {
        if let encoded = try? JSONEncoder().encode(chunks) {
            UserDefaults.standard.set(encoded, forKey: chunksKey)
            print("💾 Saved all \(chunks.count) chunks to storage")
        }
    }
    
    // MARK: - Chunk Loading
    
    func loadAllChunks() async -> [RecordingChunk] {
        guard let data = UserDefaults.standard.data(forKey: chunksKey),
              let chunks = try? JSONDecoder().decode([RecordingChunk].self, from: data) else {
            return []
        }
        return chunks
    }
    
    func loadPendingChunks() async -> [RecordingChunk] {
        let allChunks = await loadAllChunks()
        return allChunks.filter { $0.transcriptionState == .pending }
    }
    
    func loadFailedChunks() async -> [RecordingChunk] {
        let allChunks = await loadAllChunks()
        return allChunks.filter { $0.transcriptionState == .failed || $0.transcriptionState == .retryable }
    }
    
    func loadCompletedChunks() async -> [RecordingChunk] {
        let allChunks = await loadAllChunks()
        return allChunks.filter { $0.transcriptionState == .completed }
    }
    
    func loadSessionChunks(sessionId: UUID) async -> [RecordingChunk] {
        let allChunks = await loadAllChunks()
        return allChunks.filter { chunk in
            // For now, group by timestamp similarity (same recording session)
            // In enhanced version, we'd use actual sessionId
            return true // Return all for basic version
        }.sorted { $0.number < $1.number }
    }
    
    // MARK: - Chunk State Updates
    
    func markChunkAsProcessing(chunkId: UUID) async {
        await updateChunkState(chunkId: chunkId, newState: .processing)
    }
    
    func markChunkAsCompleted(chunkId: UUID, transcription: String) async {
        var chunks = await loadAllChunks()
        
        if let index = chunks.firstIndex(where: { $0.id == chunkId }) {
            chunks[index].transcriptionState = .completed
            chunks[index].transcriptionText = transcription
            chunks[index].processedAt = Date()
            
            await saveAllChunks(chunks)
            print("✅ Marked chunk \(chunks[index].number) as completed")
        }
    }
    
    func markChunkAsFailed(chunkId: UUID, error: String) async {
        var chunks = await loadAllChunks()
        
        if let index = chunks.firstIndex(where: { $0.id == chunkId }) {
            chunks[index].transcriptionState = .failed
            chunks[index].lastError = error
            chunks[index].retryCount += 1
            
            await saveAllChunks(chunks)
            print("❌ Marked chunk \(chunks[index].number) as failed: \(error)")
        }
    }
    
    func markChunkAsRetryable(chunkId: UUID) async {
        await updateChunkState(chunkId: chunkId, newState: .retryable)
    }
    
    private func updateChunkState(chunkId: UUID, newState: RecordingChunk.TranscriptionState) async {
        var chunks = await loadAllChunks()
        
        if let index = chunks.firstIndex(where: { $0.id == chunkId }) {
            chunks[index].transcriptionState = newState
            await saveAllChunks(chunks)
        }
    }
    
    // MARK: - Storage Statistics
    
    func getStorageStats() async -> ChunkStorageStats {
        let chunks = await loadAllChunks()
        
        let pending = chunks.filter { $0.transcriptionState == .pending }.count
        let processing = chunks.filter { $0.transcriptionState == .processing }.count
        let completed = chunks.filter { $0.transcriptionState == .completed }.count
        let failed = chunks.filter { $0.transcriptionState == .failed }.count
        let retryable = chunks.filter { $0.transcriptionState == .retryable }.count
        
        return ChunkStorageStats(
            totalChunks: chunks.count,
            pendingChunks: pending,
            processingChunks: processing,
            completedChunks: completed,
            failedChunks: failed,
            retryableChunks: retryable,
            totalDuration: chunks.reduce(0) { $0 + $1.duration },
            totalFileSize: chunks.reduce(0) { $0 + $1.fileSize }
        )
    }
    
    // MARK: - File Management
    
    func validateChunkFiles() async -> [UUID] {
        let chunks = await loadAllChunks()
        var missingFiles: [UUID] = []
        
        for chunk in chunks {
            if !FileManager.default.fileExists(atPath: chunk.url.path) {
                missingFiles.append(chunk.id)
                print("⚠️ Missing file for chunk \(chunk.number): \(chunk.url.lastPathComponent)")
            }
        }
        
        return missingFiles
    }
    
    func cleanupOrphanedFiles() async {
        let chunks = await loadAllChunks()
        let chunkURLs = Set(chunks.map { $0.url })
        
        // Find all .m4a files in documents directory
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        
        let audioFiles = fileURLs.filter { $0.pathExtension.lowercased() == "m4a" }
        
        for file in audioFiles {
            if !chunkURLs.contains(file) {
                do {
                    try FileManager.default.removeItem(at: file)
                    print("🗑️ Cleaned up orphaned file: \(file.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to delete orphaned file: \(error)")
                }
            }
        }
    }
    
    // MARK: - Chunk Cleanup
    
    func deleteChunk(chunkId: UUID) async {
        var chunks = await loadAllChunks()
        
        if let index = chunks.firstIndex(where: { $0.id == chunkId }) {
            let chunk = chunks[index]
            
            // Delete audio file
            do {
                try FileManager.default.removeItem(at: chunk.url)
                print("🗑️ Deleted chunk file: \(chunk.url.lastPathComponent)")
            } catch {
                print("⚠️ Failed to delete chunk file: \(error)")
            }
            
            // Remove from storage
            chunks.remove(at: index)
            await saveAllChunks(chunks)
        }
    }
    
    func deleteSessionChunks(sessionId: UUID) async {
        let sessionChunks = await loadSessionChunks(sessionId: sessionId)
        
        for chunk in sessionChunks {
            await deleteChunk(chunkId: chunk.id)
        }
        
        print("🗑️ Deleted \(sessionChunks.count) chunks for session")
    }
    
    func clearAllChunks() async {
        let chunks = await loadAllChunks()
        
        // Delete all audio files
        for chunk in chunks {
            do {
                try FileManager.default.removeItem(at: chunk.url)
            } catch {
                print("⚠️ Failed to delete chunk file: \(error)")
            }
        }
        
        // Clear storage
        UserDefaults.standard.removeObject(forKey: chunksKey)
        print("🗑️ Cleared all chunk storage")
    }
    
    // MARK: - Recovery Operations
    
    func getRecoverableChunks() async -> [RecordingChunk] {
        let chunks = await loadAllChunks()
        return chunks.filter { chunk in
            chunk.transcriptionState == .failed || 
            chunk.transcriptionState == .retryable ||
            (chunk.transcriptionState == .pending && FileManager.default.fileExists(atPath: chunk.url.path))
        }
    }
    
    func exportChunksForDebug() async -> String {
        let chunks = await loadAllChunks()
        let stats = await getStorageStats()
        
        var report = """
        📊 CHUNK STORAGE REPORT
        ======================
        Total Chunks: \(stats.totalChunks)
        Pending: \(stats.pendingChunks)
        Processing: \(stats.processingChunks) 
        Completed: \(stats.completedChunks)
        Failed: \(stats.failedChunks)
        Retryable: \(stats.retryableChunks)
        
        Total Duration: \(formatDuration(stats.totalDuration))
        Total File Size: \(formatFileSize(stats.totalFileSize))
        
        CHUNK DETAILS:
        ==============
        """
        
        for chunk in chunks.sorted(by: { $0.number < $1.number }) {
            let fileExists = FileManager.default.fileExists(atPath: chunk.url.path)
            report += """
            
            Chunk \(chunk.number): \(chunk.transcriptionState.displayName)
            Duration: \(formatDuration(chunk.duration))
            File Size: \(formatFileSize(chunk.fileSize))
            File Exists: \(fileExists ? "✅" : "❌")
            """
            
            if let error = chunk.lastError {
                report += "\nError: \(error)"
            }
            
            if chunk.retryCount > 0 {
                report += "\nRetries: \(chunk.retryCount)"
            }
        }
        
        return report
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Chunk Storage Statistics

struct ChunkStorageStats {
    let totalChunks: Int
    let pendingChunks: Int
    let processingChunks: Int
    let completedChunks: Int
    let failedChunks: Int
    let retryableChunks: Int
    let totalDuration: TimeInterval
    let totalFileSize: Int
    
    var successRate: Double {
        guard totalChunks > 0 else { return 0.0 }
        return Double(completedChunks) / Double(totalChunks)
    }
    
    var formattedSuccessRate: String {
        return String(format: "%.1f%%", successRate * 100)
    }
    
    var hasFailures: Bool {
        return failedChunks > 0 || retryableChunks > 0
    }
}

// MARK: - Storage Errors

enum ChunkStorageError: Error, LocalizedError {
    case saveFailed(String)
    case loadFailed(String) 
    case fileNotFound(URL)
    case storageCorrupted
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save chunk: \(message)"
        case .loadFailed(let message):
            return "Failed to load chunks: \(message)"
        case .fileNotFound(let url):
            return "Chunk file not found: \(url.lastPathComponent)"
        case .storageCorrupted:
            return "Chunk storage data is corrupted"
        case .insufficientSpace:
            return "Insufficient storage space for chunks"
        }
    }
}