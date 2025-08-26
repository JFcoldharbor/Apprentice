//
//  SimpleConversationTurn.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  SimpleConversationTurn.swift
//  Apprentice
//
//  Created by James Garmon on 8/23/25.
//


//
//  ConversationModels.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Conversation data models
//  RESTORED: Missing types from deleted files
//

import Foundation

// MARK: - Simple Conversation Memory Model

struct SimpleConversationTurn: Codable, Equatable, Identifiable {
    let id = UUID()
    let userInput: String
    let aiResponse: String
    let timestamp: Date
    let sessionId: String?
    
    init(userInput: String, aiResponse: String, sessionId: String? = nil) {
        self.userInput = userInput
        self.aiResponse = aiResponse
        self.timestamp = Date()
        self.sessionId = sessionId
    }
    
    // Custom Equatable implementation to avoid UUID comparison issues
    static func == (lhs: SimpleConversationTurn, rhs: SimpleConversationTurn) -> Bool {
        return lhs.userInput == rhs.userInput &&
               lhs.aiResponse == rhs.aiResponse &&
               lhs.timestamp == rhs.timestamp &&
               lhs.sessionId == rhs.sessionId
    }
}

// MARK: - Conversation Session Model

struct NewConversationSession: Codable, Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date?
    let turns: [SimpleConversationTurn]
    let sessionType: SessionType
    
    init(startTime: Date = Date(), endTime: Date? = nil, turns: [SimpleConversationTurn] = [], sessionType: SessionType = .general) {
        self.startTime = startTime
        self.endTime = endTime
        self.turns = turns
        self.sessionType = sessionType
    }
    
    enum SessionType: String, Codable, CaseIterable {
        case general = "General"
        case coaching = "Coaching"
        case planning = "Planning"
        case review = "Review"
    }
}

// MARK: - Conversation Turn (Alternative type for compatibility)

struct MyConversationTurn: Codable {
    let userInput: String
    let aiResponse: String
    let timestamp: Date
    
    init(userInput: String, aiResponse: String, timestamp: Date = Date()) {
        self.userInput = userInput
        self.aiResponse = aiResponse
        self.timestamp = timestamp
    }
    
    // Convert from SimpleConversationTurn
    init(from simple: SimpleConversationTurn) {
        self.userInput = simple.userInput
        self.aiResponse = simple.aiResponse
        self.timestamp = simple.timestamp
    }
}