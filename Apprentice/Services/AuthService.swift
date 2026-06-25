//
//  AuthService.swift
//  Apprentice
//
//  Layer 3 (Services) — real per-user identity (Sign in with Apple via Firebase).
//  Each user signs in with their own account → their own uid → their own isolated
//  data (the proxy scopes every collection by uid; see userScope on the backend).
//  No more anonymous accounts: a user must be signed in to reach the brain.
//
//  Sign in with Apple needs the "Sign in with Apple" capability in Xcode
//  (Signing & Capabilities) and the Apple provider enabled in Firebase (it is).
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    @Published private(set) var uid: String?
    @Published private(set) var email: String?
    @Published private(set) var isSignedIn = false
    @Published var errorMessage: String?

    /// Raw nonce for the in-flight Apple sign-in (set by the button's onRequest).
    private var currentNonce: String?

    private init() { sync() }

    /// Refresh published state from the current Firebase user. (Kept for the app's
    /// launch `.task`; no longer signs in anonymously.)
    func bootstrap() { sync() }

    private func sync() {
        let u = Auth.auth().currentUser
        uid = u?.uid
        email = u?.email
        // Only a real (non-anonymous) account counts as signed in.
        isSignedIn = (u != nil) && !(u?.isAnonymous ?? true)
    }

    /// A fresh ID token for the current user, or nil if not signed in.
    func currentIDToken() async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try? await user.getIDToken()
    }

    func signOut() {
        try? Auth.auth().signOut()
        sync()
    }

    // MARK: - Sign in with Apple

    /// Call from the SignInWithAppleButton's onRequest to stamp the request.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        errorMessage = nil
    }

    /// Call from the button's onCompletion. Exchanges the Apple credential for a
    /// Firebase sign-in (linking to the founder data happens server-side via
    /// FOUNDER_UID — nothing the client does here can lose data).
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        case .success(let authorization):
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple sign-in didn't return a usable credential."
                return
            }
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken, rawNonce: nonce, fullName: cred.fullName)
            Task { @MainActor in
                do {
                    _ = try await Auth.auth().signIn(with: credential)
                    sync()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Nonce helpers (Apple + Firebase require a SHA256-hashed nonce)

    static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
