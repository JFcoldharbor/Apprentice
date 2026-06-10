//
//  AudioFileStore.swift
//  Apprentice
//
//  Layer 2 (Store) — owns the on-disk audio for recording chunks.
//  Audio lives under Application Support/<bundleID>/Recordings and is referenced
//  by RELATIVE path from AudioChunk, so the binary survives container-path
//  changes and never bloats UserDefaults. Files are retained after transcription
//  (re-transcribe / playback), and only removed when their Note is deleted.
//

import Foundation

struct AudioFileStore {

    static let shared = AudioFileStore()

    /// Base directory for all recording chunk audio files.
    let recordingsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "coldharbor.Apprentice"
        let dir = appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.recordingsDirectory = dir
    }

    // MARK: Path resolution

    func url(forRelativePath path: String) -> URL {
        recordingsDirectory.appendingPathComponent(path)
    }

    func url(for chunk: AudioChunk) -> URL {
        url(forRelativePath: chunk.relativePath)
    }

    /// Allocate a new chunk file location and the relative path to persist on the model.
    func newChunkFile(noteID: UUID, index: Int, ext: String = "m4a") -> (url: URL, relativePath: String) {
        let name = "note_\(noteID.uuidString)_chunk_\(index).\(ext)"
        return (recordingsDirectory.appendingPathComponent(name), name)
    }

    // MARK: File ops

    func fileExists(for chunk: AudioChunk) -> Bool {
        FileManager.default.fileExists(atPath: url(for: chunk).path)
    }

    func fileSize(at url: URL) -> Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int) ?? 0
    }

    func deleteFile(for chunk: AudioChunk) {
        try? FileManager.default.removeItem(at: url(for: chunk))
    }

    /// Remove every audio file belonging to a note (call before deleting the Note).
    func deleteFiles(for note: Note) {
        for chunk in note.chunks {
            deleteFile(for: chunk)
        }
    }
}
