//
//  AriaSessionsScreen.swift
//  Apprentice
//
//  Redesigned Sessions archive (aria-redesign.html #v-sessions), wired to the
//  SessionManager SwiftData projection.
//

import SwiftUI

struct AriaSessionsScreen: View {
    @Binding var selectedTab: Int
    @StateObject private var manager = SessionManager.shared
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var selected: ExecutiveSession?
    @State private var pendingDelete: ExecutiveSession?
    @State private var pendingCancel: ScheduledSession?
    @State private var showingSchedule = false
    @State private var connectionCount = 0

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", team = "Team", client = "Client", board = "Board", week = "This week"
        var id: String { rawValue }
    }

    private var filtered: [ExecutiveSession] {
        var list = search.isEmpty ? manager.sessions : manager.searchSessions(query: search)
        switch filter {
        case .all: break
        case .team: list = list.filter { $0.type == .teamMeeting }
        case .client: list = list.filter { $0.type == .clientCall }
        case .board: list = list.filter { $0.type == .boardMeeting }
        case .week:
            let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            list = list.filter { $0.date >= start }
        }
        return list
    }

    private var thisWeekCount: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return manager.sessions.filter { $0.date >= start }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AriaEyebrow(text: "Archive").padding(.top, 14).padding(.bottom, 10)
                AriaTitle(plain: "Your ", em: "sessions")

                HStack(alignment: .firstTextBaseline) {
                    AriaSub(text: "Every meeting, transcribed and connected")
                    Spacer()
                    (Text("\(manager.sessions.count)").font(.fraunces(34)).foregroundColor(Aria.goldBright)
                     + Text("  total").font(.inter(13)).foregroundColor(Aria.ivoryDim))
                }
                .padding(.top, 12).padding(.bottom, 22)

                metrics.padding(.bottom, 22)

                if search.isEmpty {
                    upcomingSection.padding(.bottom, 22)
                }

                searchBar.padding(.bottom, 16)
                filters.padding(.bottom, 18)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(filtered, id: \.id) { s in
                        SessionCard(session: s)
                            .onTapGesture { selected = s }
                            .contextMenu {
                                Button(role: .destructive) { pendingDelete = s } label: {
                                    Label("Delete session", systemImage: "trash")
                                }
                            }
                            .padding(.bottom, 12)
                    }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 130)
        }
        .sheet(item: $selected) { s in
            AriaSessionDetailSheet(session: s, onDelete: { delete(s) })
        }
        .sheet(isPresented: $showingSchedule) {
            AriaScheduleSheet().presentationDetents([.large])
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { if let s = pendingDelete { delete(s) }; pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete.map { "“\($0.title)” and its audio will be removed everywhere, including Aria’s memory." } ?? "")
        }
        .confirmationDialog(
            "Cancel this scheduled session?",
            isPresented: Binding(get: { pendingCancel != nil }, set: { if !$0 { pendingCancel = nil } }),
            titleVisibility: .visible
        ) {
            Button("Cancel session", role: .destructive) { if let s = pendingCancel { manager.cancelScheduled(id: s.id) }; pendingCancel = nil }
            Button("Keep", role: .cancel) { pendingCancel = nil }
        } message: {
            Text(pendingCancel.map { "Remove “\($0.title)” from your upcoming sessions." } ?? "")
        }
        .onAppear(perform: recompute)
        .task { await manager.syncScheduledFromCloud() }
    }

    // MARK: - Upcoming (pre-staged sessions)

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AriaSectionLabel(text: "Upcoming")
                Spacer()
                Button { showingSchedule = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("Schedule")
                    }
                    .font(.inter(12.5, .medium)).foregroundColor(Aria.gold)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .overlay(Capsule().stroke(Aria.gold.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if manager.scheduled.isEmpty {
                Button { showingSchedule = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus").font(.system(size: 17)).foregroundColor(Aria.goldBright)
                        Text("Stage a client call or 1:1 ahead of time — set who's involved, ready to start.")
                            .font(.inter(12.5)).foregroundColor(Aria.ivoryDim).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Aria.line))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(manager.scheduled) { s in
                    UpcomingCard(session: s, onStart: { start(s) }, onCancel: { pendingCancel = s })
                }
            }
        }
    }

    private func start(_ s: ScheduledSession) {
        if let prefill = manager.startScheduled(id: s.id) {
            RecordingHandoff.shared.prefill = prefill
            selectedTab = 2   // jump to Record; the screen begins recording pre-filled
        }
    }

    private func delete(_ session: ExecutiveSession) {
        manager.deleteSession(session)   // also removes audio + forgets it in Aria's shared memory
        recompute()
    }

    private var metrics: some View {
        HStack(spacing: 9) {
            metric("\(manager.todaysSessions.count)", "Today", live: true)
            metric("\(thisWeekCount)", "This week")
            metric("\(connectionCount)", "Links")
            metric("0", "Patterns")
        }
    }

    private func metric(_ n: String, _ l: String, live: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(n).font(.fraunces(24)).foregroundColor(live ? Aria.goldBright : Aria.ivory)
            Text(l).font(.inter(9.5)).foregroundColor(Aria.ivoryDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundColor(Aria.ivoryFaint)
            TextField("Search by topic, person, or decision…", text: $search)
                .font(.inter(14)).foregroundColor(Aria.ivory)
                .tint(Aria.gold)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { f in
                    let on = filter == f
                    Text(f.rawValue)
                        .font(.inter(12.5, .medium))
                        .foregroundColor(on ? Color(red: 0.1, green: 0.07, blue: 0.02) : Aria.ivoryDim)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(on ? Aria.gold : .clear)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(on ? Aria.gold : Aria.lineSoft, lineWidth: 1))
                        .onTapGesture { filter = f }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.system(size: 26)).foregroundColor(Aria.gold)
            Text(search.isEmpty ? "No sessions yet" : "No matches")
                .font(.fraunces(18, .medium)).foregroundColor(Aria.ivory)
            Text(search.isEmpty ? "Record one from the Record tab and it lands here." : "Try a different search or filter.")
                .font(.inter(13)).foregroundColor(Aria.ivoryFaint).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Aria.line))
    }

    private func recompute() {
        let snap = manager.sessions
        connectionCount = snap.count > 1 ? MemoryConnectionCalculator().analyzeConnections(sessions: snap).count : 0
    }
}

