//
//  ActionItemsScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — the Actions tab. Every action item across all notes in one
//  place: filter by open/done, check them off, see the source note. Replaces the
//  legacy Memory (session-graph) tab.
//

import SwiftUI
import SwiftData

struct ActionItemsScreen: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \NoteAction.createdAt, order: .reverse) private var actions: [NoteAction]
    @State private var filter: Filter = .open

    enum Filter: String, CaseIterable, Identifiable {
        case open = "Open", done = "Done", all = "All"
        var id: String { rawValue }
    }

    private var filtered: [NoteAction] {
        switch filter {
        case .open: return actions.filter { $0.status != .completed && $0.status != .cancelled }
        case .done: return actions.filter { $0.status == .completed }
        case .all:  return actions
        }
    }

    private var openCount: Int {
        actions.filter { $0.status != .completed && $0.status != .cancelled }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 12) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filtered) { action in
                                    row(action)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 90)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Action Items")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ action: NoteAction) -> some View {
        HStack(spacing: 12) {
            Button { toggle(action) } label: {
                Image(systemName: action.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(action.status == .completed ? .green : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .foregroundStyle(.white.opacity(action.status == .completed ? 0.5 : 0.95))
                    .strikethrough(action.status == .completed)
                if let note = action.note {
                    Text(note.title)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer()
            if action.isOverdue {
                Text("Overdue").font(.caption2.weight(.semibold)).foregroundStyle(.red)
            }
            Circle().fill(action.priority.color).frame(width: 8, height: 8)
        }
        .padding(14)
        .glassCard()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
                .foregroundStyle(Color.appAccent)
            Text(filter == .open ? "No open actions" : "Nothing here")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Action items are extracted automatically when you record and analyze a note.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(.top, 60)
    }

    private func toggle(_ action: NoteAction) {
        if action.status == .completed {
            action.status = .pending
            action.completedAt = nil
        } else {
            action.status = .completed
            action.completedAt = Date()
        }
        try? context.save()
    }
}
