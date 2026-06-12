//
//  ActiveRecordingView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Clean recording interface with all build errors fixed
//  COMPLETE: All syntax issues resolved, proper structure maintained
//
//  Repointed onto the new SwiftData capture stack (RecordingViewModel /
//  NoteCaptureService): audio is RETAINED (never deleted), transcription runs
//  per-chunk through the proxy, and AI enrichment (Claude) runs automatically.
//  The visual layout is unchanged from the original design.
//

import SwiftUI
import SwiftData

struct ActiveRecordingView: View {

    // MARK: - State Properties
    @StateObject private var vm = RecordingViewModel(context: NoteStore.mainContext)

    @State private var selectedContextType: ContextType = .personalMeeting
    @State private var showingContextSelector = false
    @State private var finishedNote: Note?
    @State private var isReanalyzing = false

    // MARK: - Context Types
    enum ContextType: String, CaseIterable, Identifiable {
        case personalMeeting = "Personal Meeting"
        case teamMeeting = "Team Meeting"
        case oneOnOne = "1:1 Conversation"
        case conference = "Conference/Event"
        case externalNoteTaker = "Content Analysis"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .personalMeeting: return "person.circle"
            case .teamMeeting: return "person.3"
            case .oneOnOne: return "person.2"
            case .conference: return "speaker.wave.2"
            case .externalNoteTaker: return "doc.text.magnifyingglass"
            }
        }

        var color: Color {
            switch self {
            case .personalMeeting: return .blue
            case .teamMeeting: return .green
            case .oneOnOne: return .purple
            case .conference: return .orange
            case .externalNoteTaker: return .cyan
            }
        }

        var description: String {
            switch self {
            case .personalMeeting: return "You're leading a meeting with specific outcomes"
            case .teamMeeting: return "Collaborative team discussion and planning"
            case .oneOnOne: return "Two-way conversation with mutual engagement"
            case .conference: return "You're attending and taking notes"
            case .externalNoteTaker: return "Analyzing content for key insights and summaries"
            }
        }

        var aiProcessingContext: String {
            switch self {
            case .personalMeeting: return "User is leading a meeting. Expect leadership decisions, strategic thinking, and assigned action items."
            case .teamMeeting: return "User is in a team meeting. Look for collaborative decisions, team dynamics, and shared responsibilities."
            case .oneOnOne: return "User is in mutual conversation. Analyze conversational dynamics, relationship building, and shared decision-making."
            case .conference: return "User is an attendee. Focus on capturing external insights, speaker takeaways, and industry trends."
            case .externalNoteTaker: return "User is consuming content. Extract key insights, summarize information, and identify learning opportunities. Auto-generate descriptive title."
            }
        }

        var meetingType: ExecutiveSession.MeetingType {
            switch self {
            case .personalMeeting: return .strategySession
            case .teamMeeting: return .teamMeeting
            case .oneOnOne: return .oneOnOne
            case .conference: return .clientCall
            case .externalNoteTaker: return .boardMeeting
            }
        }

        /// New-stack NoteType equivalent (drives the SwiftData Note's type).
        var noteType: NoteType {
            switch self {
            case .personalMeeting: return .strategySession
            case .teamMeeting: return .teamMeeting
            case .oneOnOne: return .oneOnOne
            case .conference: return .clientCall
            case .externalNoteTaker: return .boardMeeting
            }
        }
    }

    // MARK: - Derived state (from the new capture VM / Note)

    /// The note currently being recorded, or the one just finished (so results
    /// stay on screen after stop, since the VM clears currentNote on stop).
    private var displayNote: Note? { vm.currentNote ?? finishedNote }

    private var transcriptText: String {
        if let n = displayNote, !n.fullTranscript.isEmpty { return n.fullTranscript }
        return ""
    }

    private var summaryText: String { displayNote?.aiSummary ?? "" }

    /// Spinner state: transcribing chunks, enriching, or a manual re-analyze.
    private var isProcessing: Bool {
        if isReanalyzing { return true }
        guard let n = displayNote else { return false }
        if n.isTranscribing { return true }
        return !n.fullTranscript.isEmpty && n.aiSummary.isEmpty
    }

    private var hasChunks: Bool { !(displayNote?.orderedChunks.isEmpty ?? true) }

    private var showResults: Bool {
        !vm.isActive && displayNote != nil && (!transcriptText.isEmpty || !summaryText.isEmpty || isProcessing)
    }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    headerSection
                    contextSelectorSection
                    recordingControlSection

                    if hasChunks {
                        chunkStatusSection
                    }

                    if showResults {
                        resultsSummarySection
                    }

                    if let err = vm.errorMessage, !err.isEmpty {
                        errorSection(err)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showingContextSelector) {
            contextSelectorSheet
        }
        .task {
            await vm.requestPermissions()
        }
    }

    // MARK: - View Components

    private var backgroundGradient: some View {
        RadialGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.02, green: 0.02, blue: 0.08)
            ],
            center: .topLeading,
            startRadius: 100,
            endRadius: 800
        )
        .ignoresSafeArea()
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Executive Recording")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Contextual AI Analysis")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var contextSelectorSection: some View {
        VStack(spacing: 16) {
            Text("Recording Context")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                showingContextSelector = true
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(selectedContextType.color.opacity(0.3))
                            .frame(width: 50, height: 50)

                        Image(systemName: selectedContextType.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(selectedContextType.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedContextType.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(selectedContextType.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedContextType.color.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var recordingControlSection: some View {
        VStack(spacing: 24) {
            // Main Recording Button
            Button(action: {
                toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(vm.isActive ?
                              LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                              LinearGradient(colors: [selectedContextType.color, selectedContextType.color.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 120, height: 120)
                        .shadow(color: (vm.isActive ? .red : selectedContextType.color).opacity(0.4), radius: 20)

                    Image(systemName: vm.isActive ? "stop.fill" : "mic.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                }
                .animation(.easeInOut(duration: 0.3), value: vm.isActive)
            }
            .disabled(vm.micDenied)

            // Recording Status
            VStack(spacing: 8) {
                Text(vm.isActive ? "Recording..." : "Ready to Record")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if vm.isActive {
                    VStack(spacing: 6) {
                        Text("Session: \(vm.formattedElapsed)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(selectedContextType.color)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: vm.isActive)

                            Text("Chunk \(vm.capture.engine.currentChunkIndex + 1)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                } else if vm.micDenied {
                    Text("Microphone permission required")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }

            // Process Button
            if let note = displayNote, !note.orderedChunks.isEmpty, !vm.isActive {
                Button("Process Recording (\(note.orderedChunks.count) chunks)") {
                    reanalyze(note)
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [selectedContextType.color, selectedContextType.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: selectedContextType.color.opacity(0.3), radius: 10)
                .disabled(isProcessing)
            }
        }
    }

    private var chunkStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recording Chunks")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            LazyVStack(spacing: 12) {
                ForEach(displayNote?.orderedChunks ?? [], id: \.id) { chunk in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(chunk.isValidSize ? chunk.status.color.opacity(0.3) : .red.opacity(0.3))
                                .frame(width: 40, height: 40)

                            Image(systemName: chunk.status.iconName)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(chunk.isValidSize ? chunk.status.color : .red)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Chunk \(chunk.index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Spacer()

                                Text(chunk.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            Text(chunk.status.displayName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        // Re-transcribe safety net: audio is retained, so a
                        // failed/timed-out chunk can always be retried.
                        if chunk.canRetry {
                            Button {
                                vm.capture.retranscribe(chunk)
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedContextType.color)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(16)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var resultsSummarySection: some View {
        VStack(spacing: 20) {
            Text("Processing Results")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: selectedContextType.color))
                        .scaleEffect(1.5)

                    Text("Processing with AI...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                if !transcriptText.isEmpty {
                    resultCard(
                        title: "Transcription",
                        content: transcriptText,
                        icon: "text.quote",
                        color: Color.blue
                    )
                }

                if !summaryText.isEmpty {
                    resultCard(
                        title: "AI Analysis",
                        content: summaryText,
                        icon: "brain",
                        color: selectedContextType.color
                    )
                }
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }

            Text(message)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(20)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var contextSelectorSheet: some View {
        NavigationView {
            List(ContextType.allCases) { contextType in
                contextOptionCard(contextType)
            }
            .navigationTitle("Select Recording Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingContextSelector = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helper Views

    private func resultCard(title: String, content: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()
            }

            ScrollView {
                Text(content)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 300)
        }
        .padding(20)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func contextOptionCard(_ contextType: ContextType) -> some View {
        Button(action: {
            selectedContextType = contextType
            showingContextSelector = false
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(contextType.color.opacity(0.3))
                        .frame(width: 60, height: 60)

                    Image(systemName: contextType.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(contextType.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(contextType.rawValue)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(contextType.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if contextType == selectedContextType {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(contextType.color)
                }
            }
            .padding(20)
            .background(contextType == selectedContextType ? contextType.color.opacity(0.1) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(contextType == selectedContextType ? contextType.color : Color(.systemGray5), lineWidth: contextType == selectedContextType ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Recording control

    private func toggleRecording() {
        if vm.isActive {
            // Finalize — audio is retained, transcription + enrichment run
            // automatically. Note: we do NOT delete audio or create a legacy
            // ExecutiveSession here (the SwiftData Note already exists and the
            // SessionManager projection surfaces it).
            finishedNote = vm.stop()
        } else {
            finishedNote = nil
            vm.noteType = selectedContextType.noteType
            vm.pendingTitle = defaultTitle()
            vm.start()
        }
    }

    /// Re-run AI enrichment on the finished note (audio is retained, so this is
    /// always possible). Enrichment also runs automatically once transcription
    /// completes; this button forces a fresh pass.
    private func reanalyze(_ note: Note) {
        guard !isReanalyzing else { return }
        isReanalyzing = true
        Task {
            _ = await NoteEnrichmentService.enrich(note, context: NoteStore.mainContext, force: true)
            isReanalyzing = false
        }
    }

    private func defaultTitle() -> String {
        // Content Analysis gets an AI-generated title during enrichment; others
        // get a context + timestamp placeholder until enrichment retitles them.
        if selectedContextType == .externalNoteTaker { return "" }
        return "\(selectedContextType.rawValue) - \(Date().formatted(date: .abbreviated, time: .shortened))"
    }
}

#Preview {
    ActiveRecordingView()
}
