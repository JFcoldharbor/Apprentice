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
    @Environment(\.dismiss) private var dismiss

    private var structured: StructuredNote? { session.notes.first }
    private var actions: [ActionItem] { session.notes.flatMap { $0.actionItems } }
    private var decisions: [Decision] { session.notes.flatMap { $0.decisions } }
    private var insights: [String] { session.notes.flatMap { $0.insights } }

    var body: some View {
        VStack(spacing: 0) {
            AriaSheetHeader(title: "Session", onClose: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    titleBlock
                    if let s = session.aiSummary, !s.isEmpty { section("Summary", icon: "brain") { paragraph(s) } }
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
                    if let t = session.transcript, !t.isEmpty {
                        section("Transcript", icon: "text.quote") { paragraph(t) }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
            }
        }
        .ariaSheetSurface()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title).font(.fraunces(26, .medium)).foregroundColor(Aria.ivory)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                Text("· \(session.type.rawValue)").foregroundColor(Aria.ivoryFaint)
                Text("· \(durationText)")
            }
            .font(.ariaMono(11.5)).foregroundColor(Aria.ivoryDim)
        }
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
        let total = Int(session.duration)
        if total < 60 { return "\(total)s" }
        return "\(total / 60)m \(String(format: "%02d", total % 60))s"
    }
}
