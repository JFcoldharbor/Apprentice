//
//  PremiumHomeView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Clean home interface with memory-enabled AI
//  FIXED: ConversationEngine initialization with memory integration
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
    
    // MARK: - FIXED: Initialization
    
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
        
        // FIXED: Remove the memoryCalculator parameter - it's created internally now
        self._conversationEngine = StateObject(wrappedValue: ConversationEngine(
            realAIService: sharedRealAI,
            documentManager: sharedDocManager,
            profileManager: profileManager,
            sessionManager: sessionManager
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
                
                // Settings button (AI name change)
                Button(action: { showingNameChange = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "gear")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Central AI Orb with Particles
    
    private var centralAIOrbSection: some View {
        ZStack {
            // Particle system - enhanced
            ForEach(0..<20, id: \.self) { index in
                let angle = Double(index) * 18
                let distance: CGFloat = 180 + CGFloat(index % 3) * 30
                
                Circle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14))
                    .offset(
                        x: cos(angle * .pi / 180) * distance * (particleAnimation ? 1.3 : 0.7),
                        y: sin(angle * .pi / 180) * distance * (particleAnimation ? 1.3 : 0.7)
                    )
                    .opacity(particleAnimation ? 0.8 : 0.3)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever()
                        .delay(Double(index) * 0.05),
                        value: particleAnimation
                    )
            }
            
            // Main AI interaction button
            Button(action: handleAIOrbTap) {
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(Color.cyan.opacity(0.2), lineWidth: 2)
                            .frame(width: 180 + CGFloat(ring) * 40, height: 180 + CGFloat(ring) * 40)
                            .scaleEffect(orbAnimation ? 1.1 + (Double(ring) * 0.05) : 0.95 + (Double(ring) * 0.05))
                            .opacity(orbAnimation ? 0.6 - (Double(ring) * 0.2) : 0.3 - (Double(ring) * 0.1))
                            .animation(
                                .easeInOut(duration: 1.8 + (Double(ring) * 0.2))
                                .repeatForever(autoreverses: true)
                                .delay(Double(ring) * 0.1),
                                value: orbAnimation
                            )
                    }
                    
                    // Particle trails connecting to orb
                    ForEach(0..<8, id: \.self) { index in
                        let angle = Double(index) * 45
                        
                        Circle()
                            .fill(Color.cyan.opacity(0.4))
                            .frame(width: 4, height: 4)
                            .offset(
                                x: cos(angle * .pi / 180) * 120 * (particleAnimation ? 1.3 : 0.7),
                                y: sin(angle * .pi / 180) * 120 * (particleAnimation ? 1.3 : 0.7)
                            )
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
                self.showingEmailComposer = true
            }
        }
    }
    
    // MARK: - AI Interaction
    
    private func handleAIOrbTap() {
        print("🎙️ [HOME] AI orb tapped - starting speech interaction")
        
        // Check for microphone permission first
        requestMicrophonePermission()
        
        // Start active listening mode
        Task {
            await speechService.startActiveListening()
        }
        
        // Update UI state
        isConnectedToAI = true
        currentAIMessage = "Listening..."
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Button Actions
    
    private func handleCalendarAction() {
        print("📅 [HOME] Calendar button tapped")
        showingCalendarEmail = true
    }
    
    private func handleEmailAction() {
        print("📧 [HOME] Email button tapped")
        showingEmailComposer = true
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        orbAnimation = true
        particleAnimation = true
        
        // Start news rotation timer
        startNewsRotation()
    }
    
    private func startNewsRotation() {
        newsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentNewsIndex = (currentNewsIndex + 1) % newsItems.count
            }
        }
    }
    
    private func startFloatingNotifications() {
        Task {
            await notificationManager.startNotificationFlow()
        }
    }
    
    // MARK: - Information Display
    
    private func getCurrentInformation() -> String {
        let currentItem = newsItems[currentNewsIndex]
        
        // Enhance with dynamic content based on actual app state
        switch currentNewsIndex {
        case 0:
            return "Market: \(getMarketStatus())"
        case 1:
            return "Next: \(getNextMeeting())"
        case 2:
            return "AI: \(sessionManager.sessions.count) sessions analyzed"
        case 3:
            return "Cal: \(calendarIntegration.hasCalendarAccess ? "Connected" : "Disconnected")"
        case 4:
            return "Docs: \(safeDocumentManager.documents.count) processed"
        case 5:
            return "Voice: \(speechService.hasPermissions ? "Active" : "Needs permission")"
        default:
            return currentItem
        }
    }
    
    private func getMarketStatus() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 9 && hour < 16 {
            return "Open +2.1%"
        } else {
            return "Closed"
        }
    }
    
    private func getNextMeeting() -> String {
        if let nextEvent = calendarIntegration.upcomingMeetings.first {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: nextEvent.startDate))"
        }
        return "No meetings"
    }
    
    private func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date()).uppercased()
    }
    
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - AI Name Change View

struct AINameChangeView: View {
    @Binding var aiName: String
    @Binding var aiDisplayName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempName: String = ""
    @State private var tempDisplayName: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Customize Your AI")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Give your executive AI assistant a personalized name and display name.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Short Name (for orb)")
                            .font(.headline)
                        
                        TextField("e.g., ARIA", text: $tempName)
                            .textFieldStyle(.roundedBorder)
                            .textCase(.uppercase)
                            .limitText($tempName, to: 6)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.headline)
                        
                        TextField("e.g., Executive AI Assistant", text: $tempDisplayName)
                            .textFieldStyle(.roundedBorder)
                            .limitText($tempDisplayName, to: 30)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(tempName.isEmpty)
                }
            }
        }
        .onAppear {
            tempName = aiName
            tempDisplayName = aiDisplayName
        }
    }
    
    private func saveChanges() {
        aiName = tempName.uppercased()
        aiDisplayName = tempDisplayName
        dismiss()
    }
}

// MARK: - Text Limiting Extension

extension View {
    func limitText(_ text: Binding<String>, to characterLimit: Int) -> some View {
        self.onChange(of: text.wrappedValue) { _, newValue in
            if newValue.count > characterLimit {
                text.wrappedValue = String(newValue.prefix(characterLimit))
            }
        }
    }
}
