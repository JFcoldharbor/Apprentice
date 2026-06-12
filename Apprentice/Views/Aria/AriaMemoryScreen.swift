//
//  AriaMemoryScreen.swift
//  Apprentice
//
//  Redesigned Memory (aria-redesign.html #v-memory): the connected-mind
//  constellation + memory metrics, wired to MemoryConnectionCalculator + sessions.
//

import SwiftUI

struct AriaMemoryScreen: View {
    @StateObject private var manager = SessionManager.shared
    @State private var seg = 0
    @State private var connectionCount = 0

    private var insightCount: Int { manager.sessions.reduce(0) { $0 + $1.notes.reduce(0) { $0 + $1.insights.count } } }
    private var conversationCount: Int { manager.sessions.count }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AriaEyebrow(text: "The connected mind").padding(.top, 14).padding(.bottom, 10)
                AriaTitle(plain: "Aria's ", em: "memory")

                ConstellationView(nodeCount: min(6, max(2, manager.sessions.count)))
                    .frame(height: 260)
                    .padding(.horizontal, -22)
                    .padding(.top, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(Aria.lineSoft).frame(height: 1) }

                VStack(spacing: 4) {
                    Text("One memory, every source").font(.fraunces(25)).foregroundColor(Aria.ivory)
                    Text("Sessions, conversations & documents woven together")
                        .font(.inter(13)).foregroundColor(Aria.ivoryDim)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 18)

                grid.padding(.bottom, 22)
                segControl.padding(.bottom, 20)

                if manager.sessions.isEmpty {
                    emptyLink
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 130)
        }
        .onAppear(perform: recompute)
    }

    private var grid: some View {
        HStack(spacing: 10) {
            memCell(icon: "link", tint: Aria.goldBright, n: connectionCount, l: "Connections")
            memCell(icon: "lightbulb", tint: Aria.rose, n: insightCount, l: "AI insights")
            memCell(icon: "bubble.left.and.bubble.right", tint: Aria.jade, n: conversationCount, l: "Conversations")
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

    private var segControl: some View {
        HStack(spacing: 4) {
            ForEach(Array(["All", "Sessions", "Conversations", "Links"].enumerated()), id: \.offset) { i, label in
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

    private var emptyLink: some View {
        VStack(spacing: 6) {
            Text("Your memory is just starting").font(.fraunces(18)).foregroundColor(Aria.ivory)
            Text("Record a session or upload a document, and Aria will begin drawing the connections between them.")
                .font(.inter(13)).foregroundColor(Aria.ivoryFaint).multilineTextAlignment(.center).lineSpacing(2)
        }
        .frame(maxWidth: .infinity).padding(34)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Aria.line))
    }

    private func recompute() {
        let snap = manager.sessions
        connectionCount = snap.count > 1 ? MemoryConnectionCalculator().analyzeConnections(sessions: snap).count : 0
    }
}

// MARK: - Constellation

private struct ConstellationView: View {
    let nodeCount: Int

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
    }

    private func content(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let pts = satellitePoints(center: center, size: size)
        return ZStack {
            // links to core
            Path { p in
                for pt in pts { p.move(to: center); p.addLine(to: pt) }
            }
            .stroke(Aria.gold.opacity(0.22), lineWidth: 1)

            // ring around core
            Circle().stroke(Aria.gold.opacity(0.3), lineWidth: 1)
                .frame(width: 66, height: 66).position(center)

            // satellites
            ForEach(Array(pts.enumerated()), id: \.offset) { item in
                satellite(at: item.element, index: item.offset)
            }

            // core
            Circle()
                .fill(RadialGradient(colors: [Aria.goldBright, Aria.gold], center: .center, startRadius: 0, endRadius: 22))
                .frame(width: 44, height: 44).position(center)
                .shadow(color: Aria.gold.opacity(0.7), radius: 12)
            Text("Aria")
                .font(.fraunces(11, .semibold))
                .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                .position(center)
        }
    }

    private func satellite(at point: CGPoint, index: Int) -> some View {
        let color: Color = index % 2 == 0 ? Aria.jade : Aria.rose
        return Circle().fill(color)
            .frame(width: 12, height: 12)
            .position(point)
            .shadow(color: color.opacity(0.8), radius: 6)
    }

    private func satellitePoints(center: CGPoint, size: CGSize) -> [CGPoint] {
        let radius: CGFloat = min(size.width, size.height) * 0.42
        let n: Int = max(1, nodeCount)
        var result: [CGPoint] = []
        for i in 0..<n {
            let angle: CGFloat = (CGFloat(i) / CGFloat(n)) * 2 * .pi - .pi / 2
            let x: CGFloat = center.x + cos(angle) * radius
            let y: CGFloat = center.y + sin(angle) * radius
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }
}
