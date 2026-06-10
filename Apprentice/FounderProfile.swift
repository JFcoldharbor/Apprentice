//
//  FounderProfile.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  FounderProfile.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//

import Foundation

// MARK: - Founder Profile

struct FounderProfile: Identifiable, Codable {
    let id: UUID
    let founderName: String
    let businessName: String?
    let businessStage: BusinessStage
    let industry: String
    let founderRole: String
    let yearsOfExperience: Int
    let currentChallenges: [String]
    let currentGoals: [String]
    let keyMetrics: [String: String]
    let createdAt: Date
    let lastUpdated: Date
    
    enum BusinessStage: String, CaseIterable, Codable {
        case idea = "Idea Stage"
        case validation = "Validation"
        case earlyStage = "Early Stage"
        case growth = "Growth Stage"
        case scale = "Scale Stage"
        case mature = "Mature"
        
        var description: String {
            switch self {
            case .idea: return "Developing initial concept"
            case .validation: return "Testing market fit"
            case .earlyStage: return "Building first version"
            case .growth: return "Scaling operations"
            case .scale: return "Expanding rapidly"
            case .mature: return "Established business"
            }
        }
    }
}
