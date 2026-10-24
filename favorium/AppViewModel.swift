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

    // MARK: - Helper title (server-computed, never goes down)
    var helperLevel: Int = 0
    /// Distinct people who confirmed a favor this user did for them
    var peopleHelped: Int = 0
    /// Set when the level is newer than this device last celebrated; ContentView presents it
    var titleToCelebrate: HelperTitle?

    var helperTitle: HelperTitle? { HelperTitle(rawValue: helperLevel) }

    /// The profile came back marked deleted (e.g. deleted from another device); ContentView signs out
    var accountWasDeleted = false

    // MARK: - Account pause (server is the authority; never cached on device)
    var pause: SupabaseService.AccountPause?

    /// Re-reads the pause. Keeps the last known value if the network call fails.
    @MainActor
    func refreshPause() async {
        guard userId != nil else { pause = nil; return }
        guard let latest = try? await SupabaseService.shared.myPause() else { return }
        pause = latest
    }

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
        if profile?.deleted_at != nil { accountWasDeleted = true; return }
        if let profile { applyTitle(from: profile) }
    }

    /// Re-reads the title after favors change (a gem received can raise it).
    @MainActor
    func refreshTitle() async {
        guard let userId,
              let profile = try? await SupabaseService.shared.getUserProfile(userId: userId) else { return }
        if profile.deleted_at != nil { accountWasDeleted = true; return }
        applyTitle(from: profile)
    }


    @MainActor
    private func applyTitle(from profile: SupabaseService.UserProfile) {
        helperLevel = profile.helper_level ?? 0
        peopleHelped = profile.people_helped ?? 0
        guard let userId, let title = helperTitle else { return }
        let celebrated = UserDefaults.standard.integer(forKey: Self.celebratedKey(userId))
        guard title.rawValue > celebrated else { return }
        // Recorded the moment it's shown: the sheet clears `titleToCelebrate` before its
        // onDismiss runs, so marking it there never saved and the alert kept returning
        UserDefaults.standard.set(title.rawValue, forKey: Self.celebratedKey(userId))
        titleToCelebrate = title
    }

    private static func celebratedKey(_ userId: UUID) -> String {
        "celebratedHelperLevel.\(userId.uuidString.lowercased())"
    }

    /// Deletes the account, then signs out locally. The server has already ended the session,
    /// so local sign-out mustn't try to re-authenticate or treat a failure as an error.
    @MainActor
    func deleteAccount(authVM: AuthViewModel) async throws {
        try await SupabaseService.shared.deleteAccount()
        await signOut(authVM: authVM)
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
        helperLevel = 0
        peopleHelped = 0
        titleToCelebrate = nil
        pause = nil
        accountWasDeleted = false
        isAuthenticated = false
    }
}
