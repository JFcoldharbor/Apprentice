//
//  AriaRecordScreen.swift
//  Apprentice
//
//  Redesigned Record (aria-redesign.html #v-record), driving the new SwiftData
//  capture pipeline (RecordingViewModel / NoteCaptureService): audio retained,
//  per-chunk proxy transcription, automatic Claude enrichment, chunk re-transcribe.
//

import SwiftUI

struct AriaRecordScreen: View {
    @StateObject private var vm = RecordingViewModel(context: NoteStore.mainContext)
    @ObservedObject private var handoff = RecordingHandoff.shared
    @State private var context: AriaRecordContext = .personal
    @State private var showingContext = false
    @State private var finishedNote: Note?
    @State private var pulse = false

    private var displayNote: Note? { vm.currentNote ?? finishedNote }
    private var isProcessing: Bool {
        guard let n = displayNote else { return false }
        if n.isTranscribing { return true }
        return !n.fullTranscript.isEmpty && n.aiSummary.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AriaEyebrow(text: "Aria · Live Intelligence").padding(.top, 14).padding(.bottom, 10)
                AriaTitle(plain: "Begin a ", em: "session")
                AriaSub(text: "Aria listens, remembers, and connects every conversation to what came before.")
                    .padding(.top, 6).padding(.bottom, 22)

                contextCard
                Text("Tap to switch · Board · Client · 1:1 · Content")
                    .font(.inter(11.5)).foregroundColor(Aria.ivoryFaint)
                    .frame(maxWidth: .infinity).padding(.top, 8)

                recordStage.padding(.top, 30)

                if let note = displayNote, !note.orderedChunks.isEmpty {
                    chunkList(note).padding(.top, 24)
                }
                if let note = displayNote, !note.fullTranscript.isEmpty || !note.aiSummary.isEmpty || isProcessing {
                    resultsCard(note).padding(.top, 18)
                }
                if displayNote == nil {
                    prep.padding(.top, 30)
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 130)
        }
        .task { await vm.requestPermissions() }
        .sheet(isPresented: $showingContext) {
            AriaContextSheet(selected: $context)
                .presentationDetents([.medium, .large])
        }
        .onAppear { pulse = true; consumePrefill() }
        .onChange(of: handoff.prefill) { _, _ in consumePrefill() }
    }

    /// Begin a recording pre-filled from a staged "Upcoming" session that the user
    /// tapped Start on (handed over via RecordingHandoff).
    private func consumePrefill() {
        guard let p = handoff.prefill, !vm.isActive else { return }
        handoff.prefill = nil
        finishedNote = nil
        vm.noteType = p.type
        vm.pendingTitle = p.title
        vm.pendingAttendees = p.attendees
        vm.start()
    }

    // MARK: Context card

    private var contextCard: some View {
        Button { showingContext = true } label: {
            HStack(spacing: 16) {
                Image(systemName: context.glyph)
                    .font(.system(size: 21)).foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(
                        RadialGradient(colors: [Aria.goldBright, Aria.gold], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 46)))
                    .shadow(color: Aria.gold.opacity(0.6), radius: 10, y: 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CONTEXT").font(.ariaMono(10)).tracking(2).foregroundColor(Aria.gold)
                    Text(context.rawValue).font(.fraunces(19, .medium)).foregroundColor(Aria.ivory)
                    Text(context.blurb).font(.inter(12.5)).foregroundColor(Aria.ivoryDim).lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15)).foregroundColor(Aria.ivoryFaint)
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .background(LinearGradient(colors: [Aria.gold.opacity(0.08), Aria.panel.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: Aria.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Aria.radius, style: .continuous).stroke(Aria.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(vm.isActive)
    }

    // MARK: Record stage

    private var recordStage: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach([184.0, 148.0, 112.0], id: \.self) { d in
                    Circle().stroke(Aria.gold.opacity(d == 184 ? 0.05 : (d == 148 ? 0.08 : 0.14)), lineWidth: 1)
                        .frame(width: d, height: d)
                        .scaleEffect(vm.isActive && pulse ? 1.12 : 1)
                        .opacity(vm.isActive && pulse ? 0 : 1)
                        .animation(vm.isActive ? .easeOut(duration: 2.4).repeatForever(autoreverses: false) : .default, value: pulse)
                }
                Button(action: toggle) {
                    Circle()
                        .fill(RadialGradient(
                            colors: vm.isActive ? [Color(red: 0.23, green: 0.13, blue: 0.1), Color(red: 0.1, green: 0.05, blue: 0.03)]
                                                : [Aria.panel2, Aria.ink],
                            center: UnitPoint(x: 0.35, y: 0.3), startRadius: 4, endRadius: 132))
                        .frame(width: 132, height: 132)
                        .overlay(Circle().stroke(vm.isActive ? Aria.rose : Aria.gold.opacity(0.3), lineWidth: 1))
                        .overlay(
                            Image(systemName: vm.isActive ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(vm.isActive ? Color(red: 0.91, green: 0.71, blue: 0.65) : Aria.goldBright)
                        )
                        .shadow(color: .black.opacity(0.8), radius: 16, y: 14)
                }
                .buttonStyle(.plain)
                .disabled(vm.micDenied)
            }
            .frame(height: 196)

            Text(vm.isActive ? "Listening…" : "Ready when you are")
                .font(.fraunces(26)).foregroundColor(Aria.ivory).padding(.top, 30)
            Text(vm.isActive ? vm.formattedElapsed : (vm.micDenied ? "Microphone access needed" : " "))
                .font(.ariaMono(13)).tracking(2).foregroundColor(vm.micDenied ? Aria.rose : Aria.gold)
                .padding(.top, 8)

            if vm.isActive { waveform.padding(.top, 18) }
        }
        .frame(maxWidth: .infinity)
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<9, id: \.self) { i in
                Capsule().fill(Aria.gold)
                    .frame(width: 3, height: pulse ? CGFloat([10, 26, 16, 22, 8, 18, 24, 12, 20][i]) : 6)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.07), value: pulse)
            }
        }
        .frame(height: 30)
    }

    // MARK: Prep checklist

    private var prep: some View {
        VStack(alignment: .leading, spacing: 0) {
            AriaSectionLabel(text: "Before you start").padding(.bottom, 6)
            prepRow(ok: !vm.micDenied, bold: "Microphone", rest: vm.micDenied ? "access needed" : "ready · clear audio")
            prepRow(ok: true, bold: "Investor Data Room", rest: "linked · documents in memory")
            prepRow(ok: false, bold: "Agenda", rest: "add talking points so Aria can track them live")
        }
    }

    private func prepRow(ok: Bool, bold: String, rest: String) -> some View {
        HStack(spacing: 13) {
            Circle().fill(ok ? Aria.jade : Aria.ivoryFaint).frame(width: 7, height: 7)
                .shadow(color: ok ? Aria.jade : .clear, radius: 5)
            (Text(bold).foregroundColor(Aria.ivory).font(.inter(14, .medium))
             + Text(" · \(rest)").foregroundColor(Aria.ivoryDim).font(.inter(14)))
            Spacer()
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Aria.lineSoft).frame(height: 1) }
    }

    // MARK: Results + chunks

    private func chunkList(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AriaSectionLabel(text: "Segments")
            ForEach(note.orderedChunks, id: \.id) { chunk in
                HStack(spacing: 14) {
                    Image(systemName: chunk.status.iconName)
                        .font(.system(size: 16)).foregroundColor(chunk.isValidSize ? chunk.status.color : Aria.rose)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill((chunk.isValidSize ? chunk.status.color : Aria.rose).opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Segment \(chunk.index + 1)").font(.inter(13, .medium)).foregroundColor(Aria.ivory)
                        Text("\(chunk.status.displayName) · \(chunk.formattedDuration)").font(.ariaMono(10.5)).foregroundColor(Aria.ivoryDim)
                    }
                    Spacer()
                    if chunk.canRetry {
                        Button { vm.capture.retranscribe(chunk) } label: {
                            Image(systemName: "arrow.clockwise.circle.fill").font(.system(size: 22)).foregroundColor(Aria.gold)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(12).background(Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
            }
        }
    }

    private func resultsCard(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if isProcessing {
                HStack(spacing: 12) {
                    ProgressView().tint(Aria.gold)
                    Text("Aria is transcribing & analyzing…").font(.inter(13)).foregroundColor(Aria.ivoryDim)
                }
            } else {
                if !note.aiSummary.isEmpty {
                    labeled("Summary", note.aiSummary, icon: "brain")
                }
                if !note.fullTranscript.isEmpty {
                    labeled("Transcript", note.fullTranscript, icon: "text.quote")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func labeled(_ title: String, _ body: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(Aria.goldBright)
                Text(title.uppercased()).font(.ariaMono(10)).tracking(2).foregroundColor(Aria.gold)
            }
            Text(body).font(.inter(13.5)).foregroundColor(Aria.ivory.opacity(0.9)).lineSpacing(3)
        }
    }

    // MARK: Actions

    private func toggle() {
        if vm.isActive {
            finishedNote = vm.stop()
        } else {
            finishedNote = nil
            vm.noteType = context.noteType
            vm.pendingTitle = context == .content ? "" : "\(context.rawValue) · \(Date().formatted(date: .abbreviated, time: .shortened))"
            vm.start()
        }
    }
}
