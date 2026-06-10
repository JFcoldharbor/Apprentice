//
//  ActiveRecordingView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Clean recording interface with all build errors fixed
//  COMPLETE: All syntax issues resolved, proper structure maintained
//

import SwiftUI

struct ActiveRecordingView: View {
    
    // MARK: - State Properties
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var aiService = RealAIService()
    @StateObject private var sessionManager = SessionManager.shared
    
    @State private var selectedContextType: ContextType = .personalMeeting
    @State private var showingContextSelector = false
    @State private var isProcessing = false
    @State private var transcription = ""
    @State private var aiResponse = ""
    @State private var errorMessage = ""
    
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
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    headerSection
                    contextSelectorSection
                    recordingControlSection
                    
                    if !audioRecorder.recordingChunks.isEmpty {
                        chunkStatusSection
                    }
                    
                    if !transcription.isEmpty {
                        resultsSummarySection
                    }
                    
                    if !errorMessage.isEmpty {
                        errorSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showingContextSelector) {
            contextSelectorSheet
        }
        .onAppear {
            Task {
                try? await audioRecorder.requestPermission()
            }
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
                audioRecorder.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isRecording ?
                              LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .top, endPoint: .bottom) :
                              LinearGradient(colors: [selectedContextType.color, selectedContextType.color.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 120, height: 120)
                        .shadow(color: (audioRecorder.isRecording ? .red : selectedContextType.color).opacity(0.4), radius: 20)
                    
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.white)
                }
                .animation(.easeInOut(duration: 0.3), value: audioRecorder.isRecording)
            }
            .disabled(!audioRecorder.hasPermission)
            
            // Recording Status
            VStack(spacing: 8) {
                Text(audioRecorder.isRecording ? "Recording..." : "Ready to Record")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if audioRecorder.isRecording {
                    VStack(spacing: 6) {
                        Text("Session: \(audioRecorder.formattedSessionDuration)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(selectedContextType.color)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                            
                            Text("Chunk \(audioRecorder.currentChunk): \(audioRecorder.formattedChunkDuration)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                } else if !audioRecorder.hasPermission {
                    Text("Microphone permission required")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            // Process Button
            if !audioRecorder.recordingChunks.isEmpty && !audioRecorder.isRecording {
                Button("Process Recording (\(audioRecorder.recordingChunks.count) chunks)") {
                    processAllRecordingChunks()
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
                ForEach(audioRecorder.recordingChunks) { chunk in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(chunk.isValidSize ? chunk.transcriptionState.color.opacity(0.3) : .red.opacity(0.3))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: chunk.transcriptionState.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(chunk.isValidSize ? chunk.transcriptionState.color : .red)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Chunk \(chunk.number)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(chunk.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Text(chunk.statusDescription)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
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
                if !transcription.isEmpty {
                    resultCard(
                        title: "Transcription",
                        content: transcription,
                        icon: "text.quote",
                        color: Color.blue
                    )
                }
                
                if !aiResponse.isEmpty {
                    resultCard(
                        title: "AI Analysis",
                        content: aiResponse,
                        icon: "brain",
                        color: selectedContextType.color
                    )
                }
            }
        }
    }
    
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text(errorMessage)
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
    
    // MARK: - Processing Methods
    
    private func processAllRecordingChunks() {
        Task {
            await processAllChunksWithAI()
        }
    }
    
    @MainActor
    private func processAllChunksWithAI() async {
        guard !audioRecorder.recordingChunks.isEmpty else {
            errorMessage = "No recording chunks to process"
            return
        }
        
        isProcessing = true
        errorMessage = ""
        transcription = ""
        aiResponse = ""
        
        do {
            let combinedTranscription = await audioRecorder.getCombinedTranscription()
            transcription = combinedTranscription
            
            if combinedTranscription.isEmpty {
                throw RecordingProcessingError.emptyTranscription
            }
            
            let contextualPrompt = buildContextualPrompt(transcription: combinedTranscription)
            let response = try await aiService.generateCoachingResponse(prompt: contextualPrompt)
            aiResponse = response
            
            createContextualSession(
                transcription: combinedTranscription,
                aiResponse: response,
                totalDuration: audioRecorder.recordingChunks.reduce(0) { $0 + $1.duration }
            )
            
        } catch {
            errorMessage = "Processing failed: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    private func buildContextualPrompt(transcription: String) -> String {
        let contextInstructions = selectedContextType.aiProcessingContext
        
        return """
        \(contextInstructions)
        
        Transcription Content:
        \(transcription)
        
        Based on this context, provide analysis and insights.
        """
    }
    
    private func createContextualSession(transcription: String, aiResponse: String, totalDuration: TimeInterval) {
        let title = selectedContextType == .externalNoteTaker ?
            generateSmartTitle(from: transcription) :
            "\(selectedContextType.rawValue) - \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        let session = ExecutiveSession(
            title: title,
            date: Date(),
            duration: totalDuration,
            type: selectedContextType.meetingType,
            priority: .medium,
            notes: [],
            attendees: selectedContextType == .externalNoteTaker ? ["AI Analysis"] : ["Participant"],
            transcript: transcription,
            aiSummary: aiResponse
        )
        
        sessionManager.addSession(session)
        audioRecorder.deleteAllChunks()
    }
    
    private func generateSmartTitle(from transcription: String) -> String {
        let words = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
            .prefix(100)
            .joined(separator: " ")
        
        let sentences = words.components(separatedBy: ".")
        if let firstSentence = sentences.first, firstSentence.count > 10 {
            let titleWords = firstSentence.components(separatedBy: .whitespacesAndNewlines)
            return Array(titleWords.prefix(6)).joined(separator: " ").capitalized
        }
        
        return "Content Analysis - \(Date().formatted(date: .abbreviated, time: .shortened))"
    }
}

#Preview {
    ActiveRecordingView()
}
