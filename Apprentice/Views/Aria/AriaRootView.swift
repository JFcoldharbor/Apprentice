//
//  AriaRootView.swift
//  Apprentice
//
//  Root shell for the Aria redesign: the six-tab layout with a center-raised
//  Record orb, matching aria-redesign.html. Home is the fully redesigned screen;
//  the other five are styled placeholders until their redesign pass lands.
//

import SwiftUI

struct AriaRootView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AriaBackground()

            Group {
                switch selectedTab {
                case 0: AriaHomeScreen(selectedTab: $selectedTab)
                case 1: AriaSessionsScreen(selectedTab: $selectedTab)
                case 2: AriaRecordScreen()
                case 3: AriaIntelligenceScreen()
                case 4: AriaMemoryScreen()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            AriaTabBar(selected: $selectedTab)
        }
        // On launch: (1) analyze any session that transcribed but never got a
        // summary, then (2) backfill — re-mirror every analyzed session to web
        // Aria, healing any whose mirror was previously missed.
        .task {
            await SessionManager.shared.enrichPendingSessions()
            SessionManager.shared.syncAnalyzedSessions()
        }
    }
}

// MARK: - Tab bar

struct AriaTabBar: View {
    @Binding var selected: Int

    private struct Item { let i: Int; let icon: String; let label: String }
    private let items: [Item] = [
        .init(i: 0, icon: "house", label: "Home"),
        .init(i: 1, icon: "list.bullet.rectangle", label: "Sessions"),
        .init(i: 2, icon: "mic.fill", label: "Record"),       // center (middle of 5), raised
        .init(i: 3, icon: "chart.line.uptrend.xyaxis", label: "Intelligence"),
        .init(i: 4, icon: "brain.head.profile", label: "Memory"),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(items, id: \.i) { item in
                if item.i == 2 { recordTab(item) } else { standardTab(item) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(
            LinearGradient(colors: [Aria.bg, Aria.bg, Aria.bg.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func standardTab(_ item: Item) -> some View {
        let active = selected == item.i
        return Button { selected = item.i } label: {
            VStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(active ? Aria.goldBright : Aria.ivoryFaint)
                    .shadow(color: active ? Aria.gold.opacity(0.5) : .clear, radius: 8)
                Text(item.label)
                    .font(.inter(9, .medium))
                    .foregroundColor(active ? Aria.goldBright : Aria.ivoryFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func recordTab(_ item: Item) -> some View {
        let active = selected == item.i
        return Button { selected = item.i } label: {
            VStack(spacing: 1) {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                    .frame(width: 50, height: 50)
                    .background(
                        Circle().fill(
                            RadialGradient(colors: active ? [Color(red: 0.91, green: 0.71, blue: 0.65), Aria.rose]
                                                          : [Aria.goldBright, Aria.gold],
                                           center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 50))
                    )
                    .shadow(color: (active ? Aria.rose : Aria.gold).opacity(0.6), radius: 12, y: 6)
                Text(item.label)
                    .font(.inter(9, .medium))
                    .foregroundColor(active ? Aria.goldBright : Aria.ivoryFaint)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder (until each screen's redesign lands)

struct AriaPlaceholder: View {
    let eyebrow: String
    let plain: String
    let em: String
    let sub: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                AriaEyebrow(text: eyebrow).padding(.bottom, 4)
                AriaTitle(plain: plain, em: em)
                AriaSub(text: sub).padding(.top, 2)

                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 26))
                        .foregroundColor(Aria.gold)
                    Text("Redesign in progress")
                        .font(.fraunces(18, .medium)).foregroundColor(Aria.ivory)
                    Text("This screen gets the Aria treatment next.")
                        .font(.inter(13)).foregroundColor(Aria.ivoryFaint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundColor(Aria.line)
                )
                .padding(.top, 40)
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 130)
        }
    }
}
