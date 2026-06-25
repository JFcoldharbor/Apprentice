//
//  DiscoverySync.swift
//  Apprentice
//
//  Layer 3 (Services) — pushes a captured InterviewRecord to the shared backend
//  (POST /discovery { record }), where it joins aria/founder/discoveryRecords and
//  the aggregate (charts + decision gates) is recomputed. Same transport as
//  AriaMirror: proxy base URL + shared-secret + Firebase ID token. Best-effort.
//

import Foundation

struct DiscoverySync {

    static let shared = DiscoverySync()

    /// Sync one interview record. The payload is built on the main actor (the
    /// record is a @Model), then POSTed off-actor.
    @MainActor
    func sync(record: InterviewRecord) {
        let body: [String: Any] = ["record": record.payload()]
        Task { await post(body) }
    }

    private func post(_ body: [String: Any]) async {
        guard ProxyConfig.isConfigured, let url = URL(string: "\(ProxyConfig.baseURL)/discovery") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request) // best-effort; ignore result
    }
}
