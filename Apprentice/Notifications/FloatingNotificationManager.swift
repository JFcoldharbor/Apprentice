//
//  FloatingNotificationManager.swift
//  Stitch Executive AI
//
//  Layer 6: Coordination - Enhanced notification manager with Calendar & Email integration
//  Connects real calendar events and email actions to floating notification cards
//

import Foundation
import SwiftUI
import EventKit

@MainActor
class FloatingNotificationManager: ObservableObject {
    @Published var activeNotifications: [ActiveNotification] = []
    
    // MARK: - Service Dependencies
    
    private var sessionManager: SessionManager?
    private var profileManager: FounderProfileManager?
    private var calendarIntegration: CalendarIntegration?
    private var emailService: EmailService?
    private var memoryInsights: [MemoryInsight] = []
    
    // MARK: - State Management
    
    private var notificationTimer: Timer?
    private var calendarTimer: Timer?
    private var emailTimer: Timer?
    
    struct ActiveNotification: Identifiable {
        let id = UUID()
        let data: NotificationCardData
        let tier: NotificationTier
        let createdAt = Date()
        let source: NotificationSource
        
        enum NotificationSource {
            case calendar
            case email
            case session
            case ai
            case system
        }
    }
    
    func initialize(
        sessionManager: SessionManager,
        profileManager: FounderProfileManager,
        memoryInsights: [MemoryInsight],
        calendarIntegration: CalendarIntegration? = nil,
        emailService: EmailService? = nil
    ) {
        self.sessionManager = sessionManager
        self.profileManager = profileManager
        self.memoryInsights = memoryInsights
        self.calendarIntegration = calendarIntegration
        self.emailService = emailService
    }
    
