//
//  RecordingChunkModels.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Recording chunk data models
//  Add this file to your Foundation layer alongside ExecutiveDataModels.swift
//

import Foundation
import SwiftUI

// MARK: - Recording Error Types

enum RecordingError: Error, LocalizedError {
    case setupFailed
    case recordingFailed
    case fileCreationFailed
    case encodingFailed
    case permissionDenied
    case audioSessionFailed
    case chunkProcessingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .setupFailed:
            return "Audio setup failed"
        case .recordingFailed:
            return "Recording failed"
        case .fileCreationFailed:
            return "Could not create recording file"
        case .encodingFailed:
            return "Audio encoding failed"
        case .permissionDenied:
            return "Microphone permission denied"
        case .audioSessionFailed:
            return "Audio session setup failed"
        case .chunkProcessingFailed(let message):
            return "Chunk processing failed: \(message)"
        }
    }
}

// MARK: - Recording Chunk Model

struct RecordingChunk: Codable, Identifiable {
    enum TranscriptionState: String, Codable, CaseIterable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        case retryable = "retryable"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .processing: return "Processing"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .retryable: return "Retryable"
            }
        }
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .processing: return .blue
            case .completed: return .green
            case .failed: return .red
            case .retryable: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock.circle"
            case .processing: return "arrow.triangle.2.circlepath"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .retryable: return "arrow.clockwise.circle"
            }
        }
    }
    
    let id = UUID()
    let number: Int
    let url: URL
    let duration: TimeInterval
    let fileSize: Int
    let timestamp: Date
    
    // Enhanced transcription tracking
    var transcriptionState: TranscriptionState = .pending
    var transcriptionText: String?
    var processedAt: Date?
    var retryCount: Int = 0
    var lastError: String?
    
    // Computed properties
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
        return fileSize > 1024 // At least 1KB
    }
    
    var canRetry: Bool {
        return transcriptionState == .failed && retryCount < 3
    }
    
    var statusDescription: String {
        switch transcriptionState {
        case .pending:
            return "Waiting to process..."
        case .processing:
            return "Transcribing audio..."
        case .completed:
            if let processedAt = processedAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                return "Completed at \(formatter.string(from: processedAt))"
            }
            return "Completed"
        case .failed:
            let errorText = lastError ?? "Unknown error"
            return "Failed: \(errorText)"
        case .retryable:
            return "Ready to retry (attempt \(retryCount + 1))"
        }
    }
    
    // Initializer
    init(
        number: Int,
        url: URL,
        duration: TimeInterval,
        fileSize: Int,
        timestamp: Date = Date()
    ) {
        self.number = number
        self.url = url
        self.duration = duration
        self.fileSize = fileSize
        self.timestamp = timestamp
    }
}

// MARK: - Recording Session Model

struct RecordingSession: Codable, Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date?
    let totalDuration: TimeInterval
    let chunkCount: Int
    let title: String
    
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var isComplete: Bool {
        return endTime != nil
    }
    
    init(startTime: Date, title: String = "Recording Session") {
        self.startTime = startTime
        self.endTime = nil
        self.totalDuration = 0
        self.chunkCount = 0
        self.title = title
    }
}

// MARK: - Processing Error Types

enum RecordingProcessingError: Error, LocalizedError {
    case emptyTranscription
    case processingTimeout
    case invalidChunkData
    
    var errorDescription: String? {
        switch self {
        case .emptyTranscription:
            return "No transcription content was generated"
        case .processingTimeout:
            return "Processing timed out"
        case .invalidChunkData:
            return "Invalid chunk data"
        }
    }
}
