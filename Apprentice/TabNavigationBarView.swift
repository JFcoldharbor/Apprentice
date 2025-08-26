//
//  TabNavigationBarView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Modern glassmorphism tab bar with Instagram/TikTok styling
//  Updated for full screen immersion with glow effects
//

import SwiftUI

struct TabNavigationBarView: View {
    @Binding var selectedTab: Int
    let memoryInsights: [MemoryInsight]
    
    private let tabs = [
        (title: "Home", icon: "house.fill"),
        (title: "Sessions", icon: "list.bullet.rectangle"),
        (title: "Record", icon: "mic.circle.fill"),
        (title: "Intelligence", icon: "brain.head.profile"),
        (title: "Memory", icon: "brain.filled.head.profile"),
        (title: "Documents", icon: "folder.fill")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Modern glassmorphism tab bar
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = index
                            }
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    // Glow effect behind selected tab
                                    if selectedTab == index {
                                        Circle()
                                            .fill(tabColor(for: index))
                                            .frame(width: 45, height: 45)
                                            .blur(radius: 12)
                                            .opacity(0.8)
                                            .scaleEffect(1.2)
                                    }
                                    
                                    // Icon background with subtle fill
                                    Circle()
                                        .fill(selectedTab == index ? tabColor(for: index).opacity(0.15) : Color.clear)
                                        .frame(width: 36, height: 36)
                                    
                                    // Icon
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 20, weight: selectedTab == index ? .semibold : .medium))
                                        .foregroundColor(selectedTab == index ? tabColor(for: index) : .black.opacity(0.5))
                                    
                                    // Memory badge
                                    if index == 4 && !memoryInsights.isEmpty {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 10, height: 10)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: 2)
                                            )
                                            .offset(x: 14, y: -14)
                                    }
                                }
                                
                                // Tab title with dynamic visibility
                                Text(tab.title)
                                    .font(.system(size: 11, weight: selectedTab == index ? .semibold : .medium))
                                    .foregroundColor(selectedTab == index ? tabColor(for: index) : .black.opacity(0.5))
                                    .opacity(selectedTab == index ? 1.0 : 0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .scaleEffect(selectedTab == index ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    // Instagram/TikTok style glassmorphism
                    ZStack {
                        // Base blur background
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.ultraThinMaterial)
                        
                        // Subtle gradient overlay
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Border highlight
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                    .shadow(
                        color: .black.opacity(0.05),
                        radius: 5,
                        x: 0,
                        y: 2
                    )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
            }
        }
    }
    
    private func tabColor(for index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1: return .green
        case 2: return .red
        case 3: return .purple
        case 4: return .yellow
        case 5: return .orange
        default: return .blue
        }
    }
}

// MARK: - Alternative Floating Tab Bar (More TikTok Style)

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    let memoryInsights: [MemoryInsight]
    
    private let tabs = [
        (title: "Home", icon: "house.fill"),
        (title: "Sessions", icon: "list.bullet.rectangle"),
        (title: "Record", icon: "mic.circle.fill"),
        (title: "Intelligence", icon: "brain.head.profile"),
        (title: "Memory", icon: "brain.filled.head.profile"),
        (title: "Documents", icon: "folder.fill")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                selectedTab = index
                            }
                        }) {
                            ZStack {
                                // Individual tab background
                                if selectedTab == index {
                                    Capsule()
                                        .fill(tabColor(for: index))
                                        .frame(width: 50, height: 50)
                                        .blur(radius: 8)
                                        .opacity(0.6)
                                }
                                
                                Capsule()
                                    .fill(selectedTab == index ? tabColor(for: index).opacity(0.2) : .white.opacity(0.1))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Capsule()
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                                
                                Image(systemName: tab.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(selectedTab == index ? tabColor(for: index) : .black.opacity(0.6))
                                
                                // Memory badge
                                if index == 4 && !memoryInsights.isEmpty {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 15, y: -15)
                                }
                            }
                            .scaleEffect(selectedTab == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selectedTab)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                )
                .padding(.horizontal, 40)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
            }
        }
    }
    
    private func tabColor(for index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1: return .green
        case 2: return .red
        case 3: return .purple
        case 4: return .yellow
        case 5: return .orange
        default: return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.white.ignoresSafeArea()
        
        TabNavigationBarView(
            selectedTab: .constant(0),
            memoryInsights: []
        )
    }
}
