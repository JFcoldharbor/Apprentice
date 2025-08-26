//
//  PersonalityInsights.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  PersonalityInsights.swift
//  Apprentice
//
//  Created by James Garmon on 8/23/25.
//


//
//  PersonalityInsights.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Personality assessment and discovery models
//  Core data structures for understanding founder psychology and working patterns
//

import Foundation

// MARK: - Personality Insights Core Model

struct PersonalityInsights: Codable, Equatable {
    let discoveryLevel: DiscoveryLevel
    let workingStyle: WorkingStyleTraits?
    let communicationPreferences: CommunicationTraits?
    let decisionMakingStyle: DecisionMakingTraits?
    let stressResponses: StressResponseTraits?
    let motivationDrivers: MotivationTraits?
    let leadershipStyle: LeadershipTraits?
    let lastUpdated: Date
    let confidence: Double // 0.0 to 1.0 indicating confidence in the insights
    
    enum DiscoveryLevel: String, Codable, CaseIterable {
        case initial = "Initial"           // 0-5 conversations
        case exploring = "Exploring"       // 6-15 conversations  
        case understanding = "Understanding" // 16-30 conversations
        case intimate = "Intimate"         // 31+ conversations
        
        var sessionRange: String {
            switch self {
            case .initial: return "0-5 sessions"
            case .exploring: return "6-15 sessions"
            case .understanding: return "16-30 sessions"
            case .intimate: return "31+ sessions"
            }
        }
        
        var coachingApproach: String {
            switch self {
            case .initial: return "Surface-level discovery questions"
            case .exploring: return "Pattern identification and deeper exploration"
            case .understanding: return "Blind spot identification and growth challenges"
            case .intimate: return "Personalized coaching based on established patterns"
            }
        }
    }
    
    init(discoveryLevel: DiscoveryLevel, workingStyle: WorkingStyleTraits? = nil, communicationPreferences: CommunicationTraits? = nil, decisionMakingStyle: DecisionMakingTraits? = nil, stressResponses: StressResponseTraits? = nil, motivationDrivers: MotivationTraits? = nil, leadershipStyle: LeadershipTraits? = nil, confidence: Double = 0.0) {
        self.discoveryLevel = discoveryLevel
        self.workingStyle = workingStyle
        self.communicationPreferences = communicationPreferences
        self.decisionMakingStyle = decisionMakingStyle
        self.stressResponses = stressResponses
        self.motivationDrivers = motivationDrivers
        self.leadershipStyle = leadershipStyle
        self.lastUpdated = Date()
        self.confidence = min(max(confidence, 0.0), 1.0)
    }
}

// MARK: - Working Style Traits

struct WorkingStyleTraits: Codable, Equatable {
    let preferredPace: WorkingPace?
    let planningStyle: PlanningApproach?
    let focusPreference: FocusStyle?
    let energySources: [EnergySource]
    let productivityPeaks: [ProductivityWindow]
    let collaborationPreference: CollaborationStyle?
    
    enum WorkingPace: String, Codable, CaseIterable {
        case fastPaced = "Fast-paced"
        case deliberate = "Deliberate"  
        case adaptive = "Adaptive"
        case sprinter = "Sprint-focused"
        case marathoner = "Marathon-focused"
        
        var description: String {
            switch self {
            case .fastPaced: return "Prefers quick decisions and rapid execution"
            case .deliberate: return "Takes time for thorough consideration"
            case .adaptive: return "Adjusts pace based on situation"
            case .sprinter: return "Works in intense bursts with recovery periods"
            case .marathoner: return "Maintains steady, consistent pace"
            }
        }
    }
    
    enum PlanningApproach: String, Codable, CaseIterable {
        case detailedPlanner = "Detailed planner"
        case bigPicture = "Big picture"
        case flexible = "Flexible"
        case goalOriented = "Goal-oriented"
        case processOriented = "Process-oriented"
        
        var description: String {
            switch self {
            case .detailedPlanner: return "Prefers comprehensive planning and clear steps"
            case .bigPicture: return "Focuses on vision and high-level strategy"
            case .flexible: return "Adapts plans as circumstances change"
            case .goalOriented: return "Plans backwards from desired outcomes"
            case .processOriented: return "Focuses on systems and methodologies"
            }
        }
    }
    
