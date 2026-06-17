//
//  SessionManager.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//
//  Layer 4: Core Services — session management.
//
//  REPOINTED onto the SwiftData note stack: `sessions` is now a read-only
//  PROJECTION of the persisted `Note` records (see NoteSessionProjection.swift),
//  not a UserDefaults blob. Every original screen still binds to
//  `SessionManager.shared.sessions` and its method signatures are unchanged, so
//  the UI is untouched — but the data is now real, enriched (Claude), and
//  audio-retained. Writes go to SwiftData; a ModelContext.didSave observer keeps
//  `sessions` live (covers async enrichment writes from the capture pipeline).
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// A pre-staged upcoming session shown in the Sessions "Upcoming" list.
struct ScheduledSession: Identifiable, Equatable {
    let id: UUID
    var title: String
    var type: NoteType
    var attendees: [String]
    var scheduledFor: Date
}

@MainActor
class SessionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SessionManager()

    // MARK: - Published Properties

    @Published var sessions: [ExecutiveSession] = []
    @Published var scheduled: [ScheduledSession] = []   // pre-staged upcoming sessions
    @Published var isLoading = false
    @Published var lastError: String?

    // MARK: - Private Properties

    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var saveObserver: AnyCancellable?
    private var refreshScheduled = false

    // MARK: - Initialization

    private init() {
        context = NoteStore.mainContext
        setupCoders()
        refresh()
        // Re-project whenever SwiftData saves anywhere — new recordings, async
        // AI enrichment, deletions, migration — so the read screens stay live
        // with zero view edits.
        saveObserver = NotificationCenter.default
            .publisher(for: ModelContext.didSave)
            .sink { [weak self] _ in
                Task { @MainActor in self?.scheduleRefresh() }
            }
    }

    private func setupCoders() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Projection

    /// Public hook for callers that mutate notes outside SessionManager and want
    /// an immediate refresh (the didSave observer normally handles this).
    func notesDidChange() { refresh() }

    /// Coalesce a burst of saves into a single projection pass.
    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        Task { @MainActor in
            self.refreshScheduled = false
            self.refresh()
        }
    }

    private func refresh() {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let notes = try context.fetch(descriptor)
            // Pre-staged sessions live in their own "Upcoming" list; the archive is
            // everything that's actually been (or is being) recorded.
            sessions = notes.filter { $0.status != .scheduled }.map { $0.asExecutiveSession() }
            scheduled = notes.filter { $0.status == .scheduled }
                .map {
                    ScheduledSession(
                        id: $0.id, title: $0.title, type: $0.type,
                        attendees: $0.attendees, scheduledFor: $0.scheduledFor ?? $0.createdAt
                    )
                }
                .sorted { $0.scheduledFor < $1.scheduledFor }
        } catch {
            lastError = "Failed to load notes: \(error.localizedDescription)"
            sessions = []
            scheduled = []
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            lastError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func note(withId id: UUID) -> Note? {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Session Management

    func addSession(_ session: ExecutiveSession) {
        let note = session.makeNote()
        context.insert(note)
        save()
        refresh()
        print("📝 Added session: \(session.title)")
    }

    func updateSession(_ session: ExecutiveSession) {
        guard let note = note(withId: session.id) else { return }
        note.title = session.title
        note.duration = session.duration
        note.type = NoteType(rawValue: session.type.rawValue) ?? note.type
        note.priority = NotePriority(rawValue: session.priority.rawValue) ?? note.priority
        note.status = NoteStatus(rawValue: session.status.rawValue) ?? note.status
        note.tags = session.tags
        note.attendees = session.attendees
        if let t = session.transcript { note.fullTranscript = t }
        if let s = session.aiSummary { note.aiSummary = s }
        note.insights = session.notes.flatMap { $0.insights }
        note.updatedAt = Date()
        save()
        refresh()
        print("✏️ Updated session: \(session.title)")
    }

    func deleteSession(withId id: UUID) {
        guard let note = note(withId: id) else { return }
        let title = note.title
        AriaMirror.shared.deleteNote(noteId: note.id.uuidString)  // forget it in shared memory too (web War Room)
        AudioFileStore.shared.deleteFiles(for: note)   // retained audio removed only on delete
        context.delete(note)
        save()
        refresh()
        print("🗑️ Deleted session: \(title)")
    }

    func deleteSession(_ session: ExecutiveSession) {
        deleteSession(withId: session.id)
    }

    func getSession(withId id: UUID) -> ExecutiveSession? {
        return sessions.first { $0.id == id }
    }

    // MARK: - Computed Properties

    var totalSessions: Int {
        sessions.count
    }

    var todaysSessions: [ExecutiveSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()

        return sessions.filter { session in
            session.date >= today && session.date < tomorrow
        }
    }

    var recentSessions: [ExecutiveSession] {
        Array(sessions.prefix(5))
    }

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Session Creation Helpers

    func createNewSession(
        title: String,
        type: ExecutiveSession.MeetingType,
        attendees: [String] = []
    ) -> ExecutiveSession {
        let note = Note(
            title: title,
            type: NoteType(rawValue: type.rawValue) ?? .general,
            status: .scheduled,
            attendees: attendees
        )
        context.insert(note)
        save()
        refresh()
        return note.asExecutiveSession()
    }

    // MARK: - Scheduled / pre-staged sessions

    /// Stage an upcoming session (manual add or Aria). Persists locally as a
    /// `.scheduled` Note and mirrors it to the shared list (web War Room sees it).
    @discardableResult
    func schedule(title: String, type: NoteType, attendees: [String], scheduledFor: Date) -> ScheduledSession {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = Note(
            title: cleanTitle.isEmpty ? "\(type.displayName)" : cleanTitle,
            type: type,
            status: .scheduled,
            attendees: attendees
        )
        note.scheduledFor = scheduledFor
        context.insert(note)
        save()
        refresh()
        AttendeeRoster.remember(attendees)
        AriaMirror.shared.upsertScheduledSession(
            id: note.id.uuidString, title: note.title, type: type.rawValue,
            attendees: attendees, scheduledFor: scheduledFor
        )
        return ScheduledSession(id: note.id, title: note.title, type: type, attendees: attendees, scheduledFor: scheduledFor)
    }

    /// Remove a staged session (cancelled) from local + shared list.
    func cancelScheduled(id: UUID) {
        guard let note = note(withId: id) else { return }
        AriaMirror.shared.deleteScheduledSession(id: note.id.uuidString)
        context.delete(note)
        save()
        refresh()
    }

    /// Begin recording from a staged session: returns its prefill and removes the
    /// staged record (the live recording creates its own Note).
    func startScheduled(id: UUID) -> RecordPrefill? {
        guard let note = note(withId: id) else { return nil }
        let prefill = RecordPrefill(title: note.title, type: note.type, attendees: note.attendees)
        AriaMirror.shared.deleteScheduledSession(id: note.id.uuidString)
        context.delete(note)
        save()
        refresh()
        return prefill
    }

    /// Pull the shared upcoming list and materialize any sessions (e.g. created by
    /// Aria on the web) that aren't already staged locally. Add-only merge.
    func syncScheduledFromCloud() async {
        let remote = await AriaMirror.shared.fetchScheduledSessions()
        var changed = false
        for r in remote where UUID(uuidString: r.id) != nil {
            let uuid = UUID(uuidString: r.id)!
            guard note(withId: uuid) == nil else { continue }
            let note = Note(
                id: uuid, title: r.title,
                type: NoteType(rawValue: r.type) ?? .general,
                status: .scheduled, attendees: r.attendees
            )
            note.scheduledFor = r.scheduledFor
            context.insert(note)
            changed = true
        }
        if changed { save(); refresh() }
    }

    /// Materialize a single scheduled session that Aria just created on this phone
    /// (returned by /chat), keeping the same id as the shared record.
    func ingestScheduled(id: String, title: String, type: String, attendees: [String], scheduledFor: Date) {
        guard let uuid = UUID(uuidString: id), note(withId: uuid) == nil else { return }
        let note = Note(
            id: uuid, title: title,
            type: NoteType(rawValue: type) ?? .general,
            status: .scheduled, attendees: attendees
        )
        note.scheduledFor = scheduledFor
        context.insert(note)
        save()
        refresh()
    }

    // MARK: - Analysis (enrichment) — also mirrors the summary to the shared Aria
    // memory, so an analyzed session becomes visible to the web War Room's Aria.

    /// (Re)run Claude analysis for one session. Force regenerates even if a
    /// summary already exists. Returns true if a summary was produced.
    @discardableResult
    func analyze(sessionId: UUID) async -> Bool {
        guard let note = note(withId: sessionId) else { return false }
        let ok = await NoteEnrichmentService.enrich(note, context: context, force: true)
        refresh()
        return ok
    }

    /// Catch-up: any completed session that has a transcript but no AI summary
    /// (enrichment failed mid-flight, the app was closed, the proxy hiccuped) gets
    /// analyzed now — which also mirrors it to the shared memory. Idempotent.
    func enrichPendingSessions() async {
        let all = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        // Heal stale recordings: a note left .inProgress (app closed/crashed mid-
        // record, or a hung transcription segment) can never analyze on its own.
        // On launch there's no active capture, so finalize them so they can be
        // analyzed and synced like any other session.
        var healed = false
        for note in all where note.status == .inProgress {
            note.status = .completed
            note.updatedAt = Date()
            healed = true
        }
        if healed { save() }

        // Analyze anything completed with a transcript but no summary — ignoring a
        // possibly-stuck chunk (on launch a "processing" chunk is just stale).
        let pending = all.filter {
            $0.status == .completed &&
            $0.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !$0.fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for note in pending {
            _ = await NoteEnrichmentService.enrich(note, context: context)
        }
        if healed || !pending.isEmpty { refresh() }
    }

    /// Backfill: re-mirror EVERY analyzed session to the shared memory (idempotent
    /// upsert). Heals sessions whose mirror was previously missed — e.g. analyzed
    /// before the mirror worked, or a failed/offline POST — so web Aria ends up
    /// with the complete set of debriefs, not just the most recent ones.
    func syncAnalyzedSessions() {
        let all = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        // Any session that HAS a summary gets mirrored — regardless of status, so a
        // stuck/.inProgress-but-analyzed session is no longer skipped.
        for note in all where !note.aiSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AriaMirror.shared.mirrorNote(from: note)
        }
    }

    func addNoteToSession(sessionId: UUID, note structured: StructuredNote) {
        guard let note = note(withId: sessionId) else { return }
        note.insights.append(contentsOf: structured.insights)
        let newActions = structured.actionItems.map { $0.makeNoteAction() }
        let newDecisions = structured.decisions.map { $0.makeNoteDecision() }
        note.actions.append(contentsOf: newActions)
        note.decisions.append(contentsOf: newDecisions)
        note.updatedAt = Date()
        save()
        refresh()
        print("📝 Added note to session: \(note.title)")
    }

    func updateSessionDuration(sessionId: UUID, duration: TimeInterval) {
        guard let note = note(withId: sessionId) else { return }
        note.duration = duration
        note.updatedAt = Date()
        save()
        refresh()
    }

    // MARK: - Search and Filter

    func searchSessions(query: String) -> [ExecutiveSession] {
        guard !query.isEmpty else { return sessions }

        return sessions.filter { session in
            session.title.localizedCaseInsensitiveContains(query) ||
            session.attendees.contains { $0.localizedCaseInsensitiveContains(query) } ||
            session.notes.contains { note in
                note.title.localizedCaseInsensitiveContains(query) ||
                note.content.localizedCaseInsensitiveContains(query)
            }
        }
    }

    func sessionsByType(_ type: ExecutiveSession.MeetingType) -> [ExecutiveSession] {
        sessions.filter { $0.type == type }
    }

    func sessionsByPriority(_ priority: ExecutiveSession.Priority) -> [ExecutiveSession] {
        sessions.filter { $0.priority == priority }
    }

    func sessionsByDateRange(from startDate: Date, to endDate: Date) -> [ExecutiveSession] {
        sessions.filter { session in
            session.date >= startDate && session.date <= endDate
        }
    }

    // MARK: - Analytics

    func averageSessionDuration() -> TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        return totalDuration / Double(sessions.count)
    }

    func sessionsByMonth() -> [String: Int] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"

        return Dictionary(grouping: sessions) { session in
            formatter.string(from: session.date)
        }.mapValues { $0.count }
    }

    func sessionsByWeek() -> [String: Int] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"

        return Dictionary(grouping: sessions) { session in
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            return formatter.string(from: startOfWeek)
        }.mapValues { $0.count }
    }

    func mostCommonMeetingType() -> ExecutiveSession.MeetingType? {
        let typeCounts = Dictionary(grouping: sessions) { $0.type }
        return typeCounts.max { $0.value.count < $1.value.count }?.key
    }

    func completionRate() -> Double {
        return actionItemCompletionRate()
    }

    func totalActionItems() -> Int {
        sessions.reduce(0) { total, session in
            total + session.notes.reduce(0) { $0 + $1.actionItems.count }
        }
    }

    func completedActionItems() -> Int {
        sessions.reduce(0) { total, session in
            total + session.notes.reduce(0) { noteTotal, note in
                noteTotal + note.actionItems.filter { $0.status == .completed }.count
            }
        }
    }

    func actionItemCompletionRate() -> Double {
        let total = totalActionItems()
        guard total > 0 else { return 0.0 }
        return Double(completedActionItems()) / Double(total)
    }

    // MARK: - Bulk Operations

    func deleteAllSessions() {
        let descriptor = FetchDescriptor<Note>()
        if let notes = try? context.fetch(descriptor) {
            for note in notes {
                AudioFileStore.shared.deleteFiles(for: note)
                context.delete(note)
            }
            save()
            refresh()
        }
        print("🗑️ Cleared all sessions")
    }

    func exportSessions() -> Data? {
        do {
            return try encoder.encode(sessions)
        } catch {
            print("❌ Failed to export sessions: \(error)")
            lastError = "Failed to export sessions"
            return nil
        }
    }

    func importSessions(from data: Data) {
        do {
            let importedSessions = try decoder.decode([ExecutiveSession].self, from: data)
            for importedSession in importedSessions where note(withId: importedSession.id) == nil {
                context.insert(importedSession.makeNote())
            }
            save()
            refresh()
            print("📥 Imported \(importedSessions.count) sessions")
        } catch {
            print("❌ Failed to import sessions: \(error)")
            lastError = "Failed to import sessions"
        }
    }

    // MARK: - Validation

    func validateSession(_ session: ExecutiveSession) -> [String] {
        var errors: [String] = []

        if session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Session title cannot be empty")
        }

        if session.duration < 0 {
            errors.append("Session duration cannot be negative")
        }

        if session.attendees.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append("Attendee names cannot be empty")
        }

        return errors
    }

    // MARK: - Convenience Methods

    func hasSessionsToday() -> Bool {
        !todaysSessions.isEmpty
    }

    func upcomingSessions(limit: Int = 5) -> [ExecutiveSession] {
        let now = Date()
        return sessions
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func overdueActionItems() -> [ActionItem] {
        let now = Date()
        return sessions.flatMap { session in
            session.notes.flatMap { note in
                note.actionItems.filter { actionItem in
                    guard let dueDate = actionItem.dueDate else { return false }
                    return dueDate < now && actionItem.status != .completed
                }
            }
        }
    }
}
