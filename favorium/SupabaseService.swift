//
//  SupabaseService.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import Foundation
import Supabase
import Helpers

final class SupabaseService {
    static let shared = SupabaseService()

    // MARK: - Configuration
    private let supabaseURL = URL(string: "https://nnnmztslzfwpfsaagiyn.supabase.co")!
    private let supabaseAnonKey = "sb_publishable_SPurNrFoPcJI2_Z_FM0haw_ixl5hEyM"

    // MARK: - Client
    private lazy var client: SupabaseClient = {
        SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseAnonKey)
    }()

    func testCoinsCount() async throws -> String {
        // Using Supabase SDK: select a single row from public.coins to validate connectivity.
        struct Coin: Decodable { let id: UUID }

        // Request a small payload and decode from raw response data for broad SDK compatibility
        let response = try await client
            .database
            .from("coins")
            .select("id")
            .limit(1)
            .execute()

        let coins = try JSONDecoder().decode([Coin].self, from: response.data)

        if coins.isEmpty {
            return "Supabase coins reachable (0 rows)"
        } else {
            return "Supabase coins reachable (1+ rows)"
        }
    }
    
    // MARK: - Auth
    struct AuthSession: Sendable {
        let userId: String?
        let accessToken: String?
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        // Must include display_name in metadata so the trigger can create profile + mint two Favors
        _ = try await client.auth.signUp(email: email, password: password, data: ["display_name": .string(displayName)])
    }
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func currentSession() async throws -> AuthSession? {
        do {
            let session = try await client.auth.session
            return AuthSession(userId: session.user.id.uuidString, accessToken: session.accessToken)
        } catch {
            return nil
        }
    }

    // MARK: - Coins
    struct CoinSummary: Decodable, Identifiable, Hashable, Sendable {
        let id: UUID
        let serial: String?
        let name: String?
        let transfer_count: Int?
        let creator_id: UUID?
        let owner_id: UUID?
        let created_at: String?
    }
    func myFavors(userId: UUID) async throws -> [CoinSummary] {
        let response = try await client.database
            .from("coins")
            .select("id,serial,name,transfer_count,creator_id,owner_id,created_at")
            .eq("owner_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        return try JSONDecoder().decode([CoinSummary].self, from: response.data)
    }

    func myOriginals(userId: UUID) async throws -> [CoinSummary] {
        let response = try await client.database
            .from("coins")
            .select("id,serial,name,transfer_count,creator_id,owner_id,created_at")
            .eq("creator_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        return try JSONDecoder().decode([CoinSummary].self, from: response.data)
    }

    // MARK: - Journey RPC
    struct CoinHistoryItem: Decodable, Identifiable, Sendable {
        let id: Int64
        let event_type: String
        let description: String?
        let created_at: String
        let from_name: String?
        let to_name: String?
        let is_from_me: Bool?
        let is_to_me: Bool?
    }
    struct CoinJourneyPayload: Decodable, Sendable {
        let id: UUID
        let serial: String
        let name: String
        let traits: JSONObject?
        let dna: JSONObject?
        let seed: String?
        let dna_version: Int
        let transfer_count: Int
        let created_at: String
        let creator_name: String?
        let owner_name: String?
        let is_owner: Bool
        let is_creator: Bool
        let history: [CoinHistoryItem]
    }

    func coinJourney(coinID: UUID) async throws -> CoinJourneyPayload {
        struct CoinJourneyParams: Encodable {
            let p_coin_id: String
        }
        
        let response = try await client.database
            .rpc("coin_journey", params: CoinJourneyParams(p_coin_id: coinID.uuidString))
            .execute()
        return try JSONDecoder().decode(CoinJourneyPayload.self, from: response.data)
    }
    
    // MARK: - Favors (Offer/Accept/Complete)
    struct Favor: Decodable, Identifiable, Sendable {
        let id: UUID
        let helper_id: UUID
        let helped_id: UUID
        let description: String
        let status: String // 'proposed', 'accepted', 'completed', 'transferred', 'declined', 'cancelled'
        let created_at: String
        let accepted_at: String?
        let completed_at: String?
        let transferred_at: String?
        let coin_id: UUID?
        let helper_name: String?
        let helped_name: String?
        
        var isProposed: Bool { status == "proposed" }
        var isAccepted: Bool { status == "accepted" }
        var isCompleted: Bool { status == "completed" }
        var isTransferred: Bool { status == "transferred" }
        var isDeclined: Bool { status == "declined" }
        var isCancelled: Bool { status == "cancelled" }
    }
    
    /// Fetch favors where current user is being helped (incoming offers)
    func myIncomingFavors(userId: UUID) async throws -> [Favor] {
        let response = try await client.database
            .from("favors")
            .select("id,helper_id,helped_id,description,status,created_at,accepted_at,completed_at,transferred_at,coin_id,helper:profiles!favors_helper_id_fkey(display_name),helped:profiles!favors_helped_id_fkey(display_name)")
            .eq("helped_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        let rawFavors = try decoder.decode([RawFavor].self, from: response.data)
        return rawFavors.map { $0.toFavor() }
    }
    
    /// Fetch favors where current user is the helper (outgoing offers)
    func myOutgoingFavors(userId: UUID) async throws -> [Favor] {
        let response = try await client.database
            .from("favors")
            .select("id,helper_id,helped_id,description,status,created_at,accepted_at,completed_at,transferred_at,coin_id,helper:profiles!favors_helper_id_fkey(display_name),helped:profiles!favors_helped_id_fkey(display_name)")
            .eq("helper_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        let rawFavors = try decoder.decode([RawFavor].self, from: response.data)
        return rawFavors.map { $0.toFavor() }
    }
    
    /// Create a new favor offer (helper offers to help someone)
    /// Uses the propose_favor RPC which enforces connection requirements and security
    func proposeFavor(helpedUserId: UUID, description: String) async throws -> UUID {
        struct ProposeFavorParams: Encodable {
            let p_helped_id: String
            let p_description: String
        }
        
        let response = try await client.database
            .rpc("propose_favor", params: ProposeFavorParams(
                p_helped_id: helpedUserId.uuidString,
                p_description: description
            ))
            .execute()
        
        // The RPC returns the new favor ID as a UUID
        let favorId = try JSONDecoder().decode(UUID.self, from: response.data)
        return favorId
    }
    
    /// Accept a favor offer (helped person accepts the help)
    /// Uses respond_to_favor RPC
    func acceptFavor(favorId: UUID) async throws {
        struct RespondParams: Encodable {
            let p_favor_id: String
            let p_accept: Bool
        }
        
        _ = try await client.database
            .rpc("respond_to_favor", params: RespondParams(
                p_favor_id: favorId.uuidString,
                p_accept: true
            ))
            .execute()
    }
    
    /// Decline a favor offer
    /// Uses respond_to_favor RPC
    func declineFavor(favorId: UUID) async throws {
        struct RespondParams: Encodable {
            let p_favor_id: String
            let p_accept: Bool
        }
        
        _ = try await client.database
            .rpc("respond_to_favor", params: RespondParams(
                p_favor_id: favorId.uuidString,
                p_accept: false
            ))
            .execute()
    }
    
    /// Cancel a favor (by the helper)
    func cancelFavor(favorId: UUID) async throws {
        struct CancelParams: Encodable {
            let p_favor_id: String
        }
        
        _ = try await client.database
            .rpc("cancel_favor", params: CancelParams(
                p_favor_id: favorId.uuidString
            ))
            .execute()
    }
    
    /// Mark favor as completed (called by helped person)
    func completeFavor(favorId: UUID) async throws {
        struct CompleteParams: Encodable {
            let p_favor_id: String
        }
        
        _ = try await client.database
            .rpc("complete_favor", params: CompleteParams(
                p_favor_id: favorId.uuidString
            ))
            .execute()
    }
    
    /// Transfer a coin to complete a favor
    func transferCoin(favorId: UUID, coinId: UUID) async throws {
        struct TransferParams: Encodable {
            let p_favor_id: String
            let p_coin_id: String
        }
        
        _ = try await client.database
            .rpc("transfer_coin", params: TransferParams(
                p_favor_id: favorId.uuidString,
                p_coin_id: coinId.uuidString
            ))
            .execute()
    }
    
    /// Legacy method - may need to be split into complete_favor + transfer_coin
    /// depending on your actual RPC implementation
    /// If complete_favor_and_mint RPC doesn't exist, this should be refactored
    func completeFavorAndMintCoin(favorId: UUID, coinName: String) async throws -> UUID {
        struct CompleteMintParams: Encodable {
            let p_favor_id: String
            let p_coin_name: String
        }
        
        // Call RPC that handles the complete workflow
        let response = try await client.database
            .rpc("complete_favor_and_mint", params: CompleteMintParams(
                p_favor_id: favorId.uuidString,
                p_coin_name: coinName
            ))
            .execute()
        
        struct MintResult: Decodable {
            let coin_id: UUID
        }
        
        let result = try JSONDecoder().decode(MintResult.self, from: response.data)
        return result.coin_id
    }
    
    // MARK: - Connections/Users
    struct UserProfile: Decodable, Identifiable, Sendable {
        let id: UUID
        let display_name: String?
        let created_at: String?
        
        var displayName: String {
            display_name ?? "Unknown User"
        }
    }
    
    /// Search for users by display name
    func searchUsers(query: String) async throws -> [UserProfile] {
        let response = try await client.database
            .from("profiles")
            .select("id,display_name,created_at")
            .ilike("display_name", pattern: "%\(query)%")
            .limit(20)
            .execute()
        
        return try JSONDecoder().decode([UserProfile].self, from: response.data)
    }
    
    /// Get users you've interacted with (exchanged favors with)
    func getConnectedUsers(userId: UUID, limit: Int = 10) async throws -> [UserProfile] {
        struct RPCParams: Encodable {
            let p_user_id: String
            let p_limit: Int
        }
        
        // Get unique user IDs from favors where current user was either helper or helped
        let response = try await client.database
            .rpc("get_connected_users", params: RPCParams(
                p_user_id: userId.uuidString,
                p_limit: limit
            ))
            .execute()
        
        return try JSONDecoder().decode([UserProfile].self, from: response.data)
    }
    
    /// Get a specific user profile
    func getUserProfile(userId: UUID) async throws -> UserProfile {
        let response = try await client.database
            .from("profiles")
            .select("id,display_name,created_at")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
        
        return try JSONDecoder().decode(UserProfile.self, from: response.data)
    }
    
    // MARK: - Helper Types for Nested Decoding
    private struct RawFavor: Decodable {
        let id: UUID
        let helper_id: UUID
        let helped_id: UUID
        let description: String
        let status: String
        let created_at: String
        let accepted_at: String?
        let completed_at: String?
        let transferred_at: String?
        let coin_id: UUID?
        let helper: ProfileName?
        let helped: ProfileName?
        
        struct ProfileName: Decodable {
            let display_name: String?
        }
        
        func toFavor() -> Favor {
            Favor(
                id: id,
                helper_id: helper_id,
                helped_id: helped_id,
                description: description,
                status: status,
                created_at: created_at,
                accepted_at: accepted_at,
                completed_at: completed_at,
                transferred_at: transferred_at,
                coin_id: coin_id,
                helper_name: helper?.display_name,
                helped_name: helped?.display_name
            )
        }
    }
}

