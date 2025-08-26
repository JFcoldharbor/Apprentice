//
//  SessionManager.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  SessionManager.swift
//  Apprentice
//
//  Layer 4: Core Services - Session management and persistence
//  Handles CRUD operations for executive sessions with UserDefaults storage
//

import Foundation
import SwiftUI

@MainActor
class SessionManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SessionManager()
    
    // MARK: - Published Properties
    
    @Published var sessions: [ExecutiveSession] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private let storageKey = "ExecutiveSessions"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    private init() {
        setupCoders()
        loadSessions()
    }
    
    private func setupCoders() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Session Management
    
    func addSession(_ session: ExecutiveSession) {
        sessions.append(session)
        saveSessions()
        print("ðŸ“ Added session: \(session.title)")
    }
    
    func updateSession(_ session: ExecutiveSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions()
            print("âœï¸ Updated session: \(session.title)")
        }
    }
    
    func deleteSession(withId id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            let title = sessions[index].title
            sessions.remove(at: index)
            saveSessions()
            print("ðŸ—‘ï¸ Deleted session: \(title)")
        }
    }
    
    func deleteSession(_ session: ExecutiveSession) {
        deleteSession(withId: session.id)
    }
    
    func getSession(withId id: UUID) -> ExecutiveSession? {
        return sessions.first { $0.id == id }
    }
    
    // MARK: - Computed Properties
    
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
    
    // MARK: - Storage Methods
    
    private func loadSessions() {
        print("ðŸ“š Loading sessions...")
        
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("ðŸ“š No saved sessions found")
            sessions = [] // Start with empty array
            return
        }
        
        do {
            sessions = try decoder.decode([ExecutiveSession].self, from: data)
            print("ðŸ“š Loaded \(sessions.count) sessions")
        } catch {
            print("âŒ Failed to load sessions: \(error)")
            lastError = "Failed to load sessions"
            sessions = [] // Start with empty array on error
        }
    }
    
    private func saveSessions() {
        do {
            let data = try encoder.encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("ðŸ’¾ Saved \(sessions.count) sessions")
        } catch {
            print("âŒ Failed to save sessions: \(error)")
            lastError = "Failed to save sessions"
        }
    }
    
    // MARK: - Session Creation Helpers
    
    func createNewSession(
        title: String,
        type: ExecutiveSession.MeetingType,
        attendees: [String] = []
    ) -> ExecutiveSession {
        let session = ExecutiveSession(
            id: UUID(),
            title: title,
            date: Date(),
            duration: 0, // Will be updated when session ends
            type: type,
            priority: .medium,
            notes: [],
            attendees: attendees
        )
        
        addSession(session)
        return session
    }
    
    func addNoteToSession(sessionId: UUID, note: StructuredNote) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].notes.append(note)
            saveSessions()
            print("ðŸ“ Added note to session: \(sessions[index].title)")
        }
    }
    
    func updateSessionDuration(sessionId: UUID, duration: TimeInterval) {
        // Note: duration is 'let' in current ExecutiveSession model
        // This method would need ExecutiveSession to have 'var duration' to work
        // For now, this is a placeholder method
        print("â±ï¸ Note: Cannot update duration - property is immutable in current model")
    }
    
    // Note: SessionStatus not in current ExecutiveSession model
    // Removed updateSessionStatus method
    
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
    
    // Note: SessionStatus not in current ExecutiveSession model
    // Removed sessionsByStatus method
    
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
        // Note: No status field in current ExecutiveSession model
        // Calculate completion based on action item completion instead
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
        sessions.removeAll()
        saveSessions()
        print("ðŸ—‘ï¸ Cleared all sessions")
    }
    
    func exportSessions() -> Data? {
        do {
            return try encoder.encode(sessions)
        } catch {
            print("âŒ Failed to export sessions: \(error)")
            lastError = "Failed to export sessions"
            return nil
        }
    }
    
    func importSessions(from data: Data) {
        do {
            let importedSessions = try decoder.decode([ExecutiveSession].self, from: data)
            
            // Merge with existing sessions, avoiding duplicates
            for importedSession in importedSessions {
                if !sessions.contains(where: { $0.id == importedSession.id }) {
                    sessions.append(importedSession)
                }
            }
            
            saveSessions()
            print("ðŸ“¥ Imported \(importedSessions.count) sessions")
        } catch {
            print("âŒ Failed to import sessions: \(error)")
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
            .filter { $0.date > now } // Note: No status field in current model
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