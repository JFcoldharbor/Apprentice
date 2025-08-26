//
//  ConversationHistoryView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  ConversationHistoryView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Conversation history display and management
//  FIXED: Updated to use ConversationHistoryManager instead of SpeechConversationService
//

import SwiftUI

struct ConversationHistoryView: View {
    @StateObject private var conversationHistoryManager = ConversationHistoryManager()
    @State private var searchText = ""
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showingClearConfirmation = false
    @State private var showingExportView = false
    
    enum DateFilter: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        
        var predicate: (SimpleConversationTurn) -> Bool {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .all:
                return { _ in true }
            case .today:
                return { turn in
                    calendar.isDate(turn.timestamp, inSameDayAs: now)
                }
            case .thisWeek:
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                return { turn in
                    turn.timestamp >= weekStart
                }
            case .thisMonth:
                let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
                return { turn in
                    turn.timestamp >= monthStart
                }
            }
        }
    }
    
    var filteredConversations: [SimpleConversationTurn] {
        let conversations = conversationHistoryManager.conversationHistory
        let dateFiltered = conversations.filter(selectedDateFilter.predicate)
        
        if searchText.isEmpty {
            return dateFiltered
        } else {
            return dateFiltered.filter { turn in
                turn.userInput.localizedCaseInsensitiveContains(searchText) ||
                turn.aiResponse.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var conversationStats: ConversationStats? {
        conversationHistoryManager.isLoading ? nil :
        ConversationStats(
            totalTurns: conversationHistoryManager.conversationHistory.count,
            totalSessions: Set(conversationHistoryManager.conversationHistory.compactMap { $0.sessionId }).count,
            lastActivity: conversationHistoryManager.conversationHistory.last?.timestamp,
            averageTurnsPerSession: 0.0, // Calculated in ConversationHistoryManager
            firstConversation: conversationHistoryManager.conversationHistory.first?.timestamp,
            conversationsThisWeek: 0, // Calculated in ConversationHistoryManager
            conversationsToday: 0 // Calculated in ConversationHistoryManager
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    headerSection
                    searchAndFilterSection
                    conversationsList
                }
            }
            .navigationTitle("Conversation History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear History") {
                            showingClearConfirmation = true
                        }
                        Button("Export") {
                            showingExportView = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .confirmationDialog(
                "Clear All Conversation History?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear", role: .destructive) {
                    Task {
                        await conversationHistoryManager.clearAllHistory()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "message.circle")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Conversations")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let stats = conversationStats {
                            Text("\(stats.totalTurns) conversations across \(stats.totalSessions) sessions")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
                
                if let stats = conversationStats {
                    statsGrid(stats: stats)
                }
            }
            .padding(20)
        }
        .padding(.horizontal, 20)
    }
    
    private func statsGrid(stats: ConversationStats) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
            StatCard(
                title: "Total",
                value: "\(stats.totalTurns)",
                icon: "message",
                color: .blue
            )
            
            StatCard(
                title: "Sessions",
                value: "\(stats.totalSessions)",
                icon: "bubble.left.and.bubble.right",
                color: .green
            )
            
            StatCard(
                title: "Today",
                value: "\(stats.conversationsToday)",
                icon: "calendar",
                color: .orange
            )
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Date Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DateFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedDateFilter = filter }) {
                            Text(filter.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(selectedDateFilter == filter ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedDateFilter == filter ? .blue : .blue.opacity(0.2))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(.blue.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if conversationHistoryManager.isLoading {
                    loadingView
                } else if filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredConversations.indices, id: \.self) { index in
                        ConversationTurnCard(
                            turn: filteredConversations[index],
                            turnIndex: index
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Loading and Empty States
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            
            Text("Loading conversations...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Conversations Yet")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Start a conversation with your AI coach to see it here")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    // MARK: - Background Gradient
    
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
}

// MARK: - Supporting Views

struct ConversationTurnCard: View {
    let turn: SimpleConversationTurn
    let turnIndex: Int
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Turn \(turnIndex + 1)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(formatDate(turn.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // User Input
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.green)
                        Text("You")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Text(turn.userInput)
                        .font(.body)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                
                // AI Response
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("AI Coach")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    Text(turn.aiResponse)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MyFilterChip: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? .blue : .blue.opacity(0.2))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.blue.opacity(0.5), lineWidth: 1)
            )
    }
}