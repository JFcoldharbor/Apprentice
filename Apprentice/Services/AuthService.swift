//
//  AuthService.swift
//  Apprentice
//
//  Layer 3 (Services) — Firebase Auth identity.
//  Ensures there is always a signed-in user (anonymous to start) so calls to the
//  key-proxy can carry a verifiable ID token instead of just the shared secret.
//  Upgrade path: link the anonymous account to Sign in with Apple later for a
//  real, cross-device identity without losing the existing UID.
//

import Foundation
import FirebaseAuth

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    @Published private(set) var uid: String?
    @Published private(set) var isAnonymous: Bool = true

    private init() {
        let user = Auth.auth().currentUser
        uid = user?.uid
        isAnonymous = user?.isAnonymous ?? true
    }

    /// Ensure a Firebase identity exists. No-ops if already signed in; otherwise
    /// signs in anonymously. Non-fatal on failure — the proxy falls back to the
    /// shared secret, so transcription still works.
    func bootstrap() async {
        if let user = Auth.auth().currentUser {
            uid = user.uid
            isAnonymous = user.isAnonymous
            return
        }
        do {
            let result = try await Auth.auth().signInAnonymously()
            uid = result.user.uid
            isAnonymous = result.user.isAnonymous
        } catch {
            // Most likely the Anonymous provider isn't enabled in the Firebase
            // console (Authentication → Sign-in method). Non-fatal.
            print("⚠️ AuthService: anonymous sign-in failed — \(error.localizedDescription)")
        }
    }

    /// A fresh ID token for the current user, or nil if not signed in.
    /// Firebase refreshes the token automatically when near expiry.
    func currentIDToken() async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        do {
            return try await user.getIDToken()
        } catch {
            return nil
        }
    }
}
