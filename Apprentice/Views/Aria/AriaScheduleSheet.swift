//
//  AriaScheduleSheet.swift
//  Apprentice
//
//  Manually stage an upcoming session — type, date/time, and the people involved
//  (checked off from a roster that remembers who you meet with). Saving stages it
//  in the Sessions "Upcoming" list (and the shared web list), ready to start.
//

import SwiftUI

struct AriaScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: NoteType = .oneOnOne
    @State private var date: Date = AriaScheduleSheet.defaultDate()
    @State private var selected: Set<String> = []
    @State private var roster: [String] = []
    @State private var newName = ""

    /// The meeting types worth staging ahead of time.
    private let types: [NoteType] = [.oneOnOne, .clientCall, .teamMeeting, .boardMeeting, .strategySession, .general]

    var body: some View {
        VStack(spacing: 0) {
            AriaSheetHeader(title: "Schedule", onClose: { dismiss() })
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    typeBlock
                    titleBlock
                    whenBlock
                    attendeeBlock
                    saveButton
                }
                .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 40)
            }
        }
        .ariaSheetSurface()
        .onAppear { roster = AttendeeRoster.remembered() }
    }

    // MARK: Type

    private var typeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "Type")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(types) { t in
                        let on = t == type
                        HStack(spacing: 7) {
                            Image(systemName: t.iconName).font(.system(size: 12.5))
                            Text(t.displayName).font(.inter(12.5, .medium))
                        }
                        .foregroundColor(on ? Color(red: 0.1, green: 0.07, blue: 0.02) : Aria.ivoryDim)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(on ? Aria.gold : .clear)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(on ? Aria.gold : Aria.lineSoft, lineWidth: 1))
                        .onTapGesture { type = t }
                    }
                }
            }
        }
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "Title")
            TextField(placeholderTitle, text: $title)
                .font(.inter(15)).foregroundColor(Aria.ivory).tint(Aria.gold)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    // MARK: When

    private var whenBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            AriaSectionLabel(text: "When")
            DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Aria.gold)
                .colorScheme(.dark)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    // MARK: Attendees

    private var attendeeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AriaSectionLabel(text: "Who's involved")
                Spacer()
                if !selected.isEmpty {
                    Text("\(selected.count) selected").font(.ariaMono(10.5)).foregroundColor(Aria.gold)
                }
            }

            if roster.isEmpty && selected.isEmpty {
                Text("Add the people in this meeting — they'll be remembered for next time.")
                    .font(.inter(12.5)).foregroundColor(Aria.ivoryFaint)
            } else {
                FlowChips(names: rosterDisplay, selected: selected) { name in
                    if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus").font(.system(size: 15)).foregroundColor(Aria.ivoryFaint)
                TextField("Add someone…", text: $newName)
                    .font(.inter(14)).foregroundColor(Aria.ivory).tint(Aria.gold)
                    .submitLabel(.done)
                    .onSubmit(addName)
                if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: addName) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundColor(Aria.gold)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Aria.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    /// Roster names plus any just-added selections not yet in the roster.
    private var rosterDisplay: [String] {
        let extra = selected.subtracting(roster)
        return roster + extra.sorted()
    }

    private func addName() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selected.insert(trimmed)
        if !roster.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            roster.insert(trimmed, at: 0)
        }
        newName = ""
    }

    // MARK: Save

    private var saveButton: some View {
        Button(action: save) {
            Text("Stage session")
                .font(.inter(15, .semibold))
                .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RadialGradient(colors: [Aria.goldBright, Aria.gold], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 220))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .shadow(color: Aria.gold.opacity(0.5), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func save() {
        let attendees = rosterDisplay.filter { selected.contains($0) }
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholderTitle : title
        SessionManager.shared.schedule(title: finalTitle, type: type, attendees: attendees, scheduledFor: date)
        dismiss()
    }

    /// Smart default title, e.g. "1:1 with Mark Feinberg".
    private var placeholderTitle: String {
        let names = rosterDisplay.filter { selected.contains($0) }
        guard !names.isEmpty else { return type.displayName }
        let who = names.count <= 2 ? names.joined(separator: " & ") : "\(names[0]) +\(names.count - 1)"
        return "\(type.displayName) with \(who)"
    }

    private static func defaultDate() -> Date {
        let cal = Calendar.current
        let next = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        // Round to the next :00 / :30.
        let minute = cal.component(.minute, from: next)
        let rounded = cal.date(bySetting: .minute, value: minute < 30 ? 30 : 0, of: next) ?? next
        return rounded
    }
}

// MARK: - Wrapping chip row

private struct FlowChips: View {
    let names: [String]
    let selected: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        // Simple wrapping layout via a lazy grid of flexible columns.
        let columns = [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(names, id: \.self) { name in
                let on = selected.contains(name)
                HStack(spacing: 6) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundColor(on ? Aria.goldBright : Aria.ivoryFaint)
                    Text(name).font(.inter(13, .medium)).foregroundColor(on ? Aria.ivory : Aria.ivoryDim)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(on ? Aria.gold.opacity(0.12) : Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? Aria.gold.opacity(0.5) : Aria.lineSoft, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { onTap(name) }
            }
        }
    }
}
