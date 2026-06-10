//
//  AudioChunk.swift
//  Apprentice
//
//  Layer 1 (Models) — one segment of a recording. The audio file is stored on
//  disk (under the recordings directory) and referenced here by RELATIVE path,
//  so the binary survives app updates / container path changes and never bloats
//  UserDefaults. Chunks are owned by a Note via the `note` back-reference, which
//  fixes the legacy "loadSessionChunks ignores sessionId / returns all" bug.
//

import Foundation
import SwiftData

@Model
final class AudioChunk {
    var id: UUID = UUID()

    /// Order within the parent Note's recording (0-based).
    var index: Int = 0

    /// Path relative to the recordings directory (resolve via AudioFileStore).
    var relativePath: String = ""

    var duration: TimeInterval = 0
    var fileSize: Int = 0
    var createdAt: Date = Date()

    var status: TranscriptionStatus = TranscriptionStatus.pending
    var transcriptText: String = ""
    var processedAt: Date?
    var retryCount: Int = 0
    var lastError: String?

    /// Owning note (inverse of Note.chunks).
    var note: Note?

    init(
        id: UUID = UUID(),
        index: Int,
        relativePath: String,
        duration: TimeInterval = 0,
        fileSize: Int = 0,
        createdAt: Date = Date(),
        status: TranscriptionStatus = .pending,
        transcriptText: String = ""
    ) {
        self.id = id
        self.index = index
        self.relativePath = relativePath
        self.duration = duration
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.status = status
        self.transcriptText = transcriptText
    }

    // MARK: Convenience

    var canRetry: Bool {
        (status == .failed || status == .retryable) && retryCount < 3
    }

    var isValidSize: Bool { fileSize > 1024 }

    var formattedDuration: String {
        let total = Int(duration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var formattedFileSize: String {
        String(format: "%.1f MB", Double(fileSize) / (1024 * 1024))
    }
}