    func startNotificationFlow() {
        // Start general notifications
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.spawnGeneralNotification()
            }
        }
        
        // Start calendar monitoring
        startCalendarNotifications()
        
        // Start email monitoring
        startEmailNotifications()
    }
    
    func stopNotificationFlow() {
        notificationTimer?.invalidate()
        calendarTimer?.invalidate()
        emailTimer?.invalidate()
        notificationTimer = nil
        calendarTimer = nil
        emailTimer = nil
    }
    
    func refreshNotifications() {
        spawnGeneralNotification()
        checkCalendarEvents()
        checkPendingEmails()
    }
    
    // MARK: - Calendar Integration
    
    private func startCalendarNotifications() {
        calendarTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkCalendarEvents()
        }
    }
    
    private func checkCalendarEvents() {
        guard let calendar = calendarIntegration,
              calendar.hasCalendarAccess else { return }
        
        Task {
            await calendar.loadUpcomingMeetings()
            
            await MainActor.run {
                let upcomingEvents = calendar.upcomingMeetings
                
                for event in upcomingEvents {
                    let timeUntilEvent = event.startDate.timeIntervalSinceNow
                    
                    // Notify 15 minutes before
                    if timeUntilEvent > 0 && timeUntilEvent <= 900 { // 15 minutes
                        createCalendarNotification(for: event, timeRemaining: Int(timeUntilEvent / 60))
                    }
                    // Notify 1 hour before for important meetings
                    else if timeUntilEvent > 0 && timeUntilEvent <= 3600 && event.isImportant {
                        createCalendarNotification(for: event, timeRemaining: Int(timeUntilEvent / 60))
                    }
                }
            }
        }
    }
    
    private func createCalendarNotification(for event: CalendarEvent, timeRemaining: Int) {
        let tier: NotificationTier = timeRemaining <= 15 ? .critical : .important
        let timeText = timeRemaining <= 1 ? "now" : "in \(timeRemaining) min"
        
        let notification = ActiveNotification(
            data: NotificationCardData(
                message: "\(event.title) starting \(timeText)",
                icon: "calendar.badge.exclamationmark"
            ) {
                self.handleCalendarTap(event: event)
            },
            tier: tier,
            source: .calendar
        )
        
        // Avoid duplicate notifications
        if !activeNotifications.contains(where: {
            $0.data.message.contains(event.title) && $0.source == .calendar
        }) {
            activeNotifications.append(notification)
            
            // Auto-remove after display time
            DispatchQueue.main.asyncAfter(deadline: .now() + tier.displayDuration) {
                self.activeNotifications.removeAll { $0.id == notification.id }
            }
        }
    }
    
    private func handleCalendarTap(event: CalendarEvent) {
        print("Calendar notification tapped for: \(event.title)")
        // Could navigate to calendar view, create session, etc.
        
        // Create coaching session from meeting
        if let sessionManager = sessionManager {
            let newSession = ExecutiveSession.createFromCalendarEvent(event)
            sessionManager.addSession(newSession)
        }
    }
    
    // MARK: - Email Integration
    
    private func startEmailNotifications() {
        emailTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPendingEmails()
            }
        }
    }
    
    private func checkPendingEmails() {
        guard let emailService = emailService else { return }
        
        // Check for pending session summaries
        if let sessionManager = sessionManager {
            let recentSessions = sessionManager.sessions.suffix(3)
            
            for session in recentSessions {
                if session.needsEmailSummary && emailService.canSendEmail() {
                    createEmailNotification(for: session)
                }
            }
        }
        
        // Check for email configuration issues
        if !emailService.canSendEmail() {
            createEmailConfigNotification()
        }
    }
    
    private func createEmailNotification(for session: ExecutiveSession) {
        let notification = ActiveNotification(
            data: NotificationCardData(
                message: "Send summary for \(session.title)?",
                icon: "envelope.badge"
            ) {
                self.handleEmailTap(session: session)
            },
            tier: .contextual,
            source: .email
        )
        
        // Avoid duplicates
        if !activeNotifications.contains(where: {
            $0.data.message.contains(session.title) && $0.source == .email
        }) {
            activeNotifications.append(notification)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                self.activeNotifications.removeAll { $0.id == notification.id }
            }
        }
    }
    
    private func createEmailConfigNotification() {
        let notification = ActiveNotification(
            data: NotificationCardData(
                message: "Email setup required for summaries",
                icon: "envelope.badge.exclamationmark"
            ) {
                self.handleEmailConfigTap()
            },
            tier: .important,
            source: .email
        )
        
        activeNotifications.append(notification)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.activeNotifications.removeAll { $0.id == notification.id }
        }
    }
    
    private func handleEmailTap(session: ExecutiveSession) {
        print("Email notification tapped for session: \(session.title)")
        // Trigger email compose view
        NotificationCenter.default.post(
            name: NSNotification.Name("ComposeSessionEmail"),
            object: session
        )
    }
    
    private func handleEmailConfigTap() {
        print("Email config notification tapped")
        // Navigate to email settings
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowEmailSettings"),
            object: nil
        )
    }
    
    // MARK: - General Notifications
    
    private func spawnGeneralNotification() {
        let mockNotifications = [
            ActiveNotification(
                data: NotificationCardData(
                    message: "AI coaching insights ready",
                    icon: "brain.head.profile"
                ) { print("AI insights tapped") },
                tier: .contextual,
                source: .ai
            ),
            ActiveNotification(
                data: NotificationCardData(
                    message: "Document analysis complete",
                    icon: "doc.text.magnifyingglass"
                ) { print("Document analysis tapped") },
                tier: .contextual,
                source: .system
            ),
            ActiveNotification(
                data: NotificationCardData(
                    message: "Weekly report available",
                    icon: "chart.bar.doc.horizontal"
                ) { print("Weekly report tapped") },
                tier: .contextual,
                source: .system
            )
        ]
        
        if let notification = mockNotifications.randomElement() {
            activeNotifications.append(notification)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                self.activeNotifications.removeAll { $0.id == notification.id }
            }
        }
    }
    
    deinit {
        Task { @MainActor in
            stopNotificationFlow()
        }
    }
}

// MARK: - Extensions

extension NotificationTier {
    var displayDuration: Double {
        switch self {
        case .critical: return 10.0
        case .important: return 8.0
        case .contextual: return 6.0
        }
    }
}

extension CalendarEvent {
    var isImportant: Bool {
        // Determine importance based on attendees, keywords, etc.
        return attendees.count > 3 ||
               title.lowercased().contains("board") ||
               title.lowercased().contains("exec") ||
               title.lowercased().contains("important")
    }
}

extension ExecutiveSession {
    static func createFromCalendarEvent(_ event: CalendarEvent) -> ExecutiveSession {
        return ExecutiveSession(
            id: UUID(),
            title: event.title,
            date: event.startDate,
            duration: event.duration,
            type: .teamMeeting, // Could be smarter based on event details
            priority: .medium,
            notes: [], // Empty notes array initially
            attendees: event.attendees
        )
    }
    
    var needsEmailSummary: Bool {
        // Logic to determine if session needs email summary
        // Check if session has completed action items and was recent
        let hasActionItems = notes.contains { !$0.actionItems.isEmpty }
        let isRecent = Date().timeIntervalSince(date) < 3600 // Within 1 hour
        
        return hasActionItems && isRecent
    }
}
