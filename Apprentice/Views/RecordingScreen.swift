//
//  RecordingScreen.swift
//  Apprentice
//
//  Layer 5 (Views) — capture UI. Live waveform + live (on-device) transcript +
//  per-chunk status while recording. Reuses the app's glassmorphism look.
//

import SwiftUI
import SwiftData

struct RecordingScreen: View {

    @StateObject private var vm = RecordingViewModel(context: NoteStore.mainContext)
    @State private var levels: [Float] = Array(repeating: 0, count: 48)

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 20) {
                header

                if vm.isActive {
                    activeRecordingBody
                } else {
                    idleBody
                }

                Spacer(minLength: 0)
                transportControls
            }
            .padding(20)
        }
        .task { await vm.requestPermissions() }
        .onChange(of: vm.audioLevel) { _, newValue in
            levels.removeFirst()
            levels.append(newValue)
        }
        .alert("Recording error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.isActive ? "Recording" : "New Note")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                if vm.isActive {
                    Text(vm.formattedElapsed)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(Color.appAccent)
                }
            }
            Spacer()
            if vm.micDenied {
                Label("Mic off", systemImage: "mic.slash.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Idle

    private var idleBody: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Note title (optional)", text: $vm.pendingTitle)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)

                Divider().overlay(.white.opacity(0.1))

                HStack {
                    Image(systemName: vm.noteType.iconName).foregroundStyle(Color.appAccent)
                    Picker("Type", selection: $vm.noteType) {
                        ForEach(NoteType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                    Spacer()
                }
            }
            .padding(16)
            .glassCard()

            Text("Tap record to start. Audio is saved and transcribed automatically — and kept, so you can re-transcribe any time.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Active

    private var activeRecordingBody: some View {
        VStack(spacing: 16) {
            WaveformView(levels: levels, paused: vm.phase == .paused)
                .frame(height: 80)
                .padding(.horizontal, 8)

            chunkStatusRow

            liveTranscriptCard
        }
    }

    private var chunkStatusRow: some View {
        HStack(spacing: 12) {
            Label("Segment \(vm.capture.engine.currentChunkIndex + 1)", systemImage: "square.stack.3d.up")
            Spacer()
            if vm.isLiveAvailable {
                Label("Live", systemImage: "waveform")
                    .foregroundStyle(.green)
            } else {
                Label("Whisper", systemImage: "cloud")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 4)
    }

    private var liveTranscriptCard: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(vm.liveTranscript.isEmpty ? "Listening…" : vm.liveTranscript)
                    .font(.body)
                    .foregroundStyle(vm.liveTranscript.isEmpty ? .white.opacity(0.4) : .white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .id("transcriptEnd")
            }
            .onChange(of: vm.liveTranscript) { _, _ in
                withAnimation { proxy.scrollTo("transcriptEnd", anchor: .bottom) }
            }
        }
        .frame(maxHeight: 280)
        .glassCard()
    }

    // MARK: - Transport

    private var transportControls: some View {
        HStack(spacing: 32) {
            switch vm.phase {
            case .idle:
                recordButton
            case .recording:
                pauseButton
                stopButton
            case .paused:
                resumeButton
                stopButton
            }
        }
        .padding(.bottom, 8)
    }

    private var recordButton: some View {
        Button {
            vm.start()
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Color.red))
                .shadow(color: .red.opacity(0.5), radius: 12)
        }
        .disabled(vm.micDenied)
    }

    private var pauseButton: some View {
        Button { vm.pause() } label: {
            controlIcon("pause.fill", tint: .orange)
        }
    }

    private var resumeButton: some View {
        Button { vm.resume() } label: {
            controlIcon("mic.fill", tint: .red)
        }
    }

    private var stopButton: some View {
        Button { vm.stop() } label: {
            controlIcon("stop.fill", tint: .white, background: Color.appAccent)
        }
    }

    private func controlIcon(_ name: String, tint: Color, background: Color = .white.opacity(0.1)) -> some View {
        Image(systemName: name)
            .font(.system(size: 26))
            .foregroundStyle(tint)
            .frame(width: 68, height: 68)
            .background(Circle().fill(background))
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let levels: [Float]
    var paused: Bool

    var body: some View {
        GeometryReader { geo in
            let barWidth = max(2, geo.size.width / CGFloat(levels.count) - 3)
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(paused ? Color.white.opacity(0.2) : Color.appAccent)
                        .frame(width: barWidth,
                               height: max(3, CGFloat(level) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
