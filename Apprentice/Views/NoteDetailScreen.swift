//
//  NoteDetailScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — full note review. Fixes the legacy blank-detail bug by
//  showing the real transcript + summary + actions, with per-chunk status and
//  re-transcription (audio is retained). Edit, export, delete.
//

import SwiftUI
import SwiftData

struct NoteDetailScreen: View {

    enum Tab: String, CaseIterable, Identifiable {
        case transcript = "Transcript"
        case summary = "Summary"
        case actions = "Actions"
        case decisions = "Decisions"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: NoteDetailViewModel
    @State private var tab: Tab = .transcript
    @State private var showRename = false
    @State private var renameText = ""
    @State private var newActionText = ""
    @State private var showDeleteConfirm = false

    init(note: Note) {
        _vm = StateObject(wrappedValue: NoteDetailViewModel(note: note, context: NoteStore.mainContext))
    }

    private var note: Note { vm.note }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 16) {
                headerCard

                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    switch tab {
                    case .transcript: transcriptSection
                    case .summary: summarySection
                    case .actions: actionsSection
                    case .decisions: decisionsSection
                    }
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { renameText = note.title; showRename = true } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    ShareLink(item: vm.exportText()) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    if note.orderedChunks.contains(where: { $0.status == .failed || $0.status == .retryable }) {
                        Button { Task { await vm.retranscribeFailed() } } label: {
                            Label("Retry failed", systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename note", isPresented: $showRename) {
            TextField("Title", text: $renameText)
            Button("Save") { vm.rename(renameText) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { vm.deleteNote(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the transcript and the recorded audio. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: note.type.iconName).foregroundStyle(Color.appAccent)
                Menu {
                    ForEach(NoteType.allCases) { type in
                        Button(type.displayName) { vm.setType(type) }
                    }
                } label: {
                    Text(note.type.displayName).font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .tint(.white)
                Spacer()
                Menu {
                    ForEach(NotePriority.allCases) { p in
                        Button(p.displayName) { vm.setPriority(p) }
                    }
                } label: {
                    Label(note.priority.displayName, systemImage: note.priority.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(note.priority.color)
                }
            }
            HStack(spacing: 10) {
                Label(note.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                Label(note.formattedDuration, systemImage: "clock")
                if note.isTranscribing {
                    Label("Transcribing…", systemImage: "waveform").foregroundStyle(.blue)
                }
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(16)
        .glassCard()
        .padding(.horizontal)
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if note.fullTranscript.isEmpty {
                placeholder(note.isTranscribing ? "Transcribing your recording…" : "No transcript yet.")
            } else {
                Text(note.fullTranscript)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard()
            }

            if !note.orderedChunks.isEmpty {
                Text("Segments").font(.headline).foregroundStyle(.white)
                ForEach(note.orderedChunks) { chunk in
                    ChunkRow(chunk: chunk) {
                        Task { await vm.retranscribe(chunk) }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if vm.isAnalyzing {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Analyzing with AI…").foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassCard()
            } else if note.aiSummary.isEmpty && note.insights.isEmpty {
                if note.fullTranscript.isEmpty {
                    placeholder(note.isTranscribing ? "Transcribing… analysis runs once that's done." : "No transcript to analyze yet.")
                } else {
                    analyzeButton(title: "Analyze with AI")
                    placeholder("Generate a summary, key insights, action items, and decisions from the transcript.")
                }
            } else {
                if !note.aiSummary.isEmpty {
                    Text(note.aiSummary)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassCard()
                }
                ForEach(note.insights, id: \.self) { insight in
                    Label(insight, systemImage: "lightbulb")
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .glassCard()
                }
                analyzeButton(title: "Re-analyze")
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }

    private func analyzeButton(title: String) -> some View {
        Button {
            Task { await vm.analyze() }
        } label: {
            Label(title, systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .glassCard()
        }
        .buttonStyle(.plain)
        .disabled(note.fullTranscript.isEmpty)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Add action item", text: $newActionText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                Button {
                    vm.addAction(title: newActionText); newActionText = ""
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.appAccent)
                }
                .disabled(newActionText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(14)
            .glassCard()

            if note.actions.isEmpty {
                placeholder("No action items yet.")
            } else {
                ForEach(note.actions) { action in
                    Button { vm.toggleAction(action) } label: {
                        HStack {
                            Image(systemName: action.status == .completed ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(action.status == .completed ? .green : .white.opacity(0.5))
                            Text(action.title)
                                .foregroundStyle(.white.opacity(action.status == .completed ? 0.5 : 0.95))
                                .strikethrough(action.status == .completed)
                            Spacer()
                        }
                        .padding(14)
                        .glassCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }

    // MARK: - Decisions

    private var decisionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if note.decisions.isEmpty {
                placeholder("No decisions captured.")
            } else {
                ForEach(note.decisions) { decision in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(decision.title).font(.headline).foregroundStyle(.white)
                        if !decision.rationale.isEmpty {
                            Text(decision.rationale).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard()
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }

    // MARK: - Helpers

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard()
    }
}

// MARK: - Chunk row

private struct ChunkRow: View {
    let chunk: AudioChunk
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: chunk.status.iconName)
                .foregroundStyle(chunk.status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Segment \(chunk.index + 1) · \(chunk.formattedDuration)")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                Text(chunk.status.displayName)
                    .font(.caption).foregroundStyle(chunk.status.color)
                if let error = chunk.lastError, chunk.status == .failed {
                    Text(error).font(.caption2).foregroundStyle(.red.opacity(0.8)).lineLimit(2)
                }
            }
            Spacer()
            if chunk.status == .processing {
                ProgressView().tint(.white)
            } else if chunk.canRetry || chunk.status == .completed {
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise").foregroundStyle(Color.appAccent)
                }
            }
        }
        .padding(12)
        .glassCard()
    }
}
