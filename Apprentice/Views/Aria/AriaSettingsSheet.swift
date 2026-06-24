//
//  AriaSettingsSheet.swift
//  Apprentice
//
//  Aria-styled Settings, reached from the Home gear. Holds voice prefs, the
//  connected-sources/Documents screen (moved off the tab bar), a proxy
//  connection test, and data management.
//

import SwiftUI

struct AriaSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("coach_autospeak") private var autoSpeak = false
    @AppStorage("coach_voice_id") private var voiceId = ""

    @State private var testState: TestState = .idle
    @State private var clearedNote: String?

    enum TestState: Equatable { case idle, testing, ok, fail(String) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AriaSheetHeader(title: "Settings", onClose: { dismiss() })
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        knowledge
                        voice
                        connection
                        data
                        about
                    }
                    .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
                }
            }
            .ariaSheetSurface()
            .navigationDestination(for: String.self) { dest in
                if dest == "documents" {
                    AriaDocumentsScreen()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                } else if dest == "discovery" {
                    AriaDiscoveryScreen()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.hidden, for: .navigationBar)
                }
            }
        }
        .tint(Aria.goldBright)
    }

    // MARK: Sections

    private var knowledge: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "Knowledge")
            NavigationLink(value: "documents") {
                row(icon: "folder", tint: Aria.rose, title: "Documents & sources",
                    subtitle: "Investor data room + uploaded files", chevron: true)
            }
            .buttonStyle(.plain)
            NavigationLink(value: "discovery") {
                row(icon: "person.line.dotted.person", tint: Aria.jade, title: "Customer Discovery",
                    subtitle: "Log interviews → War Room charts + gates", chevron: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var voice: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "Voice")
            VStack(spacing: 0) {
                Toggle(isOn: $autoSpeak) {
                    Text("Speak Aria's replies").font(.inter(14.5)).foregroundColor(Aria.ivory)
                }
                .tint(Aria.gold)
                .padding(16)
                Divider().overlay(Aria.lineSoft)
                HStack {
                    Text("ElevenLabs voice ID").font(.inter(14.5)).foregroundColor(Aria.ivory)
                    Spacer()
                    TextField("default", text: $voiceId)
                        .font(.inter(13)).foregroundColor(Aria.ivoryDim).tint(Aria.gold)
                        .multilineTextAlignment(.trailing).frame(maxWidth: 140)
                }
                .padding(16)
            }
            .background(Aria.panel).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "Connection")
            Button(action: runTest) {
                row(icon: connectionIcon, tint: connectionTint, title: "Test Aria connection",
                    subtitle: connectionSubtitle, chevron: false, busy: testState == .testing)
            }
            .buttonStyle(.plain)
            .disabled(testState == .testing)
        }
    }

    private var data: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "Data")
            Button {
                CoachViewModel(context: NoteStore.mainContext).clearConversation()
                clearedNote = "Conversation cleared."
            } label: {
                row(icon: "trash", tint: Aria.rose, title: "Clear Aria conversation",
                    subtitle: clearedNote ?? "Removes the chat history (notes are kept)", chevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "About")
            row(icon: "sparkles", tint: Aria.goldBright, title: "Apprentice · Aria",
                subtitle: "Version \(appVersion)", chevron: false)
        }
    }

    // MARK: Row

    private func row(icon: String, tint: Color, title: String, subtitle: String, chevron: Bool, busy: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 11).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.inter(14.5, .semibold)).foregroundColor(Aria.ivory)
                Text(subtitle).font(.inter(12)).foregroundColor(Aria.ivoryDim).lineLimit(2)
            }
            Spacer(minLength: 0)
            if busy { ProgressView().tint(Aria.gold) }
            else if chevron { Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(Aria.ivoryFaint) }
        }
        .padding(16).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    // MARK: Connection test (race-free: all @State mutated on the main actor)

    private var connectionIcon: String {
        switch testState {
        case .ok: return "checkmark.seal.fill"
        case .fail: return "exclamationmark.triangle.fill"
        default: return "antenna.radiowaves.left.and.right"
        }
    }
    private var connectionTint: Color {
        switch testState {
        case .ok: return Aria.jade
        case .fail: return Aria.rose
        default: return Aria.goldBright
        }
    }
    private var connectionSubtitle: String {
        switch testState {
        case .idle: return ProxyConfig.isConfigured ? "Proxy configured · tap to ping Claude" : "Proxy not configured"
        case .testing: return "Pinging Aria's brain…"
        case .ok: return "Connected — Claude responded"
        case .fail(let m): return m
        }
    }

    private func runTest() {
        testState = .testing
        Task { @MainActor in
            do {
                _ = try await AIClient.shared.chatText(
                    system: "Reply with the single word: ok.",
                    messages: [AIChatMessage(role: "user", content: "ping")],
                    tier: .classifier,
                    maxTokens: 8
                )
                testState = .ok
            } catch {
                testState = .fail(error.localizedDescription)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
