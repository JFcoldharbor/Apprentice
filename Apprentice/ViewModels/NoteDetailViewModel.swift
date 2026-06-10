//
//  NoteDetailViewModel.swift
//  Apprentice
//
//  Layer 4 (ViewModels) — command surface for a single Note: rename, retype,
//  edit/add actions & decisions, re-transcribe chunks (audio is retained), and
//  delete (including audio files). Reads are reactive via @Query in the view;
//  this VM is the write path. Talks only to L3/L2, never to the network in
//  Phase 1 except via TranscriptionService for re-transcription.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class NoteDetailViewModel: ObservableObject {

    let note: Note
    private let context: ModelContext
    private let transcription: TranscriptionService

    @Published var isReprocessing = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    init(note: Note,
         context: ModelContext,
         transcription: TranscriptionService = TranscriptionServiceFactory.make()) {
        self.note = note
        self.context = context
        self.transcription = transcription
    }

    // MARK: - Editing

    func rename(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        note.title = trimmed
        touch()
    }

    func setType(_ type: NoteType) {
        note.type = type
        touch()
    }

    func setPriority(_ priority: NotePriority) {
        note.priority = priority
        touch()
    }

    func toggleAction(_ action: NoteAction) {
        if action.status == .completed {
            action.status = .pending
            action.completedAt = nil
        } else {
            action.status = .completed
            action.completedAt = Date()
        }
        touch()
    }

    func addAction(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let action = NoteAction(title: trimmed)
        action.note = note
        context.insert(action)
        touch()
    }

    func deleteAction(_ action: NoteAction) {
        context.delete(action)
        touch()
    }

    // MARK: - Re-transcription (audio is retained, so always available)

    func retranscribe(_ chunk: AudioChunk) async {
        await reprocess([chunk])
    }

    func retranscribeFailed() async {
        let failed = note.orderedChunks.filter { $0.status == .failed || $0.status == .retryable }
        await reprocess(failed)
    }

    func retranscribeAll() async {
        await reprocess(note.orderedChunks)
    }

    private func reprocess(_ chunks: [AudioChunk]) async {
        guard !chunks.isEmpty else { return }
        isReprocessing = true
        defer { isReprocessing = false }

        for chunk in chunks {
            chunk.status = .processing
            chunk.lastError = nil
            try? context.save()

            let url = AudioFileStore.shared.url(for: chunk)
            do {
                let text = try await transcription.transcribe(fileURL: url)
                chunk.transcriptText = text
                chunk.status = .completed
                chunk.processedAt = Date()
            } catch {
                chunk.status = .failed
                chunk.lastError = error.localizedDescription
                chunk.retryCount += 1
                errorMessage = error.localizedDescription
            }
        }
        NoteAssemblyService.restitch(note)
        try? context.save()
    }

    // MARK: - AI analysis

    /// Run (or re-run) Claude enrichment over the transcript.
    func analyze(force: Bool = true) async {
        guard !note.fullTranscript.isEmpty else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        let ok = await NoteEnrichmentService.enrich(note, context: context, force: force)
        if !ok && note.aiSummary.isEmpty {
            errorMessage = "Couldn't analyze this note. Is the AI proxy deployed?"
        }
    }

    // MARK: - Delete

    func deleteNote() {
        AudioFileStore.shared.deleteFiles(for: note)
        context.delete(note)
        try? context.save()
    }

    // MARK: - Export

    func exportText() -> String {
        var lines: [String] = ["# \(note.title)", ""]
        if !note.aiSummary.isEmpty {
            lines.append("## Summary"); lines.append(note.aiSummary); lines.append("")
        }
        if !note.actions.isEmpty {
            lines.append("## Action Items")
            for action in note.actions {
                let box = action.status == .completed ? "[x]" : "[ ]"
                lines.append("- \(box) \(action.title)")
            }
            lines.append("")
        }
        lines.append("## Transcript")
        lines.append(note.fullTranscript)
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func touch() {
        note.updatedAt = Date()
        try? context.save()
    }
}
