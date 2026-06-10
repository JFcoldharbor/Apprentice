//
//  NotificationTypes.swift
//  Apprentice
//
//  Layer 1: Foundation - Single source of truth for notification types
//

import SwiftUI

// MARK: - Notification Tier

enum MyNotificationTier {
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
    
    var cardHeight: CGFloat {
        switch self {
        case .critical: return 80
        case .important: return 70
        case .contextual: return 60
        }
    }
    
    var cornerRadius: CGFloat {
        return 12
    }
    
    var strokeWidth: CGFloat {
        switch self {
        case .critical: return 2
        case .important: return 1.5
        case .contextual: return 1
        }
    }
    
    var shadowColor: Color {
        return primaryColor.opacity(0.3)
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .critical: return 8
        case .important: return 6
        case .contextual: return 4
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .critical: return 44
        case .important: return 40
        case .contextual: return 36
        }
    }
    
    var iconFontSize: CGFloat {
        switch self {
        case .critical: return 20
        case .important: return 18
        case .contextual: return 16
        }
    }
    
    var iconWeight: Font.Weight {
        switch self {
        case .critical: return .bold
        case .important: return .semibold
        case .contextual: return .medium
        }
    }
    
    var iconBackgroundColor: Color {
        return primaryColor.opacity(0.2)
    }
    
    var backgroundGradient: LinearGradient {
        switch self {
        case .critical:
            return LinearGradient(
                colors: [Color.red.opacity(0.9), Color.orange.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .important:
            return LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.yellow.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .contextual:
            return LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.cyan.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var displayDuration: Double {
        switch self {
        case .critical: return 10.0
        case .important: return 8.0
        case .contextual: return 6.0
        }
    }
}

// MARK: - Notification Card Data

struct NewNotificationCardData {
    let message: String
    let icon: String
    let onTap: () -> Void
}
