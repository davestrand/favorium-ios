import Foundation
import Supabase

/// Nonisolated so the Supabase SDK can decode it off the main actor.
nonisolated struct Profile: Decodable, Identifiable, Sendable {
    let id: UUID
    let display_name: String?
    let is_admin: Bool
    let created_at: Date
}

enum ProfileServiceError: Error {
    case notAuthenticated
    case notFound
}

final class ProfileService {
    static let shared = ProfileService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseManager.shared.client
    }

    func me() async throws -> Profile {
        let session = try await client.auth.session
        let user = session.user
        // If your Supabase setup can have an unauthenticated state, uncomment the following guard:
        // guard session.accessToken.isEmpty == false else { throw ProfileServiceError.notAuthenticated }
        let uid = user.id

        // Use Supabase Swift's decoding directly to a Profile
        let profile: Profile = try await client
            .from("profiles")
            .select("id, display_name, is_admin, created_at")
            .eq("id", value: uid)
            .single()
            .execute()
            .value

        return profile
    }
}

