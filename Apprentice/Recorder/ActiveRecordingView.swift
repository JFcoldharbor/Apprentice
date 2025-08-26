//
//  RecordingView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Enhanced contextual recording with meeting types
//  UPDATED: Stylish interface with contextual AI processing
//

import SwiftUI

struct RecordingView: View {
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var sessionManager = SessionManager.shared
    @State private var aiService: AIServiceProtocol = RealAIService()
    
    @State private var isProcessing = false
    @State private var transcription = ""
    @State private var aiResponse = ""
    @State private var errorMessage = ""
    @State private var selectedContextType: ContextType = .personalMeeting
    @State private var showingContextSelector = false
    
    enum ContextType: String, CaseIterable {
        case personalMeeting = "Personal Meeting"
        case teamMeeting = "Team Meeting"
        case oneOnOne = "1-on-1"
        case conference = "Conference"
        case externalNoteTaker = "Note Taker"
        
        var icon: String {
            switch self {
            case .personalMeeting: return "person.crop.circle.fill"
            case .teamMeeting: return "person.3.fill"
            case .oneOnOne: return "person.2.fill"
            case .conference: return "building.columns.fill"
            case .externalNoteTaker: return "doc.text.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .personalMeeting: return .blue
            case .teamMeeting: return .green
            case .oneOnOne: return .orange
            case .conference: return .purple
            case .externalNoteTaker: return .cyan
            }
        }
        
        var description: String {
            switch self {
            case .personalMeeting: return "Leading a personal or business meeting"
            case .teamMeeting: return "Leading or participating in team discussion"
            case .oneOnOne: return "Mutual conversation between two people"
            case .conference: return "Attending conference, webinar, or event"
            case .externalNoteTaker: return "Recording videos, audiobooks, or lectures"
            }
        }
        
        var aiProcessingContext: String {
            switch self {
            case .personalMeeting: return "User is leading a personal/business meeting. Expect leadership decisions, strategic thinking, and assigned action items."
            case .teamMeeting: return "User is in a team meeting. Look for collaborative decisions, team dynamics, and shared responsibilities."
            case .oneOnOne: return "User is in mutual conversation. Analyze conversational dynamics, relationship building, and shared decision-making."
            case .conference: return "User is an attendee. Focus on capturing external insights, speaker takeaways, and industry trends."
            case .externalNoteTaker: return "User is consuming content. Extract key insights, summarize information, and identify learning opportunities. Auto-generate descriptive title."
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Enhanced Background
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
            
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    contextSelectorSection
                    recordingControlSection
                    
                    if !audioRecorder.recordingChunks.isEmpty {
                        recordingStatusSection
                    }
                    
                    if isProcessing {
                        processingSection
                    }
                    
                    if !transcription.isEmpty || !aiResponse.isEmpty {
                        resultsSection
                    }
                    
                    if !errorMessage.isEmpty {
                        errorSection
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showingContextSelector) {
            contextSelectorSheet
        }
    }
    
    // MARK: - Header Section
    
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
    
    // MARK: - Context Selector Section
    
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
    
    // MARK: - Recording Control Section
    
    private var recordingControlSection: some View {
        VStack(spacing: 24) {
            // Main Recording Button
            Button(action: {
                audioRecorder.toggleRecording()
            }) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isRecording ? .red : selectedContextType.color)
                        .frame(width: 140, height: 140)
                        .scaleEffect(audioRecorder.isRecording ? 1.05 : 1.0)
                        .shadow(color: audioRecorder.isRecording ? .red.opacity(0.5) : selectedContextType.color.opacity(0.5), radius: 20)
                    
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 140, height: 140)
                    
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
    
    // MARK: - Recording Status Section
    
    private var recordingStatusSection: some View {
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
                                .fill(chunk.isValidSize ? .green.opacity(0.3) : .orange.opacity(0.3))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "waveform")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(chunk.isValidSize ? .green : .orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chunk \(chunk.number)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text(chunk.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("•")
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text(chunk.formattedFileSize)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: FileManager.default.fileExists(atPath: chunk.url.path) ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(FileManager.default.fileExists(atPath: chunk.url.path) ? .green : .red)
                            
                            Text(FileManager.default.fileExists(atPath: chunk.url.path) ? "Ready" : "Missing")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Processing Section
    
    private var processingSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(selectedContextType.color.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: selectedContextType.color))
                    .scaleEffect(1.5)
            }
            
            VStack(spacing: 8) {
                Text(audioRecorder.isProcessingChunks ? "Processing Audio Chunks" : "Generating AI Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(audioRecorder.isProcessingChunks ?
                     "Transcribing \(audioRecorder.recordingChunks.count) chunks" :
                     "Analyzing with \(selectedContextType.rawValue) context")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(32)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 20) {
            if !transcription.isEmpty {
                ResultCard(
                    title: "Transcription",
                    content: transcription,
                    icon: "text.quote",
                    color: .blue
                )
            }
            
            if !aiResponse.isEmpty {
                ResultCard(
                    title: "AI Analysis",
                    content: aiResponse,
                    icon: "brain.head.profile",
                    color: selectedContextType.color
                )
            }
        }
    }
    
