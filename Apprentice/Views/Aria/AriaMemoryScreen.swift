//
//  AriaMemoryScreen.swift
//  Apprentice
//
//  Redesigned Memory (aria-redesign.html #v-memory): the connected-mind
//  constellation + memory metrics — now wired to the REAL data. The constellation
//  draws your actual sessions as nodes and the MemoryConnectionCalculator's
//  detected links as edges; the tabs filter between Sessions, the Aria chat, and
//  the Links (what connects to what, and why).
//

import SwiftUI
import SwiftData

struct AriaMemoryScreen: View {
    @StateObject private var manager = SessionManager.shared
    @State private var seg = 0
    @State private var connections: [SessionConnection] = []
    @State private var conversations: [CoachMessage] = []
    @State private var selectedSession: ExecutiveSession?

    private var insightCount: Int { manager.sessions.reduce(0) { $0 + $1.notes.reduce(0) { $0 + $1.insights.count } } }

    /// The sessions shown as constellation nodes — the most-connected ones first,
    /// capped so the graph stays legible.
    private var graphSessions: [ExecutiveSession] {
        let degree = Dictionary(grouping: connections.flatMap { [$0.sourceSessionId, $0.targetSessionId] }) { $0 }
            .mapValues { $0.count }
        return Array(
            manager.sessions
                .sorted { (degree[$0.id] ?? 0, $0.date) > (degree[$1.id] ?? 0, $1.date) }
                .prefix(8)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AriaEyebrow(text: "The connected mind").padding(.top, 14).padding(.bottom, 10)
                AriaTitle(plain: "Aria's ", em: "memory")

                ConstellationView(sessions: graphSessions, connections: connections) { selectedSession = $0 }
                    .frame(height: 260)
                    .padding(.horizontal, -22)
                    .padding(.top, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Aria.lineSoft).frame(height: 1) }

                VStack(spacing: 4) {
                    Text("One memory, every source").font(.fraunces(25)).foregroundColor(Aria.ivory)
                    Text(connections.isEmpty
                         ? "Record a few sessions and Aria starts drawing the links"
                         : "Tap a node to open it — lines are real connections Aria found")
                        .font(.inter(13)).foregroundColor(Aria.ivoryDim).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)

                grid.padding(.bottom, 22)
                segControl.padding(.bottom, 20)

                content
            }
            .padding(.horizontal, 22).padding(.bottom, 130)
        }
        .sheet(item: $selectedSession) { AriaSessionDetailSheet(session: $0) }
        .onAppear(perform: recompute)
    }

    // MARK: Metrics

    private var grid: some View {
        HStack(spacing: 10) {
            memCell(icon: "link", tint: Aria.goldBright, n: connections.count, l: "Connections")
            memCell(icon: "lightbulb", tint: Aria.rose, n: insightCount, l: "AI insights")
            memCell(icon: "list.bullet.rectangle", tint: Aria.jade, n: manager.sessions.count, l: "Sessions")
        }
    }

    private func memCell(icon: String, tint: Color, n: Int, l: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.14)))
                .padding(.bottom, 12)
            Text("\(n)").font(.fraunces(30)).foregroundColor(Aria.ivory)
            Text(l).font(.inter(10.5)).foregroundColor(Aria.ivoryDim).padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    // MARK: Segmented control

    private let segs = ["All", "Sessions", "Conversations", "Links"]

    private var segControl: some View {
        HStack(spacing: 4) {
            ForEach(Array(segs.enumerated()), id: \.offset) { i, label in
                let on = seg == i
                Text(label).font(.inter(12, .medium))
                    .foregroundColor(on ? Color(red: 0.1, green: 0.07, blue: 0.02) : Aria.ivoryDim)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(on ? AnyView(LinearGradient(colors: [Aria.gold, Aria.goldBright], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyView(Color.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { seg = i }
            }
        }
        .padding(4).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    // MARK: Tab content

    @ViewBuilder private var content: some View {
        switch seg {
        case 1: sessionsList
        case 2: conversationsList
        case 3: linksList(limit: nil)
        default:
            VStack(alignment: .leading, spacing: 22) {
                if !connections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        AriaSectionLabel(text: "Strongest links")
                        linksList(limit: 4)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    AriaSectionLabel(text: "Sessions")
                    sessionsList
                }
            }
        }
    }

    @ViewBuilder private var sessionsList: some View {
        if manager.sessions.isEmpty {
            emptyBox("No sessions yet", "Record one and it lands here, ready to be connected.")
        } else {
            VStack(spacing: 10) {
                ForEach(manager.sessions, id: \.id) { s in
                    sessionRow(s).onTapGesture { selectedSession = s }
                }
            }
        }
    }

    @ViewBuilder private var conversationsList: some View {
        if conversations.isEmpty {
            emptyBox("No conversations yet", "Talk to Aria from any screen — your thread shows up here.")
        } else {
            VStack(spacing: 10) {
                ForEach(conversations.prefix(40)) { m in convoRow(m) }
            }
        }
    }

    @ViewBuilder private func linksList(limit: Int?) -> some View {
        if connections.isEmpty {
            emptyBox("No links yet", "Once two sessions share people, topics, or follow-ups, Aria draws the connection here.")
        } else {
            let shown = limit.map { Array(connections.prefix($0)) } ?? connections
            VStack(spacing: 10) {
                ForEach(shown) { linkCard($0) }
            }
        }
    }

    // MARK: Rows

    private func sessionRow(_ s: ExecutiveSession) -> some View {
        HStack(spacing: 13) {
            Image(systemName: s.type == .clientCall ? "phone" : "person.2")
                .font(.system(size: 15)).foregroundColor(Aria.goldBright)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11).fill(Aria.gold.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title).font(.inter(14, .medium)).foregroundColor(Aria.ivory).lineLimit(1)
                Text("\(s.date.formatted(date: .abbreviated, time: .omitted)) · \(s.type.rawValue)")
                    .font(.ariaMono(10.5)).foregroundColor(Aria.ivoryDim)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(Aria.ivoryFaint)
        }
        .padding(13).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func convoRow(_ m: CoachMessage) -> some View {
        let isUser = m.role == "user"
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isUser ? "person.crop.circle" : "sparkle")
                .font(.system(size: 13)).foregroundColor(isUser ? Aria.ivoryDim : Aria.goldBright)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(isUser ? "You" : "Aria").font(.ariaMono(9.5)).tracking(1).foregroundColor(isUser ? Aria.ivoryFaint : Aria.gold)
                Text(m.text).font(.inter(13)).foregroundColor(Aria.ivory.opacity(0.9)).lineLimit(4)
            }
            Spacer(minLength: 0)
        }
        .padding(13).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func linkCard(_ c: SessionConnection) -> some View {
        let a = session(c.sourceSessionId)?.title ?? "A session"
        let b = session(c.targetSessionId)?.title ?? "A session"
        let col = strengthColor(c.strength)
        return VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: c.connectionType.icon).font(.system(size: 13)).foregroundColor(col)
                Text(c.connectionType.rawValue).font(.inter(12.5, .semibold)).foregroundColor(Aria.ivory)
                Spacer()
                Text(c.strength.rawValue.uppercased()).font(.ariaMono(9)).tracking(1)
                    .foregroundColor(col)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(col.opacity(0.14)).clipShape(Capsule())
            }
            HStack(spacing: 8) {
                Text(a).font(.inter(13, .medium)).foregroundColor(Aria.ivory).lineLimit(1)
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 11)).foregroundColor(Aria.ivoryFaint)
                Text(b).font(.inter(13, .medium)).foregroundColor(Aria.ivory).lineLimit(1)
            }
            ForEach(c.reasons.prefix(3)) { r in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(col).frame(width: 4, height: 4).padding(.top, 6)
                    Text(r.description).font(.inter(12)).foregroundColor(Aria.ivoryDim).lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(col.opacity(0.3), lineWidth: 1))
    }

    private func emptyBox(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.fraunces(17)).foregroundColor(Aria.ivory)
            Text(sub).font(.inter(13)).foregroundColor(Aria.ivoryFaint).multilineTextAlignment(.center).lineSpacing(2)
        }
        .frame(maxWidth: .infinity).padding(30)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Aria.line))
    }

    // MARK: Helpers

    private func session(_ id: UUID) -> ExecutiveSession? { manager.sessions.first { $0.id == id } }

    private func strengthColor(_ s: ConnectionStrength) -> Color {
        switch s {
        case .weak: return Aria.ivoryFaint
        case .moderate: return Aria.jade
        case .strong: return Aria.gold
        case .critical: return Aria.rose
        }
    }

    private func recompute() {
        let snap = manager.sessions
        connections = snap.count > 1 ? MemoryConnectionCalculator().analyzeConnections(sessions: snap) : []
        let descriptor = FetchDescriptor<CoachMessage>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        conversations = (try? NoteStore.mainContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Constellation (real: nodes = sessions, edges = detected connections)

private struct ConstellationView: View {
    let sessions: [ExecutiveSession]
    let connections: [SessionConnection]
    let onTap: (ExecutiveSession) -> Void

    var body: some View {
        GeometryReader { geo in content(in: geo.size) }
    }

    private func content(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let pts = nodePoints(center: center, size: size)
        let index = Dictionary(uniqueKeysWithValues: sessions.enumerated().map { ($1.id, $0) })
        // Only edges whose endpoints are both on screen.
        let edges = connections.filter { index[$0.sourceSessionId] != nil && index[$0.targetSessionId] != nil }

        return ZStack {
            // edges (real connections)
            ForEach(edges) { e in
                if let i = index[e.sourceSessionId], let j = index[e.targetSessionId], i < pts.count, j < pts.count {
                    Path { p in p.move(to: pts[i]); p.addLine(to: pts[j]) }
                        .stroke(Aria.gold.opacity(0.15 + min(0.5, e.score * 0.6)), lineWidth: 1)
                }
            }

            // core
            Circle().stroke(Aria.gold.opacity(0.25), lineWidth: 1).frame(width: 60, height: 60).position(center)
            Circle().fill(RadialGradient(colors: [Aria.goldBright, Aria.gold], center: .center, startRadius: 0, endRadius: 20))
                .frame(width: 40, height: 40).position(center)
                .shadow(color: Aria.gold.opacity(0.7), radius: 12)
            Text("Aria").font(.fraunces(10, .semibold)).foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02)).position(center)

            // nodes (sessions)
            ForEach(Array(sessions.enumerated()), id: \.element.id) { i, s in
                if i < pts.count { node(s, at: pts[i], index: i) }
            }

            if sessions.isEmpty {
                Text("No sessions yet").font(.inter(12)).foregroundColor(Aria.ivoryFaint).position(x: center.x, y: center.y + 52)
            }
        }
    }

    private func node(_ s: ExecutiveSession, at point: CGPoint, index: Int) -> some View {
        let color: Color = s.type == .clientCall ? Aria.jade : (index % 2 == 0 ? Aria.gold : Aria.rose)
        return VStack(spacing: 4) {
            Circle().fill(color).frame(width: 13, height: 13).shadow(color: color.opacity(0.8), radius: 6)
            Text(s.title).font(.inter(8.5)).foregroundColor(Aria.ivoryDim)
                .lineLimit(1).frame(maxWidth: 76)
        }
        .position(point)
        .onTapGesture { onTap(s) }
    }

    private func nodePoints(center: CGPoint, size: CGSize) -> [CGPoint] {
        let radius = min(size.width, size.height) * 0.40
        let n = max(1, sessions.count)
        return (0..<n).map { i in
            let angle = (CGFloat(i) / CGFloat(n)) * 2 * .pi - .pi / 2
            return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
    }
}
