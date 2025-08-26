//
//  ConversationHistoryManagerProtocol.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  ConversationHistoryManagerProtocol.swift
//  Apprentice
//
//  Created by James Garmon on 8/23/25.
//


//
//  ConversationHistoryManager.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Pure conversation persistence and storage
//  CLEAN VERSION: Data I/O only, no business logic or AI integration
//

import Foundation
import SwiftUI

// MARK: - Conversation Storage Protocol

protocol ConversationHistoryManagerProtocol {
    func saveConversationTurn(_ turn: SimpleConversationTurn) async
    func loadConversationHistory() async -> [SimpleConversationTurn]
    func getConversationTurnsSince(_ date: Date) async -> [SimpleConversationTurn]
    func getConversationStats() async -> ConversationStats
    func searchConversations(query: String) async -> [SimpleConversationTurn]
    func clearAllHistory() async
    func startNewSession() -> UUID
    func endCurrentSession() async
}

// MARK: - Conversation Statistics Model

struct ConversationStats: Codable {
    let totalTurns: Int
    let totalSessions: Int
    let lastActivity: Date?
    let averageTurnsPerSession: Double
    let firstConversation: Date?
    let conversationsThisWeek: Int
    let conversationsToday: Int
}

// MARK: - Storage Errors

enum ConversationStorageError: Error, LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case corruptedData
    case storageUnavailable
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save conversation: \(message)"
        case .loadFailed(let message):
            return "Failed to load conversations: \(message)"
        case .corruptedData:
            return "Conversation data is corrupted"
        case .storageUnavailable:
            return "Storage is unavailable"
        }
    }
}

// MARK: - Conversation History Manager

@MainActor
class ConversationHistoryManager: ObservableObject, ConversationHistoryManagerProtocol {
    
    // MARK: - Published Properties
    
    @Published var conversationHistory: [SimpleConversationTurn] = []
    @Published var currentSessionId: UUID?
    @Published var isLoading = false
    @Published var lastError: ConversationStorageError?
    
    // MARK: - Storage Configuration
    
    private let storageKey = "ExecutiveConversationHistory_v1"
    private let sessionStorageKey = "ExecutiveConversationSessions_v1"
    private let maxHistoryTurns = 1000 // Keep up to 1000 conversation turns
    private let maxSessionAge: TimeInterval = 86400 * 30 // 30 days
    
    // MARK: - Private Properties
    
    private var conversationSessions: [UUID: Date] = [:] // SessionID -> Creation Date
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Public Interface Methods
    
    func saveConversationTurn(_ turn: SimpleConversationTurn) async {
        print("ðŸ’¾ [CONV-HISTORY] Saving conversation turn: \(turn.userInput.prefix(50))...")
        
        // Add to memory
        conversationHistory.append(turn)
        
        // Maintain size limits
        if conversationHistory.count > maxHistoryTurns {
            conversationHistory = Array(conversationHistory.suffix(maxHistoryTurns))
            print("ðŸ—ƒï¸ [CONV-HISTORY] Trimmed history to \(maxHistoryTurns) turns")
        }
        
        // Persist to storage
        do {
            try await persistConversationHistory()
            print("âœ… [CONV-HISTORY] Turn saved successfully")
        } catch {
            await MainActor.run {
                lastError = .saveFailed(error.localizedDescription)
            }
            print("âŒ [CONV-HISTORY] Save failed: \(error)")
        }
    }
    
