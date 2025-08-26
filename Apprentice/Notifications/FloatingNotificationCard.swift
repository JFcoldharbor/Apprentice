//
//  FloatingNotificationCard.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  FloatingNotificationCard.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Clean floating notification card following development rules
//  Modular design with proper separation of concerns
//

import SwiftUI

struct FloatingNotificationCard: View {
    let data: NotificationCardData
    let tier: NotificationTier
    
    @State private var offset: CGFloat = UIScreen.main.bounds.width + 100
    @State private var isVisible = false
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: data.onTap) {
            HStack(spacing: 12) {
                iconSection
                messageSection
                Spacer()
                chevronSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: 320, height: tier.cardHeight)
            .background(tier.backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: tier.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: tier.cornerRadius)
                    .stroke(tier.primaryColor, lineWidth: tier.strokeWidth)
            )
            .shadow(color: tier.shadowColor, radius: tier.shadowRadius, x: 0, y: 4)
            .offset(x: offset)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear(perform: startAnimation)
    }
    
    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(tier.iconBackgroundColor)
                .frame(width: tier.iconSize, height: tier.iconSize)
            
            Image(systemName: data.icon)
                .font(.system(size: tier.iconFontSize, weight: tier.iconWeight))
                .foregroundColor(.white)
        }
        .scaleEffect(isPulsing && tier == .critical ? 1.1 : 1.0)
        .animation(
            tier == .critical ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .none,
            value: isPulsing
        )
    }
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tier.urgencyLabel)
                    .font(tier.labelFont)
                    .foregroundColor(tier.labelColor)
                
                Spacer()
                
                Circle()
                    .fill(tier.primaryColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(data.message)
                .font(tier.messageFont)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
    
    private var chevronSection: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
    }
    
    private func startAnimation() {
        if tier == .critical {
            isPulsing = true
        }
        
        withAnimation(.easeOut(duration: 0.6)) {
            offset = 50
            isVisible = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + tier.centerPauseDuration) {
            withAnimation(.linear(duration: tier.floatDuration)) {
                offset = -420
            }
            
            let fadeStartTime = tier.floatDuration * 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeStartTime) {
                withAnimation(.easeIn(duration: tier.floatDuration * 0.2)) {
                    isVisible = false
                }
            }
        }
    }
}

extension NotificationTier {
    var floatDuration: Double {
        switch self {
        case .critical: return 8.0
        case .important: return 6.0
        case .contextual: return 3.5
        }
    }
    
    var centerPauseDuration: Double {
        switch self {
        case .critical: return 3.5
        case .important: return 2.5
        case .contextual: return 1.5
        }
    }
    
    var MyprimaryColor: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .contextual: return .blue
        }
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
    
    var urgencyLabel: String {
        switch self {
        case .critical: return "URGENT"
        case .important: return "IMPORTANT"
        case .contextual: return "INFO"
        }
    }
    
    var labelColor: Color {
        switch self {
        case .critical: return .red.opacity(0.9)
        case .important: return .orange.opacity(0.9)
        case .contextual: return .blue.opacity(0.9)
        }
    }
    
    var labelFont: Font {
        switch self {
        case .critical: return .caption.weight(.bold)
        case .important: return .caption.weight(.semibold)
        case .contextual: return .caption.weight(.medium)
        }
    }
    
    var messageFont: Font {
        switch self {
        case .critical: return .subheadline.weight(.semibold)
        case .important: return .subheadline.weight(.medium)
        case .contextual: return .body.weight(.regular)
        }
    }
    
    var cardHeight: CGFloat {
        switch self {
        case .critical: return 80
        case .important: return 75
        case .contextual: return 70
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .critical: return 16
        case .important: return 12
        case .contextual: return 8
        }
    }
    
    var strokeWidth: CGFloat {
        switch self {
        case .critical: return 2
        case .important: return 1.5
        case .contextual: return 1
        }
    }
    
    var shadowRadius: CGFloat {
        switch self {
        case .critical: return 8
        case .important: return 6
        case .contextual: return 4
        }
    }
    
    var shadowColor: Color {
        switch self {
        case .critical: return .red.opacity(0.4)
        case .important: return .orange.opacity(0.3)
        case .contextual: return .blue.opacity(0.2)
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
        switch self {
        case .critical: return .red.opacity(0.2)
        case .important: return .orange.opacity(0.2)
        case .contextual: return .blue.opacity(0.2)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 100) {
            FloatingNotificationCard(
                data: NotificationCardData(
                    message: "Board meeting in 1 hour",
                    icon: "exclamationmark.triangle.fill"
                ) {
                    print("Critical card tapped")
                },
                tier: .critical
            )
            
            FloatingNotificationCard(
                data: NotificationCardData(
                    message: "Team standup in 15 minutes",
                    icon: "calendar.badge.clock"
                ) {
                    print("Important card tapped")
                },
                tier: .important
            )
            
            FloatingNotificationCard(
                data: NotificationCardData(
                    message: "Perfect weather for office",
                    icon: "sun.max.fill"
                ) {
                    print("Contextual card tapped")
                },
                tier: .contextual
            )
        }
    }
}