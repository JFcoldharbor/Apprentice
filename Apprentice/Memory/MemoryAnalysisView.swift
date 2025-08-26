//
//  MemoryAnalysisView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  MemoryAnalysisView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Enhanced memory analysis with conversation integration
//  UPDATED: Shows unified analysis of sessions AND orb conversations
//

import SwiftUI

struct MemoryAnalysisView: View {
    @ObservedObject var sessionManager: SessionManager
    let memoryConnections: [SessionConnection]
    let memoryPatterns: [MemoryPattern]
    let memoryInsights: [MemoryInsight]
    let isAnalyzing: Bool
    
    @StateObject private var conversationHistoryManager = ConversationHistoryManager()
    @State private var selectedFilter: ConnectionFilter = .all
    @State private var showingConversationStats = false
    @State private var showingConversationHistory = false
    
    enum ConnectionFilter: String, CaseIterable {
        case all = "All"
        case sessions = "Sessions Only"
        case conversations = "Conversations"
        case crossType = "Session-Conversation Links"
        
        var icon: String {
            switch self {
            case .all: return "brain.filled.head.profile"
            case .sessions: return "list.bullet.rectangle"
            case .conversations: return "message.circle"
            case .crossType: return "arrow.triangle.2.circlepath"
            }
        }
    }
    
    var filteredConnections: [SessionConnection] {
        switch selectedFilter {
        case .all:
            return memoryConnections
        case .sessions:
            return memoryConnections.filter { connection in
                isBusinessSession(connection.sourceSessionId) && isBusinessSession(connection.targetSessionId)
            }
        case .conversations:
            return memoryConnections.filter { connection in
                isConversationSession(connection.sourceSessionId) && isConversationSession(connection.targetSessionId)
            }
        case .crossType:
            return memoryConnections.filter { connection in
                (isBusinessSession(connection.sourceSessionId) && isConversationSession(connection.targetSessionId)) ||
                (isConversationSession(connection.sourceSessionId) && isBusinessSession(connection.targetSessionId))
            }
        }
    }
    
    var conversationInsights: [MemoryInsight] {
        return memoryInsights.filter { insight in
            insight.title.contains("Coaching") ||
            insight.title.contains("Conversation") ||
            insight.title.contains("Idea Evolution") ||
            insight.title.contains("Implementation")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if isAnalyzing {
                    loadingView
                } else if memoryConnections.isEmpty {
                    emptyStateView
                } else {
                    analysisResultsView
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showingConversationHistory) {
            ConversationHistoryView()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "brain.filled.head.profile")
                        .font(.title)
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unified Memory Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Sessions, conversations & connections")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: { showingConversationStats.toggle() }) {
                        Image(systemName: "chart.bar")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showingConversationHistory = true }) {
                        Image(systemName: "message.circle")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                // Enhanced statistics
                statsGrid
                
                // Filter selector
                filterSelector
            }
            .padding(20)
        }
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            StatView(
                value: "\(filteredConnections.count)",
                label: "Connections",
                icon: "link",
                color: .blue
            )
            
            StatView(
                value: "\(conversationInsights.count)",
                label: "AI Insights",
                icon: "brain.head.profile",
                color: .purple
            )
            
            StatView(
                value: "\(conversationHistoryManager.conversationHistory.count)",
                label: "Conversations",
                icon: "message.circle",
                color: .green
            )
        }
    }
    
    private var filterSelector: some View {
        HStack(spacing: 12) {
            ForEach(ConnectionFilter.allCases, id: \.self) { filter in
                Button(action: { selectedFilter = filter }) {
                    HStack(spacing: 8) {
                        Image(systemName: filter.icon)
                            .font(.caption)
                        Text(filter.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedFilter == filter ? .blue.opacity(0.3) : .white.opacity(0.1))
                    .foregroundColor(selectedFilter == filter ? .blue : .white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Analysis Results
    
    private var analysisResultsView: some View {
        VStack(spacing: 24) {
            // Conversation insights section (if any)
            if !conversationInsights.isEmpty {
                conversationInsightsSection
            }
            
            // Connection insights
            connectionsSection
            
            // Cross-type connections highlight
            if selectedFilter == .crossType && !filteredConnections.isEmpty {
                crossTypeConnectionsSection
            }
            
            // Original insights
            if !memoryInsights.isEmpty {
                insightsSection
            }
            
            // Patterns
            if !memoryPatterns.isEmpty {
                patternsSection
            }
        }
    }
    
    private var conversationInsightsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Coaching Insights")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(conversationInsights.count) insights from conversations")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(conversationInsights.prefix(3)) { insight in
                        ConversationInsightCard(insight: insight)
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var crossTypeConnectionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conversation â†’ Session Links")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("AI coaching leading to business action")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(filteredConnections.prefix(5)) { connection in
                        CrossTypeConnectionCard(
                            connection: connection,
                            sessionManager: sessionManager
                        )
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var connectionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "link")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Memory Connections")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(filteredConnections.count)")
                        .font(.title3.bold())
                        .foregroundColor(.blue)
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(filteredConnections.prefix(5)) { connection in
                        ConnectionCard(
                            connection: connection,
                            sessions: sessionManager.sessions
                        ) {
                            // Handle connection tap
                        }
                    }
                }
                
                if filteredConnections.count > 5 {
                    Button("View All \(filteredConnections.count) Connections") {
                        // TODO: Navigate to detailed connections view
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
            .padding(20)
        }
    }
    
    private var insightsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    
                    Text("Business Insights")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(memoryInsights.count)")
                        .font(.title3.bold())
                        .foregroundColor(.yellow)
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(memoryInsights.filter { insight in
                        !conversationInsights.contains { $0.id == insight.id }
                    }.prefix(3)) { insight in
                        InsightCard(insight: insight) {
                            // Handle insight tap
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var patternsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "waveform.path")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Behavior Patterns")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(memoryPatterns.count)")
                        .font(.title3.bold())
                        .foregroundColor(.green)
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(memoryPatterns.prefix(3)) { pattern in
                        PatternCard(pattern: pattern) {
                            // Handle pattern tap
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Loading and Empty States
    
    private var loadingView: some View {
        GlassCard {
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Analyzing Memory Patterns")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Connecting sessions and conversations...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(40)
        }
    }
    
    private var emptyStateView: some View {
        GlassCard {
            VStack(spacing: 20) {
                Image(systemName: "brain")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(spacing: 8) {
                    Text("No Memory Patterns Yet")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Start recording sessions or having AI conversations to build your executive memory.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.05, green: 0.08, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Helper Methods
    
    private func isBusinessSession(_ sessionId: UUID) -> Bool {
        return sessionManager.sessions.contains { $0.id == sessionId }
    }
    
    private func isConversationSession(_ sessionId: UUID) -> Bool {
        // Check if this session ID comes from converted conversations
        return !isBusinessSession(sessionId)
    }
}

struct ConversationInsightCard: View {
    let insight: MemoryInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                ConfidenceBadge(confidence: insight.confidence)
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(12)
        .background(.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CrossTypeConnectionCard: View {
    let connection: SessionConnection
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Image(systemName: "message.circle")
                    .foregroundColor(.green)
                Text("Chat")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(.orange)
            
            VStack(spacing: 4) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.blue)
                Text("Session")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.reasons.first?.description ?? "Connection detected")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    ConnectionStrengthBadge(strength: connection.strength)
                    Text("Score: \(String(format: "%.2f", connection.score))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatView: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.blue.opacity(0.3))
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}