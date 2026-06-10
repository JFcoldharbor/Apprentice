//
//  CalendarEmailIntegrationView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  CalendarEmailIntegrationView.swift
//  Apprentice
//
//  Layer 8: Views - Calendar and Email integration interface
//

import SwiftUI
import EventKit
import MessageUI

struct CalendarEmailIntegrationView: View {
    @StateObject private var calendarIntegration = CalendarIntegration.shared
    @StateObject private var emailService = EmailService()
    @StateObject private var sessionManager = SessionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingEmailComposer = false
    @State private var selectedSession: ExecutiveSession?
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        if calendarIntegration.hasCalendarAccess {
                            upcomingMeetingsSection
                            coachingSuggestionsSection
                        } else {
                            calendarPermissionSection
                        }
                        
                        emailSection
                        
                        if !sessionManager.sessions.isEmpty {
                            recentSessionsSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Calendar & Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if calendarIntegration.hasCalendarAccess {
                Task {
                    await calendarIntegration.loadUpcomingMeetings()
                    await calendarIntegration.generateCoachingSuggestions()
                }
            }
        }
        .sheet(isPresented: $showingEmailComposer) {
            if let session = selectedSession {
                EmailComposeView(session: session)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.05, green: 0.08, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var calendarPermissionSection: some View {
        VStack(spacing: 16) {
            Text("Calendar Integration")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Calendar Access Required")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Enable calendar access to automatically sync meetings, schedule coaching sessions, and create action item reminders.")
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Button("Enable Calendar Access") {
                    Task {
                        await calendarIntegration.requestCalendarAccess()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var upcomingMeetingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Meetings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(calendarIntegration.upcomingMeetings.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            if calendarIntegration.upcomingMeetings.isEmpty {
                Text("No upcoming meetings found")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(calendarIntegration.upcomingMeetings.prefix(5)) { meeting in
                    CalendarMeetingCard(meeting: meeting) {
                        calendarIntegration.createSessionFromMeeting(meeting)
                    }
                }
            }
        }
    }
    
    private var coachingSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Coaching Suggestions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await calendarIntegration.generateCoachingSuggestions()
                    }
                }
                .font(.caption)
                .foregroundColor(.cyan)
            }
            
            if calendarIntegration.suggestedCoachingSessions.isEmpty {
                Text("No coaching suggestions available")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(calendarIntegration.suggestedCoachingSessions) { suggestion in
                    CoachingSuggestionCard(suggestion: suggestion) {
                        Task {
                            await calendarIntegration.scheduleCoachingSession(suggestion)
                        }
                    }
                }
            }
        }
    }
    
    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Email Integration")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: emailService.canSendEmail ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(emailService.canSendEmail ? .green : .orange)
                    
                    Text(emailService.canSendEmail ? "Email Ready" : "Email Setup Required")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                Text(emailService.canSendEmail ?
                     "Send session summaries and action items" :
                     "Configure Mail app to send session summaries")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.subheadline)
            }
            .padding()
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Send Session Summaries")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ForEach(sessionManager.sessions.prefix(3)) { session in
                SessionEmailCard(session: session) {
                    selectedSession = session
                    showingEmailComposer = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CalendarMeetingCard: View {
    let meeting: CalendarEvent
    let onCreateSession: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(meeting.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if !meeting.attendees.isEmpty {
                    HStack {
                        Image(systemName: "person.2")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("\(meeting.attendees.count) attendees")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            Button(action: onCreateSession) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CoachingSuggestionCard: View {
    let suggestion: CoachingSessionSuggestion
    let onSchedule: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested Time")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(suggestion.suggestedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: onSchedule) {
                    Text("Schedule")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionEmailCard: View {
    let session: ExecutiveSession
    let onSendEmail: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: onSendEmail) {
                Image(systemName: "envelope")
                    .font(.title3)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EmailComposeView: View {
    let session: ExecutiveSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if MFMailComposeViewController.canSendMail() {
                    Text("Email composition would open here")
                        .foregroundColor(.white)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        
                        Text("Mail Not Available")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Please configure Mail app to send session summaries")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Send Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CalendarEmailIntegrationView()
}
