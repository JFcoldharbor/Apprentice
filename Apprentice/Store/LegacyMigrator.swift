//
//  LegacyMigrator.swift
//  Apprentice
//
//  Layer 2 (Store) — one-time migration of legacy data into SwiftData.
//  Reads the old `ExecutiveSessions` UserDefaults JSON (still decodable via the
//  legacy `ExecutiveSession` Codable type) and rebuilds it as Note records.
//  Non-destructive: legacy UserDefaults is left intact, and the "done" flag is
//  only set on success (or when there's nothing to migrate), so a later code fix
//  can retry a failed decode.
//

import Foundation
import SwiftData

@MainActor
enum LegacyMigrator {

    static let migratedKey = "note_migration_v1_completed"
    static let legacySessionsKey = "ExecutiveSessions"

    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        guard let data = UserDefaults.standard.data(forKey: legacySessionsKey) else {
            // Nothing to migrate — mark done so we don't keep checking.
            UserDefaults.standard.set(true, forKey: migratedKey)
            return
        }

        guard let legacy = decodeLegacy(data) else {
            // Leave the flag unset so a future build can retry; don't lose data.
            print("⚠️ LegacyMigrator: could not decode legacy sessions; will retry next launch.")
            return
        }

        for session in legacy {
            insert(session, into: context)
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: migratedKey)
            print("✅ LegacyMigrator: migrated \(legacy.count) legacy session(s) to Notes.")
        } catch {
            print("⚠️ LegacyMigrator: save failed — \(error)")
        }
    }

    // MARK: - Decode (tolerant of either date strategy)

    private static func decodeLegacy(_ data: Data) -> [ExecutiveSession]? {
        let iso = JSONDecoder()
        iso.dateDecodingStrategy = .iso8601
        if let result = try? iso.decode([ExecutiveSession].self, from: data) { return result }

        let plain = JSONDecoder()
        if let result = try? plain.decode([ExecutiveSession].self, from: data) { return result }

        return nil
    }

    // MARK: - Mapping

    private static func insert(_ session: ExecutiveSession, into context: ModelContext) {
        let note = Note(
            id: session.id,
            title: session.title,
            createdAt: session.date,
            type: NoteType(rawValue: session.type.rawValue) ?? .general,
            priority: NotePriority(rawValue: session.priority.rawValue) ?? .medium,
            status: NoteStatus(rawValue: session.status.rawValue) ?? .completed,
            duration: session.duration,
            tags: session.tags,
            attendees: session.attendees,
            fullTranscript: session.transcript ?? "",
            aiSummary: session.aiSummary ?? ""
        )
        context.insert(note)

        for structured in session.notes {
            note.insights.append(contentsOf: structured.insights)

            for item in structured.actionItems {
                let action = NoteAction(
                    id: item.id,
                    title: item.title,
                    detail: item.description,
                    assignee: item.assignee,
                    dueDate: item.dueDate,
                    priority: NotePriority(rawValue: item.priority.rawValue) ?? .medium,
                    status: ActionStatus(rawValue: item.status.rawValue) ?? .pending,
                    createdAt: item.createdAt,
                    completedAt: item.completedAt,
                    estimatedEffortHours: item.estimatedEffort,
                    tags: item.tags
                )
                action.note = note
                context.insert(action)
            }

            for decision in structured.decisions {
                let mapped = NoteDecision(
                    id: decision.id,
                    title: decision.title,
                    detail: decision.description,
                    decisionMaker: decision.decisionMaker,
                    rationale: decision.rationale,
                    impact: decision.impact,
                    date: decision.date,
                    followUpRequired: decision.followUpRequired,
                    followUpDate: decision.followUpDate
                )
                mapped.note = note
                context.insert(mapped)
            }
        }
    }
}
