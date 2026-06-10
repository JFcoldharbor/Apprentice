//
//  CoachMessage.swift
//  Apprentice
//
//  Layer 1 (Models) — one turn in the ongoing coach conversation.
//  A single rolling conversation for v1 (no threads yet).
//

import Foundation
import SwiftData

@Model
final class CoachMessage {
    var id: UUID = UUID()
    var role: String = "user"      // "user" | "assistant"
    var text: String = ""
    var createdAt: Date = Date()

    init(role: String, text: String, createdAt: Date = Date()) {
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }

    var isUser: Bool { role == "user" }
}
