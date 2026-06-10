//
//  Secrets.swift
//  Apprentice
//
//  Layer 3 (Services) — secure resolution of API credentials.
//  Resolution order: process environment (scheme env var) → git-ignored
//  `Secrets.plist` (bundled at build time) → Info.plist (legacy) → empty.
//  NEVER hardcode a key in tracked source or Info.plist: secrets live ONLY in
//  Secrets.plist, which is git-ignored.
//
//  To configure locally, create `Apprentice/Secrets.plist` (a dictionary):
//    OPENAI_API_KEY      = sk-...
//    PROXY_SHARED_SECRET = <hex>
//  It is auto-bundled by the filesystem-synchronized group and ignored by git.
//

import Foundation

enum Secrets {

    /// Real keys, loaded once from the git-ignored bundled Secrets.plist.
    private static let store: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else {
            return [:]
        }
        return dict
    }()

    /// Resolve a credential by key, preferring an injected env var (dev scheme),
    /// then Secrets.plist, then a legacy Info.plist entry.
    static func value(for key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        if let v = store[key], !v.isEmpty, !v.hasPrefix("$(") {
            return v
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plist.isEmpty, !plist.hasPrefix("$(") {
            return plist
        }
        return ""
    }

    static var openAIKey: String { value(for: "OPENAI_API_KEY") }
    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }

    static var proxySharedSecret: String { value(for: "PROXY_SHARED_SECRET") }
}
