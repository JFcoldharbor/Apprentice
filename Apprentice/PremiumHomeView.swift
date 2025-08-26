//
//  PremiumHomeView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Clean home interface with customizable AI name
//  Error-free implementation with proper structure
//

import SwiftUI
import AVFoundation

struct PremiumHomeView: View {
    
    // MARK: - Parameters
    
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var profileManager: FounderProfileManager
    @ObservedObject var audioRecorder: AudioRecorder
    let requestMicrophonePermission: () -> Void
    @Binding var selectedTab: Int
    
    // MARK: - Core Services
    
    @StateObject private var speechService = SpeechConversationService()
    @StateObject private var speechRecognition = SpeechRecognitionService()
    @StateObject private var conversationEngine: ConversationEngine
    @StateObject private var safeDocumentManager = SafeDocumentManager()
    @StateObject private var realAIService = RealAIService()
    @StateObject private var calendarIntegration = CalendarIntegration.shared
    @StateObject private var emailService = EmailService()
    
    // MARK: - Floating Notifications
    @StateObject private var notificationManager = FloatingNotificationManager()
    
    // MARK: - AI Bot Configuration
    
    @State private var aiName = "ARIA"
    @State private var aiDisplayName = "Executive AI Assistant"
    @State private var showingNameChange = false
    
    // MARK: - UI State
    
    @State private var showingProfile = false
    @State private var showingCalendarEmail = false
    @State private var showingEmailComposer = false
    @State private var orbAnimation = false
    @State private var isConnectedToAI = false
    @State private var isProcessingResponse = false
    @State private var currentAIMessage = "Ready for executive coaching"
    @State private var particleAnimation = false
    
    // MARK: - News Feed
    
    @State private var newsItems = [
        "BREAKING: Market opens strong",
        "EXECUTIVE: Meeting in 30 minutes",
        "INSIGHTS: AI analysis complete",
        "UPDATE: Calendar synchronized",
        "ALERT: New document processed",
        "STATUS: Speech recognition active"
    ]
    @State private var currentNewsIndex = 0
    @State private var newsTimer: Timer?
    
    // MARK: - Initialization
    
    init(
        sessionManager: SessionManager,
        profileManager: FounderProfileManager,
        audioRecorder: AudioRecorder,
        requestMicrophonePermission: @escaping () -> Void,
        selectedTab: Binding<Int>
    ) {
        self.sessionManager = sessionManager
        self.profileManager = profileManager
        self.audioRecorder = audioRecorder
        self.requestMicrophonePermission = requestMicrophonePermission
        self._selectedTab = selectedTab
        
        let sharedRealAI = RealAIService()
        let sharedDocManager = SafeDocumentManager()
        sharedDocManager.setRealAIService(sharedRealAI)
        
        self._conversationEngine = StateObject(wrappedValue: ConversationEngine(
            realAIService: sharedRealAI,
            documentManager: sharedDocManager,
            profileManager: profileManager,
            sessionManager: sessionManager,
            memoryCalculator: MemoryConnectionCalculator()
        ))
        
        self._realAIService = StateObject(wrappedValue: sharedRealAI)
        self._safeDocumentManager = StateObject(wrappedValue: sharedDocManager)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pure white background - edge to edge
                Color.white
                    .ignoresSafeArea(.all)
                
                // Floating notifications overlay
                FloatingNotificationOverlay(
                    notificationManager: notificationManager,
                    sessionManager: sessionManager,
                    profileManager: profileManager,
                    memoryInsights: []
                )
                
                VStack(spacing: 0) {
                    // Header section with profile and utility buttons
                    headerWithButtonsSection
                        .padding(.top, geometry.safeAreaInsets.top + 10)
                    
                    // Central AI orb with particles - moved down significantly
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 180)
                        
                        centralAIOrbSection
                        
                        Spacer()
                    }
                    