    enum FocusStyle: String, Codable, CaseIterable {
        case deepFocus = "Deep focus"
        case multiTasking = "Multi-tasking"
        case contextSwitching = "Context switching"
        case timeBlocking = "Time blocking"
        
        var description: String {
            switch self {
            case .deepFocus: return "Prefers long, uninterrupted work sessions"
            case .multiTasking: return "Comfortable juggling multiple tasks"
            case .contextSwitching: return "Switches between different types of work"
            case .timeBlocking: return "Structures day with dedicated time blocks"
            }
        }
    }
    
    enum EnergySource: String, Codable, CaseIterable {
        case problemSolving = "Problem solving"
        case collaboration = "Collaboration"
        case soloWork = "Solo work"
        case creativity = "Creativity"
        case learning = "Learning"
        case teaching = "Teaching"
        case strategizing = "Strategizing"
        case execution = "Execution"
        
        var icon: String {
            switch self {
            case .problemSolving: return "puzzlepiece.fill"
            case .collaboration: return "person.2.fill"
            case .soloWork: return "person.fill"
            case .creativity: return "paintbrush.fill"
            case .learning: return "book.fill"
            case .teaching: return "person.wave.2.fill"
            case .strategizing: return "lightbulb.fill"
            case .execution: return "checkmark.circle.fill"
            }
        }
    }
    
    enum ProductivityWindow: String, Codable, CaseIterable {
        case earlyMorning = "Early morning"
        case midMorning = "Mid-morning"
        case afternoon = "Afternoon"
        case evening = "Evening"
        case lateNight = "Late night"
        
        var timeRange: String {
            switch self {
            case .earlyMorning: return "5:00-8:00 AM"
            case .midMorning: return "8:00-11:00 AM"
            case .afternoon: return "1:00-4:00 PM"
            case .evening: return "6:00-9:00 PM"
            case .lateNight: return "9:00 PM-12:00 AM"
            }
        }
    }
    
    enum CollaborationStyle: String, Codable, CaseIterable {
        case highlyCollaborative = "Highly collaborative"
        case selectiveCollaboration = "Selective collaboration"
        case independentWithCheckIns = "Independent with check-ins"
        case mostlyIndependent = "Mostly independent"
    }
}

// MARK: - Communication Traits

struct CommunicationTraits: Codable, Equatable {
    let preferredStyle: CommunicationStyle?
    let feedbackPreference: FeedbackStyle?
    let conflictStyle: ConflictApproach?
    let listeningStyle: ListeningApproach?
    let informationProcessing: InformationStyle?
    let meetingPreferences: MeetingPreference?
    
    enum CommunicationStyle: String, Codable, CaseIterable {
        case direct = "Direct"
        case diplomatic = "Diplomatic"
        case analytical = "Analytical"
        case inspirational = "Inspirational"
        case storytelling = "Storytelling"
        case datadriven = "Data-driven"
        
        var description: String {
            switch self {
            case .direct: return "Clear, straightforward communication"
            case .diplomatic: return "Tactful and considerate in delivery"
            case .analytical: return "Logical, evidence-based communication"
            case .inspirational: return "Motivational and vision-focused"
            case .storytelling: return "Uses narratives and examples"
            case .datadriven: return "Supports points with metrics and facts"
            }
        }
    }
    
    enum FeedbackStyle: String, Codable, CaseIterable {
        case immediate = "Immediate"
        case structured = "Structured"
        case privateOneOnOne = "Private one-on-one"
        case publicRecognition = "Public recognition"
        case written = "Written"
        case verbal = "Verbal"
        
        var description: String {
            switch self {
            case .immediate: return "Prefers feedback right after events"
            case .structured: return "Likes scheduled feedback sessions"
            case .privateOneOnOne: return "Prefers private feedback conversations"
            case .publicRecognition: return "Appreciates public acknowledgment"
            case .written: return "Prefers detailed written feedback"
            case .verbal: return "Prefers face-to-face conversations"
            }
        }
    }
    
    enum ConflictApproach: String, Codable, CaseIterable {
        case addressDirectly = "Address directly"
        case collaborativeProblemSolving = "Collaborative problem-solving"
        case avoidConflict = "Avoid conflict"
        case mediatedDiscussion = "Mediated discussion"
        case timeToReflect = "Time to reflect first"
        
