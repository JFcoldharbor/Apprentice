//
//  AriaHomeScreen.swift
//  Apprentice
//
//  Redesigned Home — "Aria, the centerpiece." Translated from the
//  aria-redesign.html #v-home, wired to real data (SessionManager projection +
//  founder profile). The orb / ask bar open the Aria coach (Claude + note memory).
//

import SwiftUI

struct AriaHomeScreen: View {
    @Binding var selectedTab: Int

    @StateObject private var sessions = SessionManager.shared
    @StateObject private var profiles = FounderProfileManager.shared

    @State private var connectionCount = 0
    @State private var showingAsk = false
    @State private var showingVoice = false
    @State private var showingSettings = false
    @State private var orbFloat = false

    private var profile: FounderProfile? { profiles.founderProfile }
    private var firstName: String {
        let n = profile?.founderName ?? ""
        return n.isEmpty ? "there" : n.split(separator: " ").first.map(String.init) ?? n
    }
    private var initial: String { String(firstName.prefix(1)).uppercased() }

    private var sessionCount: Int { sessions.sessions.count }
    private var todoCount: Int { sessions.totalActionItems() - sessions.completedActionItems() }
    private var recent: [ExecutiveSession] { Array(sessions.sessions.prefix(3)) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                ariaStage
                vitals
                reportCTA
                timeline
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 130)
        }
        .sheet(isPresented: $showingVoice) { AriaVoiceSheet() }
        .sheet(isPresented: $showingAsk) { AriaAskSheet() }
        .sheet(isPresented: $showingSettings) { AriaSettingsSheet() }
        .onAppear { orbFloat = true; recomputeConnections() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Text(initial)
                .font(.fraunces(19, .medium))
                .foregroundColor(Aria.goldBright)
                .frame(width: 46, height: 46)
                .background(
                    Circle().fill(
                        RadialGradient(colors: [Aria.panel2, Aria.ink],
                                       center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 46))
                )
                .overlay(Circle().stroke(Aria.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(greeting).font(.inter(12.5)).foregroundColor(Aria.ivoryDim)
                Text(firstName).font(.fraunces(19, .medium)).foregroundColor(Aria.ivory)
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19))
                    .foregroundColor(Aria.ivoryDim)
                    .frame(width: 40, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Aria.lineSoft, lineWidth: 1))
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 30)
    }

    // MARK: - Aria orb stage

    private var ariaStage: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(haloSpecs, id: \.self) { spec in
                    Circle()
                        .stroke(Aria.gold.opacity(spec.opacity), lineWidth: 1)
                        .frame(width: spec.size, height: spec.size)
                }
                orbCore
            }
            .frame(width: 230, height: 230)
            .offset(y: orbFloat ? -7 : 0)
            .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: orbFloat)
            .onTapGesture { showingVoice = true }

            HStack(spacing: 9) {
                Circle().fill(Aria.jade).frame(width: 7, height: 7)
                    .shadow(color: Aria.jade, radius: 5)
                (Text("Aria analyzed ").foregroundColor(Aria.ivoryDim)
                 + Text("\(sessionCount) \(sessionCount == 1 ? "session" : "sessions")").foregroundColor(Aria.ivory).bold()
                 + Text(" so far").foregroundColor(Aria.ivoryDim))
                    .font(.inter(14))
            }
            .padding(.top, 24)

            askBar.padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 26)
    }

    private var orbCore: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95), Aria.goldBright, Aria.gold, Color(red: 0.61, green: 0.51, blue: 0.28)],
                        center: UnitPoint(x: 0.38, y: 0.32), startRadius: 4, endRadius: 150)
                )
                .frame(width: 150, height: 150)
                .shadow(color: Aria.gold.opacity(0.55), radius: 30)
                .shadow(color: .black.opacity(0.7), radius: 25, y: 18)
            Text("ARIA")
                .font(.fraunces(33, .medium))
                .tracking(1)
                .foregroundColor(Color(red: 0.23, green: 0.17, blue: 0.06))
        }
    }

    private var askBar: some View {
        Button { showingAsk = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 17))
                    .foregroundColor(Aria.goldBright)
                Text("Ask Aria anything…")
                    .font(.inter(14.5))
                    .foregroundColor(Aria.ivoryDim)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Aria.gold.opacity(0.12), Aria.panel.opacity(0.5)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Aria.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Vitals

    private var vitals: some View {
        HStack(spacing: 0) {
            vital(n: "\(sessionCount)", l: "Sessions", color: Aria.goldBright) { selectedTab = 1 }
            divider
            vital(n: "\(connectionCount)", l: "Connections", color: Aria.jade) { selectedTab = 4 }
            divider
            vital(n: "\(max(0, todoCount))", l: "To do", color: Aria.ivory) { selectedTab = 3 }
        }
        .background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        .padding(.bottom, 20)
    }

    private var divider: some View { Rectangle().fill(Aria.lineSoft).frame(width: 1, height: 56) }

    private func vital(n: String, l: String, color: Color, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 6) {
                Text(n).font(.fraunces(26)).foregroundColor(color)
                Text(l).font(.inter(10.5)).foregroundColor(Aria.ivoryDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly report CTA

    private var reportCTA: some View {
        Button { showingAsk = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color.black.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your weekly report is ready")
                        .font(.inter(14.5, .semibold))
                        .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                    Text("Trends, decisions & follow-ups · \(weekRange)")
                        .font(.inter(11.5))
                        .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02).opacity(0.7))
                }
                Spacer()
                Text("→").font(.system(size: 20, weight: .light))
                    .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
            }
            .padding(.horizontal, 20).padding(.vertical, 17)
            .background(
                LinearGradient(colors: [Aria.gold, Aria.goldBright], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 26)
    }

    // MARK: - Recent activity timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AriaSectionLabel(text: "Recent activity")
                Spacer()
                Button("View all") { selectedTab = 1 }
                    .font(.inter(12, .medium)).foregroundColor(Aria.gold)
            }
            .padding(.bottom, 14)

            if recent.isEmpty {
                Text("No sessions yet — tap the orb or record one and Aria starts building your memory.")
                    .font(.inter(13)).foregroundColor(Aria.ivoryFaint)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, s in
                    timelineRow(session: s, dotColor: dotColors[idx % dotColors.count], isLast: idx == recent.count - 1)
                }
            }
        }
    }

    private func timelineRow(session s: ExecutiveSession, dotColor: Color, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle().fill(dotColor).frame(width: 8, height: 8).shadow(color: dotColor, radius: 4)
                    .padding(.top, 3)
                if !isLast {
                    Rectangle().fill(Aria.lineSoft).frame(width: 1).frame(maxHeight: .infinity).padding(.top, 4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title).font(.inter(14.5, .semibold)).foregroundColor(Aria.ivory)
                    .lineLimit(1)
                Text(activitySubtitle(s)).font(.inter(12)).foregroundColor(Aria.ivoryDim)
                    .lineLimit(1)
                Text(relativeTime(s.date)).font(.ariaMono(10.5)).foregroundColor(Aria.ivoryFaint)
                    .tracking(0.3).padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast { Rectangle().fill(Aria.lineSoft).frame(height: 1) }
        }
    }

    private func activitySubtitle(_ s: ExecutiveSession) -> String {
        if let summary = s.aiSummary, !summary.isEmpty {
            return summary
        }
        let actions = s.notes.reduce(0) { $0 + $1.actionItems.count }
        if actions > 0 { return "\(actions) action item\(actions == 1 ? "" : "s") captured" }
        return s.type.rawValue
    }

    // MARK: - Helpers

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Working late"
        }
    }

    private var weekRange: String {
        let cal = Calendar.current
        let now = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let endF = DateFormatter(); endF.dateFormat = "d"
        return "\(f.string(from: start))–\(endF.string(from: now))"
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    private let dotColors: [Color] = [Aria.gold, Aria.jade, Aria.rose]

    private struct Halo: Hashable { let size: CGFloat; let opacity: Double }
    private var haloSpecs: [Halo] {
        [Halo(size: 238, opacity: 0.07), Halo(size: 202, opacity: 0.14), Halo(size: 162, opacity: 0.28)]
    }

    private func recomputeConnections() {
        let snapshot = sessions.sessions
        guard snapshot.count > 1 else { connectionCount = 0; return }
        connectionCount = MemoryConnectionCalculator().analyzeConnections(sessions: snapshot).count
    }
}
