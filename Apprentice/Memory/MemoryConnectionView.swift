//
//  MemoryConnectionView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  MemoryConnectionView.swift
//  Stitch Executive AI
//
//  Created by James Garmon on 8/21/25.
//


//
//  MemoryConnectionView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Standalone memory connection visualization
//  Interactive session relationship analysis and pattern exploration
//

import SwiftUI

struct MemoryConnectionView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var connections: [SessionConnection] = []
    @State private var patterns: [MemoryPattern] = []
    @State private var insights: [MemoryInsight] = []
    @State private var clusters: [SessionCluster] = []
    @State private var isAnalyzing = false
    @State private var selectedConnection: SessionConnection?
    @State private var selectedPattern: MemoryPattern?
    @State private var selectedInsight: MemoryInsight?
    @State private var analysisComplete = false
    @State private var showingConnectionDetail = false
    @State private var searchText = ""
    @State private var selectedConnectionType: ConnectionType?
    @State private var selectedStrengthFilter: ConnectionStrength?
    
    private let memoryCalculator = MemoryConnectionCalculator()
    
    var filteredConnections: [SessionConnection] {
        var filtered = connections
        
        if !searchText.isEmpty {
            filtered = filtered.filter { connection in
                // Filter by session titles or connection reasons
                let sourceSession = sessionManager.sessions.first { $0.id == connection.sourceSessionId }
                let targetSession = sessionManager.sessions.first { $0.id == connection.targetSessionId }
                
                return sourceSession?.title.localizedCaseInsensitiveContains(searchText) == true ||
                       targetSession?.title.localizedCaseInsensitiveContains(searchText) == true ||
                       connection.reasons.contains { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        if let typeFilter = selectedConnectionType {
            filtered = filtered.filter { $0.connectionType == typeFilter }
        }
        
        if let strengthFilter = selectedStrengthFilter {
            filtered = filtered.filter { $0.strength == strengthFilter }
        }
        
        return filtered.sorted { $0.score > $1.score }
    }
    
    var body: some View {
        NavigationView {
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
                
                if isAnalyzing {
                    analysisLoadingView
                } else if connections.isEmpty && analysisComplete {
                    emptyMemoryView
                } else {
                    memoryAnalysisContent
                }
            }
            .navigationTitle("Memory Intelligence")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        analyzeMemoryConnections()
                    }
                    .foregroundColor(.cyan)
                    .disabled(isAnalyzing)
                }
            }
        }
        .onAppear {
            if !analysisComplete {
                analyzeMemoryConnections()
            }
        }
        .sheet(isPresented: $showingConnectionDetail) {
            if let connection = selectedConnection {
                ConnectionDetailView(
                    connection: connection,
                    sessions: sessionManager.sessions
                )
            }
        }
    }
    
    // MARK: - Analysis Loading View
    
    private var analysisLoadingView: some View {
        VStack(spacing: 24) {
            // Animated brain visualization
            ZStack {
                Circle()
                    .stroke(.cyan.opacity(0.3), lineWidth: 3)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(.cyan, lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(isAnalyzing ? 360 : 0))
                    .animation(.linear(duration: 2.0).repeatForever(autoreverses: false), value: isAnalyzing)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.cyan)
            }
            
            VStack(spacing: 12) {
                Text("Analyzing Memory Connections")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Processing \(sessionManager.sessions.count) sessions for relationships and patterns")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 20) {
                    AnalysisStep(title: "Connections", isActive: true)
                    AnalysisStep(title: "Patterns", isActive: true)
                    AnalysisStep(title: "Insights", isActive: true)
                    AnalysisStep(title: "Clusters", isActive: true)
                }
            }
        }
        .padding(40)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Empty Memory View
    
    private var emptyMemoryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Memory Connections Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Record more sessions to discover relationships and patterns between your executive conversations")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 8) {
                Text("To build memory connections, you need:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    RequirementRow(text: "Multiple sessions with different topics")
                    RequirementRow(text: "Sessions with overlapping attendees")
                    RequirementRow(text: "Related action items or decisions")
                    RequirementRow(text: "Similar business themes or categories")
                }
            }
        }
        .padding(40)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }
    
    // MARK: - Memory Analysis Content
    
    private var memoryAnalysisContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Analysis Overview
                memoryOverviewSection
                
                // Search and Filters
                searchAndFiltersSection
                
                // Quick Insights
                if !insights.isEmpty {
                    quickInsightsSection
                }
                
                // Connection Network Visualization
                connectionNetworkSection
                
                // Patterns Discovered
                if !patterns.isEmpty {
                    patternsSection
                }
                
                // Session Clusters
                if !clusters.isEmpty {
                    clustersSection
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Memory Overview Section
    
    private var memoryOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Analysis Overview")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MemoryStatCard(
                    title: "Total Connections",
                    value: "\(connections.count)",
                    subtitle: "Relationships found",
                    icon: "link.circle",
                    color: .cyan
                )
                
                MemoryStatCard(
                    title: "Strong Links",
                    value: "\(strongConnectionsCount)",
                    subtitle: "High confidence",
                    icon: "link.circle.fill",
                    color: .blue
                )
                
                MemoryStatCard(
                    title: "Patterns",
                    value: "\(patterns.count)",
                    subtitle: "Behavioral patterns",
                    icon: "brain.head.profile",
                    color: .purple
                )
                
                MemoryStatCard(
                    title: "Insights",
                    value: "\(insights.count)",
                    subtitle: "AI discoveries",
                    icon: "lightbulb.circle.fill",
                    color: .yellow
                )
                
                MemoryStatCard(
                    title: "Clusters",
                    value: "\(clusters.count)",
                    subtitle: "Session groups",
                    icon: "circle.hexagonpath",
                    color: .green
                )
                
                MemoryStatCard(
                    title: "Sessions",
                    value: "\(sessionManager.sessions.count)",
                    subtitle: "Total analyzed",
                    icon: "doc.text.fill",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Search and Filters Section
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search connections, sessions, or insights...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Filter controls
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Connection type filter
                    Menu {
                        Button("All Types") {
                            selectedConnectionType = nil
                        }
                        ForEach(ConnectionType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                selectedConnectionType = selectedConnectionType == type ? nil : type
                            }
                        }
                    } label: {
                        FilterChip(
                            title: selectedConnectionType?.rawValue ?? "All Types",
                            icon: selectedConnectionType?.icon ?? "line.3.horizontal.decrease.circle",
                            isSelected: selectedConnectionType != nil,
                            color: .cyan
                        )
                    }
                    
                    // Strength filter
                    Menu {
                        Button("All Strengths") {
                            selectedStrengthFilter = nil
                        }
                        ForEach(ConnectionStrength.allCases, id: \.self) { strength in
                            Button(strength.rawValue) {
                                selectedStrengthFilter = selectedStrengthFilter == strength ? nil : strength
                            }
                        }
                    } label: {
                        FilterChip(
                            title: selectedStrengthFilter?.rawValue ?? "All Strengths",
                            icon: "gauge",
                            isSelected: selectedStrengthFilter != nil,
                            color: .blue
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Quick Insights Section
    
    private var quickInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(insights.prefix(3)) { insight in
                        InsightCard(insight: insight) {
                            selectedInsight = insight
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // MARK: - Connection Network Section
    
    private var connectionNetworkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Connection Network")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(filteredConnections.count) connections")
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
            
            if filteredConnections.isEmpty {
                Text("No connections match your current filters")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredConnections.prefix(10)) { connection in
                        ConnectionCard(
                            connection: connection,
                            sessions: sessionManager.sessions
                        ) {
                            selectedConnection = connection
                            showingConnectionDetail = true
                        }
                    }
                    
                    if filteredConnections.count > 10 {
                        Button("View All \(filteredConnections.count) Connections") {
                            // Could expand or navigate to full list
                        }
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Patterns Section
    
    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discovered Patterns")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVStack(spacing: 12) {
                ForEach(patterns) { pattern in
                    PatternCard(pattern: pattern) {
                        selectedPattern = pattern
                    }
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Clusters Section
    
    private var clustersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Clusters")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVStack(spacing: 12) {
                ForEach(clusters) { cluster in
                    ClusterCard(
                        cluster: cluster,
                        sessions: sessionManager.sessions
                    )
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Properties
    
    private var strongConnectionsCount: Int {
        connections.filter { $0.strength == .strong || $0.strength == .critical }.count
    }
    
    // MARK: - Memory Analysis
    
    private func analyzeMemoryConnections() {
        guard !sessionManager.sessions.isEmpty else {
            analysisComplete = true
            return
        }
        
        isAnalyzing = true
        
        Task {
            // Run comprehensive memory analysis
            let newConnections = await Task.detached {
                return await memoryCalculator.analyzeConnections(sessions: sessionManager.sessions)
            }.value
            
            let newPatterns = await Task.detached {
                return await memoryCalculator.detectPatterns(sessions: sessionManager.sessions, connections: newConnections)
            }.value
            
            let newInsights = await Task.detached {
                return await memoryCalculator.generateInsights(sessions: sessionManager.sessions, connections: newConnections, patterns: newPatterns)
            }.value
            
            let newClusters = await Task.detached {
                return await memoryCalculator.createSessionClusters(sessions: sessionManager.sessions, connections: newConnections)
            }.value
            
            await MainActor.run {
                self.connections = newConnections
                self.patterns = newPatterns
                self.insights = newInsights
                self.clusters = newClusters
                self.isAnalyzing = false
                self.analysisComplete = true
                
                print("Memory analysis complete: \(newConnections.count) connections, \(newPatterns.count) patterns, \(newInsights.count) insights, \(newClusters.count) clusters")
            }
        }
    }
}

// MARK: - Supporting Views

struct RequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct AnalysisStep: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? .cyan : .white.opacity(0.3))
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(isActive ? .cyan : .white.opacity(0.6))
        }
    }
}

struct myRequirementRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct MemoryStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    
    var body: some View {
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
}

struct InsightCard: View {
    let insight: MemoryInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: insight.insightType.icon)
                        .foregroundColor(.yellow)
                    
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(Int(insight.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(width: 280, alignment: .leading)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConnectionCard: View {
    let connection: SessionConnection
    let sessions: [ExecutiveSession]
    let onTap: () -> Void
    
    private var sourceSession: ExecutiveSession? {
        sessions.first { $0.id == connection.sourceSessionId }
    }
    
    private var targetSession: ExecutiveSession? {
        sessions.first { $0.id == connection.targetSessionId }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Connection header
                HStack {
                    Image(systemName: connection.connectionType.icon)
                        .foregroundColor(Color(connection.connectionType.color))
                    
                    Text(connection.connectionType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    ConnectionStrengthBadge(strength: connection.strength)
                }
                
                // Connected sessions
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sourceSession?.title ?? "Unknown Session")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let sourceSession = sourceSession {
                            Text(sourceSession.date, style: .date)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(targetSession?.title ?? "Unknown Session")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if let targetSession = targetSession {
                            Text(targetSession.date, style: .date)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                // Connection reasons
                if !connection.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connection reasons:")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        
                        ForEach(connection.reasons.prefix(2), id: \.id) { reason in
                            Text("Ã¢â‚¬Â¢ \(reason.description)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConnectionStrengthBadge: View {
    let strength: ConnectionStrength
    
    var body: some View {
        Text(strength.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(strength.color))
            .clipShape(Capsule())
    }
}

struct PatternCard: View {
    let pattern: MemoryPattern
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: pattern.patternType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(pattern.patternType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    
                    HStack {
                        Text("\(pattern.sessions.count) sessions")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Ã¢â‚¬Â¢")
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Strength: \(Int(pattern.strength * 100))%")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ClusterCard: View {
    let cluster: SessionCluster
    let sessions: [ExecutiveSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.hexagonpath")
                    .foregroundColor(.green)
                
                Text(cluster.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(cluster.sessions.count) sessions")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if !cluster.dominantTopics.isEmpty {
                HStack {
                    Text("Topics:")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(cluster.dominantTopics.prefix(3).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            
            HStack {
                Text("Cohesion: \(Int(cluster.cohesion * 100))%")
                    .font(.caption2)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text(cluster.businessImpact.rawValue + " Impact")
                    .font(.caption2)
                    .foregroundColor(Color(cluster.businessImpact.color))
            }
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Connection Detail View

struct ConnectionDetailView: View {
    let connection: SessionConnection
    let sessions: [ExecutiveSession]
    @Environment(\.dismiss) private var dismiss
    
    private var sourceSession: ExecutiveSession? {
        sessions.first { $0.id == connection.sourceSessionId }
    }
    
    private var targetSession: ExecutiveSession? {
        sessions.first { $0.id == connection.targetSessionId }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection overview
                    connectionOverviewSection
                    
                    // Connected sessions
                    connectedSessionsSection
                    
                    // Connection reasons
                    connectionReasonsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.08),
                        Color(red: 0.05, green: 0.08, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Connection Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var connectionOverviewSection: some View {
        VStack(spacing: 16) {
            // Connection type and strength
            HStack {
                Image(systemName: connection.connectionType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(connection.connectionType.color))
                
                Text(connection.connectionType.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                ConnectionStrengthBadge(strength: connection.strength)
            }
            
            // Connection score
            VStack(spacing: 8) {
                Text("Connection Strength")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack {
                    ProgressView(value: connection.score)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(connection.strength.color)))
                    
                    Text("\(Int(connection.score * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            
            // Description
            Text(connection.connectionType.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var connectedSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Sessions")
                .font(.headline)
                .foregroundColor(.white)
            
            if let sourceSession = sourceSession {
                SessionDetailCard(session: sourceSession, label: "Source Session")
            }
            
            Image(systemName: "arrow.down")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
            
            if let targetSession = targetSession {
                SessionDetailCard(session: targetSession, label: "Target Session")
            }
        }
    }
    
    private var connectionReasonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Reasons")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(connection.reasons, id: \.id) { reason in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(reason.type.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(reason.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    
                    Text(reason.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                    
                    if !reason.evidence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Evidence:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            ForEach(reason.evidence.prefix(3), id: \.self) { evidence in
                                Text("Ã¢â‚¬Â¢ \(evidence)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(16)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct SessionDetailCard: View {
    let session: ExecutiveSession
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    Text(session.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Ã¢â‚¬Â¢")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(session.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                
                if !session.attendees.isEmpty {
                    Text("Attendees: \(session.attendees.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MemoryConnectionView()
}