        var description: String {
            switch self {
            case .addressDirectly: return "Confronts issues head-on"
            case .collaborativeProblemSolving: return "Seeks win-win solutions"
            case .avoidConflict: return "Prefers to minimize confrontation"
            case .mediatedDiscussion: return "Benefits from neutral third party"
            case .timeToReflect: return "Needs processing time before addressing"
            }
        }
    }
    
    enum ListeningApproach: String, Codable, CaseIterable {
        case activeQuestioner = "Active questioner"
        case reflectiveListener = "Reflective listener"
        case solutionFocused = "Solution-focused"
        case empathetic = "Empathetic"
        case analytical = "Analytical"
        
        var description: String {
            switch self {
            case .activeQuestioner: return "Asks clarifying questions while listening"
            case .reflectiveListener: return "Summarizes and reflects back"
            case .solutionFocused: return "Listens for actionable next steps"
            case .empathetic: return "Focuses on emotional understanding"
            case .analytical: return "Processes information logically"
            }
        }
    }
    
    enum InformationStyle: String, Codable, CaseIterable {
        case detailOriented = "Detail-oriented"
        case bigPictureFirst = "Big picture first"
        case contextualBackground = "Contextual background"
        case bottomLineFirst = "Bottom line first"
        
        var description: String {
            switch self {
            case .detailOriented: return "Wants comprehensive information"
            case .bigPictureFirst: return "Starts with high-level overview"
            case .contextualBackground: return "Needs background and context"
            case .bottomLineFirst: return "Wants conclusion upfront"
            }
        }
    }
    
    enum MeetingPreference: String, Codable, CaseIterable {
        case structuredAgenda = "Structured agenda"
        case openDiscussion = "Open discussion"
        case shortAndFocused = "Short and focused"
        case deepDive = "Deep dive"
        case oneOnOne = "One-on-one"
        case smallGroup = "Small group"
    }
}

// MARK: - Decision Making Traits

struct DecisionMakingTraits: Codable, Equatable {
    let approach: DecisionApproach?
    let riskTolerance: RiskProfile?
    let informationNeed: InformationRequirement?
    let timePreference: DecisionTiming?
    let consultationStyle: ConsultationApproach?
    let implementationStyle: ImplementationApproach?
    
    enum DecisionApproach: String, Codable, CaseIterable {
        case datadriven = "Data-driven"
        case intuitive = "Intuitive"
        case consensusBuilding = "Consensus-building"
        case quickDecisive = "Quick decisive"
        case collaborative = "Collaborative"
        case expertConsultation = "Expert consultation"
        
        var description: String {
            switch self {
            case .datadriven: return "Relies heavily on metrics and analysis"
            case .intuitive: return "Trusts gut feelings and experience"
            case .consensusBuilding: return "Seeks agreement from stakeholders"
            case .quickDecisive: return "Makes rapid decisions with available info"
            case .collaborative: return "Involves team in decision process"
            case .expertConsultation: return "Seeks advice from specialists"
            }
        }
    }
    
    enum RiskProfile: String, Codable, CaseIterable {
        case riskAverse = "Risk-averse"
        case calculatedRisks = "Calculated risks"
        case riskSeeking = "Risk-seeking"
        case contextDependent = "Context-dependent"
        
        var description: String {
            switch self {
            case .riskAverse: return "Prefers safe, proven approaches"
            case .calculatedRisks: return "Takes measured risks with analysis"
            case .riskSeeking: return "Comfortable with high-risk, high-reward scenarios"
            case .contextDependent: return "Risk tolerance varies by situation"
            }
        }
    }
    
    enum InformationRequirement: String, Codable, CaseIterable {
        case minimalInfo = "Minimal info"
        case comprehensiveAnalysis = "Comprehensive analysis"
        case keyInsightsOnly = "Key insights only"
        case multipleScenarios = "Multiple scenarios"
        
        var description: String {
            switch self {
            case .minimalInfo: return "Decides quickly with basic information"
            case .comprehensiveAnalysis: return "Needs thorough research and data"
            case .keyInsightsOnly: return "Wants critical insights highlighted"
            case .multipleScenarios: return "Considers various potential outcomes"
            }
        }
    }
    
    enum DecisionTiming: String, Codable, CaseIterable {
        case quickDecisions = "Quick decisions"
        case thoughtfulConsideration = "Thoughtful consideration"
        case sleepOnIt = "Sleep on it"
        case deadlineDriven = "Deadline-driven"
        
