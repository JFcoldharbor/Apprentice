//
//  AttendeeRoster.swift
//  Apprentice
//
//  Layer 3 (Services) — the founder's running roster of people he meets with.
//  Backs the "checkmark whose involved" picker: names are remembered (UserDefaults)
//  the first time they're used, and unioned with everyone seen across past
//  sessions, so the next time he schedules he just checks them off.
//

import Foundation

enum AttendeeRoster {
    private static let key = "attendee_roster_v1"

    /// All known attendee names, de-duplicated and sorted, drawn from the saved
    /// roster plus everyone who has appeared in a past session.
    @MainActor
    static func remembered() -> [String] {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        let fromSessions = SessionManager.shared.sessions.flatMap { $0.attendees } +
            SessionManager.shared.scheduled.flatMap { $0.attendees }
        let cleaned = (saved + fromSessions)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Persist any newly-typed names so they show up as checkable chips next time.
    static func remember(_ names: [String]) {
        var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { saved.insert(trimmed) }
        }
        UserDefaults.standard.set(Array(saved), forKey: key)
    }
}