    // MARK: - Error Section
    
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
        .background(.red.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.red.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Context Selector Sheet
    
    private var contextSelectorSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Recording Context")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose how AI should analyze this recording")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Context Options
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(ContextType.allCases, id: \.self) { contextType in
                            ContextOptionCard(
                                contextType: contextType,
                                isSelected: contextType == selectedContextType
                            ) {
                                selectedContextType = contextType
                                showingContextSelector = false
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
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
            // Get combined transcription
            let combinedTranscription = await audioRecorder.getCombinedTranscription()
            transcription = combinedTranscription
            
            if combinedTranscription.isEmpty {
                throw ProcessingError.emptyTranscription
            }
            
            // Generate contextual AI response
            let contextualPrompt = buildContextualPrompt(transcription: combinedTranscription)
            let response = try await aiService.generateCoachingResponse(prompt: contextualPrompt)
            aiResponse = response
            
            // Create session with contextual data
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
        
        Based on this context, provide appropriate analysis:
        - For leadership contexts: Focus on decisions made, strategic insights, action items
        - For collaborative contexts: Analyze team dynamics, shared outcomes, relationship aspects
        - For consumption contexts: Extract key learnings, actionable insights, generate descriptive title
        - For conference contexts: Capture speaker insights, industry trends, external perspectives
        """
    }
    
    private func createContextualSession(transcription: String, aiResponse: String, totalDuration: TimeInterval) {
        let insights = extractInsights(from: aiResponse)
        let actionItems = extractActionItems(from: aiResponse)
        
        let note = StructuredNote(
            id: UUID(),
            title: "Recording Analysis - \(selectedContextType.rawValue)",
            content: transcription,
            category: .coaching,
            insights: insights,
            actionItems: actionItems.map { actionText in
                ActionItem(
                    id: UUID(),
                    title: String(actionText.prefix(50)),
                    description: actionText,
                    assignee: nil,
                    dueDate: nil,
                    priority: .medium,
                    status: .pending,
                    createdAt: Date()
                )
            },
            decisions: [],
            createdAt: Date()
        )
        
        let sessionTitle = selectedContextType == .externalNoteTaker ?
            generateSmartTitle(from: transcription) :
            "\(selectedContextType.rawValue) Session"
        
        let session = ExecutiveSession(
            id: UUID(),
            title: sessionTitle,
            date: Date(),
            duration: totalDuration,
            type: contextTypeToMeetingType(selectedContextType),
            priority: .medium,
            notes: [note],
            attendees: selectedContextType == .oneOnOne ? ["Participant"] : ["AI Analysis"]
        )
        
        sessionManager.addSession(session)
        audioRecorder.deleteAllChunks()
    }
    
    // MARK: - Helper Methods
    
    private func generateSmartTitle(from transcription: String) -> String {
        let words = transcription.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
            .prefix(100)
            .joined(separator: " ")
        
        // Simple title extraction from first meaningful content
        let sentences = words.components(separatedBy: ".")
        if let firstSentence = sentences.first, firstSentence.count > 10 {
            let titleWords = firstSentence.components(separatedBy: .whitespacesAndNewlines)
            return Array(titleWords.prefix(6)).joined(separator: " ").capitalized
        }
        
        return "Content Analysis - \(Date().formatted(date: .abbreviated, time: .shortened))"
    }
    
    private func contextTypeToMeetingType(_ contextType: ContextType) -> ExecutiveSession.MeetingType {
        switch contextType {
        case .personalMeeting: return .oneOnOne
        case .teamMeeting: return .teamMeeting
        case .oneOnOne: return .oneOnOne
        case .conference: return .clientCall
        case .externalNoteTaker: return .coaching
        }
    }
    
    private func extractInsights(from aiResponse: String) -> [String] {
        let lines = aiResponse.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") ||
               trimmed.contains("insight") || trimmed.contains("key point") {
                return trimmed
            }
            return nil
        }.prefix(5).map { String($0) }
    }
    
    private func extractActionItems(from aiResponse: String) -> [String] {
        let lines = aiResponse.components(separatedBy: .newlines)
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("should") || trimmed.contains("recommend") ||
               trimmed.contains("suggest") || trimmed.contains("action") {
                return trimmed
            }
            return nil
        }.prefix(3).map { String($0) }
    }
}

// MARK: - Supporting Views

struct ContextOptionCard: View {
    let contextType: RecordingView.ContextType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(contextType.color)
                }
            }
            .padding(20)
            .background(isSelected ? contextType.color.opacity(0.1) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? contextType.color : Color(.systemGray5), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ResultCard: View {
    let title: String
    let content: String
    let icon: String
    let color: Color
    
    var body: some View {
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
}

enum ProcessingError: Error, LocalizedError {
    case emptyTranscription
    
    var errorDescription: String? {
        switch self {
        case .emptyTranscription:
            return "No transcription content was generated"
        }
    }
}

#Preview {
    RecordingView()
}