        var description: String {
            switch self {
            case .quickDecisions: return "Prefers to decide quickly and move forward"
            case .thoughtfulConsideration: return "Takes time to weigh options carefully"
            case .sleepOnIt: return "Benefits from overnight reflection"
            case .deadlineDriven: return "Works well with clear decision deadlines"
            }
        }
    }
    
    enum ConsultationApproach: String, Codable, CaseIterable {
        case soloDecision = "Solo decision"
        case keyStakeholders = "Key stakeholders"
        case teamInput = "Team input"
        case externalAdvisors = "External advisors"
        
        var description: String {
            switch self {
            case .soloDecision: return "Prefers to decide independently"
            case .keyStakeholders: return "Consults directly affected parties"
            case .teamInput: return "Gathers input from team members"
            case .externalAdvisors: return "Seeks outside perspective and expertise"
            }
        }
    }
    
    enum ImplementationApproach: String, Codable, CaseIterable {
        case immediateAction = "Immediate action"
        case plannedRollout = "Planned rollout"
        case pilotTesting = "Pilot testing"
        case phaseImplementation = "Phase implementation"
        
        var description: String {
            switch self {
            case .immediateAction: return "Implements decisions quickly"
            case .plannedRollout: return "Develops implementation plan first"
            case .pilotTesting: return "Tests decisions on small scale first"
            case .phaseImplementation: return "Rolls out decisions in stages"
            }
        }
    }
}

// MARK: - Stress Response Traits

struct StressResponseTraits: Codable, Equatable {
    let stressTriggers: [StressTrigger]
    let copingStrategies: [CopingStrategy]
    let supportNeeds: [SupportType]
    let communicationUnderStress: StressCommunicationStyle?
    let performanceUnderPressure: PressureResponse?
    
    enum StressTrigger: String, Codable, CaseIterable {
        case unclearExpectations = "Unclear expectations"
        case timePressure = "Time pressure"
        case conflictSituations = "Conflict situations"
        case lackOfControl = "Lack of control"
        case informationOverload = "Information overload"
        case resourceConstraints = "Resource constraints"
        case ambiguousGoals = "Ambiguous goals"
        case interpersonalTension = "Interpersonal tension"
        
        var icon: String {
            switch self {
            case .unclearExpectations: return "questionmark.circle"
            case .timePressure: return "clock.badge.exclamationmark"
            case .conflictSituations: return "exclamationmark.triangle"
            case .lackOfControl: return "hand.raised.slash"
            case .informationOverload: return "doc.on.doc"
            case .resourceConstraints: return "minus.circle"
            case .ambiguousGoals: return "target"
            case .interpersonalTension: return "person.2.badge.minus"
            }
        }
    }
    
    enum CopingStrategy: String, Codable, CaseIterable {
        case exercise = "Exercise"
        case planning = "Planning"
        case talkingThrough = "Talking through"
        case soloProcessing = "Solo processing"
        case breakingDownTasks = "Breaking down tasks"
        case seekingSupport = "Seeking support"
        case timeAway = "Time away"
        case focusOnControlable = "Focus on controlable"
        
        var description: String {
            switch self {
            case .exercise: return "Physical activity to manage stress"
            case .planning: return "Creates detailed plans to regain control"
            case .talkingThrough: return "Discusses problems with others"
            case .soloProcessing: return "Needs quiet time to think"
            case .breakingDownTasks: return "Divides overwhelming tasks"
            case .seekingSupport: return "Asks for help from team or advisors"
            case .timeAway: return "Takes breaks or time off"
            case .focusOnControlable: return "Focuses energy on what can be influenced"
            }
        }
    }
    
    enum SupportType: String, Codable, CaseIterable {
        case spaceToThink = "Space to think"
        case collaborativeProblemSolving = "Collaborative problem solving"
        case emotionalSupport = "Emotional support"
        case practicalHelp = "Practical help"
        case expertAdvice = "Expert advice"
        case teamBackup = "Team backup"
        
        var description: String {
            switch self {
            case .spaceToThink: return "Needs uninterrupted time to process"
            case .collaborativeProblemSolving: return "Benefits from working through issues together"
            case .emotionalSupport: return "Needs empathy and understanding"
            case .practicalHelp: return "Needs assistance with tasks or logistics"
            case .expertAdvice: return "Needs specialized knowledge or guidance"
            case .teamBackup: return "Needs team to step up and support"
            }
        }
    }
    
