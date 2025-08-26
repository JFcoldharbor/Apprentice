//
//  FloatingNotificationOverlay.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  FloatingNotificationOverlay.swift
//  My CeO
//
//  Created by James Garmon on 8/21/25.
//


//
//  FloatingNotificationOverlay.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Floating notification system extracted from ContentView
//  Following development rules for modular components
//

import SwiftUI

struct FloatingNotificationOverlay: View {
    @ObservedObject var notificationManager: FloatingNotificationManager
    let sessionManager: SessionManager
    let profileManager: FounderProfileManager
    let memoryInsights: [MemoryInsight]
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                ForEach(notificationManager.activeNotifications, id: \.id) { notification in
                    CompactFloatingCard(data: notification.data, tier: notification.tier)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .allowsHitTesting(true)
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct CompactFloatingCard: View {
    let data: NotificationCardData
    let tier: NotificationTier
    
    @State private var offset: CGFloat = UIScreen.main.bounds.width + 100
    @State private var isVisible = false
    
    var body: some View {
        Button(action: data.onTap) {
            HStack(spacing: 8) {
                Image(systemName: data.icon)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .frame(width: 20)
                
                Text(data.message)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(height: 32)
            .background(tier.compactBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: tier.primaryColor.opacity(0.3), radius: 4)
            .offset(x: offset)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            startCompactAnimation()
        }
    }
    
    private func startCompactAnimation() {
        withAnimation(.easeOut(duration: 0.4)) {
            offset = 0
            isVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.linear(duration: 4.0)) {
                offset = -UIScreen.main.bounds.width - 100
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeIn(duration: 0.5)) {
                    isVisible = false
                }
            }
        }
    }
}

extension NotificationTier {
    var compactBackgroundColor: Color {
        switch self {
        case .critical: return .red.opacity(0.8)
        case .important: return .orange.opacity(0.8)
        case .contextual: return .blue.opacity(0.8)
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .contextual: return .blue
        }
    }
}

enum NotificationTier {
    case critical
    case important
    case contextual
}

struct NotificationCardData {
    let message: String
    let icon: String
    let onTap: () -> Void
}