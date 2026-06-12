//
//  AriaContextSheet.swift
//  Apprentice
//
//  Recording-context picker, Aria-styled. The context enum lives here (top
//  level) so both the Record screen and this sheet share it.
//

import SwiftUI

enum AriaRecordContext: String, CaseIterable, Identifiable {
    case personal = "Personal Meeting"
    case team = "Team Meeting"
    case board = "Board Meeting"
    case client = "Client Call"
    case oneOnOne = "1:1 Conversation"
    case content = "Content Analysis"
    var id: String { rawValue }

    var blurb: String {
        switch self {
        case .personal: return "You're leading — Aria tunes its analysis to your outcomes"
        case .team: return "Collaborative team discussion and planning"
        case .board: return "Strategic updates and decisions for the board"
        case .client: return "Capture the client's concerns and objectives"
        case .oneOnOne: return "A two-way conversation with mutual engagement"
        case .content: return "Analyzing content for key insights and summaries"
        }
    }
    var glyph: String {
        switch self {
        case .personal: return "person.crop.circle"
        case .team: return "person.3"
        case .board: return "building.columns"
        case .client: return "phone"
        case .oneOnOne: return "person.2"
        case .content: return "doc.text.magnifyingglass"
        }
    }
    var noteType: NoteType {
        switch self {
        case .personal: return .strategySession
        case .team: return .teamMeeting
        case .board: return .boardMeeting
        case .client: return .clientCall
        case .oneOnOne: return .oneOnOne
        case .content: return .general
        }
    }
}

struct AriaContextSheet: View {
    @Binding var selected: AriaRecordContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AriaSheetHeader(title: "Context", onClose: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(AriaRecordContext.allCases) { c in
                        row(c)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 24)
            }
        }
        .ariaSheetSurface()
    }

    private func row(_ c: AriaRecordContext) -> some View {
        let on = c == selected
        return Button {
            selected = c
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: c.glyph)
                    .font(.system(size: 20))
                    .foregroundColor(on ? Color(red: 0.1, green: 0.07, blue: 0.02) : Aria.goldBright)
                    .frame(width: 46, height: 46)
                    .background(
                        Group {
                            if on {
                                RadialGradient(colors: [Aria.goldBright, Aria.gold], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 46)
                            } else {
                                Aria.gold.opacity(0.12)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.rawValue).font(.fraunces(17, .medium)).foregroundColor(Aria.ivory)
                    Text(c.blurb).font(.inter(12.5)).foregroundColor(Aria.ivoryDim)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if on {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(Aria.goldBright)
                }
            }
            .padding(16)
            .background(Aria.panel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? Aria.gold.opacity(0.5) : Aria.lineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