    func loadConversationHistory() async -> [SimpleConversationTurn] {
        print("ðŸ“‚ [CONV-HISTORY] Loading conversation history...")
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let history = try await loadPersistedHistory()
            conversationHistory = history
            print("âœ… [CONV-HISTORY] Loaded \(history.count) conversation turns")
            return history
        } catch {
            await MainActor.run {
                lastError = .loadFailed(error.localizedDescription)
            }
            print("âŒ [CONV-HISTORY] Load failed: \(error)")
            return []
        }
    }
    
    func getConversationTurnsSince(_ date: Date) async -> [SimpleConversationTurn] {
        return conversationHistory.filter { $0.timestamp >= date }
    }
    
    func getConversationStats() async -> ConversationStats {
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate session count
        let sessionIds = Set(conversationHistory.compactMap { $0.sessionId })
        
        // Calculate time-based metrics
        let todayStart = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let conversationsToday = conversationHistory.filter { 
            $0.timestamp >= todayStart 
        }.count
        
        let conversationsThisWeek = conversationHistory.filter { 
            $0.timestamp >= weekStart 
        }.count
        
        let averageTurnsPerSession = sessionIds.isEmpty ? 0.0 : 
            Double(conversationHistory.count) / Double(sessionIds.count)
        
        return ConversationStats(
            totalTurns: conversationHistory.count,
            totalSessions: sessionIds.count,
            lastActivity: conversationHistory.last?.timestamp,
            averageTurnsPerSession: averageTurnsPerSession,
            firstConversation: conversationHistory.first?.timestamp,
            conversationsThisWeek: conversationsThisWeek,
            conversationsToday: conversationsToday
        )
    }
    
    func searchConversations(query: String) async -> [SimpleConversationTurn] {
        guard !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        return conversationHistory.filter { turn in
            turn.userInput.lowercased().contains(lowercaseQuery) ||
            turn.aiResponse.lowercased().contains(lowercaseQuery)
        }
    }
    
    func clearAllHistory() async {
        print("ðŸ—‘ï¸ [CONV-HISTORY] Clearing all conversation history...")
        
        conversationHistory.removeAll()
        conversationSessions.removeAll()
        currentSessionId = nil
        
        // Clear persistent storage
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        
        print("âœ… [CONV-HISTORY] History cleared successfully")
    }
    
    func startNewSession() -> UUID {
        let sessionId = UUID()
        currentSessionId = sessionId
        conversationSessions[sessionId] = Date()
        
        // Persist session data
        Task {
            await persistSessionData()
        }
        
        print("ðŸ†• [CONV-HISTORY] Started new session: \(sessionId.uuidString.prefix(8))")
        return sessionId
    }
    
    func endCurrentSession() async {
        if let sessionId = currentSessionId {
            print("ðŸ [CONV-HISTORY] Ended session: \(sessionId.uuidString.prefix(8))")
        }
        
        currentSessionId = nil
        await persistSessionData()
    }
    
    // MARK: - Conversation History Access (for other services)
    
    func getRecentConversations(limit: Int = 10) -> [SimpleConversationTurn] {
        return Array(conversationHistory.suffix(limit))
    }
    
    func getConversationsFromSession(_ sessionId: UUID) -> [SimpleConversationTurn] {
        return conversationHistory.filter { $0.sessionId == sessionId.uuidString }
    }
    
    func getConversationsFromDate(_ date: Date) -> [SimpleConversationTurn] {
        let calendar = Calendar.current
        return conversationHistory.filter { turn in
            calendar.isDate(turn.timestamp, inSameDayAs: date)
        }
    }
    
    // MARK: - Private Storage Methods
    
    private func loadInitialData() async {
        await loadPersistedSessions()
        _ = await loadConversationHistory()
        await cleanupOldSessions()
    }
    
    private func persistConversationHistory() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(conversationHistory)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("ðŸ’¾ [CONV-HISTORY] Persisted \(conversationHistory.count) turns")
        } catch {
            throw ConversationStorageError.saveFailed(error.localizedDescription)
        }
    }
    
    private func loadPersistedHistory() async throws -> [SimpleConversationTurn] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("ðŸ“‚ [CONV-HISTORY] No existing history found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let history = try decoder.decode([SimpleConversationTurn].self, from: data)
            return history
        } catch {
            print("âŒ [CONV-HISTORY] Failed to decode history: \(error)")
            throw ConversationStorageError.corruptedData
        }
    }
    
    private func persistSessionData() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(conversationSessions)
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
            
            // Also persist current session ID
            if let sessionId = currentSessionId {
                UserDefaults.standard.set(sessionId.uuidString, forKey: "CurrentConversationSession")
            } else {
                UserDefaults.standard.removeObject(forKey: "CurrentConversationSession")
            }
            
        } catch {
            print("âŒ [CONV-HISTORY] Failed to persist session data: \(error)")
        }
    }
    
    private func loadPersistedSessions() async {
        // Load session data
        if let data = UserDefaults.standard.data(forKey: sessionStorageKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                conversationSessions = try decoder.decode([UUID: Date].self, from: data)
                print("ðŸ“‚ [CONV-HISTORY] Loaded \(conversationSessions.count) session records")
            } catch {
                print("âŒ [CONV-HISTORY] Failed to decode session data: \(error)")
                conversationSessions = [:]
            }
        }
        
        // Load current session ID
        if let sessionIdString = UserDefaults.standard.string(forKey: "CurrentConversationSession"),
           let sessionId = UUID(uuidString: sessionIdString) {
            currentSessionId = sessionId
            print("ðŸ“‚ [CONV-HISTORY] Restored current session: \(sessionId.uuidString.prefix(8))")
        }
    }
    
    private func cleanupOldSessions() async {
        let cutoffDate = Date().addingTimeInterval(-maxSessionAge)
        let initialCount = conversationSessions.count
        
        conversationSessions = conversationSessions.filter { (_, date) in
            date >= cutoffDate
        }
        
        let removedCount = initialCount - conversationSessions.count
        if removedCount > 0 {
            print("ðŸ§¹ [CONV-HISTORY] Cleaned up \(removedCount) old sessions")
            await persistSessionData()
        }
    }
    
    // MARK: - Data Export/Import (for future features)
    
    func exportConversationHistory() async -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let exportData = ConversationExport(
                conversations: conversationHistory,
                sessions: conversationSessions,
                exportDate: Date(),
                version: "1.0"
            )
            
            return try encoder.encode(exportData)
        } catch {
            print("âŒ [CONV-HISTORY] Export failed: \(error)")
            return nil
        }
    }
    
    func importConversationHistory(from data: Data, mergeStrategy: ImportMergeStrategy = .append) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importData = try decoder.decode(ConversationExport.self, from: data)
        
        switch mergeStrategy {
        case .replace:
            conversationHistory = importData.conversations
            conversationSessions = importData.sessions
        case .append:
            conversationHistory.append(contentsOf: importData.conversations)
            conversationSessions.merge(importData.sessions) { (current, _) in current }
        case .merge:
            // More sophisticated merging logic could be added here
            conversationHistory.append(contentsOf: importData.conversations)
            conversationSessions.merge(importData.sessions) { (current, _) in current }
        }
        
        // Remove duplicates and sort
        conversationHistory = Array(Set(conversationHistory)).sorted { $0.timestamp < $1.timestamp }
        
        // Persist the merged data
        try await persistConversationHistory()
        await persistSessionData()
        
        print("âœ… [CONV-HISTORY] Import completed: \(importData.conversations.count) conversations")
    }
}

// MARK: - Export/Import Models

struct ConversationExport: Codable {
    let conversations: [SimpleConversationTurn]
    let sessions: [UUID: Date]
    let exportDate: Date
    let version: String
}

enum ImportMergeStrategy {
    case replace    // Replace all existing data
    case append     // Add to existing data
    case merge      // Smart merge with deduplication
}

// MARK: - SimpleConversationTurn Hashable Extension

extension SimpleConversationTurn: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(userInput)
        hasher.combine(aiResponse)
        hasher.combine(timestamp)
        hasher.combine(sessionId)
    }
}