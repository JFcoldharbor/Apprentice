//
//  HomeScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — the Home tab. A real dashboard over the new note stack:
//  greeting, quick actions, open action items, recent notes. Replaces the legacy
//  PremiumHomeView (broken on-device-key speech orb).
//

import SwiftUI
import SwiftData

struct HomeScreen: View {

    @Binding var selectedTab: Int
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    private var recentNotes: [Note] { Array(notes.prefix(4)) }
    private var openActions: [NoteAction] {
        notes.flatMap { $0.actions }
            .filter { $0.status != .completed && $0.status != .cancelled }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        quickActions
                        if !openActions.isEmpty { openActionsCard }
                        recentNotesSection
                    }
                    .padding()
                    .padding(.bottom, 90) // clear the floating tab bar
                }
            }
            .navigationDestination(for: Note.self) { NoteDetailScreen(note: $0) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(notes.isEmpty ? "Record your first note to get started." : "\(notes.count) note\(notes.count == 1 ? "" : "s") · \(openActions.count) open action\(openActions.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Still up?"
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            quickAction(title: "Record", subtitle: "Capture a note", icon: "mic.fill", tab: 2)
            quickAction(title: "Coach", subtitle: "Ask anything", icon: "brain.head.profile", tab: 3)
        }
    }

    private func quickAction(title: String, subtitle: String, icon: String, tab: Int) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.appAccent)
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Open actions

    private var openActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Open action items", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(openActions.prefix(5)) { action in
                HStack(spacing: 10) {
                    Image(systemName: "circle").font(.caption).foregroundStyle(.orange)
                    Text(action.title).font(.subheadline).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                    Spacer()
                }
            }
            if openActions.count > 5 {
                Text("+ \(openActions.count - 5) more")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: - Recent notes

    private var recentNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent notes").font(.headline).foregroundStyle(.white)
                Spacer()
                if !notes.isEmpty {
                    Button("See all") { selectedTab = 1 }
                        .font(.caption).tint(Color.appAccent)
                }
            }

            if recentNotes.isEmpty {
                Text("No notes yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard()
            } else {
                ForEach(recentNotes) { note in
                    NavigationLink(value: note) {
                        HStack(spacing: 12) {
                            Image(systemName: note.type.iconName)
                                .foregroundStyle(Color.appAccent)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.appAccent.opacity(0.15)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.title).font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white).lineLimit(1)
                                Text(note.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            if note.isTranscribing { ProgressView().tint(.white) }
                        }
                        .padding(14)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
