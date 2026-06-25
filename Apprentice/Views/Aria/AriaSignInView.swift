//
//  AriaSignInView.swift
//  Apprentice
//
//  The sign-in gate. A user signs in with their own Apple account, which gives a
//  per-user identity → their own isolated workspace. Shown by ContentView until
//  a real (non-anonymous) account is signed in.
//

import SwiftUI
import AuthenticationServices

struct AriaSignInView: View {
    @ObservedObject private var auth = AuthService.shared

    var body: some View {
        ZStack {
            AriaBackground()
            VStack(spacing: 0) {
                Spacer()

                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.95), Aria.goldBright, Aria.gold, Color(red: 0.61, green: 0.51, blue: 0.28)],
                        center: UnitPoint(x: 0.38, y: 0.32), startRadius: 3, endRadius: 90))
                    .frame(width: 96, height: 96)
                    .shadow(color: Aria.gold.opacity(0.5), radius: 28)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 26, weight: .light))
                        .foregroundColor(Color(red: 0.23, green: 0.17, blue: 0.06).opacity(0.85)))
                    .padding(.bottom, 28)

                AriaEyebrow(text: "Apprentice · Aria")
                Text("Your private workspace")
                    .font(.fraunces(28)).foregroundColor(Aria.ivory)
                    .multilineTextAlignment(.center).padding(.top, 6)
                Text("Sign in to your own account. Your notes, sessions, and Aria are private to you.")
                    .font(.inter(14)).foregroundColor(Aria.ivoryDim)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.top, 10).padding(.horizontal, 36)

                Spacer()

                SignInWithAppleButton(.signIn,
                    onRequest: { request in auth.prepareAppleRequest(request) },
                    onCompletion: { result in auth.handleAppleCompletion(result) })
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .padding(.horizontal, 30)

                if let err = auth.errorMessage {
                    Text(err).font(.inter(12.5)).foregroundColor(Aria.rose)
                        .multilineTextAlignment(.center).padding(.horizontal, 30).padding(.top, 12)
                }

                Text("Private to your account · sign out anytime in Settings.")
                    .font(.inter(11)).foregroundColor(Aria.ivoryFaint)
                    .padding(.top, 16)

                Spacer().frame(height: 44)
            }
        }
    }
}
