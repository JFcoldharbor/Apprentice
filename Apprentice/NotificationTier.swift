//
//  NotificationTier.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  NotificationTypes.swift
//  Stitch Executive AI
//
//  Layer 1: Foundation - Shared notification types
//  Single source of truth for notification system types
//

import SwiftUI

// MARK: - Notification Tier

enum NotificationTier {
    case critical
    case important
    case contextual
    
    var primaryColor: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .contextual: return .blue
        }
    }
    
    var floatDuration: Double {
        switch self {
        case .critical: return 8.0
        case .important: return 6.0
        case .contextual: return 3.5
        }
    }
    
    var centerPauseDuration: Double {
        switch self {
        case .critical: return 4.0
        case .important: return 3.0
        case .contextual: return 2.0
        }
    }
    
    var urgencyLabel: String {
        switch self {
        case .critical: return "URGENT"
        case .important: return "IMPORTANT"
        case .contextual: return "INFO"
        }
    }
    
    var labelColor: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .contextual: return .blue
        }
    }
    
    var compactBackgroundColor: Color {
        switch self {
        case .critical: return .red.opacity(0.8)
        case .important: return .orange.opacity(0.8)
        case .contextual: return .blue.opacity(0.8)
        }
    }
}

// MARK: - Notification Card Data

struct NotificationCardData {
    let message: String
    let icon: String
    let onTap: () -> Void
}