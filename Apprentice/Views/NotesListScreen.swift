//
//  NotesListScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — the Notes tab. Reactive @Query list (auto-updates as
//  transcription completes), searchable, swipe-to-delete (removes audio too).
//

import SwiftUI
import SwiftData

struct NotesListScreen: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var searchText = ""

    private var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.fullTranscript.localizedCaseInsensitiveContains(searchText) ||
            note.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if notes.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredNotes) { note in
                            ZStack {
                                NavigationLink(value: note) { EmptyView() }.opacity(0)
                                NoteRow(note: note)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Notes")
            .navigationDestination(for: Note.self) { note in
                NoteDetailScreen(note: note)
            }
            .searchable(text: $searchText, prompt: "Search notes & transcripts")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundStyle(Color.appAccent)
            Text("No notes yet")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Record from the mic tab — your transcript shows up here automatically.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            AudioFileStore.shared.deleteFiles(for: note)
            context.delete(note)
        }
        try? context.save()
    }
}

// MARK: - Row

private struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: note.type.iconName)
                .font(.title3)
                .foregroundStyle(Color.appAccent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.appAccent.opacity(0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(note.createdAt, format: .dateTime.month().day().hour().minute())
                    Text("·")
                    Text(note.formattedDuration)
                    if note.openActionCount > 0 {
                        Text("·")
                        Label("\(note.openActionCount)", systemImage: "checklist")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if note.isTranscribing {
                ProgressView().tint(.white)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .glassCard()
        .padding(.vertical, 4)
    }
}
