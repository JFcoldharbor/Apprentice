//
//  SettingsScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — the Settings tab. Voice prefs, account/auth status, a live
//  proxy connection test, and data management. Replaces the legacy Documents tab.
//

import SwiftUI
import SwiftData

struct SettingsScreen: View {

    @Environment(\.modelContext) private var context
    @ObservedObject private var auth = AuthService.shared

    @AppStorage("coach_autospeak") private var autoSpeak = false
    @AppStorage("coach_voice_id") private var voiceId = ""

    @State private var testing = false
    @State private var connectionResult: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                List {
                    voiceSection
                    accountSection
                    connectionSection
                    dataSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
            }
            .navigationTitle("Settings")
        }
        .tint(Color.appAccent)
    }

    // MARK: - Sections

    private var voiceSection: some View {
        Section {
            Toggle("Speak coach replies", isOn: $autoSpeak)
            HStack {
                Text("ElevenLabs voice ID")
                Spacer()
                TextField("default", text: $voiceId)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.white.opacity(0.6))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        } header: {
            Text("Voice").foregroundStyle(.white.opacity(0.6))
        } footer: {
            Text("Leave the voice ID blank to use the default brand voice.")
                .foregroundStyle(.white.opacity(0.4))
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private var accountSection: some View {
        Section {
            LabeledContent("Status", value: accountStatus)
            if let uid = auth.uid {
                LabeledContent("User ID", value: String(uid.prefix(12)) + "\u{2026}")
            }
        } header: {
            Text("Account").foregroundStyle(.white.opacity(0.6))
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private var connectionSection: some View {
        Section {
            LabeledContent("AI proxy", value: ProxyConfig.isConfigured ? "Configured" : "Not configured")
            Button {
                Task { await testConnection() }
            } label: {
                HStack {
                    Text("Test connection")
                    Spacer()
                    if testing {
                        ProgressView().tint(.white)
                    } else if let result = connectionResult {
                        Text(result).foregroundStyle(result.hasPrefix("Connected") ? .green : .red)
                    }
                }
            }
            .disabled(testing || !ProxyConfig.isConfigured)
        } header: {
            Text("Connection").foregroundStyle(.white.opacity(0.6))
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private var dataSection: some View {
        Section {
            Button("Clear coach conversation", role: .destructive) {
                clearCoachConversation()
            }
        } header: {
            Text("Data").foregroundStyle(.white.opacity(0.6))
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About").foregroundStyle(.white.opacity(0.6))
        }
        .listRowBackground(Color.white.opacity(0.06))
    }

    // MARK: - Helpers

    private var accountStatus: String {
        auth.isSignedIn ? "Signed in" : "Not signed in"
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func testConnection() async {
        testing = true
        connectionResult = nil
        defer { testing = false }
        do {
            _ = try await AIClient.shared.chatText(
                system: nil,
                messages: [AIChatMessage(role: "user", content: "ping")],
                tier: .classifier,
                maxTokens: 16
            )
            connectionResult = "Connected"
        } catch {
            connectionResult = "Failed"
        }
    }

    private func clearCoachConversation() {
        let all = (try? context.fetch(FetchDescriptor<CoachMessage>())) ?? []
        for message in all { context.delete(message) }
        try? context.save()
    }
}
