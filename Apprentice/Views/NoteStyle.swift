//
//  NoteStyle.swift
//  Apprentice
//
//  Layer 5 (Views) — shared styling for the note stack. Enum colors live here
//  (not in L1) so the model layer stays free of SwiftUI.
//

import SwiftUI

struct AppBackground: View {
    var body: some View {
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
}

extension Color {
    static let appAccent = Color(red: 0.36, green: 0.52, blue: 1.0)
}

extension NotePriority {
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

extension NoteStatus {
    var color: Color {
        switch self {
        case .scheduled: return .blue
        case .inProgress: return .green
        case .completed: return .gray
        case .cancelled: return .red
        case .rescheduled: return .orange
        }
    }
}

extension ActionStatus {
    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .blue
        case .blocked: return .red
        case .completed: return .green
        case .cancelled: return .orange
        }
    }
}

extension TranscriptionStatus {
    var color: Color {
        switch self {
        case .pending: return .gray
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .retryable: return .orange
        }
    }
}
