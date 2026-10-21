//
//  AppViewModel.swift
//  favorium
//
//  Shared app-level state: current user identity, driving data refresh
//  across all tabs. Loaded once after sign-in and refreshed on demand.
//

import Foundation
import Observation

@Observable
final class AppViewModel {

    // MARK: - Identity
    var userId: UUID?
    var displayName: String = ""
    var email: String = ""
    /// Signed-in user's profile photo (nil → initials)
    var avatarURL: String?
    var isAuthenticated: Bool = false

    // MARK: - Shared loading flag (used by tabs during first load)
    var isBootstrapping: Bool = true

    // MARK: - Bootstrap
    /// Call once at app launch / after sign-in to resolve the current session.
    @MainActor
    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        guard let session = try? await SupabaseService.shared.currentSession(),
              let idString = session.userId,
              let id = UUID(uuidString: idString) else {
            isAuthenticated = false
            return
        }

        userId = id
        isAuthenticated = true
        email = session.email ?? ""

        // The profile row is the source of truth for the name and photo; fall back to
        // the name given at sign-up so the Profile tab never shows a blank.
        // Read through the same client that signed in, with the lenient decoder the
        // other screens use — a strict decode failure here used to drop the photo silently.
        let profile = try? await SupabaseService.shared.getUserProfile(userId: id)
        let profileName = profile?.display_name
        avatarURL = profile?.avatar_url.flatMap { $0.isEmpty ? nil : $0 }
        displayName = [profileName, session.signUpDisplayName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    @MainActor
    func signOut(authVM: AuthViewModel) async {
        // Remove this phone's push token while the session is still valid
        await PushManager.shared.signingOut()
        await authVM.signOut()
        userId = nil
        displayName = ""
        avatarURL = nil
        email = ""
        isAuthenticated = false
    }
}
