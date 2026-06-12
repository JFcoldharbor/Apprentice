//
//  AriaAskSheet.swift
//  Apprentice
//
//  "Ask Aria" — the conversational coach (Claude via proxy, grounded in the
//  founder's notes + open actions), restyled in the Aria language. Replaces the
//  CoachScreen sheet on Home.
//

import SwiftUI
import SwiftData

struct AriaAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CoachMessage.createdAt) private var messages: [CoachMessage]
    @StateObject private var vm = CoachViewModel(context: NoteStore.mainContext)
    @ObservedObject private var dictation = DictationService.shared

    var body: some View {
        VStack(spacing: 0) {
            AriaSheetHeader(title: "Ask Aria", onClose: { dismiss() }) {
                Button {
                    vm.autoSpeak.toggle()
                    if !vm.autoSpeak { VoiceService.shared.stop() }
                } label: {
                    Image(systemName: vm.autoSpeak ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.system(size: 14))
                        .foregroundColor(vm.autoSpeak ? Aria.goldBright : Aria.ivoryDim)
                        .ariaHeaderIcon()
                }
                if !messages.isEmpty {
                    Button { vm.clearConversation() } label: {
                        Image(systemName: "trash").font(.system(size: 13))
                            .foregroundColor(Aria.ivoryDim).ariaHeaderIcon()
                    }
                }
            }
            messageList
            inputBar
        }
        .ariaSheetSurface()
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty { emptyState }
                    ForEach(messages) { m in
                        AriaBubble(message: m) { Task { await VoiceService.shared.speak(m.text) } }
                    }
                    if vm.isSending { AriaTyping().id("typing") }
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in scrollDown(proxy) }
            .onChange(of: vm.isSending) { _, _ in scrollDown(proxy) }
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation {
            if vm.isSending { proxy.scrollTo("typing", anchor: .bottom) }
            else if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(RadialGradient(colors: [Aria.goldBright, Aria.gold], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 34))
                .frame(width: 64, height: 64)
                .shadow(color: Aria.gold.opacity(0.5), radius: 16)
            Text("Ask Aria anything")
                .font(.fraunces(20, .medium)).foregroundColor(Aria.ivory)
            Text("She reads your recorded notes and open action items. Ask what to prioritize, where you're stuck, or for a recap.")
                .font(.inter(13)).foregroundColor(Aria.ivoryDim)
                .multilineTextAlignment(.center).lineSpacing(2)
            VStack(spacing: 8) {
                suggestion("What should I focus on this week?")
                suggestion("Summarize where things stand across my recent notes.")
                suggestion("What am I avoiding?")
            }
            .padding(.top, 6)
        }
        .padding(.top, 40).padding(.horizontal, 6)
    }

    private func suggestion(_ text: String) -> some View {
        Button { vm.draft = text } label: {
            Text("“\(text)”")
                .font(.inter(13)).foregroundColor(Aria.ivory.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask Aria…", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .font(.inter(14.5)).foregroundColor(Aria.ivory).tint(Aria.gold)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))

            Button { Task { await dictation.toggle() } } label: {
                Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 22)).foregroundColor(dictation.isListening ? Aria.rose : Aria.goldBright)
            }
            Button { vm.send() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? Aria.goldBright : Aria.ivoryFaint)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
        .onChange(of: dictation.transcript) { _, newValue in
            if dictation.isListening { vm.draft = newValue }
        }
    }

    private var canSend: Bool {
        !vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isSending
    }
}

// MARK: - Bubbles

private struct AriaBubble: View {
    let message: CoachMessage
    var onSpeak: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 44) }
            Text(message.text)
                .font(.inter(14.5))
                .foregroundColor(message.isUser ? Color(red: 0.1, green: 0.07, blue: 0.02) : Aria.ivory.opacity(0.92))
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(
                    Group {
                        if message.isUser {
                            LinearGradient(colors: [Aria.gold, Aria.goldBright], startPoint: .topLeading, endPoint: .bottomTrailing)
                        } else {
                            Aria.panel
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(message.isUser ? Color.clear : Aria.lineSoft, lineWidth: 1))
            if !message.isUser { Spacer(minLength: 44) }
        }
        .id(message.id)
        .contextMenu {
            if !message.isUser {
                Button { onSpeak() } label: { Label("Speak", systemImage: "speaker.wave.2") }
            }
        }
    }
}

private struct AriaTyping: View {
    @State private var animating = false
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Aria.gold.opacity(0.7)).frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1 : 0.5)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
                }
            }
            .padding(12)
            .background(Aria.panel).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 44)
        }
        .onAppear { animating = true }
    }
}
