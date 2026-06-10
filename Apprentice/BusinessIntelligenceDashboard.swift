//
//  BusinessIntelligenceDashboard.swift
//  Apprentice
//
//  Layer 8: Views - Business Intelligence Dashboard
//

import SwiftUI

struct BusinessIntelligenceDashboard: View {
    @StateObject private var sessionManager = SessionManager.shared
    @StateObject private var profileManager = FounderProfileManager.shared
    
    private var sessionsThisWeek: Int {
        sessionManager.sessions.filter { session in
            Calendar.current.isDate(session.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    quickStatsSection
                    insightsSection
                    Spacer()
                }
            }
            .background(Color.black)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Business Intelligence")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("Analytics")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal)
    }
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            
            StatCard(
                title: "Total Sessions",
                value: "\(sessionManager.sessions.count)",
                icon: "list.bullet.rectangle",
                color: .blue
            )
            
            StatCard(
                title: "This Week",
                value: "\(sessionsThisWeek)",
                icon: "calendar.badge.plus",
                color: .green
            )
            
            if let profile = profileManager.founderProfile {
                StatCard(
                    title: "Business Stage",
                    value: profile.businessStage.rawValue,
                    icon: "building.2",
                    color: .orange
                )
                
                StatCard(
                    title: "Industry",
                    value: profile.industry,
                    icon: "briefcase",
                    color: .purple
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Insights")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                InsightRow(
                    title: "Meeting Frequency Up 25%",
                    description: "Team meetings have increased this quarter",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
                
                InsightRow(
                    title: "Action Items Completion: 78%",
                    description: "Above average completion rate",
                    icon: "checkmark.circle",
                    color: .blue
                )
                
                InsightRow(
                    title: "Focus Area: Product Development",
                    description: "Most discussed topic this month",
                    icon: "gear",
                    color: .orange
                )
            }
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InsightRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
