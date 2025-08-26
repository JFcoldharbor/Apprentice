//
//  OnboardingFlow.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  OnboardingFlow.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Pure UI for onboarding intake form
//  CLEAN SEPARATION: UI only, business logic handled by OnboardingCoordinator
//

import SwiftUI

struct OnboardingFlow: View {
    @ObservedObject var profileManager: FounderProfileManager
    let onComplete: () -> Void
    
    // CLEAN: Use coordinator for all business logic
    @StateObject private var coordinator: OnboardingCoordinator
    
    init(profileManager: FounderProfileManager, onComplete: @escaping () -> Void) {
        self.profileManager = profileManager
        self.onComplete = onComplete
        self._coordinator = StateObject(wrappedValue: OnboardingCoordinator(profileManager: profileManager))
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                progressIndicator
                
                TabView(selection: $coordinator.currentStep) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    personalInfoStep.tag(OnboardingStep.personalInfo)
                    businessInfoStep.tag(OnboardingStep.businessInfo)
                    completionStep.tag(OnboardingStep.completion)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                navigationButtons
            }
        }
        .alert("Profile Creation Failed", isPresented: .constant(coordinator.errorMessage != nil)) {
            Button("OK") {
                coordinator.clearError()
            }
        } message: {
            Text(coordinator.errorMessage ?? "Unknown error occurred")
        }
        .onChange(of: coordinator.isComplete) { _, isComplete in
            if isComplete {
                onComplete()
            }
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
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack {
            ForEach(Array(OnboardingStep.allCases.enumerated()), id: \.offset) { index, step in
                Circle()
                    .fill(step.rawValue <= coordinator.currentStep.rawValue ? .blue : .white.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(step == coordinator.currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: coordinator.currentStep)
                
                if index < OnboardingStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < coordinator.currentStep.rawValue ? .blue : .white.opacity(0.3))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.3), value: coordinator.currentStep)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Circle()
                    .fill(.blue.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white)
                    )
                
                VStack(spacing: 12) {
                    Text("Welcome to")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("APPRENTICE AI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your AI-powered business coach for executive growth and strategic insights")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "mic.circle.fill",
                    title: "Voice-First Coaching",
                    description: "Record conversations and get AI insights"
                )
                
                FeatureRow(
                    icon: "lightbulb.fill",
                    title: "Business Intelligence",
                    description: "Track patterns and identify opportunities"
                )
                
                FeatureRow(
                    icon: "target",
                    title: "Personalized Guidance",
                    description: "Coaching tailored to your business stage"
                )
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Personal Info Step
    
    private var personalInfoStep: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Text("Tell us about yourself")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("This helps us personalize your AI coaching experience")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    IntakeField(
                        title: "Your Name",
                        text: Binding(
                            get: { coordinator.formData.founderName },
                            set: { coordinator.updateFounderName($0) }
                        ),
                        placeholder: "Enter your full name"
                    )
                    
                    IntakePickerField(
                        title: "Your Role",
                        selection: Binding(
                            get: { coordinator.formData.founderRole },
                            set: { coordinator.updateFounderRole($0) }
                        ),
                        options: OnboardingFormData.availableRoles
                    )
                    
                    IntakeStepperField(
                        title: "Years of Experience",
                        value: Binding(
                            get: { coordinator.formData.yearsOfExperience },
                            set: { coordinator.updateYearsOfExperience($0) }
                        ),
                        range: 0...50
                    )
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 30)
        }
    }
    
    // MARK: - Business Info Step
    
    private var businessInfoStep: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Text("About your business")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Help us understand your business context for better coaching")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                VStack(spacing: 20) {
                    IntakeField(
                        title: "Business Name (Optional)",
                        text: Binding(
                            get: { coordinator.formData.businessName },
                            set: { coordinator.updateBusinessName($0) }
                        ),
                        placeholder: "Enter your business name"
                    )
                    
                    IntakePickerField(
                        title: "Industry",
                        selection: Binding(
                            get: { coordinator.formData.industry },
                            set: { coordinator.updateIndustry($0) }
                        ),
                        options: OnboardingFormData.availableIndustries
                    )
                    
                    BusinessStageSelector(
                        selectedStage: Binding(
                            get: { coordinator.formData.businessStage },
                            set: { coordinator.updateBusinessStage($0) }
                        )
                    )
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 30)
        }
    }
    
    // MARK: - Completion Step
    
    private var completionStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 12) {
                    Text("You're all set!")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your AI business coach is ready to help you grow your business")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            IntakeSummaryCard(formData: coordinator.formData)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if coordinator.canGoBack {
                Button("Back") {
                    coordinator.goToPreviousStep()
                }
                .font(.headline)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(coordinator.isProcessing)
            }
            
            Button(coordinator.currentStep.nextButtonTitle) {
                coordinator.goToNextStep()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(coordinator.canProceedToNextStep ? .blue : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!coordinator.canProceedToNextStep || coordinator.isProcessing)
            .overlay(
                Group {
                    if coordinator.isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }
            )
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 50)
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct IntakeField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
}

struct IntakePickerField: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding()
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct IntakeStepperField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Text("\(value) years")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
            .padding()
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct BusinessStageSelector: View {
    @Binding var selectedStage: FounderProfile.BusinessStage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Business Stage")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                ForEach(FounderProfile.BusinessStage.allCases, id: \.self) { stage in
                    Button(action: {
                        selectedStage = stage
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stage.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Text(stage.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: selectedStage == stage ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedStage == stage ? .blue : .white.opacity(0.3))
                        }
                        .padding()
                        .background(selectedStage == stage ? .blue.opacity(0.2) : .white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct IntakeSummaryCard: View {
    let formData: OnboardingFormData
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Profile Summary")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                SummaryRow(label: "Name", value: formData.founderName)
                SummaryRow(label: "Role", value: formData.founderRole)
                if !formData.businessName.isEmpty {
                    SummaryRow(label: "Business", value: formData.businessName)
                }
                SummaryRow(label: "Industry", value: formData.industry)
                SummaryRow(label: "Stage", value: formData.businessStage.rawValue)
                SummaryRow(label: "Experience", value: "\(formData.yearsOfExperience) years")
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 30)
    }
}

struct SummaryRow: View {
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

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(.white.opacity(0.1))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Extension for Coordinator Error Clearing

extension OnboardingCoordinator {
    func clearError() {
        errorMessage = nil
    }
}

#Preview {
    OnboardingFlow(profileManager: FounderProfileManager.shared) {
        print("Onboarding completed")
    }
}