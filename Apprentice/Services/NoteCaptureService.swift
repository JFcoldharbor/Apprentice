//
//  NoteCaptureService.swift
//  Apprentice
//
//  Layer 3 (Services) — orchestrates a capture session end to end.
//  Owns the RecordingEngine + LiveTranscriber, creates the in-progress Note,
//  persists each finalized chunk to SwiftData immediately (crash-safe), kicks
//  off per-chunk Whisper transcription, and restitches the transcript as chunks
//  complete. The ViewModel (L4) drives this; Views never touch it directly.
//

import Foundation
import SwiftData

@MainActor
final class NoteCaptureService: ObservableObject {

    let engine = RecordingEngine()
    let live = LiveTranscriber()

    @Published private(set) var currentNote: Note?

    private let context: ModelContext
    private let transcription: TranscriptionService
    private let useLiveTranscript: Bool

    init(context: ModelContext,
         transcription: TranscriptionService = TranscriptionServiceFactory.make(),
         useLiveTranscript: Bool = true) {
        self.context = context
        self.transcription = transcription
        self.useLiveTranscript = useLiveTranscript

        engine.onChunkFinalized = { [weak self] chunk in
            self?.handleFinalized(chunk)
        }
        if useLiveTranscript {
            engine.onAudioBuffer = { [weak self] buffer in
                self?.live.feed(buffer)
            }
        }
    }

    // MARK: - Control

    @discardableResult
    func startRecording(type: NoteType = .general, title: String = "") throws -> Note {
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = Note(
            title: resolvedTitle.isEmpty ? Self.defaultTitle() : resolvedTitle,
            type: type,
            status: .inProgress
        )
        context.insert(note)
        try? context.save()
        currentNote = note

        if useLiveTranscript { live.start() }
        try engine.start(noteID: note.id)
        return note
    }

    func pause() { engine.pause() }
    func resume() { engine.resume() }

    func stopRecording() {
        engine.stop()
        live.stop()
        guard let note = currentNote else { return }
        note.status = .completed
        note.updatedAt = Date()
        try? context.save()
        currentNote = nil
        maybeEnrich(note) // covers the case where all chunks already transcribed
    }

    /// Re-run transcription for a single chunk. Always possible because audio is retained.
    func retranscribe(_ chunk: AudioChunk) {
        guard let note = chunk.note else { return }
        transcribe(chunk, in: note)
    }

    // MARK: - Chunk handling

    private func handleFinalized(_ finalized: RecordingEngine.FinalizedChunk) {
        guard let note = currentNote else { return }

        let chunk = AudioChunk(
            index: finalized.index,
            relativePath: finalized.relativePath,
            duration: finalized.duration,
            fileSize: finalized.fileSize,
            status: .pending
        )
        chunk.note = note
        context.insert(chunk)
        note.duration += finalized.duration
        note.updatedAt = Date()
        try? context.save() // persist the chunk before transcription — crash-safe

        transcribe(chunk, in: note)
    }

    private func transcribe(_ chunk: AudioChunk, in note: Note) {
        chunk.status = .processing
        chunk.lastError = nil
        try? context.save()

        let url = AudioFileStore.shared.url(for: chunk)
        Task { @MainActor in
            do {
                let text = try await transcription.transcribe(fileURL: url)
                chunk.transcriptText = text
                chunk.status = .completed
                chunk.processedAt = Date()
            } catch {
                chunk.status = .failed
                chunk.lastError = error.localizedDescription
                chunk.retryCount += 1
            }
            NoteAssemblyService.restitch(note)
            try? context.save()
            maybeEnrich(note) // fires when the last chunk finishes after stop
        }
    }

    // MARK: - Helpers

    /// Run AI enrichment exactly once — when the note has stopped recording and
    /// every chunk has finished transcribing, and it hasn't been enriched yet.
    private func maybeEnrich(_ note: Note) {
        guard note.status == .completed,
              !note.isTranscribing,
              !note.fullTranscript.isEmpty,
              note.aiSummary.isEmpty else { return }
        Task { @MainActor in
            await NoteEnrichmentService.enrich(note, context: context)
        }
    }

    private static func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return "Note · \(formatter.string(from: Date()))"
    }
}
