//
//  NoteAssemblyService.swift
//  Apprentice
//
//  Layer 3 (Services) — assembles chunk transcripts into a Note's full
//  transcript. Kept separate so the Phase 2 AI layer can hang summary /
//  action-item / decision extraction off the same seam without touching capture.
//

import Foundation

enum NoteAssemblyService {

    /// Rebuild `note.fullTranscript` from its completed chunks, in order.
    static func restitch(_ note: Note) {
        let parts = note.orderedChunks
            .filter { $0.status == .completed }
            .map { $0.transcriptText.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        note.fullTranscript = parts.joined(separator: "\n\n")
        note.updatedAt = Date()
    }
}
