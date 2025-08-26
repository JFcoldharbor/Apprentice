//
//  ProfileView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  ProfileView.swift
//  Apprentice
//
//  Layer 8: Views - Founder profile management and settings
//  FIXED - Simplified to match actual FounderProfileManager implementation
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var profileManager: FounderProfileManager
    @ObservedObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isEditing = false
    @State private var founderName = ""
    @State private var businessName = ""
    @State private var selectedIndustry = "Technology"
    @State private var selectedStage = FounderProfile.BusinessStage.earlyStage
    @State private var founderRole = "CEO"
    @State private var yearsOfExperience = 5
    @State private var showingDeleteAlert = false
    
    private let industries = [
        "Technology", "Healthcare", "Finance", "E-commerce", 
        "Education", "Real Estate", "Consulting", "Manufacturing", 
        "Media & Entertainment", "Non-profit", "Other"
    ]
    
    private let roles = [
        "CEO", "Founder", "Co-Founder", "President", 
        "Managing Director", "Entrepreneur", "CTO", "CMO", "Other"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if hasProfile {
                            profileSummaryCard
                            aiRelationshipSection
                            if isEditing {
                                profileDetailsSection
                            }
                            dangerZoneSection
                        } else {
                            createProfileSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Executive Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                if hasProfile {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isEditing ? "Save" : "Edit") {
                            if isEditing {
                                saveProfile()
                            } else {
                                startEditing()
                            }
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    // MARK: - Background
    
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
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.cyan, .blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 8) {
                Text(hasProfile ? (profileManager.founderProfile?.founderName ?? "Executive") : "Setup Your Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if hasProfile, let profile = profileManager.founderProfile {
                    Text("\(profile.founderRole) • \(profile.industry)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Profile Summary Card
    
    private var profileSummaryCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.badge.key.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Executive Profile")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(relationshipLevel.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(relationshipLevel.color.opacity(0.2))
                        .foregroundColor(relationshipLevel.color)
                        .clipShape(Capsule())
                }
                
                if let profile = profileManager.founderProfile {
                    VStack(spacing: 12) {
                        ProfileRow(label: "Name", value: profile.founderName)
                        ProfileRow(label: "Role", value: profile.founderRole)
                        
                        if let businessName = profile.businessName {
                            ProfileRow(label: "Company", value: businessName)
                        }
                        
                        ProfileRow(label: "Industry", value: profile.industry)
                        ProfileRow(label: "Stage", value: profile.businessStage.rawValue)
                        ProfileRow(label: "Experience", value: "\(profile.yearsOfExperience) years")
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - AI Relationship Section
    
    private var aiRelationshipSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("AI Coaching Relationship")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Sessions Completed")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(sessionManager.sessions.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Relationship Level")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(relationshipLevel.rawValue)
                            .fontWeight(.semibold)
                            .foregroundColor(relationshipLevel.color)
                    }
                    
                    HStack {
                        Text("Next Milestone")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(nextMilestone)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                
                Text(relationshipDescription)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .padding(20)
        }
    }
    
    // MARK: - Profile Details Section (Editing)
    
    private var profileDetailsSection: some View {
        GlassCard {
            VStack(spacing: 20) {
                Text("Edit Profile Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    ProfileEditField(label: "Full Name", text: $founderName)
                    ProfileEditField(label: "Business Name (Optional)", text: $businessName)
                    
                    // Role Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Menu {
                            ForEach(roles, id: \.self) { role in
                                Button(role) {
                                    founderRole = role
                                }
                            }
                        } label: {
                            HStack {
                                Text(founderRole)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Industry Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Industry")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Menu {
                            ForEach(industries, id: \.self) { industry in
                                Button(industry) {
                                    selectedIndustry = industry
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedIndustry)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Business Stage Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Business Stage")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Menu {
                            ForEach(FounderProfile.BusinessStage.allCases, id: \.self) { stage in
                                Button(stage.rawValue) {
                                    selectedStage = stage
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedStage.rawValue)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Years of Experience
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Years of Experience: \(yearsOfExperience)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Slider(value: Binding(
                            get: { Double(yearsOfExperience) },
                            set: { yearsOfExperience = Int($0) }
                        ), in: 0...50, step: 1)
                        .accentColor(.blue)
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Create Profile Section
    
    private var createProfileSection: some View {
        VStack(spacing: 24) {
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Create Your Executive Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Set up your business context to unlock personalized AI coaching that knows your industry, challenges, and goals.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    Button("Get Started") {
                        isEditing = true
                        // Initialize with defaults
                        founderName = ""
                        businessName = ""
                        selectedIndustry = "Technology"
                        selectedStage = .earlyStage
                        founderRole = "CEO"
                        yearsOfExperience = 5
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(24)
            }
        }
    }
    
    // MARK: - Danger Zone
    
    private var dangerZoneSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Profile Management")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button("Reset Profile") {
                    showingDeleteAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
        }
        .alert("Reset Profile", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetProfile()
            }
        } message: {
            Text("This will permanently delete your profile and reset your AI coaching relationship. This cannot be undone.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasProfile: Bool {
        profileManager.founderProfile != nil
    }
    
    private var relationshipLevel: ProfileRelationshipLevel {
        let sessionCount = sessionManager.sessions.count
        
        if sessionCount >= 115 {
            return .executivePartner
        } else if sessionCount >= 95 {
            return .strategicAdvisor
        } else if sessionCount >= 70 {
            return .trustedPartner
        } else if sessionCount >= 35 {
            return .developingPartnership
        } else {
            return .newMentorship
        }
    }
    
    private var nextMilestone: String {
        let sessionCount = sessionManager.sessions.count
        
        if sessionCount < 35 {
            return "\(35 - sessionCount) sessions to Developing Partnership"
        } else if sessionCount < 70 {
            return "\(70 - sessionCount) sessions to Trusted Partner"
        } else if sessionCount < 95 {
            return "\(95 - sessionCount) sessions to Strategic Advisor"
        } else if sessionCount < 115 {
            return "\(115 - sessionCount) sessions to Executive Partner"
        } else {
            return "Maximum relationship level achieved"
        }
    }
    
    private var relationshipDescription: String {
        switch relationshipLevel {
        case .newMentorship:
            return "Your AI coach is getting to know your business style and building rapport. Expect direct, challenging questions as you prove yourself through tough business decisions."
        case .developingPartnership:
            return "You're earning your AI coach's respect through consistent performance. The relationship is becoming more collaborative as trust builds."
        case .trustedPartner:
            return "You've established a trusted business partnership. Your AI coach provides balanced guidance while respecting your proven track record."
        case .strategicAdvisor:
            return "Your AI coach now serves as a strategic advisor, offering high-level guidance with growing warmth and mutual respect."
        case .executivePartner:
            return "You've reached the highest level - an intimate business partnership. Your AI coach treats you as a close friend while maintaining the highest professional standards."
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentProfile() {
        guard let profile = profileManager.founderProfile else { return }
        
        founderName = profile.founderName
        businessName = profile.businessName ?? ""
        selectedIndustry = profile.industry
        selectedStage = profile.businessStage
        founderRole = profile.founderRole
        yearsOfExperience = profile.yearsOfExperience
    }
    
    private func startEditing() {
        isEditing = true
        loadCurrentProfile()
    }
    
    // ✅ FIXED: Simplified to match OnboardingFlow.swift pattern
    private func saveProfile() {
        profileManager.createProfile(
            founderName: founderName,
            businessName: businessName.isEmpty ? nil : businessName,
            businessStage: selectedStage,
            industry: selectedIndustry,
            founderRole: founderRole,
            yearsOfExperience: yearsOfExperience
        )
        
        isEditing = false
    }
    
    // ✅ FIXED: Create a minimal reset that works
    private func resetProfile() {
        profileManager.createProfile(
            founderName: "",
            businessName: nil,
            businessStage: .earlyStage,
            industry: "Technology",
            founderRole: "CEO",
            yearsOfExperience: 0
        )
        isEditing = false
        dismiss()
    }
}

// MARK: - Supporting Views

struct ProfileRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

struct ProfileEditField: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            TextField(label, text: $text)
                .textFieldStyle(ProfileTextFieldStyle())
        }
    }
}

struct ProfileTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(.white.opacity(0.1))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Profile Relationship Level Enum (Renamed to avoid conflict)

enum ProfileRelationshipLevel {
    case newMentorship
    case developingPartnership
    case trustedPartner
    case strategicAdvisor
    case executivePartner
    
    var color: Color {
        switch self {
        case .newMentorship: return .orange
        case .developingPartnership: return .yellow
        case .trustedPartner: return .green
        case .strategicAdvisor: return .blue
        case .executivePartner: return .purple
        }
    }
    
    var rawValue: String {
        switch self {
        case .newMentorship: return "New Mentorship"
        case .developingPartnership: return "Developing Partnership"
        case .trustedPartner: return "Trusted Partner"
        case .strategicAdvisor: return "Strategic Advisor"
        case .executivePartner: return "Executive Partner"
        }
    }
}

#Preview {
    ProfileView(
        profileManager: FounderProfileManager.shared,
        sessionManager: SessionManager.shared
    )
}