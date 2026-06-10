//
//  DetailedSessionView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//

import SwiftUI

struct DetailedSessionView: View {
    let session: ExecutiveSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    sessionDetailsSection
                    Spacer()
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack {
                Label(session.type.rawValue, systemImage: "briefcase")
                
                Spacer()
                
                Label(session.formattedDate, systemImage: "calendar")
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal)
    }
    
    private var sessionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            durationAndPrioritySection
            notesSection
            attendeesSection
        }
        .padding(.horizontal)
    }
    
    private var durationAndPrioritySection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Duration")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(session.formattedDuration)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Priority")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(session.priority.rawValue)
                    .font(.headline)
                    .foregroundColor(session.priorityColor)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var notesSection: some View {
        Group {
            if !session.notes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(session.notes) { note in
                        noteCard(for: note)
                    }
                }
            }
        }
    }
    
    private func noteCard(for note: StructuredNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.content)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
            
            if !note.actionItems.isEmpty {
                actionItemsSection(for: note.actionItems)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func actionItemsSection(for actionItems: [ActionItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Action Items")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            ForEach(actionItems) { actionItem in
                HStack {
                    Circle()
                        .fill(actionItem.priorityColor)
                        .frame(width: 6, height: 6)
                    
                    Text(actionItem.title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
            }
        }
    }
    
    private var attendeesSection: some View {
        Group {
            if !session.attendees.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attendees")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(session.attendees, id: \.self) { attendee in
                            attendeeCard(for: attendee)
                        }
                    }
                }
            }
        }
    }
    
    private func attendeeCard(for attendee: String) -> some View {
        HStack {
            Image(systemName: "person.circle")
                .foregroundColor(.blue)
            
            Text(attendee)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Extensions for Display

extension ExecutiveSession {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    var priorityColor: Color {
        switch self.priority {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

extension ActionItem {
    var priorityColor: Color {
        switch self.priority {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
