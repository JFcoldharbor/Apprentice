//
//  StitchDataRoomSource.swift
//  Apprentice
//
//  Layer 3 (Services) — the first DocumentSource: the Stitch Social investor data
//  room. Calls the Firebase key-proxy's POST /syncDataRoom (which reads the
//  stitch-dataroom project server-side with the Admin SDK, bypassing the investor
//  magic-link gate). Maps the response into SourceItems for generic ingestion.
//
//  Same transport as AIClient: x-proxy-secret + optional Firebase ID token.
//

import Foundation

struct StitchDataRoomSource: DocumentSource {

    let id = "stitch-dataroom"
    let displayName = "Investor Data Room"

    // MARK: - Wire format (mirrors functions/src/dataRoom.ts response)

    private struct SyncResponse: Decodable {
        struct Section: Decodable {
            let key: String
            let title: String
            let eyebrow: String
            let text: String
        }
        struct Document: Decodable {
            let id: String
            let section: String
            let title: String
            let note: String
            let kind: String
            let filename: String
            let storagePath: String
            let url: String?
        }
        let sections: [Section]
        let documents: [Document]
    }

    // MARK: - DocumentSource

    func fetch() async throws -> [SourceItem] {
        guard ProxyConfig.isConfigured else { throw AIError.notConfigured }

        let url = URL(string: "\(ProxyConfig.baseURL)/syncDataRoom")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(ProxyConfig.sharedSecret, forHTTPHeaderField: "x-proxy-secret")
        if let token = await AuthService.shared.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.http(-1, "Invalid response")
        }
        guard http.statusCode == 200 else {
            throw AIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(SyncResponse.self, from: data)
        var items: [SourceItem] = []

        // Narrative sections → text items. Carry the eyebrow + title as a header so
        // the assistant gets section context inline.
        for section in decoded.sections {
            let header = section.eyebrow.isEmpty
                ? section.title
                : "\(section.eyebrow)\n\(section.title)"
            let body = section.text.isEmpty ? header : "\(header)\n\n\(section.text)"
            items.append(
                SourceItem(title: "Data Room — \(section.title)", note: nil, payload: .text(body))
            )
        }

        // Document files → remote-file items (downloaded + extracted on device).
        for doc in decoded.documents {
            guard let urlString = doc.url, let remote = URL(string: urlString) else { continue }
            items.append(
                SourceItem(
                    title: "Data Room — \(doc.title)",
                    note: doc.note.isEmpty ? nil : doc.note,
                    payload: .remoteFile(url: remote, ext: fileExtension(for: doc))
                )
            )
        }

        return items
    }

    // MARK: - Helpers

    /// Prefer the real filename's extension, then the storage path's, then a kind map.
    private func fileExtension(for doc: SyncResponse.Document) -> String {
        let fromName = (doc.filename as NSString).pathExtension
        if !fromName.isEmpty { return fromName.lowercased() }
        let fromPath = (doc.storagePath as NSString).pathExtension
        if !fromPath.isEmpty { return fromPath.lowercased() }
        return doc.kind.lowercased() == "sheet" ? "csv" : "pdf"
    }
}
