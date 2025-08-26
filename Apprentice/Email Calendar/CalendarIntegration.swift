//
//  CalendarIntegration.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  CalendarIntegration.swift
//  My CeO
//
//  Created by James Garmon on 8/21/25.
//


//
//  CalendarIntegration.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Calendar integration for executive scheduling
//  Automatically schedule coaching sessions and track meetings
//

import Foundation
import EventKit
import SwiftUI

@MainActor
class CalendarIntegration: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var hasCalendarAccess = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var upcomingMeetings: [CalendarEvent] = []
    @Published var suggestedCoachingSessions: [CoachingSessionSuggestion] = []
    
    // MARK: - Private Properties
    
    private let eventStore = EKEventStore()
    private let sessionManager = SessionManager.shared
    private let profileManager = FounderProfileManager.shared
    
    // MARK: - Singleton
    
    static let shared = CalendarIntegration()
    
    private init() {
        checkCalendarAccess()
    }
    
    // MARK: - Calendar Access Management
    
    func requestCalendarAccess() async {
        isLoading = true
        errorMessage = nil
        
        if #available(iOS 17.0, *) {
            // iOS 17+ - Full access API
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                hasCalendarAccess = granted
                
                if granted {
                    await loadUpcomingMeetings()
                    await generateCoachingSuggestions()
                    print("Ã¢Å“â€¦ Calendar access granted (iOS 17+)")
                } else {
                    errorMessage = "Calendar access denied. Please enable in Settings."
                    print("Ã¢ÂÅ’ Calendar access denied")
                }
            } catch {
                errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
                print("Ã¢ÂÅ’ Calendar access error: \(error)")
            }
        } else {
            // iOS 16 and earlier - Legacy API
            let status = EKEventStore.authorizationStatus(for: .event)
            
            if status == .notDetermined {
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    Task { @MainActor in
                        guard let self = self else { return }
                        
                        self.hasCalendarAccess = granted
                        
                        if granted {
                            await self.loadUpcomingMeetings()
                            await self.generateCoachingSuggestions()
                            print("Ã¢Å“â€¦ Calendar access granted (iOS 16)")
                        } else {
                            self.errorMessage = error?.localizedDescription ?? "Calendar access denied"
                            print("Ã¢ÂÅ’ Calendar access denied: \(error?.localizedDescription ?? "Unknown")")
                        }
                    }
                }
            } else {
                hasCalendarAccess = (status == .authorized)
                if hasCalendarAccess {
                    await loadUpcomingMeetings()
                    await generateCoachingSuggestions()
                }
            }
        }
        
        isLoading = false
    }
    
    private func checkCalendarAccess() {
        if #available(iOS 17.0, *) {
            // iOS 17+ authorization status
            let status = EKEventStore.authorizationStatus(for: .event)
            
            switch status {
            case .fullAccess:
                hasCalendarAccess = true
                Task {
                    await loadUpcomingMeetings()
                    await generateCoachingSuggestions()
                }
            case .denied, .restricted:
                hasCalendarAccess = false
                errorMessage = "Calendar access is required for scheduling features"
            case .notDetermined:
                hasCalendarAccess = false
            case .writeOnly:
                hasCalendarAccess = false
                errorMessage = "Full calendar access is required"
            @unknown default:
                hasCalendarAccess = false
            }
        } else {
            // iOS 16 and earlier authorization status
            let status = EKEventStore.authorizationStatus(for: .event)
            
            switch status {
            case .authorized:
                hasCalendarAccess = true
                Task {
                    await loadUpcomingMeetings()
                    await generateCoachingSuggestions()
                }
            case .denied, .restricted:
                hasCalendarAccess = false
                errorMessage = "Calendar access is required for scheduling features"
            case .notDetermined:
                hasCalendarAccess = false
            @unknown default:
                hasCalendarAccess = false
            }
        }
    }
    
    // MARK: - Meeting Detection & Loading
    
    func loadUpcomingMeetings() async {
        guard hasCalendarAccess else { return }
        
        isLoading = true
        
        let calendar = Calendar.current
        let startDate = Date()
        let endDate = calendar.date(byAdding: .weekOfYear, value: 2, to: startDate) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Filter for business meetings (not personal events)
        let businessEvents = events.filter { event in
            isBusinessMeeting(event)
        }
        
        upcomingMeetings = businessEvents.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled Meeting",
                startDate: event.startDate,
                endDate: event.endDate,
                attendees: event.attendees?.compactMap { $0.name } ?? [],
                location: event.location,
                notes: event.notes,
                isAllDay: event.isAllDay,
                meetingType: detectMeetingType(from: event)
            )
        }.sorted { $0.startDate < $1.startDate }
        
        isLoading = false
        print("Ã°Å¸â€œâ€¦ Loaded \(upcomingMeetings.count) upcoming meetings")
    }
    
    private func isBusinessMeeting(_ event: EKEvent) -> Bool {
        let title = event.title?.lowercased() ?? ""
        let businessKeywords = [
            "meeting", "call", "standup", "review", "planning", "strategy",
            "sync", "check-in", "1:1", "interview", "demo", "presentation",
            "board", "team", "client", "customer", "vendor", "partner"
        ]
        
        // Has attendees (not personal event)
        if let attendees = event.attendees, attendees.count > 1 {
            return true
        }
        
        // Contains business keywords
        return businessKeywords.contains { keyword in
            title.contains(keyword)
        }
    }
    
    private func detectMeetingType(from event: EKEvent) -> ExecutiveSession.MeetingType {
        let title = event.title?.lowercased() ?? ""
        let attendeeCount = event.attendees?.count ?? 0
        
        if title.contains("board") {
            return .boardMeeting
        } else if title.contains("client") || title.contains("customer") {
            return .clientCall
        } else if title.contains("strategy") || title.contains("planning") {
            return .strategySession
        } else if title.contains("1:1") || attendeeCount <= 2 {
            return .oneOnOne
        } else {
            return .teamMeeting
        }
    }
    
    // MARK: - Coaching Session Scheduling
    
    func generateCoachingSuggestions() async {
        guard hasCalendarAccess else { return }
        
        // Analyze meeting patterns and suggest coaching sessions
        let suggestions = await analyzeScheduleForCoaching()
        suggestedCoachingSessions = suggestions
        
        print("Ã°Å¸Â¤â€“ Generated \(suggestions.count) coaching suggestions")
    }
    
    private func analyzeScheduleForCoaching() async -> [CoachingSessionSuggestion] {
        var suggestions: [CoachingSessionSuggestion] = []
        
        // Suggest weekly coaching sessions
        if shouldSuggestWeeklyCoaching() {
            suggestions.append(
                CoachingSessionSuggestion(
                    type: .weekly,
                    suggestedDate: findBestTimeForCoaching(),
                    reason: "Weekly executive coaching to review progress and plan ahead",
                    priority: .high,
                    duration: 30 * 60, // 30 minutes
                    relatedMeeting: nil
                )
            )
        }
        
        // Suggest pre-meeting preparation
        for meeting in upcomingMeetings.prefix(3) {
            if shouldSuggestPreMeetingCoaching(for: meeting) {
                let prepTime = Calendar.current.date(byAdding: .hour, value: -1, to: meeting.startDate) ?? meeting.startDate
                
                suggestions.append(
                    CoachingSessionSuggestion(
                        type: .preMeeting,
                        suggestedDate: prepTime,
                        reason: "Prepare for \(meeting.title) - strategic planning and key talking points",
                        priority: .medium,
                        duration: 15 * 60, // 15 minutes
                        relatedMeeting: meeting
                    )
                )
            }
        }
        
        // Suggest post-meeting follow-up
        let recentSessions = sessionManager.sessions.filter { session in
            Calendar.current.isDate(session.date, inSameDayAs: Date())
        }
        
        if !recentSessions.isEmpty {
            suggestions.append(
                CoachingSessionSuggestion(
                    type: .followUp,
                    suggestedDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                    reason: "Follow-up on today's sessions - action item review and next steps",
                    priority: .medium,
                    duration: 20 * 60, // 20 minutes
                    relatedMeeting: nil
                )
            )
        }
        
        return suggestions.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }
    
    private func shouldSuggestWeeklyCoaching() -> Bool {
        // Check if user hasn't had a coaching session this week
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let thisWeekSessions = sessionManager.sessions.filter { session in
            session.date >= weekStart && session.type == .coaching
        }
        
        return thisWeekSessions.isEmpty
    }
    
    private func shouldSuggestPreMeetingCoaching(for meeting: CalendarEvent) -> Bool {
        let importantMeetingTypes: [ExecutiveSession.MeetingType] = [.boardMeeting, .clientCall, .strategySession]
        return importantMeetingTypes.contains(meeting.meetingType)
    }
    
    private func findBestTimeForCoaching() -> Date {
        // Find the best time slot for coaching (avoid conflicts)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Try 9 AM, 11 AM, 2 PM, 4 PM
        let preferredHours = [9, 11, 14, 16]
        
        for hour in preferredHours {
            if let candidateTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tomorrow) {
                if !hasConflict(at: candidateTime, duration: 30 * 60) {
                    return candidateTime
                }
            }
        }
        
        // Fallback to tomorrow at 3 PM
        return calendar.date(bySettingHour: 15, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
    
    private func hasConflict(at date: Date, duration: TimeInterval) -> Bool {
        let endDate = date.addingTimeInterval(duration)
        
        return upcomingMeetings.contains { meeting in
            let meetingStart = meeting.startDate
            let meetingEnd = meeting.endDate
            
            // Check for overlap
            return (date < meetingEnd && endDate > meetingStart)
        }
    }
    
    // MARK: - Schedule Coaching Sessions
    
    func scheduleCoachingSession(_ suggestion: CoachingSessionSuggestion) async {
        guard hasCalendarAccess else {
            errorMessage = "Calendar access required to schedule sessions"
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = suggestion.title
        event.startDate = suggestion.suggestedDate
        event.endDate = suggestion.suggestedDate.addingTimeInterval(TimeInterval(suggestion.duration))
        event.notes = suggestion.reason
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add location for coaching sessions
        event.location = "AI Coaching Session"
        
        // Set reminder 15 minutes before
        let alarm = EKAlarm(relativeOffset: -15 * 60) // 15 minutes before
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            // Create corresponding session in app
            let newSession = sessionManager.createNewSession(
                title: suggestion.title,
                type: .coaching,
                attendees: ["AI Coach"]
            )
            
            print("Ã¢Å“â€¦ Scheduled coaching session: \(suggestion.title)")
            
            // Remove from suggestions
            if let index = suggestedCoachingSessions.firstIndex(where: { $0.id == suggestion.id }) {
                suggestedCoachingSessions.remove(at: index)
            }
            
        } catch {
            errorMessage = "Failed to schedule session: \(error.localizedDescription)"
            print("Ã¢ÂÅ’ Failed to schedule session: \(error)")
        }
    }
    
    // MARK: - Meeting Session Creation
    
    func createSessionFromMeeting(_ meeting: CalendarEvent) {
        let session = ExecutiveSession(
            id: UUID(),
            title: meeting.title,
            date: meeting.startDate,
            duration: meeting.endDate.timeIntervalSince(meeting.startDate),
            type: meeting.meetingType,
            priority: .medium,
            notes: [],
            attendees: meeting.attendees
        )
        
        sessionManager.addSession(session)
        print("Ã°Å¸â€œÂ Created session from calendar meeting: \(meeting.title)")
    }
    
    // MARK: - Action Item Calendar Integration
    
    func scheduleActionItem(_ actionItem: ActionItem) async {
        guard hasCalendarAccess,
              let dueDate = actionItem.dueDate else { return }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "Ã°Å¸â€œâ€¹ " + actionItem.title
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(30 * 60) // 30 min block
        event.notes = actionItem.description
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Set reminder based on priority
        let reminderOffset: TimeInterval
        switch actionItem.priority {
        case .critical: reminderOffset = -24 * 60 * 60 // 1 day before
        case .high: reminderOffset = -4 * 60 * 60 // 4 hours before
        case .medium: reminderOffset = -60 * 60 // 1 hour before
        case .low: reminderOffset = -30 * 60 // 30 minutes before
        }
        
        let alarm = EKAlarm(relativeOffset: reminderOffset)
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("Ã°Å¸â€œâ€¦ Scheduled action item: \(actionItem.title)")
        } catch {
            print("Ã¢ÂÅ’ Failed to schedule action item: \(error)")
        }
    }
}

// MARK: - Calendar Models

struct CalendarEvent: Identifiable, Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let attendees: [String]
    let location: String?
    let notes: String?
    let isAllDay: Bool
    let meetingType: ExecutiveSession.MeetingType
    
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

struct CoachingSessionSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let suggestedDate: Date
    let reason: String
    let priority: Priority
    let duration: Int // seconds
    let relatedMeeting: CalendarEvent?
    
    enum SuggestionType {
        case weekly
        case preMeeting
        case followUp
        case strategic
        
        var title: String {
            switch self {
            case .weekly: return "Weekly Executive Coaching"
            case .preMeeting: return "Pre-Meeting Strategy Session"
            case .followUp: return "Follow-up Coaching"
            case .strategic: return "Strategic Planning Session"
            }
        }
    }
    
    enum Priority {
        case low, medium, high, critical
        
        var sortOrder: Int {
            switch self {
            case .critical: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .green
            }
        }
    }
    
    var title: String {
        return type.title
    }
}