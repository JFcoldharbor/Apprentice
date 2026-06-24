//
//  NoteStore.swift
//  Apprentice
//
//  Layer 2 (Store) — the SwiftData persistence primitive for the note stack.
//  Owns the ModelContainer/schema. CloudKit sync is wired but OFF by default;
//  flip `enableCloudKit` once the models are reviewed for CloudKit constraints
//  (all-optional / no .unique). Views reach data via @Query + this container;
//  they never talk to the store internals directly.
//

import Foundation
import SwiftData

enum NoteStore {

    /// All @Model types in the note stack.
    static let schema = Schema([
        Note.self,
        AudioChunk.self,
        NoteAction.self,
        NoteDecision.self,
        CoachMessage.self,
        InterviewRecord.self
    ])

    /// Toggle for iCloud sync. Keep false until models are CloudKit-audited.
    static let enableCloudKit = false

    static let container: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: enableCloudKit ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A failed container means the on-disk store is corrupt/incompatible.
            // Surface loudly in development rather than silently losing data.
            fatalError("NoteStore: failed to create ModelContainer — \(error)")
        }
    }()

    /// Convenience main-thread context.
    @MainActor
    static var mainContext: ModelContext { container.mainContext }
}
