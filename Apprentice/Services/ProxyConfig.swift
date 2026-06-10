//
//  ProxyConfig.swift
//  Apprentice
//
//  Layer 3 (Services) — points the app at the Firebase key-proxy.
//  When configured, STT (and later AI/TTS) route through the proxy so the
//  provider keys live server-side, never in the app bundle.
//
//  Set these in Info.plist after deploying functions/:
//    PROXY_BASE_URL    = https://us-central1-coldharbordigital.cloudfunctions.net
//    PROXY_SHARED_SECRET = <same value set as the PROXY_SHARED_SECRET function secret>
//

import Foundation

enum ProxyConfig {

    static var baseURL: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "PROXY_BASE_URL") as? String ?? ""
        // strip a trailing slash so "\(baseURL)/transcribe" is always clean
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }

    static var sharedSecret: String {
        Secrets.proxySharedSecret
    }

    /// True once both values are present — the app then prefers the proxy.
    static var isConfigured: Bool { !baseURL.isEmpty && !sharedSecret.isEmpty }
}

/// Chooses the proxy-backed transcription path when configured, else the direct
/// (on-device key) path. Lets the rest of the app stay provider-agnostic.
enum TranscriptionServiceFactory {
    static func make() -> TranscriptionService {
        ProxyConfig.isConfigured ? ProxyTranscriptionService() : WhisperTranscriptionService()
    }
}
