//
//  AriaDiscoveryScreen.swift
//  Apprentice
//
//  The logged customer-discovery interviews (SwiftData @Query). Tap + to capture
//  a new one; each save syncs to /discovery and feeds the War Room Discovery lane.
//

import SwiftUI
import SwiftData

struct AriaDiscoveryScreen: View {
    @Query(sort: \InterviewRecord.date, order: .reverse) private var records: [InterviewRecord]
    @State private var capturing = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if records.isEmpty {
                    empty
                } else {
                    ForEach(records) { row($0) }
                }
            }
            .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
        }
        .ariaSheetSurface()
        .navigationTitle("Customer Discovery")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { capturing = true } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold)).foregroundColor(Aria.goldBright)
                }
            }
        }
        .sheet(isPresented: $capturing) { AriaInterviewCaptureView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(records.count) interview\(records.count == 1 ? "" : "s") logged")
                .font(.inter(13)).foregroundColor(Aria.ivoryDim)
            Text("Each one feeds the War Room's Discovery charts and decision gates.")
                .font(.inter(12)).foregroundColor(Aria.ivoryFaint)
        }
        .padding(.bottom, 4)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.line.dotted.person").font(.system(size: 30)).foregroundColor(Aria.ivoryFaint)
            Text("No interviews yet").font(.inter(15, .semibold)).foregroundColor(Aria.ivory)
            Text("Tap + after a customer conversation to log it. The charts build themselves from here.")
                .font(.inter(12.5)).foregroundColor(Aria.ivoryDim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50).padding(.horizontal, 20)
    }

    private func row(_ r: InterviewRecord) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(r.who.isEmpty ? "Interviewee" : r.who).font(.inter(15, .semibold)).foregroundColor(Aria.ivory)
                    Text(r.group.label.uppercased()).font(.inter(9.5, .semibold)).foregroundColor(Aria.ivoryFaint)
                }
                Text(subtitle(r)).font(.inter(12)).foregroundColor(Aria.ivoryDim).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.inter(10.5)).foregroundColor(Aria.ivoryFaint)
                Circle().fill(r.synced ? Aria.jade : Aria.ivoryFaint).frame(width: 6, height: 6)
            }
        }
        .padding(16).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private func subtitle(_ r: InterviewRecord) -> String {
        var bits: [String] = ["Adopt \(r.adoptionScore) · Frust \(r.frustrationScore)"]
        if !r.themes.isEmpty { bits.append(r.themes.prefix(2).map { $0.label }.joined(separator: ", ")) }
        bits.append(r.willPay.label.lowercased() == "unknown" ? "pay: ?" : "pay: \(r.willPay.label.lowercased())")
        return bits.joined(separator: "  ·  ")
    }
}