    enum StressCommunicationStyle: String, Codable, CaseIterable {
        case moreDirectThanUsual = "More direct than usual"
        case withdrawsFromCommunication = "Withdraws from communication"
        case increasesQuestioning = "Increases questioning"
        case becomesMoreDetailed = "Becomes more detailed"
        case shortensResponses = "Shortens responses"
        
        var description: String {
            switch self {
            case .moreDirectThanUsual: return "Communication becomes more blunt under stress"
            case .withdrawsFromCommunication: return "Reduces communication when overwhelmed"
            case .increasesQuestioning: return "Asks more clarifying questions when stressed"
            case .becomesMoreDetailed: return "Provides more context and detail under pressure"
            case .shortensResponses: return "Gives brief, essential information only"
            }
        }
    }
    
    enum PressureResponse: String, Codable, CaseIterable {
        case thrivestUnderPressure = "Thrives under pressure"
        case performsWellWithStructure = "Performs well with structure"
        case needsTimeToAdapt = "Needs time to adapt"
        case prefersLowPressureEnvironment = "Prefers low-pressure environment"
        
        var description: String {
            switch self {
            case .thrivestUnderPressure: return "Peak performance under tight deadlines"
            case .performsWellWithStructure: return "Handles pressure well with clear frameworks"
            case .needsTimeToAdapt: return "Requires adjustment period for high-pressure situations"
            case .prefersLowPressureEnvironment: return "Optimal performance in calm environments"
            }
        }
    }
}

// MARK: - Motivation Traits

struct MotivationTraits: Codable, Equatable {
    let coreDrivers: [CoreMotivator]
    let workRewards: [WorkReward]
    let longTermAspirations: [LongTermAspiration]
    let learningPreferences: [LearningStyle]
    let recognitionPreference: RecognitionStyle?
    
    enum CoreMotivator: String, Codable, CaseIterable {
        case achievement = "Achievement"
        case autonomy = "Autonomy"
        case impact = "Impact"
        case recognition = "Recognition"
        case mastery = "Mastery"
        case purpose = "Purpose"
        case growth = "Growth"
        case security = "Security"
        
        var description: String {
            switch self {
            case .achievement: return "Driven by accomplishing goals and reaching milestones"
            case .autonomy: return "Motivated by independence and self-direction"
            case .impact: return "Energized by making a meaningful difference"
            case .recognition: return "Motivated by acknowledgment and praise"
            case .mastery: return "Driven by becoming excellent at skills"
            case .purpose: return "Motivated by meaningful work aligned with values"
            case .growth: return "Energized by learning and personal development"
            case .security: return "Motivated by stability and predictability"
            }
        }
        
        var icon: String {
            switch self {
            case .achievement: return "trophy.fill"
            case .autonomy: return "person.fill"
            case .impact: return "arrow.up.right.circle.fill"
            case .recognition: return "hand.thumbsup.fill"
            case .mastery: return "star.fill"
            case .purpose: return "heart.fill"
            case .growth: return "arrow.up.circle.fill"
            case .security: return "shield.fill"
            }
        }
    }
    
    enum WorkReward: String, Codable, CaseIterable {
        case challengingProblems = "Challenging problems"
        case teamSuccess = "Team success"
        case innovation = "Innovation"
        case clientImpact = "Client impact"
        case skillDevelopment = "Skill development"
        case leadershipOpportunities = "Leadership opportunities"
        case creativeFreedom = "Creative freedom"
        case financialGrowth = "Financial growth"
        
        var description: String {
            switch self {
            case .challengingProblems: return "Energized by complex, difficult challenges"
            case .teamSuccess: return "Fulfilled by team achievements and wins"
            case .innovation: return "Excited by creating new solutions"
            case .clientImpact: return "Motivated by positive client outcomes"
            case .skillDevelopment: return "Rewarded by learning new capabilities"
            case .leadershipOpportunities: return "Energized by leading and mentoring"
            case .creativeFreedom: return "Motivated by creative autonomy"
            case .financialGrowth: return "Driven by business and revenue growth"
            }
        }
    }
    
    enum LongTermAspiration: String, Codable, CaseIterable {
        case buildLegacy = "Build legacy"
        case industryLeadership = "Industry leadership"
        case socialImpact = "Social impact"
        case financialFreedom = "Financial freedom"
        case workLifeBalance = "Work-life balance"
        case continuousLearning = "Continuous learning"
        case mentorNextGeneration = "Mentor next generation"
        case innovationLeadership = "Innovation leadership"
        
