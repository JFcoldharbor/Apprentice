//
//  AriaSessionDetailSheet.swift
//  Apprentice
//
//  Aria-styled session detail. Reads the ExecutiveSession projection
//  (summary / transcript / actions / decisions / insights). Replaces the legacy
//  DetailedSessionView sheet.
//

import SwiftUI

struct AriaSessionDetailSheet: View {
    let session: ExecutiveSession
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SessionManager.shared
    @State private var confirmDelete = false
    @State private var isAnalyzing = false

    /// Live projection (reflects re-analysis), falling back to the passed snapshot.
    private var s: ExecutiveSession { manager.sessions.first { $0.id == session.id } ?? session }

    private var actions: [ActionItem] { s.notes.flatMap { $0.actionItems } }
    private var decisions: [Decision] { s.notes.flatMap { $0.decisions } }
    private var insights: [String] { s.notes.flatMap { $0.insights } }
    private var hasSummary: Bool { !(s.aiSummary ?? "").isEmpty }
    private var hasTranscript: Bool { !(s.transcript ?? "").isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            AriaSheetHeader(title: "Session", onClose: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    titleBlock
                    if hasTranscript && !hasSummary { analyzeCard }
                    if let summary = s.aiSummary, !summary.isEmpty {
                        section("Summary", icon: "brain") {
                            VStack(alignment: .leading, spacing: 10) { paragraph(summary); reanalyzeButton }
                        }
                    }
                    if !insights.isEmpty {
                        section("Insights", icon: "lightbulb") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(insights.enumerated()), id: \.offset) { _, i in bullet(i) }
                            }
                        }
                    }
                    if !actions.isEmpty {
                        section("Action items", icon: "checklist") {
                            VStack(spacing: 8) { ForEach(actions) { actionRow($0) } }
                        }
                    }
                    if !decisions.isEmpty {
                        section("Decisions", icon: "signpost.right") {
                            VStack(spacing: 8) { ForEach(decisions) { decisionRow($0) } }
                        }
                    }
                    if let t = s.transcript, !t.isEmpty {
                        section("Transcript", icon: "text.quote") { paragraph(t) }
                    }
                    if onDelete != nil { deleteButton.padding(.top, 6) }
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
            }
        }
        .ariaSheetSurface()
        .confirmationDialog("Delete this session?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { dismiss(); onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("“\(session.title)” and its audio will be removed everywhere, including Aria’s memory.")
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmDelete = true } label: {
            HStack(spacing: 9) {
                Image(systemName: "trash").font(.system(size: 14))
                Text("Delete session").font(.inter(14, .semibold))
            }
            .foregroundColor(Aria.rose)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Aria.rose.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.rose.opacity(0.35), lineWidth: 1))
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.title).font(.fraunces(26, .medium)).foregroundColor(Aria.ivory)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(s.date.formatted(date: .abbreviated, time: .shortened))
                Text("· \(s.type.rawValue)").foregroundColor(Aria.ivoryFaint)
                Text("· \(durationText)")
            }
            .font(.ariaMono(11.5)).foregroundColor(Aria.ivoryDim)
        }
    }

    // MARK: Analyze

    /// Shown when a session was transcribed but never analyzed (enrichment failed
    /// or was interrupted). Analyzing also mirrors it to web Aria.
    private var analyzeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles").font(.system(size: 15)).foregroundColor(Aria.goldBright)
                Text("Not analyzed yet").font(.inter(14, .semibold)).foregroundColor(Aria.ivory)
            }
            Text("This session has a transcript but no summary. Analyze it to pull out the summary, actions & decisions — and share it with Aria on web.")
                .font(.inter(12.5)).foregroundColor(Aria.ivoryDim).lineSpacing(2)
            Button(action: runAnalyze) {
                HStack(spacing: 8) {
                    if isAnalyzing { ProgressView().tint(Color(red: 0.1, green: 0.07, blue: 0.02)) }
                    else { Image(systemName: "wand.and.stars").font(.system(size: 14)) }
                    Text(isAnalyzing ? "Analyzing…" : "Analyze with Aria").font(.inter(14, .semibold))
                }
                .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(RadialGradient(colors: [Aria.goldBright, Aria.gold], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 220))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain).disabled(isAnalyzing)
        }
        .padding(16)
        .background(LinearGradient(colors: [Aria.gold.opacity(0.10), Aria.panel], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.gold.opacity(0.35), lineWidth: 1))
    }

    private var reanalyzeButton: some View {
        Button(action: runAnalyze) {
            HStack(spacing: 6) {
                if isAnalyzing { ProgressView().scaleEffect(0.7).tint(Aria.gold) }
                else { Image(systemName: "arrow.clockwise").font(.system(size: 11)) }
                Text(isAnalyzing ? "Re-analyzing…" : "Re-analyze").font(.inter(11.5, .medium))
            }
            .foregroundColor(Aria.gold)
        }
        .buttonStyle(.plain).disabled(isAnalyzing)
    }

    private func runAnalyze() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        Task { await manager.analyze(sessionId: session.id); isAnalyzing = false }
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(Aria.goldBright)
                AriaSectionLabel(text: title)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text).font(.inter(14)).foregroundColor(Aria.ivory.opacity(0.9)).lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(Aria.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Aria.gold).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).font(.inter(13.5)).foregroundColor(Aria.ivory.opacity(0.9)).lineSpacing(2)
            Spacer(minLength: 0)
        }
    }

    private func actionRow(_ a: ActionItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: a.status == .completed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18)).foregroundColor(a.status == .completed ? Aria.jade : Aria.ivoryFaint)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title).font(.inter(14, .medium)).foregroundColor(Aria.ivory)
                if !a.description.isEmpty {
                    Text(a.description).font(.inter(12)).foregroundColor(Aria.ivoryDim).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func decisionRow(_ d: Decision) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(d.title).font(.inter(14, .semibold)).foregroundColor(Aria.ivory)
            if !d.description.isEmpty {
                Text(d.description).font(.inter(12.5)).foregroundColor(Aria.ivoryDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) { Rectangle().fill(Aria.rose.opacity(0.5)).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var durationText: String {
        let total = Int(s.duration)
        if total < 60 { return "\(total)s" }
        return "\(total / 60)m \(String(format: "%02d", total % 60))s"
    }
}