                    // Bottom spacer that goes to very bottom
                    Spacer(minLength: geometry.safeAreaInsets.bottom + 100)
                }
            }
        }
        .onAppear {
            setupServices()
            startAnimations()
            startFloatingNotifications()
        }
        .onDisappear {
            newsTimer?.invalidate()
            notificationManager.stopNotificationFlow()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(
                profileManager: profileManager,
                sessionManager: sessionManager
            )
        }
        .sheet(isPresented: $showingCalendarEmail) {
            CalendarEmailIntegrationView()
        }
        .sheet(isPresented: $showingEmailComposer) {
            if let lastSession = sessionManager.sessions.last {
                EmailComposeView(session: lastSession)
            } else {
                Text("No sessions available to email")
                    .padding()
            }
        }
        .sheet(isPresented: $showingNameChange) {
            AINameChangeView(aiName: $aiName, aiDisplayName: $aiDisplayName)
        }
    }
    
    // MARK: - Header Section with Profile and Utility Buttons
    
    private var headerWithButtonsSection: some View {
        HStack(spacing: 0) {
            // Left side - Info box and profile button
            HStack(spacing: 16) {
                // Profile button
                Button(action: { showingProfile = true }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        if let founderName = profileManager.founderProfile?.founderName {
                            Text(String(founderName.prefix(1)))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
                
                // Dynamic altering info box
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALTERING INFO BOX")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.black)
                        .tracking(0.5)
                    
                    Text(getCurrentInformation())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .animation(.easeInOut(duration: 0.5), value: currentNewsIndex)
                    
                    // Date and time
                    HStack(spacing: 8) {
                        Text(getCurrentDate())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text(getCurrentTime())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            // Right side - Utility buttons
            HStack(spacing: 12) {
                // Calendar button
                Button(action: { handleCalendarAction() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                
                // Email button
                Button(action: { handleEmailAction() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "envelope")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
                
                // Settings/More button
                Button(action: { handleSettingsAction() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Central AI Orb
    
    private var centralAIOrbSection: some View {
        VStack(spacing: 30) {
            Button(action: { handleAIConnection() }) {
                ZStack {
                    // Particle system - dots around orb
                    ForEach(0..<24, id: \.self) { index in
                        Circle()
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: 2, height: 2)
                            .offset(
                                x: cos(Double(index) * .pi / 12) * 90,
                                y: sin(Double(index) * .pi / 12) * 90
                            )
                            .scaleEffect(particleAnimation ? 1.3 : 0.7)
                            .opacity(particleAnimation ? 0.8 : 0.3)
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever()
                                .delay(Double(index) * 0.05),
                                value: particleAnimation
                            )
                    }
                    
                    // Main AI orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.1, green: 0.7, blue: 1.0),  // Bright cyan
                                    Color(red: 0.0, green: 0.4, blue: 0.8),  // Deep blue
                                    Color(red: 0.1, green: 0.6, blue: 0.9)   // Mid cyan
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(orbAnimation ? 1.05 : 0.98)
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: orbAnimation)
                    
                    // AI name text - customizable
                    Text(aiName)
                        .font(.system(size: 72, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Service Integration
    
    private func setupServices() {
        safeDocumentManager.setRealAIService(realAIService)
        speechService.setSafeDocumentManager(safeDocumentManager)
        speechRecognition.setSpeechService(speechService)
        
        // Initialize enhanced floating notifications with calendar & email
        notificationManager.initialize(
            sessionManager: sessionManager,
            profileManager: profileManager,
            memoryInsights: [],
            calendarIntegration: calendarIntegration,
            emailService: emailService
        )
        
        // Setup notification listeners
        setupNotificationListeners()
    }
    
    private func setupNotificationListeners() {
        // Listen for email compose requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ComposeSessionEmail"),
            object: nil,
            queue: .main
        ) { notification in
            if let session = notification.object as? ExecutiveSession {
                // Set the session and show email composer
                // Note: You'd need to add selectedSession state variable
                self.showingEmailComposer = true
            }
        }
        
        // Listen for email settings requests
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowEmailSettings"),
            object: nil,
            queue: .main
        ) { _ in
            self.showingCalendarEmail = true
        }
    }
    
    private func startAnimations() {
        // Start orb animation
        withAnimation {
            orbAnimation = true
            particleAnimation = true
        }
        
        // Start news cycling
        newsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentNewsIndex = (currentNewsIndex + 1) % newsItems.count
            }
        }
    }
    
    private func startFloatingNotifications() {
        // Delay before starting notifications
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            notificationManager.startNotificationFlow()
        }
    }
    
    private func handleAIConnection() {
        Task {
            await connectToAI()
            
            // Trigger notification when AI connects
            if isConnectedToAI {
                notificationManager.refreshNotifications()
            }
        }
    }
    
    private func connectToAI() async {
        guard !isConnectedToAI else {
            if speechRecognition.isListening {
                speechRecognition.stop()
            } else {
                await startListening()
            }
            return
        }
        
        let permissionsGranted = await speechRecognition.requestPermissions()
        guard permissionsGranted else {
            requestMicrophonePermission()
            return
        }
        
        isConnectedToAI = true
        currentAIMessage = "\(aiName) coaching session activated. How can I help you today?"
        
        let welcomeMessage = await conversationEngine.generateProactiveWelcome()
        
        do {
            try await speechService.speak(text: welcomeMessage)
            await startListening()
        } catch {
            print("Failed to speak welcome message: \(error)")
        }
    }
    
    private func startListening() async {
        do {
            try await speechRecognition.startContinuous()
        } catch {
            print("Failed to start continuous listening: \(error)")
        }
    }
    
    private func getCurrentInformation() -> String {
        return newsItems[currentNewsIndex % newsItems.count]
    }
    
    private func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    // MARK: - Button Action Handlers
    
    private func handleCalendarAction() {
        print("Calendar button tapped")
        showingCalendarEmail = true
        notificationManager.refreshNotifications()
    }
    
    private func handleEmailAction() {
        print("Email button tapped")
        showingEmailComposer = true
        notificationManager.refreshNotifications()
    }
    
    private func handleSettingsAction() {
        print("Settings button tapped")
        showingNameChange = true
    }
}

// MARK: - AI Name Change View

struct AINameChangeView: View {
    @Binding var aiName: String
    @Binding var aiDisplayName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var newName = ""
    @State private var newDisplayName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Customize Your AI Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assistant Name (appears in orb)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter AI name", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Display Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter full name", text: $newDisplayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        aiName = newName.isEmpty ? "ARIA" : newName.uppercased()
                        aiDisplayName = newDisplayName.isEmpty ? "Executive AI Assistant" : newDisplayName
                        dismiss()
                    }
                    .disabled(newName.isEmpty && newDisplayName.isEmpty)
                }
            }
        }
        .onAppear {
            newName = aiName
            newDisplayName = aiDisplayName
        }
    }
}

// MARK: - Preview

#Preview {
    PremiumHomeView(
        sessionManager: SessionManager.shared,
        profileManager: FounderProfileManager.shared,
        audioRecorder: AudioRecorder(),
        requestMicrophonePermission: {},
        selectedTab: .constant(0)
    )
}
