//
//  OnboardingStep.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  OnboardingStep.swift
//  Apprentice
//
//  Created by James Garmon on 8/23/25.
//


//
//  OnboardingCoordinator.swift
//  Stitch Executive AI
//
//  Layer 6: Coordination - Onboarding business logic and flow management
//  CLEAN SEPARATION: Business logic extracted from UI layer
//

import Foundation
import SwiftUI

// MARK: - Onboarding Flow State

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case personalInfo = 1
    case businessInfo = 2
    case completion = 3
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .personalInfo: return "Personal Info"
        case .businessInfo: return "Business Info"
        case .completion: return "Complete"
        }
    }
    
    var nextButtonTitle: String {
        switch self {
        case .welcome: return "Get Started"
        case .personalInfo, .businessInfo: return "Continue"
        case .completion: return "Start Coaching"
        }
    }
}

// MARK: - Onboarding Form Data

struct OnboardingFormData {
    var founderName: String = ""
    var businessName: String = ""
    var industry: String = ""
    var businessStage: FounderProfile.BusinessStage = .earlyStage
    var founderRole: String = ""
    var yearsOfExperience: Int = 0
    
    // Validation
    var isPersonalInfoValid: Bool {
        !founderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isBusinessInfoValid: Bool {
        !industry.isEmpty
    }
    
    // Static Data
    static let availableIndustries = [
        "Technology", "Healthcare", "Finance", "E-commerce",
        "Education", "Real Estate", "Consulting", "Manufacturing", "Other"
    ]
    
    static let availableRoles = [
        "CEO", "Founder", "Co-Founder", "President",
        "Managing Director", "Entrepreneur", "Other"
    ]
}

// MARK: - Onboarding Coordinator

@MainActor
class OnboardingCoordinator: ObservableObject {
    
    // MARK: - Dependencies
    
    private let profileManager: FounderProfileManager
    
    // MARK: - Published Properties
    
    @Published var currentStep: OnboardingStep = .welcome
    @Published var formData = OnboardingFormData()
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var isComplete = false
    
    // MARK: - Computed Properties
    
    var progressPercentage: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
    
    var canProceedToNextStep: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .personalInfo:
            return formData.isPersonalInfoValid
        case .businessInfo:
            return formData.isBusinessInfoValid
        case .completion:
            return true
        }
    }
    
    var canGoBack: Bool {
        currentStep != .welcome && !isProcessing
    }
    
    // MARK: - Initialization
    
    init(profileManager: FounderProfileManager) {
        self.profileManager = profileManager
    }
    
    // MARK: - Navigation Actions
    
    func goToNextStep() {
        guard canProceedToNextStep else { return }
        
        if currentStep == .completion {
            createProfile()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .welcome
            }
        }
    }
    
    func goToPreviousStep() {
        guard canGoBack else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
        }
    }
    
    func goToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }
    
    // MARK: - Form Data Management
    
    func updateFounderName(_ name: String) {
        formData.founderName = name
        clearError()
    }
    
    func updateBusinessName(_ name: String) {
        formData.businessName = name
    }
    
    func updateIndustry(_ industry: String) {
        formData.industry = industry
    }
    
    func updateBusinessStage(_ stage: FounderProfile.BusinessStage) {
        formData.businessStage = stage
    }
    
    func updateFounderRole(_ role: String) {
        formData.founderRole = role
    }
    
    func updateYearsOfExperience(_ years: Int) {
        formData.yearsOfExperience = years
    }
    
    // MARK: - Profile Creation
       
       func createProfile() {
           guard canProceedToNextStep else {
               setError("Please complete all required fields")
               return
           }
           
           isProcessing = true
           clearError()
           
           Task {
               do {
                   // Validate form data
                   try validateFormData()
                   
                   // Create profile using existing FounderProfileManager
                   await MainActor.run {
                       profileManager.createProfile(
                           founderName: formData.founderName.trimmingCharacters(in: .whitespacesAndNewlines),
                           businessName: formData.businessName.isEmpty ? nil : formData.businessName.trimmingCharacters(in: .whitespacesAndNewlines),
                           businessStage: formData.businessStage,
                           industry: formData.industry,
                           founderRole: formData.founderRole,
                           yearsOfExperience: formData.yearsOfExperience
                       )
                       
                       // Mark onboarding as complete directly
                       UserDefaults.standard.set(true, forKey: "onboarding_completed")
                   }
                   
                   // Check if profile creation was successful
                   await MainActor.run {
                       // Check if profile was created successfully by checking if it exists
                       if profileManager.founderProfile != nil {
                           self.isComplete = true
                           print("✅ [ONBOARDING] Profile created successfully")
                       } else {
                           self.setError("Failed to create profile")
                       }
                       
                       self.isProcessing = false
                   }
                   
               } catch {
                   await MainActor.run {
                       self.setError(error.localizedDescription)
                       self.isProcessing = false
                   }
               }
           }
       }
    // MARK: - Validation
    
    private func validateFormData() throws {
        // Validate founder name
        let trimmedName = formData.founderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw OnboardingError.invalidFounderName
        }
        
        guard trimmedName.count >= 2 else {
            throw OnboardingError.founderNameTooShort
        }
        
        // Validate industry
        guard !formData.industry.isEmpty else {
            throw OnboardingError.invalidIndustry
        }
        
        // Validate role
        guard !formData.founderRole.isEmpty else {
            throw OnboardingError.invalidRole
        }
        
        // Validate experience
        guard formData.yearsOfExperience >= 0 && formData.yearsOfExperience <= 50 else {
            throw OnboardingError.invalidExperience
        }
    }
    
    // MARK: - Error Handling
    
    private func setError(_ message: String) {
        errorMessage = message
        print("❌ [ONBOARDING] Error: \(message)")
    }
    
    private func MyclearError() {
        errorMessage = nil
    }
    
    // MARK: - Reset
    
    func reset() {
        currentStep = .welcome
        formData = OnboardingFormData()
        isProcessing = false
        errorMessage = nil
        isComplete = false
    }
}

// MARK: - Onboarding Errors

enum OnboardingError: Error, LocalizedError {
    case invalidFounderName
    case founderNameTooShort
    case invalidIndustry
    case invalidRole
    case invalidExperience
    case profileCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFounderName:
            return "Please enter your name"
        case .founderNameTooShort:
            return "Name must be at least 2 characters long"
        case .invalidIndustry:
            return "Please select an industry"
        case .invalidRole:
            return "Please select your role"
        case .invalidExperience:
            return "Years of experience must be between 0 and 50"
        case .profileCreationFailed(let message):
            return "Profile creation failed: \(message)"
        }
    }
}
