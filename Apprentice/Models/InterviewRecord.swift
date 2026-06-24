//
//  InterviewRecord.swift
//  Apprentice
//
//  Layer 1 (Models) — one customer-discovery interview, captured after each call.
//  The ONLY hand-entered data in the Discovery module; every War Room chart + the
//  four decision gates are live aggregates of these. Field names + enum raw values
//  are the CONTRACT shared verbatim with the proxy (/discovery) and the web lane —
//  don't rename without changing both sides. (See Discovery_Module_Build_Spec.)
//

import Foundation
import SwiftData

// MARK: - Locked enums (the charts group on these — never free strings)

enum DiscoveryGroup: String, Codable, CaseIterable, Identifiable {
    case parents, genZ, grandparents
    var id: String { rawValue }
    var label: String {
        switch self {
        case .parents: return "Parents"
        case .genZ: return "Gen-Z"
        case .grandparents: return "Grandparents"
        }
    }
}

enum DiscoverySituation: String, Codable, CaseIterable, Identifiable {
    case none, distance, move, newBaby
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .distance: return "Distance"
        case .move: return "Recent move"
        case .newBaby: return "New baby"
        }
    }
}

enum DiscoveryRaised: String, Codable, CaseIterable, Identifiable {
    case unprompted, whenAsked, none
    var id: String { rawValue }
    var label: String {
        switch self {
        case .unprompted: return "Unprompted"
        case .whenAsked: return "When asked"
        case .none: return "Not at all"
        }
    }
}

enum DiscoveryWhatIf: String, Codable, CaseIterable, Identifiable {
    case pulledToOwnLife, polite, flat
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pulledToOwnLife: return "Pulled to own life"
        case .polite: return "Polite"
        case .flat: return "Flat"
        }
    }
}

enum DiscoveryPay: String, Codable, CaseIterable, Identifiable {
    case yes, adjacentTools, no, unknown
    var id: String { rawValue }
    var label: String {
        switch self {
        case .yes: return "Yes"
        case .adjacentTools: return "Adjacent"
        case .no: return "No"
        case .unknown: return "Unknown"
        }
    }
}

enum DiscoveryTheme: String, Codable, CaseIterable, Identifiable {
    case appFatigue, authenticity, noDMs, algorithmFrustration, videoReplies, privacyWorry
    var id: String { rawValue }
    var label: String {
        switch self {
        case .appFatigue: return "App fatigue"
        case .authenticity: return "Authenticity"
        case .noDMs: return "No DMs"
        case .algorithmFrustration: return "Algorithm frustration"
        case .videoReplies: return "Video replies"
        case .privacyWorry: return "Privacy worry"
        }
    }
}

// MARK: - The record

@Model
final class InterviewRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var who: String = ""                              // short interviewee label, e.g. "Photographer"
    var group: DiscoveryGroup = DiscoveryGroup.parents
    var situation: DiscoverySituation = DiscoverySituation.none
    var howTheyShareToday: String = ""
    var frustration: String = ""
    var frustrationRaised: DiscoveryRaised = DiscoveryRaised.none
    var whatItCosts: String = ""
    var workaround: String = ""                       // empty = no workaround (weak signal)
    var quotes: [String] = []                         // verbatim — the gold
    var themeKeys: [String] = []                      // DiscoveryTheme raw values
    var adoptionScore: Int = 5                        // 1–10
    var frustrationScore: Int = 5                     // 1–10 (persona matrix X)
    var whatIfReaction: DiscoveryWhatIf = DiscoveryWhatIf.flat
    var willPay: DiscoveryPay = DiscoveryPay.unknown
    var synced: Bool = false                          // pushed to /discovery yet?

    init() {}

    var themes: [DiscoveryTheme] {
        get { themeKeys.compactMap { DiscoveryTheme(rawValue: $0) } }
        set { themeKeys = newValue.map { $0.rawValue } }
    }

    /// JSON body for the proxy (`POST /discovery { record }`). Keys/enum raw values
    /// match the backend's InterviewRecord contract exactly.
    func payload() -> [String: Any] {
        [
            "id": id.uuidString,
            "date": ISO8601DateFormatter().string(from: date),
            "who": who,
            "group": group.rawValue,
            "situation": situation.rawValue,
            "howTheyShareToday": howTheyShareToday,
            "frustration": frustration,
            "frustrationRaised": frustrationRaised.rawValue,
            "whatItCosts": whatItCosts,
            "workaround": workaround,
            "quotes": quotes,
            "themes": themeKeys,
            "adoptionScore": adoptionScore,
            "frustrationScore": frustrationScore,
            "whatIfReaction": whatIfReaction.rawValue,
            "willPay": willPay.rawValue,
        ]
    }
}
