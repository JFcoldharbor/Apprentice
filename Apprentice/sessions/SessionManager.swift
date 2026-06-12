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

@MainActor
class SessionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SessionManager()

    // MARK: - Published Properties

    @Published var sessions: [ExecutiveSession] = []
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
            sessions = notes.map { $0.asExecutiveSession() }
        } catch {
            lastError = "Failed to load notes: \(error.localizedDescription)"
            sessions = []
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
