//
//  AriaVoiceSheet.swift
//  Apprentice
//
//  A live, hands-free spoken conversation with Aria — tap the orb to begin.
//  Loop: on-device STT (DictationService) → Claude + note memory
//  (AIClient + CoachContext) → ElevenLabs voice (VoiceService), turn-taking
//  automatically. Shares the same CoachMessage thread as the text chat.
//
//  All state is driven on the main actor (the services are @MainActor), so the
//  turn-taking transitions are race-free.
//

import SwiftUI
import SwiftData

struct AriaVoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dictation = DictationService.shared
    @ObservedObject private var voice = VoiceService.shared

    enum Phase { case idle, listening, thinking, speaking }
    @State private var phase: Phase = .idle
    @State private var active = false
    @State private var lastReply = ""
    @State private var pulse = false
    @State private var errorText: String?

    private let context = NoteStore.mainContext

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            orb
            statusBlock
            Spacer(minLength: 0)
            controls
        }
        .ariaSheetSurface()
        .onAppear { startConversation() }
        .onDisappear { endConversation() }
        // Turn-taking transitions
        .onChange(of: dictation.isListening) { _, listening in
            if !listening, phase == .listening { turnCaptured() }
        }
        .onChange(of: voice.isSpeaking) { _, speaking in
            if !speaking, phase == .speaking { resumeListening() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            AriaEyebrow(text: "Live · Aria")
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Aria.ivoryDim).ariaHeaderIcon()
            }
        }
        .padding(.horizontal, 22).padding(.top, 18)
    }

    // MARK: - Orb

    private var orb: some View {
        ZStack {
            ForEach(haloSizes, id: \.self) { d in
                Circle().stroke(ringColor.opacity(0.18), lineWidth: 1)
                    .frame(width: d, height: d)
                    .scaleEffect(animate ? 1.08 : 1.0)
                    .opacity(animate ? 0.2 : 1.0)
                    .animation(animate ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true) : .default, value: pulse)
            }
            Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.95), Aria.goldBright, Aria.gold, Color(red: 0.61, green: 0.51, blue: 0.28)],
                    center: UnitPoint(x: 0.38, y: 0.32), startRadius: 4, endRadius: 130))
                .frame(width: 150, height: 150)
                .shadow(color: ringColor.opacity(0.6), radius: 34)
                .overlay(
                    Image(systemName: orbIcon)
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color(red: 0.23, green: 0.17, blue: 0.06).opacity(0.85))
                )
                .scaleEffect(phase == .speaking && pulse ? 1.04 : 1.0)
                .animation(phase == .speaking ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: pulse)
        }
        .frame(height: 240)
        .onTapGesture { tapOrb() }
    }

    private var statusBlock: some View {
        VStack(spacing: 14) {
            Text(statusLabel)
                .font(.fraunces(24)).foregroundColor(Aria.ivory)
            Text(transcriptText.isEmpty ? placeholder : transcriptText)
                .font(.inter(15))
                .foregroundColor(transcriptText.isEmpty ? Aria.ivoryFaint : Aria.ivory.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 30)
                .frame(minHeight: 60)
            if let errorText {
                Text(errorText).font(.inter(12)).foregroundColor(Aria.rose)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            }
        }
        .padding(.top, 30)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 36) {
            controlButton(icon: dictation.isListening ? "mic.fill" : "mic",
                          tint: dictation.isListening ? Aria.jade : Aria.ivoryDim,
                          label: dictation.isListening ? "Listening" : "Tap orb to talk") { tapOrb() }
            controlButton(icon: "xmark.circle", tint: Aria.rose, label: "End") { dismiss() }
        }
        .padding(.bottom, 30)
    }

    private func controlButton(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(tint)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Aria.panel))
                    .overlay(Circle().stroke(Aria.lineSoft, lineWidth: 1))
                Text(label).font(.inter(10.5)).foregroundColor(Aria.ivoryDim)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversation loop

    private func startConversation() {
        active = true
        pulse = true
        resumeListening()
    }

    private func endConversation() {
        active = false
        phase = .idle
        dictation.stop()
        voice.stop()
    }

    private func resumeListening() {
        guard active else { return }
        errorText = nil
        phase = .listening
        Task { await dictation.start() }
    }

    private func turnCaptured() {
        guard active, phase == .listening else { return }
        let said = dictation.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if said.isEmpty {
            // Silence with nothing said — listen again after a short beat to avoid a tight loop.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if active, phase == .listening, !dictation.isListening { await dictation.start() }
            }
            return
        }
        sendToAria(said)
    }

    private func tapOrb() {
        switch phase {
        case .listening: dictation.stop()      // → turnCaptured (sends what was said)
        case .speaking:  voice.stop()          // interrupt → resumeListening
        case .thinking:  break
        case .idle:      resumeListening()
        }
    }

    private func sendToAria(_ said: String) {
        lastReply = ""
        phase = .thinking
        context.insert(CoachMessage(role: "user", text: said))
        try? context.save()

        Task { @MainActor in
            do {
                let system = CoachPersona.system + "\n\n" + CoachContext.build(query: said, context: context)
                let reply = try await AIClient.shared.chatText(
                    system: system, messages: recentHistory(), tier: .standard, maxTokens: 1500)
                context.insert(CoachMessage(role: "assistant", text: reply))
                try? context.save()
                guard active else { return }
                lastReply = reply
                phase = .speaking
                await voice.speak(reply)
                // If TTS didn't start (proxy off / failed), the isSpeaking observer
                // won't fire — resume listening directly.
                if phase == .speaking, !voice.isSpeaking { resumeListening() }
            } catch {
                errorText = error.localizedDescription
                guard active else { return }
                resumeListening()
            }
        }
    }

    private func recentHistory(limit: Int = 12) -> [AIChatMessage] {
        var descriptor = FetchDescriptor<CoachMessage>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let recent = ((try? context.fetch(descriptor)) ?? []).reversed()
        var messages = recent.map { AIChatMessage(role: $0.role, content: $0.text) }
        while let first = messages.first, first.role != "user" { messages.removeFirst() }
        return messages
    }

    // MARK: - Presentation helpers

    private var animate: Bool { phase == .listening || phase == .speaking }
    private var ringColor: Color {
        switch phase {
        case .listening: return Aria.jade
        case .speaking: return Aria.gold
        default: return Aria.gold
        }
    }
    private var orbIcon: String {
        switch phase {
        case .listening: return "waveform"
        case .thinking: return "ellipsis"
        case .speaking: return "speaker.wave.2.fill"
        case .idle: return "mic.fill"
        }
    }
    private var statusLabel: String {
        switch phase {
        case .listening: return "Listening…"
        case .thinking: return "Thinking…"
        case .speaking: return "Aria"
        case .idle: return "Tap to talk"
        }
    }
    private var transcriptText: String {
        switch phase {
        case .listening: return dictation.transcript
        case .speaking, .thinking: return lastReply
        case .idle: return ""
        }
    }
    private var placeholder: String {
        switch phase {
        case .listening: return "Say something to Aria…"
        case .thinking: return ""
        default: return "Tap the orb and start talking. Aria hears you, thinks with your notes, and answers out loud."
        }
    }
    private let haloSizes: [CGFloat] = [240, 204, 168]
}
