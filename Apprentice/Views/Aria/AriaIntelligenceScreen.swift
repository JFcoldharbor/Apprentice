//
//  AriaIntelligenceScreen.swift
//  Apprentice
//
//  Redesigned Business Intelligence (aria-redesign.html #v-intel), wired to the
//  founder profile + SessionManager analytics.
//

import SwiftUI

struct AriaIntelligenceScreen: View {
    @StateObject private var manager = SessionManager.shared
    @StateObject private var profiles = FounderProfileManager.shared

    private var profile: FounderProfile? { profiles.founderProfile }

    private var thisWeekCount: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return manager.sessions.filter { $0.date >= start }.count
    }
    private var completionPct: Int { Int((manager.actionItemCompletionRate() * 100).rounded()) }
    private var commonType: String { manager.mostCommonMeetingType()?.rawValue ?? "—" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AriaEyebrow(text: "Analytics").padding(.top, 14).padding(.bottom, 10)
                AriaTitle(plain: "Business ", em: "intelligence")
                AriaSub(text: "Patterns Aria has noticed across your sessions.")
                    .padding(.top, 6).padding(.bottom, 24)

                profileRow.padding(.bottom, 24)
                highlights.padding(.bottom, 24)

                AriaSectionLabel(text: "Recent insights").padding(.bottom, 4)
                insights
            }
            .padding(.horizontal, 22).padding(.bottom, 130)
        }
    }

    private var profileRow: some View {
        HStack(spacing: 11) {
            profileCard(icon: "chart.bar.doc.horizontal", tint: Aria.goldBright,
                        value: profile?.businessStage.rawValue ?? "—", key: "Business stage")
            profileCard(icon: "briefcase", tint: Aria.rose,
                        value: profile?.industry ?? "—", key: "Industry")
        }
    }

    private func profileCard(icon: String, tint: Color, value: String, key: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.14)))
                .padding(.bottom, 14)
            Text(value).font(.fraunces(20, .medium)).foregroundColor(Aria.ivory).lineLimit(1)
            Text(key.uppercased()).font(.ariaMono(10.5)).foregroundColor(Aria.ivoryDim).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private var highlights: some View {
        HStack(spacing: 11) {
            highlightCard(big: "\(thisWeekCount)", small: "session\(thisWeekCount == 1 ? "" : "s") this week")
            highlightCard(big: "\(completionPct)%", small: "of action items completed")
        }
    }

    private func highlightCard(big: String, small: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(big).font(.fraunces(32)).foregroundColor(Aria.goldBright)
            Text(small).font(.inter(12)).foregroundColor(Aria.ivoryDim).lineSpacing(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LinearGradient(colors: [Aria.gold.opacity(0.1), Aria.panel.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Aria.line, lineWidth: 1))
    }

    @ViewBuilder private var insights: some View {
        if manager.sessions.isEmpty {
            Text("Record a few sessions and Aria starts surfacing trends here.")
                .font(.inter(13)).foregroundColor(Aria.ivoryFaint).padding(.vertical, 16)
        } else {
            insightRow(icon: "chart.line.uptrend.xyaxis", tint: Aria.jade,
                       title: "Meeting cadence", body: "\(thisWeekCount) session\(thisWeekCount == 1 ? "" : "s") logged this week")
            insightRow(icon: "checkmark", tint: Aria.goldBright,
                       title: "Follow-through", body: "\(completionPct)% of action items closed")
            insightRow(icon: "scope", tint: Aria.rose,
                       title: "Focus: \(commonType)", body: "Your most-recorded session type")
        }
    }

    private func insightRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.inter(15, .semibold)).foregroundColor(Aria.ivory)
                Text(body).font(.inter(12.5)).foregroundColor(Aria.ivoryDim)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(Aria.lineSoft).frame(height: 1) }
    }
}
