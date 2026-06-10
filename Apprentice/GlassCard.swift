//
//  GlassCard.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  GlassCard.swift
//  Stitch Executive AI
//
//  Reusable UI Component - Glassmorphism card for consistent design
//  Used throughout all views for professional executive interface
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.15),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Glass Card Variants

struct GlassCardHighlight<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.blue.opacity(0.3), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GlassCardAction<Content: View>: View {
    let content: Content
    let action: () -> Void
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.05))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(GlassCardButtonStyle())
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Glass Card Button Style

struct GlassCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension View {
    func glassCard() -> some View {
        GlassCard {
            self
        }
    }
    
    func glassCardHighlight() -> some View {
        GlassCardHighlight {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.05, green: 0.08, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text("Executive Profile")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    Text("This is a glass card component used throughout the Stitch Executive AI interface for consistent glassmorphism design.")
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(20)
            }
            
            GlassCardAction(action: {}) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Actionable Glass Card")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(16)
            }
        }
        .padding()
    }
}