// MARK: - Upcoming card

private struct UpcomingCard: View {
    let session: ScheduledSession
    let onStart: () -> Void
    let onCancel: () -> Void

    private var isCall: Bool { session.type == .clientCall }
    private var railColor: Color { isCall ? Aria.jade : Aria.gold }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(railColor.opacity(0.14)).frame(width: 40, height: 40)
                    Image(systemName: session.type.iconName).font(.system(size: 17)).foregroundColor(isCall ? Aria.jade : Aria.goldBright)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).font(.fraunces(16, .medium)).foregroundColor(Aria.ivory).lineLimit(2)
                    Text(whenText).font(.ariaMono(11.5)).foregroundColor(Aria.gold)
                }
                Spacer(minLength: 0)
            }

            if !session.attendees.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "person.2.fill").font(.system(size: 11)).foregroundColor(Aria.ivoryFaint)
                    Text(session.attendees.joined(separator: ", "))
                        .font(.inter(12)).foregroundColor(Aria.ivoryDim).lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                Button(action: onStart) {
                    HStack(spacing: 7) {
                        Image(systemName: "mic.fill").font(.system(size: 13))
                        Text("Start").font(.inter(13.5, .semibold))
                    }
                    .foregroundColor(Color(red: 0.1, green: 0.07, blue: 0.02))
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(RadialGradient(colors: [Aria.goldBright, Aria.gold], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 80))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onCancel) {
                    Text("Cancel").font(.inter(13)).foregroundColor(Aria.ivoryDim)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .overlay(Capsule().stroke(Aria.lineSoft, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(16)
        .background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(railColor.opacity(0.3), lineWidth: 1))
        .overlay(alignment: .leading) {
            Rectangle().fill(railColor.opacity(0.6)).frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .contextMenu {
            Button(role: .destructive, action: onCancel) { Label("Cancel session", systemImage: "trash") }
        }
    }

    private var whenText: String {
        let cal = Calendar.current
        let time = session.scheduledFor.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(session.scheduledFor) { return "Today · \(time)" }
        if cal.isDateInTomorrow(session.scheduledFor) { return "Tomorrow · \(time)" }
        let day = session.scheduledFor.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(time)"
    }
}

// MARK: - Session card

private struct SessionCard: View {
    let session: ExecutiveSession

    private var isCall: Bool { session.type == .clientCall }
    private var railColor: Color { isCall ? Aria.jade : Aria.gold }
    private var icon: String {
        switch session.type {
        case .clientCall: return "phone"
        case .teamMeeting, .allHands: return "person.3"
        case .oneOnOne: return "person.2"
        case .boardMeeting: return "building.columns"
        default: return "person.crop.circle"
        }
    }
    private var actionCount: Int { session.notes.reduce(0) { $0 + $1.actionItems.count } }

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [railColor.opacity(0.16), railColor.opacity(0.04)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(isCall ? Aria.jade : Aria.goldBright)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    Text(session.title).font(.fraunces(16.5, .medium)).foregroundColor(Aria.ivory)
                        .lineLimit(2)
                    Spacer()
                    Circle().fill(railColor).frame(width: 7, height: 7).shadow(color: railColor, radius: 4).padding(.top, 6)
                }
                HStack(spacing: 8) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    Text("· \(session.type.rawValue)").foregroundColor(Aria.ivoryFaint)
                    Text("· \(durationText)")
                }
                .font(.ariaMono(11.5)).foregroundColor(Aria.ivoryDim)

                if actionCount > 0 || !session.tags.isEmpty {
                    HStack(spacing: 8) {
                        if actionCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "checklist").font(.system(size: 11))
                                Text("\(actionCount) action\(actionCount == 1 ? "" : "s")").font(.inter(11, .medium))
                            }
                            .foregroundColor(Aria.gold)
                        }
                        Spacer()
                    }
                    .padding(.top, 5)
                    .overlay(alignment: .top) { Rectangle().fill(Aria.lineSoft).frame(height: 1).offset(y: -6) }
                }
            }
        }
        .padding(18)
        .background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        .overlay(alignment: .leading) {
            Rectangle().fill(railColor.opacity(0.5)).frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var durationText: String {
        let total = Int(session.duration)
        if total < 60 { return "\(total)s" }
        return "\(total / 60)m \(String(format: "%02d", total % 60))s"
    }
}
