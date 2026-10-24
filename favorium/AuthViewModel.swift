//
//  AuthViewModel.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    enum Mode { case signIn, signUp }

    // UI State
    var mode: Mode = .signIn
    var email: String = ""
    var password: String = ""
    var displayName: String = "" // used for sign-up only

    var isLoading: Bool = false
    var errorMessage: String?
    var infoMessage: String?
    var isAuthenticated: Bool = false

    // MARK: - Actions
    @MainActor
    func submit() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case .signIn:
                try await SupabaseService.shared.signIn(email: email, password: password)
                isAuthenticated = true
            case .signUp:
                guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NSError(domain: "Auth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Display name is required."])
                }
                let signedIn = try await SupabaseService.shared.signUp(email: email, password: password, displayName: displayName)
                if signedIn {
                    // Email confirmation is off: the new account goes straight in
                    isAuthenticated = true
                } else {
                    // Only if confirmation is switched on later: no session until the address is confirmed
                    infoMessage = "Check your inbox to confirm your email, then sign in."
                    mode = .signIn
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func signOut() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }
        // Local state always clears: after an account is deleted the server session is
        // already gone, and a failed network sign-out mustn't leave the app half signed in
        try? await SupabaseService.shared.signOut()
        isAuthenticated = false
    }
}
