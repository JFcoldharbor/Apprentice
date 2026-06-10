//
//  FounderProfileManager.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  FounderProfileManager.swift
//  Stitch Executive AI
//
//  Layer 6: Coordination - Founder profile management and business intelligence
//  COMPLETE VERSION - Matches all existing view implementations
//

import Foundation
import SwiftUI

@MainActor
class FounderProfileManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = FounderProfileManager()
    
    // MARK: - Published Properties
    
    @Published var founderProfile: FounderProfile?
    @Published var isCreatingProfile = false
    @Published var profileError: String?
    
    // MARK: - Storage Configuration
    
    private let profileStorageKey = "founder_profile_v2"
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    private init() {
        loadProfile()
    }
    
    // MARK: - Profile Management
    
    func createProfile(
        founderName: String,
        businessName: String? = nil,
        businessStage: FounderProfile.BusinessStage,
        industry: String,
        founderRole: String,
        yearsOfExperience: Int
    ) {
        print("[PROFILE] Creating founder profile...")
        
        isCreatingProfile = true
        profileError = nil
        
        let profile = FounderProfile(
            id: UUID(),
            founderName: founderName.trimmingCharacters(in: .whitespacesAndNewlines),
            businessName: businessName?.trimmingCharacters(in: .whitespacesAndNewlines),
            businessStage: businessStage,
            industry: industry,
            founderRole: founderRole,
            yearsOfExperience: max(0, yearsOfExperience),
            currentChallenges: generateInitialChallenges(for: businessStage),
            currentGoals: generateInitialGoals(for: businessStage),
            keyMetrics: generateInitialMetrics(for: businessStage),
            createdAt: Date(),
            lastUpdated: Date()
        )
        
        self.founderProfile = profile
        saveProfile()
        
        isCreatingProfile = false
        
        print("[PROFILE] Profile created for \(founderName)")
    }
    
    func updateProfile(
        founderName: String? = nil,
        businessName: String? = nil,
        businessStage: FounderProfile.BusinessStage? = nil,
        industry: String? = nil,
        founderRole: String? = nil,
        yearsOfExperience: Int? = nil,
        currentChallenges: [String]? = nil,
        currentGoals: [String]? = nil,
        keyMetrics: [String: String]? = nil
    ) {
        guard var profile = founderProfile else {
            profileError = "No profile exists to update"
            return
        }
        
        // Create updated profile with new values
        let updatedProfile = FounderProfile(
            id: profile.id,
            founderName: founderName ?? profile.founderName,
            businessName: businessName ?? profile.businessName,
            businessStage: businessStage ?? profile.businessStage,
            industry: industry ?? profile.industry,
            founderRole: founderRole ?? profile.founderRole,
            yearsOfExperience: yearsOfExperience ?? profile.yearsOfExperience,
            currentChallenges: currentChallenges ?? profile.currentChallenges,
            currentGoals: currentGoals ?? profile.currentGoals,
            keyMetrics: keyMetrics ?? profile.keyMetrics,
            createdAt: profile.createdAt,
            lastUpdated: Date()
        )
        
        self.founderProfile = updatedProfile
        saveProfile()
        
        print("[PROFILE] Profile updated")
    }
    
    func deleteProfile() {
        founderProfile = nil
        userDefaults.removeObject(forKey: profileStorageKey)
        print("[PROFILE] Profile deleted")
    }
    
    // MARK: - Business Intelligence Generation
    
    private func generateInitialChallenges(for stage: FounderProfile.BusinessStage) -> [String] {
        switch stage {
        case .idea:
            return ["Validating market need", "Building MVP", "Finding initial customers"]
        case .validation:
            return ["Product-market fit", "Customer acquisition", "Revenue generation"]
        case .earlyStage:
            return ["Scaling operations", "Team building", "Funding runway"]
        case .growth:
            return ["Market expansion", "Team management", "Operational efficiency"]
        case .scale:
            return ["International expansion", "Strategic partnerships", "Exit planning"]
        case .mature:
            return ["Innovation initiatives", "Market disruption", "Legacy planning"]
        }
    }
    
    private func generateInitialGoals(for stage: FounderProfile.BusinessStage) -> [String] {
        switch stage {
        case .idea:
            return ["Complete market research", "Build prototype", "Validate concept"]
        case .validation:
            return ["Launch beta version", "Acquire 100 users", "Generate first revenue"]
        case .earlyStage:
            return ["Reach product-market fit", "Build core team", "Secure funding"]
        case .growth:
            return ["Scale to $1M ARR", "Expand to new markets", "Optimize operations"]
        case .scale:
            return ["Achieve $10M+ revenue", "Build strategic moat", "Prepare for exit"]
        case .mature:
            return ["Maintain market leadership", "Drive innovation", "Plan succession"]
        }
    }
    
    private func generateInitialMetrics(for stage: FounderProfile.BusinessStage) -> [String: String] {
        switch stage {
        case .idea:
            return [
                "Market Research": "In Progress",
                "Prototype Status": "Planning",
                "Validation Score": "0%"
            ]
        case .validation:
            return [
                "Beta Users": "0",
                "Product-Market Fit": "Testing",
                "Revenue": "$0"
            ]
        case .earlyStage:
            return [
                "Monthly Revenue": "$0",
                "Team Size": "1-3",
                "Runway": "6-12 months"
            ]
        case .growth:
            return [
                "Monthly Revenue": "$10K+",
                "Team Size": "5-15",
                "Growth Rate": "10%+ MoM"
            ]
        case .scale:
            return [
                "Annual Revenue": "$1M+",
                "Team Size": "20+",
                "Market Share": "Expanding"
            ]
        case .mature:
            return [
                "Annual Revenue": "$10M+",
                "Team Size": "50+",
                "Market Position": "Leader"
            ]
        }
    }
    
    // MARK: - Personality & Coaching Integration
    
    func getCoachingPersonality() -> String {
        guard let profile = founderProfile else {
            return "supportive and discovery-focused"
        }
        
        // Adapt coaching style based on experience and stage
        switch (profile.businessStage, profile.yearsOfExperience) {
        case (.idea, 0...2):
            return "patient and educational, focused on fundamentals"
        case (.validation, 0...5):
            return "encouraging but direct about market realities"
        case (.earlyStage, 3...10):
            return "strategic and growth-oriented"
        case (.growth, 5...15):
            return "operationally focused with scaling expertise"
        case (.scale, 10...):
            return "executive-level strategic thinking"
        case (.mature, 15...):
            return "peer-level advisor with deep respect"
        default:
            return "adaptable and insight-driven"
        }
    }
    
    func getBusinessContext() -> String {
        guard let profile = founderProfile else {
            return "No profile context available"
        }
        
        var context = """
        BUSINESS CONTEXT:
        • Founder: \(profile.founderName), \(profile.founderRole)
        • Industry: \(profile.industry)
        • Stage: \(profile.businessStage.rawValue) (\(profile.businessStage.description))
        • Experience: \(profile.yearsOfExperience) years
        """
        
        if let businessName = profile.businessName {
            context += "\n• Company: \(businessName)"
        }
        
        if !profile.currentChallenges.isEmpty {
            context += "\n• Challenges: \(profile.currentChallenges.joined(separator: ", "))"
        }
        
        if !profile.currentGoals.isEmpty {
            context += "\n• Goals: \(profile.currentGoals.joined(separator: ", "))"
        }
        
        return context
    }
    
    // MARK: - Persistence
    
    private func saveProfile() {
        guard let profile = founderProfile else { return }
        
        do {
            let encoded = try JSONEncoder().encode(profile)
            userDefaults.set(encoded, forKey: profileStorageKey)
            print("[PROFILE] Profile saved successfully")
        } catch {
            print("[PROFILE] Failed to save profile: \(error)")
            profileError = "Failed to save profile"
        }
    }
    
    private func loadProfile() {
        guard let data = userDefaults.data(forKey: profileStorageKey) else {
            print("[PROFILE] No saved profile found")
            return
        }
        
        do {
            let profile = try JSONDecoder().decode(FounderProfile.self, from: data)
            self.founderProfile = profile
            print("[PROFILE] Profile loaded for \(profile.founderName)")
        } catch {
            print("[PROFILE] Failed to load profile: \(error)")
            userDefaults.removeObject(forKey: profileStorageKey)
        }
    }
    
    // MARK: - Validation
    
    func validateProfileData(
        founderName: String,
        businessStage: FounderProfile.BusinessStage,
        industry: String,
        founderRole: String,
        yearsOfExperience: Int
    ) -> [String] {
        var errors: [String] = []
        
        if founderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Founder name is required")
        }
        
        if industry.isEmpty {
            errors.append("Industry selection is required")
        }
        
        if founderRole.isEmpty {
            errors.append("Founder role is required")
        }
        
        if yearsOfExperience < 0 || yearsOfExperience > 50 {
            errors.append("Years of experience must be between 0 and 50")
        }
        
        return errors
    }
    
    // MARK: - Business Intelligence Helpers
    
    func getCurrentBusinessPhase() -> String {
        guard let profile = founderProfile else { return "Unknown" }
        
        let experience = profile.yearsOfExperience
        let stage = profile.businessStage
        
        switch (stage, experience) {
        case (.idea, 0...2):
            return "First-time founder in ideation"
        case (.validation, 0...3):
            return "Early founder testing market"
        case (.earlyStage, 2...8):
            return "Experienced founder building"
        case (.growth, 5...15):
            return "Scaling founder with proven track record"
        case (.scale, 10...):
            return "Serial entrepreneur scaling enterprise"
        case (.mature, 15...):
            return "Veteran founder with mature business"
        default:
            return "Experienced business leader"
        }
    }
    
    func getRecommendedCoachingFrequency() -> String {
        guard let profile = founderProfile else { return "Weekly" }
        
        switch profile.businessStage {
        case .idea, .validation:
            return "2-3 times per week"
        case .earlyStage:
            return "Weekly"
        case .growth:
            return "Bi-weekly"
        case .scale, .mature:
            return "Monthly with ad-hoc sessions"
        }
    }
}