        var description: String {
            switch self {
            case .buildLegacy: return "Create lasting impact and be remembered"
            case .industryLeadership: return "Become recognized leader in field"
            case .socialImpact: return "Make positive difference in society"
            case .financialFreedom: return "Achieve financial independence"
            case .workLifeBalance: return "Maintain healthy personal/professional balance"
            case .continuousLearning: return "Never stop growing and learning"
            case .mentorNextGeneration: return "Develop and guide emerging leaders"
            case .innovationLeadership: return "Pioneer new technologies or approaches"
            }
        }
    }
    
    enum LearningStyle: String, Codable, CaseIterable {
        case handsOn = "Hands-on"
        case mentorship = "Mentorship"
        case reading = "Reading"
        case experimentation = "Experimentation"
        case formalEducation = "Formal education"
        case peerDiscussion = "Peer discussion"
        case caseStudies = "Case studies"
        case observation = "Observation"
        
        var description: String {
            switch self {
            case .handsOn: return "Learns best by doing and practicing"
            case .mentorship: return "Learns through guidance and coaching"
            case .reading: return "Absorbs information through written material"
            case .experimentation: return "Learns by trying different approaches"
            case .formalEducation: return "Benefits from structured learning programs"
            case .peerDiscussion: return "Learns through conversation and debate"
            case .caseStudies: return "Learns from real-world examples and scenarios"
            case .observation: return "Learns by watching others and analyzing patterns"
            }
        }
    }
    
    enum RecognitionStyle: String, Codable, CaseIterable {
        case publicAcknowledgment = "Public acknowledgment"
        case privateAppreciation = "Private appreciation"
        case tangibleRewards = "Tangible rewards"
        case increasedResponsibility = "Increased responsibility"
        case peerRespect = "Peer respect"
        case expertStatus = "Expert status"
        
        var description: String {
            switch self {
            case .publicAcknowledgment: return "Appreciates public recognition and praise"
            case .privateAppreciation: return "Values personal, one-on-one acknowledgment"
            case .tangibleRewards: return "Motivated by bonuses, gifts, or benefits"
            case .increasedResponsibility: return "Sees new challenges as recognition"
            case .peerRespect: return "Values respect and admiration from colleagues"
            case .expertStatus: return "Wants to be seen as authority in field"
            }
        }
    }
}

// MARK: - Leadership Traits

struct LeadershipTraits: Codable, Equatable {
    let style: LeadershipStyle?
    let teamManagement: [TeamManagementApproach]
    let delegationStyle: DelegationApproach?
    let visionCommunication: VisionCommunicationStyle?
    let conflictResolution: ConflictResolutionStyle?
    let developmentApproach: DevelopmentApproach?
    
    enum LeadershipStyle: String, Codable, CaseIterable {
        case coaching = "Coaching"
        case directive = "Directive"
        case collaborative = "Collaborative"
        case servantLeader = "Servant leader"
        case transformational = "Transformational"
        case situational = "Situational"
        
        var description: String {
            switch self {
            case .coaching: return "Focuses on developing others and building capabilities"
            case .directive: return "Provides clear instructions and expects compliance"
            case .collaborative: return "Seeks input and builds consensus"
            case .servantLeader: return "Puts team needs first and serves others"
            case .transformational: return "Inspires and motivates through vision"
            case .situational: return "Adapts leadership style to situation and person"
            }
        }
    }
    
    enum TeamManagementApproach: String, Codable, CaseIterable {
        case regularOneOnOnes = "Regular 1:1s"
        case teamMeetings = "Team meetings"
        case openDoor = "Open door"
        case projectBasedCheckIns = "Project-based check-ins"
        case informalConnections = "Informal connections"
        case performanceReviews = "Performance reviews"
        
        var description: String {
            switch self {
            case .regularOneOnOnes: return "Schedules consistent individual meetings"
            case .teamMeetings: return "Relies on group meetings for coordination"
            case .openDoor: return "Maintains accessibility for team members"
            case .projectBasedCheckIns: return "Connects around specific work deliverables"
            case .informalConnections: return "Builds relationships through casual interactions"
            case .performanceReviews: return "Uses formal review processes for development"
            }
        }
    }
    
