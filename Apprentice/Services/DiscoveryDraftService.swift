//
//  DiscoveryDraftService.swift
//  Apprentice
//
//  Layer 3 (Services) — drafts a customer-discovery InterviewRecord from a
//  recorded interview's transcript (Claude via AIClient, constrained schema), so
//  the founder reviews/edits in the capture form instead of typing it cold. This
//  is the "it just takes the information and graphs it" bridge: he picks which
//  recording is an interview; Aria fills the fields; he confirms.
//

import Foundation

/// A pre-filled capture draft. Identifiable so it can drive `.sheet(item:)`.
struct DiscoveryDraft: Identifiable {
    let id = UUID()
    var who: String
    var group: DiscoveryGroup
    var situation: DiscoverySituation
    var howTheyShareToday: String
    var frustration: String
    var frustrationRaised: DiscoveryRaised
    var whatItCosts: String
    var workaround: String
    var adoptionScore: Int
    var frustrationScore: Int
    var whatIfReaction: DiscoveryWhatIf
    var willPay: DiscoveryPay
    var themes: [DiscoveryTheme]
    var quotes: [String]
}

@MainActor
enum DiscoveryDraftService {

    private static let persona = """
    You extract a single structured customer-discovery interview record from the \
    transcript of a customer conversation. Use ONLY what the transcript supports — \
    never invent numbers, quotes, or sentiment. When a field isn't evident, use the \
    neutral default (situation "none", frustrationRaised "none", willPay "unknown", \
    whatIfReaction "flat", empty strings, scores 5, empty arrays).

    Guidance:
    - who: a short role/label for the interviewee (e.g. "Photographer", "New parent"), \
      inferred from the transcript; "Interviewee" if unclear.
    - frustrationRaised: "unprompted" only if they raised the core frustration before \
      you asked about it.
    - quotes: 1–4 VERBATIM phrases, copied exactly — the exact words are the asset.
    - themes: tag only themes clearly present.
    - adoptionScore / frustrationScore: 1–10, your honest read from the transcript.
    """

    private struct Result: Decodable {
        let who: String
        let group: String
        let situation: String
        let howTheyShareToday: String
        let frustration: String
        let frustrationRaised: String
        let whatItCosts: String
        let workaround: String
        let adoptionScore: Int
        let frustrationScore: Int
        let whatIfReaction: String
        let willPay: String
        let themes: [String]
        let quotes: [String]
    }

    private static var schema: [String: Any] {
        let str: [String: Any] = ["type": "string"]
        let score: [String: Any] = ["type": "integer", "minimum": 1, "maximum": 10]
        return [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "who": str,
                "group": ["type": "string", "enum": ["parents", "genZ", "grandparents"]],
                "situation": ["type": "string", "enum": ["distance", "move", "newBaby", "none"]],
                "howTheyShareToday": str,
                "frustration": str,
                "frustrationRaised": ["type": "string", "enum": ["unprompted", "whenAsked", "none"]],
                "whatItCosts": str,
                "workaround": str,
                "adoptionScore": score,
                "frustrationScore": score,
                "whatIfReaction": ["type": "string", "enum": ["pulledToOwnLife", "polite", "flat"]],
                "willPay": ["type": "string", "enum": ["yes", "adjacentTools", "no", "unknown"]],
                "themes": ["type": "array", "items": ["type": "string", "enum": ["appFatigue", "authenticity", "noDMs", "algorithmFrustration", "videoReplies", "privacyWorry"]]],
                "quotes": ["type": "array", "items": str],
            ],
            "required": [
                "who", "group", "situation", "howTheyShareToday", "frustration", "frustrationRaised",
                "whatItCosts", "workaround", "adoptionScore", "frustrationScore", "whatIfReaction",
                "willPay", "themes", "quotes",
            ],
        ]
    }

    static func draft(transcript: String, summary: String) async throws -> DiscoveryDraft {
        var input = "Transcript:\n\n\(transcript)"
        if !summary.trimmingCharacters(in: .whitespaces).isEmpty { input += "\n\nExisting summary:\n\(summary)" }
        let r = try await AIClient.shared.chatJSON(
            Result.self,
            system: persona,
            messages: [AIChatMessage(role: "user", content: input)],
            schema: schema,
            tier: .standard)
        return DiscoveryDraft(
            who: r.who,
            group: DiscoveryGroup(rawValue: r.group) ?? .parents,
            situation: DiscoverySituation(rawValue: r.situation) ?? .none,
            howTheyShareToday: r.howTheyShareToday,
            frustration: r.frustration,
            frustrationRaised: DiscoveryRaised(rawValue: r.frustrationRaised) ?? .none,
            whatItCosts: r.whatItCosts,
            workaround: r.workaround,
            adoptionScore: min(10, max(1, r.adoptionScore)),
            frustrationScore: min(10, max(1, r.frustrationScore)),
            whatIfReaction: DiscoveryWhatIf(rawValue: r.whatIfReaction) ?? .flat,
            willPay: DiscoveryPay(rawValue: r.willPay) ?? .unknown,
            themes: r.themes.compactMap { DiscoveryTheme(rawValue: $0) },
            quotes: r.quotes.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}
