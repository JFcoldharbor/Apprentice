//
//  SessionsListView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  SessionsListView.swift
//  Stitch Executive AI
//
//  Created by James Garmon on 8/21/25.
//


//
//  SessionsListView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Browse and manage executive sessions with memory connections
//  Sessions list with memory relationship indicators and filtering
//

import SwiftUI

struct SessionsListView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var searchText = ""
    @State private var selectedSession: ExecutiveSession?
    @State private var showingSessionDetail = false
    @State private var connections: [SessionConnection] = []
    @State private var patterns: [MemoryPattern] = []
    @State private var isAnalyzingMemory = false
    @State private var selectedConnectionFilter: ConnectionType?
    
    private let memoryCalculator = MemoryConnectionCalculator()
    
    var filteredSessions: [ExecutiveSession] {
        var filtered = sessionManager.sessions
        
        if !searchText.isEmpty {
            filtered = filtered.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.attendees.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                session.notes.contains { note in
                    note.title.localizedCaseInsensitiveContains(searchText) ||
                    note.content.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        if let connectionFilter = selectedConnectionFilter {
            let sessionIdsWithConnectionType = Set(connections
                .filter { $0.connectionType == connectionFilter }
                .flatMap { [$0.sourceSessionId, $0.targetSessionId] })
            
            filtered = filtered.filter { sessionIdsWithConnectionType.contains($0.id) }
        }
        
        return filtered
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.05, green: 0.08, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Search and Memory Filters
                searchAndFiltersSection
                
                // Sessions List
                if filteredSessions.isEmpty {
                    emptyStateView
                } else {
                    sessionsList
                }
            }
        }
        .onAppear {
            analyzeMemoryConnections()
        }
        .sheet(isPresented: $showingSessionDetail) {
            if let session = selectedSession {
                DetailedSessionView(session: session)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Executive Sessions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Quick stats with memory info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sessionManager.totalSessions)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Enhanced metrics with memory connections
            HStack(spacing: 20) {
                SimpleMetricCard(
                    title: "Today",
                    value: "\(sessionManager.sessions.filter { Calendar.current.isDateInToday($0.date) }.count)",
                    icon: "calendar.badge.clock"
                )
                
                SimpleMetricCard(
                    title: "This Week",
                    value: "\(sessionsThisWeek)",
                    icon: "calendar"
                )
                
                SimpleMetricCard(
                    title: "Connections",
                    value: "\(connections.count)",
                    icon: "link.circle"
                )
                
                SimpleMetricCard(
                    title: "Patterns",
                    value: "\(patterns.count)",
                    icon: "brain.head.profile"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Search and Filters Section
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Memory connection filters
            if !connections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All sessions filter
                        SimpleFilterChip(
                            title: "All Sessions",
                            icon: "list.bullet",
                            isSelected: selectedConnectionFilter == nil,
                            color: .blue
                        ) {
                            selectedConnectionFilter = nil
                        }
                        
                        // Connection type filters
                        ForEach(uniqueConnectionTypes, id: \.self) { connectionType in
                            let count = connections.filter { $0.connectionType == connectionType }.count
                            
                            SimpleFilterChip(
                                title: "\(connectionType.rawValue) (\(count))",
                                icon: connectionType.icon,
                                isSelected: selectedConnectionFilter == connectionType,
                                color: Color(connectionType.color)
                            ) {
                                selectedConnectionFilter = selectedConnectionFilter == connectionType ? nil : connectionType
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Sessions List
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSessions) { session in
                    SessionRowWithMemory(
                        session: session,
                        connections: connectionsForSession(session.id),
                        patterns: patternsForSession(session.id)
                    ) {
                        selectedSession = session
                        showingSessionDetail = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100) // Space for tab bar
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: searchText.isEmpty ? "mic.slash.circle" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text(searchText.isEmpty ? "No Sessions Yet" : "No Matching Sessions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(searchText.isEmpty ?
                 "Start recording your first executive session" :
                 "Try adjusting your search terms or filters")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            if searchText.isEmpty {
                Button("Start Recording") {
                    // Navigate to recording
                    print("Start recording tapped")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Computed Properties
    
    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        return sessionManager.sessions.filter { session in
            session.date >= startOfWeek
        }.count
    }
    
    private var uniqueConnectionTypes: [ConnectionType] {
        let types = Set(connections.map { $0.connectionType })
        return Array(types).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Helper Methods
    
    private func connectionsForSession(_ sessionId: UUID) -> [SessionConnection] {
        return connections.filter { connection in
            connection.sourceSessionId == sessionId || connection.targetSessionId == sessionId
        }
    }
    
    private func patternsForSession(_ sessionId: UUID) -> [MemoryPattern] {
        return patterns.filter { pattern in
            pattern.sessions.contains(sessionId)
        }
    }
    
    private func analyzeMemoryConnections() {
        guard !sessionManager.sessions.isEmpty else { return }
        
        isAnalyzingMemory = true
        
        Task {
            let newConnections = await Task.detached {
                return await memoryCalculator.analyzeConnections(sessions: sessionManager.sessions)
            }.value
            
            let newPatterns = await Task.detached {
                return await memoryCalculator.detectPatterns(sessions: sessionManager.sessions, connections: newConnections)
            }.value
            
            await MainActor.run {
                self.connections = newConnections
                self.patterns = newPatterns
                self.isAnalyzingMemory = false
                
                print("Memory analysis complete: \(newConnections.count) connections, \(newPatterns.count) patterns")
            }
        }
    }
}

// MARK: - Supporting Views

struct SimpleMetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SimpleFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : .white.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SessionRowWithMemory: View {
    let session: ExecutiveSession
    let connections: [SessionConnection]
    let patterns: [MemoryPattern]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Main session info
                HStack(spacing: 16) {
                    // Session type icon with memory indicator
                    ZStack {
                        Circle()
                            .fill(typeColor)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: session.type.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            )
                        
                        // Memory connection indicator
                        if !connections.isEmpty {
                            Circle()
                                .fill(.cyan)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Text("\(connections.count)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                                .offset(x: 15, y: -15)
                        }
                    }
                    
                    // Session details
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(session.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Priority indicator
                            Circle()
                                .fill(priorityColor)
                                .frame(width: 12, height: 12)
                        }
                        
                        HStack {
                            Text(session.date, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Ã¢â‚¬Â¢")
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(formatDuration(session.duration))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text(session.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        // Session content summary
                        HStack {
                            if !session.notes.isEmpty {
                                Text("\(session.notes.count) notes")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                if totalActionItems > 0 {
                                    Text("Ã¢â‚¬Â¢ \(totalActionItems) actions")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                // Memory connections preview
                if !connections.isEmpty {
                    memoryConnectionsPreview
                }
                
                // Pattern indicators
                if !patterns.isEmpty {
                    patternIndicators
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private var memoryConnectionsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link.circle")
                    .font(.caption)
                    .foregroundColor(.cyan)
                
                Text("Memory Connections (\(connections.count))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(connections.prefix(3), id: \.id) { connection in
                        ConnectionTypeChip(
                            connectionType: connection.connectionType,
                            strength: connection.strength
                        )
                    }
                    
                    if connections.count > 3 {
                        Text("+\(connections.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var patternIndicators: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text("Business Patterns (\(patterns.count))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(patterns.prefix(2), id: \.id) { pattern in
                        PatternChip(pattern: pattern)
                    }
                    
                    if patterns.count > 2 {
                        Text("+\(patterns.count - 2) more")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    
    private var typeColor: Color {
        switch session.type {
        case .teamMeeting: return .blue
        case .clientCall: return .green
        case .strategySession: return .purple
        case .oneOnOne: return .orange
        case .boardMeeting: return .red
        case .coaching: return .cyan
        }
    }
    
    private var priorityColor: Color {
        switch session.priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private var totalActionItems: Int {
        session.notes.reduce(0) { $0 + $1.actionItems.count }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct ConnectionTypeChip: View {
    let connectionType: ConnectionType
    let strength: ConnectionStrength
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: connectionType.icon)
                .font(.caption2)
                .foregroundColor(Color(connectionType.color))
            
            Text(connectionType.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(strength.color).opacity(0.3))
        .clipShape(Capsule())
    }
}

struct PatternChip: View {
    let pattern: MemoryPattern
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: pattern.patternType.icon)
                .font(.caption2)
                .foregroundColor(.purple)
            
            Text(pattern.patternType.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.purple.opacity(0.3))
        .clipShape(Capsule())
    }
}

#Preview {
    SessionsListView()
}