    enum DelegationApproach: String, Codable, CaseIterable {
        case clearInstructions = "Clear instructions"
        case outcomeFocused = "Outcome-focused"
        case handsOff = "Hands-off"
        case collaborativeApproach = "Collaborative approach"
        case developmentalDelegation = "Developmental delegation"
        
        var description: String {
            switch self {
            case .clearInstructions: return "Provides detailed guidance on how to complete tasks"
            case .outcomeFocused: return "Defines desired results and lets team determine approach"
            case .handsOff: return "Delegates fully and provides minimal oversight"
            case .collaborativeApproach: return "Works with team to determine approach and execution"
            case .developmentalDelegation: return "Uses delegation as opportunity to build skills"
            }
        }
    }
    
    enum VisionCommunicationStyle: String, Codable, CaseIterable {
        case storytelling = "Storytelling"
        case datadriven = "Data-driven"
        case inspiring = "Inspiring"
        case practical = "Practical"
        case collaborative = "Collaborative"
        
        var description: String {
            switch self {
            case .storytelling: return "Uses narratives and examples to communicate vision"
            case .datadriven: return "Supports vision with facts, metrics, and analysis"
            case .inspiring: return "Motivates through emotional connection and passion"
            case .practical: return "Focuses on concrete benefits and implementation"
            case .collaborative: return "Builds vision together with team input"
            }
        }
    }
    
    enum ConflictResolutionStyle: String, Codable, CaseIterable {
        case mediator = "Mediator"
        case directIntervention = "Direct intervention"
        case coachingApproach = "Coaching approach"
        case systemicSolution = "Systemic solution"
        case avoidanceUntilCritical = "Avoidance until critical"
        
        var description: String {
            switch self {
            case .mediator: return "Facilitates resolution between conflicting parties"
            case .directIntervention: return "Steps in and makes decisions to resolve conflict"
            case .coachingApproach: return "Helps parties develop their own solutions"
            case .systemicSolution: return "Addresses root causes and systemic issues"
            case .avoidanceUntilCritical: return "Lets conflicts resolve naturally unless severe"
            }
        }
    }
    
    enum DevelopmentApproach: String, Codable, CaseIterable {
        case formalPrograms = "Formal programs"
        case stretchAssignments = "Stretch assignments"
        case mentoring = "Mentoring"
        case skillBasedTraining = "Skill-based training"
        case experientialLearning = "Experiential learning"
        case externalDevelopment = "External development"
        
        var description: String {
            switch self {
            case .formalPrograms: return "Uses structured development and training programs"
            case .stretchAssignments: return "Develops people through challenging new roles"
            case .mentoring: return "Provides personal guidance and career advice"
            case .skillBasedTraining: return "Focuses on specific capability development"
            case .experientialLearning: return "Creates learning opportunities through experience"
            case .externalDevelopment: return "Supports outside learning and development"
            }
        }
    }
}

// MARK: - Personality Insights Extensions

extension PersonalityInsights {
    
    /// Calculate overall confidence based on available traits
    var overallConfidence: Double {
        let traits = [
            workingStyle != nil ? 1.0 : 0.0,
            communicationPreferences != nil ? 1.0 : 0.0,
            decisionMakingStyle != nil ? 1.0 : 0.0,
            stressResponses != nil ? 1.0 : 0.0,
            motivationDrivers != nil ? 1.0 : 0.0,
            leadershipStyle != nil ? 1.0 : 0.0
        ]
        
        let completeness = traits.reduce(0, +) / Double(traits.count)
        return min(completeness * confidence, 1.0)
    }
    
    /// Get summary of key traits for quick reference
    var keyTraitsSummary: String {
        var summary: [String] = []
        
        if let working = workingStyle?.preferredPace?.rawValue {
            summary.append(working)
        }
        
        if let communication = communicationPreferences?.preferredStyle?.rawValue {
            summary.append("\(communication) communicator")
        }
        
        if let decision = decisionMakingStyle?.approach?.rawValue {
            summary.append("\(decision.lowercased()) decisions")
        }
        
        if let leadership = leadershipStyle?.style?.rawValue {
            summary.append("\(leadership.lowercased()) leader")
        }
        
        return summary.joined(separator: " â€¢ ")
    }
    
    /// Check if insights are recent enough to be reliable
    var isCurrentlyRelevant: Bool {
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
        return daysSinceUpdate < 30 // Consider insights stale after 30 days
    }
}