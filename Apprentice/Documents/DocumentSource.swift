//
//  DocumentSource.swift
//  Apprentice
//
//  Layer 3 (Services) — the source-agnostic seam for connected document sources.
//  A DocumentSource only knows how to FETCH its items; ingestion into the memory
//  store is generic (SafeDocumentManager.syncSource). The Stitch data room is the
//  first implementation; Google Drive is the next — same interface, new adapter.
//
//  Single-tenant in the data today (one hardcoded connection), multi-tenant in the
//  shape: nothing source-specific leaks past this protocol.
//

import Foundation

/// A connected place documents live (a data room, a Drive folder, …). The app
/// talks only to this — never to Firestore/Drive directly.
protocol DocumentSource {
    /// Stable identifier, also used to namespace + dedupe this source's docs
    /// (e.g. "stitch-dataroom").
    var id: String { get }
    /// Human-facing name, shown in the UI and spoken in sync confirmations.
    var displayName: String { get }
    /// Pull everything currently in the source. Network/source-specific work
    /// lives here; the result is ready for generic ingestion.
    func fetch() async throws -> [SourceItem]
}

/// One ingestible unit from a source: either already-extracted text (a narrative
/// section) or a remote file to download and extract.
struct SourceItem {
    enum Payload {
        /// Text that's already plain (e.g. a data-room section narrative).
        case text(String)
        /// A downloadable file (signed URL) plus the extension to extract by.
        case remoteFile(url: URL, ext: String)
    }

    /// Display title, typically prefixed with the source (e.g. "Data Room — Financials Brief").
    let title: String
    /// Optional short note/subtitle from the source.
    let note: String?
    let payload: Payload
}
