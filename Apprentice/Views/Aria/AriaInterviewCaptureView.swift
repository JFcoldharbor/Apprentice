//
//  AriaInterviewCaptureView.swift
//  Apprentice
//
//  The capture intake (Discovery_Module_Build_Spec §02) — the same fields every
//  interview, filled after each call. This is the ONLY place discovery data is
//  entered; the War Room charts + decision gates are all derived from it. On save
//  the record persists to SwiftData and syncs to /discovery.
//

import SwiftUI
import SwiftData

struct AriaInterviewCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    private let context = NoteStore.mainContext

    @State private var who = ""
    @State private var group: DiscoveryGroup = .parents
    @State private var situation: DiscoverySituation = .none
    @State private var howTheyShareToday = ""
    @State private var frustration = ""
    @State private var frustrationRaised: DiscoveryRaised = .none
    @State private var whatItCosts = ""
    @State private var workaround = ""
    @State private var adoptionScore = 5.0
    @State private var frustrationScore = 5.0
    @State private var whatIfReaction: DiscoveryWhatIf = .flat
    @State private var willPay: DiscoveryPay = .unknown
    @State private var selectedThemes: Set<DiscoveryTheme> = []
    @State private var quotes: [String] = [""]

    /// Optional pre-fill from a transcript draft (Aria-extracted); the founder
    /// reviews/edits before saving.
    init(draft: DiscoveryDraft? = nil) {
        _who = State(initialValue: draft?.who ?? "")
        _group = State(initialValue: draft?.group ?? .parents)
        _situation = State(initialValue: draft?.situation ?? .none)
        _howTheyShareToday = State(initialValue: draft?.howTheyShareToday ?? "")
        _frustration = State(initialValue: draft?.frustration ?? "")
        _frustrationRaised = State(initialValue: draft?.frustrationRaised ?? .none)
        _whatItCosts = State(initialValue: draft?.whatItCosts ?? "")
        _workaround = State(initialValue: draft?.workaround ?? "")
        _adoptionScore = State(initialValue: Double(draft?.adoptionScore ?? 5))
        _frustrationScore = State(initialValue: Double(draft?.frustrationScore ?? 5))
        _whatIfReaction = State(initialValue: draft?.whatIfReaction ?? .flat)
        _willPay = State(initialValue: draft?.willPay ?? .unknown)
        _selectedThemes = State(initialValue: Set(draft?.themes ?? []))
        let q = draft?.quotes ?? []
        _quotes = State(initialValue: q.isEmpty ? [""] : q)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AriaSheetHeader(title: "Log interview", onClose: { dismiss() })
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        single("Who", text: $who, placeholder: "Role or label, e.g. Photographer")
                        chips("Group", DiscoveryGroup.allCases, selection: $group) { $0.label }
                        chips("Situation", DiscoverySituation.allCases, selection: $situation) { $0.label }

                        multiline("How they share today", text: $howTheyShareToday, placeholder: "Tools, with whom, how often…")
                        multiline("The frustration", text: $frustration, placeholder: "What's broken about how they do it now…")
                        chips("Raised the frustration", DiscoveryRaised.allCases, selection: $frustrationRaised) { $0.label }
                        multiline("What it costs them", text: $whatItCosts, placeholder: "Time, missed moments, money…")
                        multiline("Their workaround", text: $workaround, placeholder: "What they've cobbled together…")

                        slider("Adoption", value: $adoptionScore)
                        slider("Frustration", value: $frustrationScore)
                        chips("What-if reaction", DiscoveryWhatIf.allCases, selection: $whatIfReaction) { $0.label }
                        chips("Will pay?", DiscoveryPay.allCases, selection: $willPay) { $0.label }

                        themesPicker
                        quotesEditor

                        saveButton
                    }
                    .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 44)
                }
            }
            .ariaSheetSurface()
        }
        .tint(Aria.goldBright)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button(action: save) {
            Text("Save interview")
                .font(.inter(15, .semibold)).foregroundColor(Color(red: 0.07, green: 0.05, blue: 0.02))
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(canSave ? Aria.gold : Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!canSave)
        .padding(.top, 6)
    }

    private var canSave: Bool { !who.trimmingCharacters(in: .whitespaces).isEmpty }

    private func save() {
        let rec = InterviewRecord()
        rec.who = who.trimmingCharacters(in: .whitespaces)
        rec.group = group
        rec.situation = situation
        rec.howTheyShareToday = howTheyShareToday
        rec.frustration = frustration
        rec.frustrationRaised = frustrationRaised
        rec.whatItCosts = whatItCosts
        rec.workaround = workaround
        rec.adoptionScore = Int(adoptionScore)
        rec.frustrationScore = Int(frustrationScore)
        rec.whatIfReaction = whatIfReaction
        rec.willPay = willPay
        rec.themes = Array(selectedThemes)
        rec.quotes = quotes.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        context.insert(rec)
        try? context.save()
        DiscoverySync.shared.sync(record: rec)
        dismiss()
    }

    // MARK: - Field builders

    private func single(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AriaSectionLabel(text: label)
            TextField(placeholder, text: text)
                .font(.inter(14)).foregroundColor(Aria.ivory).tint(Aria.gold)
                .padding(13).background(Aria.panel)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    private func multiline(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AriaSectionLabel(text: label)
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder).font(.inter(13)).foregroundColor(Aria.ivoryFaint)
                        .padding(.horizontal, 14).padding(.top, 14)
                }
                TextEditor(text: text)
                    .font(.inter(14)).foregroundColor(Aria.ivory).tint(Aria.gold)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72)
                    .padding(6)
            }
            .background(Aria.panel)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
        }
    }

    private func chips<T: Hashable>(_ label: String, _ options: [T], selection: Binding<T>, _ title: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AriaSectionLabel(text: label)
            FlowChips {
                ForEach(options, id: \.self) { opt in
                    let active = selection.wrappedValue == opt
                    Button { selection.wrappedValue = opt } label: {
                        Text(title(opt)).font(.inter(12.5, active ? .semibold : .regular))
                            .foregroundColor(active ? Color(red: 0.07, green: 0.05, blue: 0.02) : Aria.ivoryDim)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(active ? Aria.gold : Aria.panel)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(active ? .clear : Aria.lineSoft, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func slider(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AriaSectionLabel(text: label)
                Spacer()
                Text("\(Int(value.wrappedValue))/10").font(.inter(13, .semibold)).foregroundColor(Aria.gold)
            }
            Slider(value: value, in: 1...10, step: 1).tint(Aria.gold)
        }
    }

    private var themesPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            AriaSectionLabel(text: "Themes present")
            FlowChips {
                ForEach(DiscoveryTheme.allCases) { theme in
                    let active = selectedThemes.contains(theme)
                    Button {
                        if active { selectedThemes.remove(theme) } else { selectedThemes.insert(theme) }
                    } label: {
                        Text(theme.label).font(.inter(12.5, active ? .semibold : .regular))
                            .foregroundColor(active ? Color(red: 0.07, green: 0.05, blue: 0.02) : Aria.ivoryDim)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(active ? Aria.jade : Aria.panel)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(active ? .clear : Aria.lineSoft, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quotesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            AriaSectionLabel(text: "Exact quotes (verbatim — the gold)")
            ForEach(quotes.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    TextField("\u{201C}…\u{201D}", text: Binding(
                        get: { quotes.indices.contains(i) ? quotes[i] : "" },
                        set: { if quotes.indices.contains(i) { quotes[i] = $0 } }))
                        .font(.inter(13.5)).foregroundColor(Aria.ivory).tint(Aria.gold)
                        .padding(11).background(Aria.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
                    if quotes.count > 1 {
                        Button { quotes.remove(at: i) } label: {
                            Image(systemName: "minus.circle").font(.system(size: 18)).foregroundColor(Aria.rose)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Button { quotes.append("") } label: {
                Label("Add quote", systemImage: "plus").font(.inter(13)).foregroundColor(Aria.gold)
            }.buttonStyle(.plain)
        }
    }
}

/// Simple wrapping row of chips.
private struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        // A lazy wrap via fixed-size HStacks would be ideal; SwiftUI's native
        // wrapping isn't available pre-iOS 16 Layout, so use a simple wrapping
        // container.
        WrapHStack { content }
    }
}

/// Minimal flow layout (wraps chips to the next line).
private struct WrapHStack<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        FlowLayout(spacing: 8) { content }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.minX + maxWidth, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
