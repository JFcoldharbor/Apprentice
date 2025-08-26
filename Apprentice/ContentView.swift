//
//  ContentView.swift
//  Stitch Executive AI
//
//  Updated for full screen immersion with transparent background
//

import SwiftUI

struct ContentView: View {
    
    // MARK: - State Management
    
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var profileManager = FounderProfileManager.shared
    @StateObject private var audioRecorder = AudioRecorder()
    
    @State private var selectedTab = 0
    @State private var showingProfileSetup = false
    @State private var showingMicPermissionAlert = false
    
    // MARK: - Memory Analysis State
    
    @State private var memoryConnections: [SessionConnection] = []
    @State private var memoryPatterns: [MemoryPattern] = []
    @State private var memoryInsights: [MemoryInsight] = []
    @State private var isAnalyzingMemory = false
    
    private let memoryCalculator = MemoryConnectionCalculator()
    
    var body: some View {
        ZStack {
            // Transparent background for immersion
            Color.clear
                .ignoresSafeArea(.all)
            
            if showingProfileSetup {
                OnboardingFlow(profileManager: profileManager) {
                    checkOnboardingStatus()
                }
            } else {
                mainContent
            }
        }
        .onAppear {
            checkOnboardingStatus()
            requestMicrophonePermission()
            startMemoryAnalysis()
        }
        .alert("Microphone Permission Required", isPresented: $showingMicPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable microphone access in Settings to use voice features.")
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Tab content
                TabView(selection: $selectedTab) {
                    PremiumHomeView(
                        sessionManager: sessionManager,
                        profileManager: profileManager,
                        audioRecorder: audioRecorder,
                        requestMicrophonePermission: {
                            requestMicrophonePermission()
                        },
                        selectedTab: $selectedTab
                    )
                    .tag(0)
                    
                    SessionsListView()
                        .tag(1)
                    
                    RecordingView()
                        .tag(2)
                    
                    BusinessIntelligenceDashboard()
                        .tag(3)
                    
                    MemoryAnalysisView(
                        sessionManager: sessionManager,
                        memoryConnections: memoryConnections,
                        memoryPatterns: memoryPatterns,
                        memoryInsights: memoryInsights,
                        isAnalyzing: isAnalyzingMemory
                    )
                    .tag(4)
                    
                    DocumentUploadView()
                        .environmentObject(sessionManager)
                        .tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Modern glassmorphism tab bar
                VStack {
                    Spacer()
                    
                    ModernTabBar(
                        selectedTab: $selectedTab,
                        memoryInsights: memoryInsights,
                        geometry: geometry
                    )
                }
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func checkOnboardingStatus() {
        showingProfileSetup = profileManager.founderProfile == nil || !profileManager.isOnboardingComplete
    }
    
    private func requestMicrophonePermission() {
        Task {
            do {
                try await audioRecorder.requestPermission()
                await MainActor.run {
                    if !audioRecorder.hasPermission {
                        showingMicPermissionAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    showingMicPermissionAlert = true
                }
            }
        }
    }
    
    private func startMemoryAnalysis() {
        guard !sessionManager.sessions.isEmpty else { return }
        
        isAnalyzingMemory = true
        
        Task {
            let connections = await memoryCalculator.analyzeConnections(sessions: sessionManager.sessions)
            let patterns = await memoryCalculator.detectPatterns(
                sessions: sessionManager.sessions,
                connections: connections
            )
            let insights = await memoryCalculator.generateInsights(
                sessions: sessionManager.sessions,
                connections: connections,
                patterns: patterns
            )
            
            await MainActor.run {
                self.memoryConnections = connections
                self.memoryPatterns = patterns
                self.memoryInsights = insights
                self.isAnalyzingMemory = false
            }
        }
    }
}

// MARK: - Modern Tab Bar with Glassmorphism

struct ModernTabBar: View {
    @Binding var selectedTab: Int
    let memoryInsights: [MemoryInsight]
    let geometry: GeometryProxy
    
    private let tabs = [
        (title: "Home", icon: "house.fill"),
        (title: "Sessions", icon: "list.bullet.rectangle"),
        (title: "Record", icon: "mic.circle.fill"),
        (title: "Intelligence", icon: "brain.head.profile"),
        (title: "Memory", icon: "brain.filled.head.profile"),
        (title: "Documents", icon: "folder.fill")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            // Glow effect behind selected tab
                            if selectedTab == index {
                                Circle()
                                    .fill(tabColor(for: index))
                                    .frame(width: 40, height: 40)
                                    .blur(radius: 8)
                                    .opacity(0.6)
                            }
                            
                            // Icon background
                            Circle()
                                .fill(selectedTab == index ? tabColor(for: index).opacity(0.2) : Color.clear)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(selectedTab == index ? tabColor(for: index) : .black.opacity(0.6))
                            
                            // Memory badge
                            if index == 4 && !memoryInsights.isEmpty {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 12, y: -12)
                            }
                        }
                        
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedTab == index ? tabColor(for: index) : .black.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, geometry.safeAreaInsets.bottom - (geometry.size.height * 0.05))
    }
    
    private func tabColor(for index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1: return .green
        case 2: return .red
        case 3: return .purple
        case 4: return .yellow
        case 5: return .orange
        default: return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
