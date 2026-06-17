//
//  RecordingHandoff.swift
//  Apprentice
//
//  Layer 3 (Services) — a tiny coordinator that hands a pre-staged session from
//  the Sessions tab to the Record tab. Tapping "Start" on an upcoming session
//  sets `prefill` and switches to the Record tab; AriaRecordScreen consumes it on
//  appear and begins recording pre-filled with the title, type, and attendees.
//

import Foundation

struct RecordPrefill: Equatable {
    let title: String
    let type: NoteType
    let attendees: [String]
}

@MainActor
final class RecordingHandoff: ObservableObject {
    static let shared = RecordingHandoff()
    private init() {}

    /// Set by the Sessions "Start" button; consumed (and cleared) by the Record screen.
    @Published var prefill: RecordPrefill?
}
