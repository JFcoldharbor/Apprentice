//
//  CoachScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — the Coach tab. Chat with the business-growth advisor that
//  reads your notes + open actions. Reactive message list via @Query; sending
//  goes through CoachViewModel.
//

import SwiftUI
import SwiftData

struct CoachScreen: View {

    @Query(sort: \CoachMessage.createdAt) private var messages: [CoachMessage]
    @StateObject private var vm = CoachViewModel(context: NoteStore.mainContext)
    @ObservedObject private var dictation = DictationService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    messageList
                    inputBar
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.autoSpeak.toggle()
                        if !vm.autoSpeak { VoiceService.shared.stop() }
                    } label: {
                        Image(systemName: vm.autoSpeak ? "speaker.wave.2.fill" : "speaker.slash")
                    }
                    .tint(vm.autoSpeak ? Color.appAccent : .white)
                }
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { vm.clearConversation() } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.white)
                    }
                }
            }
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty { emptyState }
                    ForEach(messages) { message in
                        CoachBubble(message: message) {
                            Task { await VoiceService.shared.speak(message.text) }
                        }
                    }
                    if vm.isSending { TypingBubble().id("typing") }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: vm.isSending) { _, _ in scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if vm.isSending {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundStyle(Color.appAccent)
            Text("Talk to your coach")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Ask about your notes, what to prioritize, or where you're stuck. The coach reads your recorded notes and open action items.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                suggestion("What should I focus on this week?")
                suggestion("Summarize where things stand across my recent notes.")
                suggestion("What am I avoiding?")
            }
            .padding(.top, 8)
        }
        .padding(.top, 50)
        .padding(.horizontal, 20)
    }

    private func suggestion(_ text: String) -> some View {
        Button { vm.draft = text } label: {
            Text("\u{201C}\(text)\u{201D}")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your coach\u{2026}", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassCard()

            Button {
                Task { await dictation.toggle() }
            } label: {
                Image(systemName: dictation.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 24))
                    .foregroundStyle(dictation.isListening ? .red : Color.appAccent)
            }

            Button { vm.send() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.appAccent : .white.opacity(0.25))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: dictation.transcript) { _, newValue in
            if dictation.isListening { vm.draft = newValue }
        }
    }

    private var canSend: Bool {
        !vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isSending
    }
}

// MARK: - Bubbles

private struct CoachBubble: View {
    let message: CoachMessage
    var onSpeak: () -> Void = {}

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser { Spacer(minLength: 40) }
            Text(message.text)
                .foregroundStyle(message.isUser ? .white : .white.opacity(0.92))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(message.isUser ? Color.appAccent.opacity(0.85) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(message.isUser ? 0 : 0.1), lineWidth: 1)
                )
            if !message.isUser { Spacer(minLength: 40) }
        }
        .id(message.id)
        .contextMenu {
            if !message.isUser {
                Button { onSpeak() } label: { Label("Speak", systemImage: "speaker.wave.2") }
            }
        }
    }
}

private struct TypingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06)))
            Spacer(minLength: 40)
        }
        .onAppear { animating = true }
    }
}
