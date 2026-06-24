//
//  AriaDiscoveryScreen.swift
//  Apprentice
//
//  The logged customer-discovery interviews (SwiftData @Query). Tap + to capture
//  a new one; each save syncs to /discovery and feeds the War Room Discovery lane.
//

import SwiftUI
import SwiftData

struct AriaDiscoveryScreen: View {
    @Query(sort: \InterviewRecord.date, order: .reverse) private var records: [InterviewRecord]
    @State private var capturing = false
    @State private var picking = false
    @State private var draft: DiscoveryDraft?
    @State private var draftingTitle: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if records.isEmpty {
                    empty
                } else {
                    ForEach(records) { row($0) }
                }
            }
            .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
        }
        .ariaSheetSurface()
        .navigationTitle("Customer Discovery")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { capturing = true } label: { Label("Blank interview", systemImage: "square.and.pencil") }
                    Button { picking = true } label: { Label("From a recording", systemImage: "waveform") }
                } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundColor(Aria.goldBright)
                }
            }
        }
        .sheet(isPresented: $capturing) { AriaInterviewCaptureView() }
        .sheet(isPresented: $picking) { DiscoveryRecordingPicker { note in picking = false; startDraft(from: note) } }
        .sheet(item: $draft) { d in AriaInterviewCaptureView(draft: d) }
        .overlay { if draftingTitle != nil { draftingOverlay } }
    }

    // Aria reads a recorded interview's transcript → a pre-filled capture draft.
    // On failure, fall back to a blank form so the founder can still log it.
    private func startDraft(from note: Note) {
        let transcript = note.fullTranscript
        let summary = note.aiSummary
        draftingTitle = note.title
        Task { @MainActor in
            defer { draftingTitle = nil }
            do { draft = try await DiscoveryDraftService.draft(transcript: transcript, summary: summary) }
            catch { capturing = true }
        }
    }

    private var draftingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(Aria.gold)
                Text("Aria is reading the interview…").font(.inter(13)).foregroundColor(Aria.ivory)
            }
            .padding(26).background(Aria.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(records.count) interview\(records.count == 1 ? "" : "s") logged")
                .font(.inter(13)).foregroundColor(Aria.ivoryDim)
            Text("Each one feeds the War Room's Discovery charts and decision gates.")
                .font(.inter(12)).foregroundColor(Aria.ivoryFaint)
        }
        .padding(.bottom, 4)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.line.dotted.person").font(.system(size: 30)).foregroundColor(Aria.ivoryFaint)
            Text("No interviews yet").font(.inter(15, .semibold)).foregroundColor(Aria.ivory)
            Text("Tap + after a customer conversation to log it. The charts build themselves from here.")
                .font(.inter(12.5)).foregroundColor(Aria.ivoryDim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50).padding(.horizontal, 20)
    }

    private func row(_ r: InterviewRecord) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(r.who.isEmpty ? "Interviewee" : r.who).font(.inter(15, .semibold)).foregroundColor(Aria.ivory)
                    Text(r.group.label.uppercased()).font(.inter(9.5, .semibold)).foregroundColor(Aria.ivoryFaint)
                }
                Text(subtitle(r)).font(.inter(12)).foregroundColor(Aria.ivoryDim).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.inter(10.5)).foregroundColor(Aria.ivoryFaint)
                Circle().fill(r.synced ? Aria.jade : Aria.ivoryFaint).frame(width: 6, height: 6)
            }
        }
        .padding(16).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func subtitle(_ r: InterviewRecord) -> String {
        var bits: [String] = ["Adopt \(r.adoptionScore) · Frust \(r.frustrationScore)"]
        if !r.themes.isEmpty { bits.append(r.themes.prefix(2).map { $0.label }.joined(separator: ", ")) }
        bits.append(r.willPay.label.lowercased() == "unknown" ? "pay: ?" : "pay: \(r.willPay.label.lowercased())")
        return bits.joined(separator: "  ·  ")
    }
}

/// Picks one recorded session (with a transcript) for Aria to draft an interview
/// record from.
private struct DiscoveryRecordingPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    let onPick: (Note) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AriaSheetHeader(title: "Pick a recording", onClose: { dismiss() })
                ScrollView(showsIndicators: false) {
                    let usable = notes.filter { !$0.fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    VStack(alignment: .leading, spacing: 10) {
                        if usable.isEmpty {
                            Text("No recorded sessions with a transcript yet. Record an interview first, then come back.")
                                .font(.inter(13)).foregroundColor(Aria.ivoryDim)
                                .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.vertical, 44).padding(.horizontal, 16)
                        } else {
                            ForEach(usable) { n in
                                Button { onPick(n) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "waveform").font(.system(size: 15)).foregroundColor(Aria.jade)
                                            .frame(width: 36, height: 36)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(Aria.jade.opacity(0.14)))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(n.title).font(.inter(14.5, .semibold)).foregroundColor(Aria.ivory).lineLimit(1)
                                            Text(n.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(.inter(11.5)).foregroundColor(Aria.ivoryDim)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "sparkles").font(.system(size: 13)).foregroundColor(Aria.goldBright)
                                    }
                                    .padding(14).background(Aria.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
                }
            }
            .ariaSheetSurface()
        }
        .tint(Aria.goldBright)
    }
}
