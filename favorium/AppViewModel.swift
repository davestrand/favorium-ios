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

        if let profile = try? await ProfileService.shared.me() {
            displayName = profile.display_name ?? ""
        }
    }

    @MainActor
    func signOut(authVM: AuthViewModel) async {
        await authVM.signOut()
        userId = nil
        displayName = ""
        isAuthenticated = false
    }
}
