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

    // MARK: - Auth
    struct AuthSession: Sendable {
        let userId: String?
        let accessToken: String?
        let email: String?
        /// display_name saved in auth metadata at sign-up (fallback when the profile row can't load)
        let signUpDisplayName: String?
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        // Must include display_name in metadata so the trigger can create profile + mint two Favors
        _ = try await client.auth.signUp(email: email, password: password, data: ["display_name": .string(displayName)])
    }
    /// Emails a link to favorium.app/reset, where the new password is set in the browser.
    /// Succeeds whether or not the address has an account, so nothing can be enumerated.
    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: FavoriumWeb.reset)
    }

    struct DeleteAccountResult: Decodable, Sendable {
        /// "deleted" or "already_deleted" — both are success
        let status: String?
        let cancelled_favors: Int?
    }

    /// Deletes the signed-in account (self-scoped on the server; no id is passed).
    /// The login and identity go immediately; shared gems and favor history stay.
    @discardableResult
    func deleteAccount() async throws -> DeleteAccountResult {
        let response = try await client.rpc("delete_account").execute()
        return (try? JSONDecoder().decode(DeleteAccountResult.self, from: response.data))
            ?? DeleteAccountResult(status: nil, cancelled_favors: nil)
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
            return AuthSession(
                userId: session.user.id.uuidString,
                accessToken: session.accessToken,
                email: session.user.email,
                signUpDisplayName: session.user.userMetadata["display_name"]?.stringValue
            )
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
        let dna: JSONObject?
        /// When this gem's 24h transfer cooldown ends; nil = it can move now (IOS_CONTRACT §15)
        var available_at: String? = nil

        /// The cooldown end, only while it's still in the future
        var restingUntil: Date? {
            SupabaseService.restingUntil(available_at)
        }

        // Hashable conformance — dna (JSONObject) doesn't auto-conform, so exclude it.
        static func == (lhs: CoinSummary, rhs: CoinSummary) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }

        /// Decode the dna blob into a GemDNA, handling both Layer-1 and Layer-2 shapes.
        /// Returns nil only when dna is entirely absent.
        var gemDNA: GemDNA? {
            guard let dna,
                  let encoded = try? JSONEncoder().encode(dna)
            else { return nil }
            return try? JSONDecoder().decode(GemDNA.self, from: encoded)
        }
    }
    /// A gem may change hands once per rolling 24h; `transfer_coin` raises this
    /// message prefix (followed by a UTC timestamp) while it's resting.
    static let restingErrorPrefix = "Gem is resting"

    /// The cooldown end parsed from `available_at`, or nil once it has passed.
    static func restingUntil(_ availableAt: String?) -> Date? {
        guard let availableAt, let date = PairingCode.parseTimestamp(availableAt), date > .now else { return nil }
        return date
    }

    /// The end time inside a "Gem is resting — it can move again at <ISO>" error, if that's what this is.
    static func restingUntil(from error: Error) -> Date? {
        let message = (error as? PostgrestError)?.message ?? error.localizedDescription
        guard message.hasPrefix(restingErrorPrefix),
              let raw = message.components(separatedBy: " at ").last else { return nil }
        return PairingCode.parseTimestamp(raw.trimmingCharacters(in: .whitespaces))
    }

    func myFavors(userId: UUID) async throws -> [CoinSummary] {
        let response = try await client
            .from("coins")
            .select("id,serial,name,transfer_count,creator_id,owner_id,created_at,dna,available_at")
            .eq("owner_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        return try JSONDecoder().decode([CoinSummary].self, from: response.data)
    }

    func myOriginals(userId: UUID) async throws -> [CoinSummary] {
        let response = try await client
            .from("coins")
            .select("id,serial,name,transfer_count,creator_id,owner_id,created_at,dna,available_at")
            .eq("creator_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()

        return try JSONDecoder().decode([CoinSummary].self, from: response.data)
    }

    // MARK: - Journey RPC

    /// Flat Layer-1 DNA keys written by mint_coin (dna_version 2).
    /// Also used as the canonical gem identity on both platforms.
    struct GemDNA: Decodable, Sendable {
        let gemFamily: String       // "lightning" | "celestial" | "victorian" | "darkheart"
        let primaryHue: Double      // 0–360
        let saturation: Double      // 0–1
        let trait: String?          // nil until first Bloom transfer
        let seed: String

        // Layer-2 nested block — present on dna_version 2 rows and the 6 repaired rows.
        // Decoded separately; use gemFamily / primaryHue from Layer 1 when available.
        struct Identity: Decodable, Sendable {
            let primaryColor: Double
            let secondaryColor: Double
            let accentColor: Double
            let saturation: Double?
            let baseForm: String
            let materialFamily: String?
            let colorRelationship: String?
            let secondaryInfluence: Double?
            let refraction: Double?
            let frameHue: Double?

            enum CodingKeys: String, CodingKey {
                case primaryColor       = "primary_color"
                case secondaryColor     = "secondary_color"
                case accentColor        = "accent_color"
                case saturation
                case baseForm           = "base_form"
                case materialFamily     = "material_family"
                case colorRelationship  = "color_relationship"
                case secondaryInfluence = "secondary_influence"
                case refraction
                case frameHue           = "frame_hue"
            }
        }

        struct Personality: Decodable, Sendable {
            let complexityBias: Double?
            let orbitalAffinity: Double?
            let evolutionFamily: String?

            enum CodingKeys: String, CodingKey {
                case complexityBias   = "complexity_bias"
                case orbitalAffinity  = "orbital_affinity"
                case evolutionFamily  = "evolution_family"
            }
        }

        let identity: Identity?
        let personality: Personality?

        // Resolved values — Layer 1 wins, fall back to Layer 2
        /// Layer 1 `gemFamily` wins, then Layer 2 `identity.base_form`, then "lightning".
        /// A layer only counts if it names a known asset family, so an unexpected
        /// Layer 1 value still falls through to a valid `base_form`.
        var resolvedFamily: String {
            [gemFamily, identity?.baseForm]
                .compactMap { GemFamily.normalized($0) }
                .first?.rawValue ?? GemFamily.lightning.rawValue
        }
        var resolvedHue: Double     { primaryHue > 0 || !gemFamily.isEmpty ? primaryHue : (identity?.primaryColor ?? 45) }
        var resolvedSaturation: Double { saturation > 0 ? saturation : (identity?.saturation ?? 0.7) }

        // Custom init so Layer-1 keys decode gracefully when absent (repair rows)
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            gemFamily   = (try? c.decode(String.self,  forKey: .gemFamily))   ?? ""
            primaryHue  = (try? c.decode(Double.self,  forKey: .primaryHue))  ?? 0
            saturation  = (try? c.decode(Double.self,  forKey: .saturation))  ?? 0
            trait       = try? c.decode(String.self,   forKey: .trait)
            seed        = (try? c.decode(String.self,  forKey: .seed))        ?? ""
            identity    = try? c.decode(Identity.self,    forKey: .identity)
            personality = try? c.decode(Personality.self, forKey: .personality)
        }

        enum CodingKeys: String, CodingKey {
            case gemFamily, primaryHue, saturation, trait, seed, identity, personality
        }
    }

    struct CoinHistoryItem: Decodable, Identifiable, Sendable {
        let id: Int64
        let eventType: String       // "minted" | "transferred" | "renamed" | "gifted"
        let description: String?
        let createdAt: String
        let fromName: String?
        let toName: String?
        let isFromMe: Bool?         // nullable when called without user JWT
        let isToMe: Bool?           // nullable when called without user JWT
        // People on this step (ids drive the initials colour; avatars are photo URLs)
        let fromId: UUID?
        let toId: UUID?
        let fromAvatar: String?
        let toAvatar: String?
        var fromLevel: Int? = nil   // helper title levels; on a transfer, `to` is the helper
        var toLevel: Int? = nil
        // Only on "renamed" rows, where `from_*` is the person who renamed it and `to_*` is null
        var oldName: String? = nil
        var newName: String? = nil

        /// True only for an actual hand-off. Renames are never custody events.
        var isTransfer: Bool { eventType == "transferred" }
        var isRename: Bool { eventType == "renamed" }
        /// A gem the zero-balance safety valve gave to someone with an empty shelf
        var isGift: Bool { eventType == "gifted" }
        /// Someone sealed a secret message in the gem. Never carries the text; not custody.
        var isEngraving: Bool { eventType == "engraved" }

        enum CodingKeys: String, CodingKey {
            case id, description
            case eventType  = "event_type"
            case oldName    = "old_name"
            case newName    = "new_name"
            case createdAt  = "created_at"
            case fromName   = "from_name"
            case toName     = "to_name"
            case isFromMe   = "is_from_me"
            case isToMe     = "is_to_me"
            case fromId     = "from_id"
            case toId       = "to_id"
            case fromAvatar = "from_avatar"
            case toAvatar   = "to_avatar"
            case fromLevel  = "from_level"
            case toLevel    = "to_level"
        }
    }

    struct CoinJourneyPayload: Decodable, Sendable {
        let id: UUID
        let serial: String
        let name: String
        // traits omitted — always empty object, ignored by both platforms
        let dna: GemDNA?            // nullable for hand-repaired / legacy rows
        let seed: String?
        let dnaVersion: Int
        let transferCount: Int
        let createdAt: String
        let creatorName: String?
        let ownerName: String?
        let creatorId: UUID?
        let ownerId: UUID?
        let creatorAvatar: String?
        let ownerAvatar: String?
        var creatorLevel: Int? = nil
        var ownerLevel: Int? = nil
        let isOwner: Bool?          // null when called without user JWT
        let isCreator: Bool?        // null when called without user JWT
        /// 24h transfer cooldown (IOS_CONTRACT §15); nil = can move now
        var availableAt: String? = nil
        var isResting: Bool? = nil
        let history: [CoinHistoryItem]

        /// The cooldown end while it's still in the future
        var restingUntil: Date? {
            isResting == false ? nil : SupabaseService.restingUntil(availableAt)
        }

        enum CodingKeys: String, CodingKey {
            case id, serial, name, dna, seed, history
            case dnaVersion   = "dna_version"
            case transferCount = "transfer_count"
            case createdAt    = "created_at"
            case creatorName  = "creator_name"
            case ownerName    = "owner_name"
            case creatorId    = "creator_id"
            case ownerId      = "owner_id"
            case creatorAvatar = "creator_avatar"
            case ownerAvatar  = "owner_avatar"
            case creatorLevel = "creator_level"
            case ownerLevel   = "owner_level"
            case isOwner      = "is_owner"
            case isCreator    = "is_creator"
            case availableAt  = "available_at"
            case isResting    = "is_resting"
        }
    }

    // MARK: - Engravings (IOS_CONTRACT §17)
    // One unsigned secret per gem, readable only by its current holder. Every rule
    // (level, holder, cooldown, length, filter) is enforced server-side.

    struct Engraving: Decodable, Identifiable, Sendable {
        let id: UUID
        let text: String
        let created_at: String
    }

    struct EngravingStatus: Decodable, Sendable {
        let eligible: Bool
        let available_at: String?
        let min_level: Int

        /// When the author's 24h engraving cooldown ends, while it's still in the future
        var restingUntil: Date? { SupabaseService.restingUntil(available_at) }
    }

    /// Live knobs; read them instead of hard-coding limits.
    struct EngravingSettings: Decodable, Sendable {
        let min_level: Int
        let cooldown_hours: Double
        let max_length: Int
    }

    struct EngraveResult: Decodable, Sendable {
        let id: UUID
        let created_at: String
        let replaced: Bool
    }

    static let engravingRestingPrefix = "Engraving is resting"

    /// The end time in "Engraving is resting — you can engrave again at <ISO>", if that's the error.
    static func engravingRestingUntil(from error: Error) -> Date? {
        let message = errorMessage(error)
        guard message.hasPrefix(engravingRestingPrefix),
              let raw = message.components(separatedBy: " at ").last else { return nil }
        return PairingCode.parseTimestamp(raw.trimmingCharacters(in: .whitespaces))
    }

    /// The server's plain message (its error texts are meant to be shown verbatim).
    static func errorMessage(_ error: Error) -> String {
        (error as? PostgrestError)?.message ?? error.localizedDescription
    }

    func engraveCoin(coinId: UUID, text: String) async throws -> EngraveResult {
        struct Params: Encodable { let p_coin_id: String; let p_text: String }
        let response = try await client
            .rpc("engrave_coin", params: Params(p_coin_id: coinId.uuidString, p_text: text))
            .execute()
        return try JSONDecoder().decode(EngraveResult.self, from: response.data)
    }

    /// Empty for gems nobody has engraved, and for anyone who doesn't hold the gem.
    func coinEngravings(coinId: UUID) async throws -> [Engraving] {
        struct Params: Encodable { let p_coin_id: String }
        let response = try await client
            .rpc("coin_engravings", params: Params(p_coin_id: coinId.uuidString))
            .execute()
        return (try? JSONDecoder().decode([Engraving].self, from: response.data)) ?? []
    }

    /// Hides the message for the current holder only; it stays for future holders.
    func hideEngraving(id: UUID) async throws {
        struct Params: Encodable { let p_engraving_id: String }
        _ = try await client
            .rpc("hide_engraving", params: Params(p_engraving_id: id.uuidString))
            .execute()
    }

    func myEngravingStatus() async throws -> EngravingStatus {
        let response = try await client.rpc("my_engraving_status").execute()
        return try JSONDecoder().decode(EngravingStatus.self, from: response.data)
    }

    func engravingSettings() async throws -> EngravingSettings {
        struct Settings: Decodable { let engraving: EngravingSettings }
        let response = try await client.rpc("gem_economy_settings").execute()
        return try JSONDecoder().decode(Settings.self, from: response.data).engraving
    }

    func coinJourney(coinID: UUID) async throws -> CoinJourneyPayload {
        struct CoinJourneyParams: Encodable {
            let p_coin_id: String
        }
        let response = try await client
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
        /// Profile photo URLs (null until the person adds one)
        var helper_avatar_url: String? = nil
        var helped_avatar_url: String? = nil
        /// Helper title levels, 0–5 (IOS_CONTRACT: helper titles)
        var helper_level: Int? = nil
        var helped_level: Int? = nil
        
        var isProposed: Bool { status == "proposed" }
        var isAccepted: Bool { status == "accepted" }
        var isCompleted: Bool { status == "completed" }
        var isTransferred: Bool { status == "transferred" }
        var isDeclined: Bool { status == "declined" }
        var isCancelled: Bool { status == "cancelled" }
    }
    
    /// Fetch favors where current user is being helped (incoming offers)
    func myIncomingFavors(userId: UUID) async throws -> [Favor] {
        let response = try await client
            .from("favors")
            .select("id,helper_id,helped_id,description,status,created_at,accepted_at,completed_at,transferred_at,coin_id,helper:profiles!favors_helper_id_fkey(display_name,avatar_url,helper_level),helped:profiles!favors_helped_id_fkey(display_name,avatar_url,helper_level)")
            .eq("helped_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        let rawFavors = try decoder.decode([RawFavor].self, from: response.data)
        return rawFavors.map { $0.toFavor() }
    }
    
    /// Fetch favors where current user is the helper (outgoing offers)
    func myOutgoingFavors(userId: UUID) async throws -> [Favor] {
        let response = try await client
            .from("favors")
            .select("id,helper_id,helped_id,description,status,created_at,accepted_at,completed_at,transferred_at,coin_id,helper:profiles!favors_helper_id_fkey(display_name,avatar_url,helper_level),helped:profiles!favors_helped_id_fkey(display_name,avatar_url,helper_level)")
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
        
        let response = try await client
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
        
        _ = try await client
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
        
        _ = try await client
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
        
        _ = try await client
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
        
        _ = try await client
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
        
        _ = try await client
            .rpc("transfer_coin", params: TransferParams(
                p_favor_id: favorId.uuidString,
                p_coin_id: coinId.uuidString
            ))
            .execute()
    }
    
    
    // MARK: - Connections/Users
    struct UserProfile: Decodable, Identifiable, Sendable {
        let id: UUID
        let display_name: String?
        let created_at: String?
        var avatar_url: String? = nil
        /// Helper title level 0–5; never goes down
        var helper_level: Int? = nil
        /// Distinct people who confirmed a favor this user did (completed or paid)
        var people_helped: Int? = nil
        /// When the current level was reached (null at level 0)
        var helper_level_at: String? = nil
        /// Set once the account was deleted (the row stays so shared journeys still read)
        var deleted_at: String? = nil
        
        var displayName: String {
            display_name ?? "Unknown User"
        }
    }
    
    /// Search for users by display name
    func searchUsers(query: String) async throws -> [UserProfile] {
        let response = try await client
            .from("profiles")
            .select("id,display_name,created_at,avatar_url,helper_level")
            .ilike("display_name", pattern: "%\(query)%")
            .limit(20)
            .execute()
        
        return try JSONDecoder().decode([UserProfile].self, from: response.data)
    }
    
    /// Get users you've interacted with (exchanged favors with)
    // MARK: - Profile photo (IOS_CONTRACT §11a)

    /// Uploads a square 512×512 JPEG to avatars/{uid}/avatar.jpg (overwriting), then
    /// records it with set_avatar. Returns the versioned public URL.
    func uploadAvatar(jpeg: Data, userId: UUID) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        try await client.storage.from("avatars")
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: true))
        struct Params: Encodable { let p_path: String }
        let response = try await client
            .rpc("set_avatar", params: Params(p_path: path))
            .execute()
        return try JSONDecoder().decode(String.self, from: response.data)
    }

    /// Back to initials (clear_avatar). The stored file is left; the column is the truth.
    func clearAvatar() async throws {
        _ = try await client.rpc("clear_avatar").execute()
    }

    // MARK: - Push device tokens

    /// Registers this device's APNs token for the signed-in user (register_device).
    /// The backend (owned by the web project, see its PUSH_CONTRACT.md) sends pushes from
    /// a database webhook — the app never calls notify-favor itself.
    func registerDevice(token: String, environment: String) async throws {
        struct Params: Encodable { let p_token: String; let p_environment: String; let p_platform: String }
        _ = try await client
            .rpc("register_device", params: Params(p_token: token, p_environment: environment, p_platform: "ios"))
            .execute()
    }

    /// Removes this device's token for the signed-in user (unregister_device).
    func unregisterDevice(token: String) async throws {
        struct Params: Encodable { let p_token: String }
        _ = try await client
            .rpc("unregister_device", params: Params(p_token: token))
            .execute()
    }

    /// A gem's current name, or nil if it can't be read.
    func coinName(coinId: UUID) async throws -> String? {
        struct Row: Decodable { let name: String? }
        let response = try await client
            .from("coins")
            .select("name")
            .eq("id", value: coinId.uuidString)
            .limit(1)
            .execute()
        return try JSONDecoder().decode([Row].self, from: response.data).first?.name
    }

    /// A user's display name, or nil if it can't be read.
    func displayName(userId: UUID) async throws -> String? {
        struct Row: Decodable { let display_name: String? }
        let response = try await client
            .from("profiles")
            .select("display_name")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
        return try JSONDecoder().decode([Row].self, from: response.data).first?.display_name
    }

    /// Renames a gem (rename_coin). Only the gem's original creator may rename it;
    /// the server trims/collapses whitespace, enforces 1–40 characters, and returns
    /// the name exactly as stored.
    func renameCoin(coinId: UUID, name: String) async throws -> String {
        struct RenameParams: Encodable {
            let p_coin_id: String
            let p_name: String
        }
        let response = try await client
            .rpc("rename_coin", params: RenameParams(p_coin_id: coinId.uuidString, p_name: name))
            .execute()
        return try JSONDecoder().decode(String.self, from: response.data)
    }

    /// Everyone the user is connected with — the people propose_favor allows them to help.
    /// `connections` stores each pair once, ordered (user_a < user_b), so the user can be on either side.
    func myConnections(userId: UUID) async throws -> [UserProfile] {
        struct ConnectionRow: Decodable {
            let user_a: UUID
            let user_b: UUID
        }

        let rowsResponse = try await client
            .from("connections")
            .select("user_a,user_b")
            .or("user_a.eq.\(userId.uuidString),user_b.eq.\(userId.uuidString)")
            .execute()
        let rows = try JSONDecoder().decode([ConnectionRow].self, from: rowsResponse.data)

        let otherIds = Set(rows.map { $0.user_a == userId ? $0.user_b : $0.user_a })
        guard !otherIds.isEmpty else { return [] }

        let profilesResponse = try await client
            .from("profiles")
            .select("id,display_name,created_at,avatar_url,helper_level")
            .in("id", values: otherIds.map(\.uuidString))
            .execute()
        return try JSONDecoder().decode([UserProfile].self, from: profilesResponse.data)
    }

    // MARK: - Pairing (PAIRING_CONTRACT)
    // Codes are created and redeemed only through the two SECURITY DEFINER RPCs;
    // neither `pairing_codes` nor `connections` accepts client writes.

    /// A short-lived invitation. `code` is the primary key; `expires_at` is the authority.
    struct PairingCode: Decodable, Equatable, Sendable {
        let code: String
        let expires_at: String

        var expiresAt: Date? { Self.parseTimestamp(expires_at) }

        /// Postgres timestamps arrive with or without fractional seconds.
        nonisolated static func parseTimestamp(_ raw: String) -> Date? {
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        }
    }

    /// Someone you are paired with: one `connections` row resolved to the other person.
    struct CircleMember: Identifiable, Sendable {
        let id: UUID            // the other person's user id
        let displayName: String
        let avatarURL: String?
        var helperLevel: Int? = nil
        let pairedAt: String    // connections.created_at — the pairing date
    }

    /// Creates a fresh code, expiring any live one you already hold.
    func createPairingCode() async throws -> PairingCode {
        let response = try await client.rpc("create_pairing_code").execute()
        // Returned as a single-row table: (code, expires_at)
        if let rows = try? JSONDecoder().decode([PairingCode].self, from: response.data), let first = rows.first {
            return first
        }
        return try JSONDecoder().decode(PairingCode.self, from: response.data)
    }

    /// Your still-valid code, if any, so a relaunch doesn't silently replace the QR someone is scanning.
    func activePairingCode(userId: UUID) async throws -> PairingCode? {
        let response = try await client
            .from("pairing_codes")
            .select("code,expires_at")
            .eq("user_id", value: userId.uuidString)
            .is("used_by", value: nil)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
        return try JSONDecoder().decode([PairingCode].self, from: response.data).first
    }

    /// Who redeemed one of your codes (nil while unused). Reads a row you own.
    func pairingCodeRedeemer(code: String) async throws -> UUID? {
        struct Row: Decodable { let used_by: UUID? }
        let response = try await client
            .from("pairing_codes")
            .select("used_by")
            .eq("code", value: code)
            .limit(1)
            .execute()
        return try JSONDecoder().decode([Row].self, from: response.data).first?.used_by
    }

    /// Redeems someone else's code. Returns the other person's user id — also when you
    /// were already paired (the code is burnt either way).
    func redeemPairingCode(_ code: String) async throws -> UUID {
        struct Params: Encodable { let p_code: String }
        let response = try await client
            .rpc("redeem_pairing_code", params: Params(p_code: code))
            .execute()
        return try JSONDecoder().decode(UUID.self, from: response.data)
    }

    /// "People you are paired with": real pairings only, newest first.
    /// Deliberately not `get_connected_users`, which also includes favor counterparties.
    func myCircle(userId: UUID) async throws -> [CircleMember] {
        struct ConnectionRow: Decodable {
            let user_a: UUID
            let user_b: UUID
            let created_at: String
        }
        let rowsResponse = try await client
            .from("connections")
            .select("id,user_a,user_b,created_at")
            .order("created_at", ascending: false)
            .execute()
        let rows = try JSONDecoder().decode([ConnectionRow].self, from: rowsResponse.data)
        guard !rows.isEmpty else { return [] }

        let others = rows.map { (id: $0.user_a == userId ? $0.user_b : $0.user_a, pairedAt: $0.created_at) }
        let profilesResponse = try await client
            .from("profiles")
            .select("id,display_name,created_at,avatar_url,helper_level")
            .in("id", values: others.map(\.id.uuidString))
            .execute()
        let profiles = try JSONDecoder().decode([UserProfile].self, from: profilesResponse.data)
        let byId = Dictionary(profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return others.map { other in
            let profile = byId[other.id]
            let name = profile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CircleMember(
                id: other.id,
                displayName: name.isEmpty ? "Someone" : name,
                avatarURL: profile?.avatar_url,
                helperLevel: profile?.helper_level,
                pairedAt: other.pairedAt
            )
        }
    }

    func getConnectedUsers(userId: UUID, limit: Int = 10) async throws -> [UserProfile] {
        struct RPCParams: Encodable {
            let p_user_id: String
            let p_limit: Int
        }
        
        // Get unique user IDs from favors where current user was either helper or helped
        let response = try await client
            .rpc("get_connected_users", params: RPCParams(
                p_user_id: userId.uuidString,
                p_limit: limit
            ))
            .execute()
        
        return try JSONDecoder().decode([UserProfile].self, from: response.data)
    }
    
    /// Get a specific user profile
    func getUserProfile(userId: UUID) async throws -> UserProfile {
        let response = try await client
            .from("profiles")
            .select("id,display_name,created_at,avatar_url,helper_level,people_helped,helper_level_at,deleted_at")
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
        
        return try JSONDecoder().decode(UserProfile.self, from: response.data)
    }
    
    /// Gems by id (e.g. one that just arrived, for showing its art)
    func coins(ids: [UUID]) async throws -> [CoinSummary] {
        guard !ids.isEmpty else { return [] }
        let response = try await client
            .from("coins")
            .select("id,serial,name,transfer_count,creator_id,owner_id,created_at,dna,available_at")
            .in("id", values: ids.map(\.uuidString))
            .execute()
        return try JSONDecoder().decode([CoinSummary].self, from: response.data)
    }

    // MARK: - Reporting & Blocking (IOS_CONTRACT §18, App Store 1.2)

    enum ReportTarget: String, Sendable { case user, favor, engraving }

    enum ReportReason: String, CaseIterable, Identifiable, Sendable {
        case harassment, scam_or_nonpayment, inappropriate, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .harassment:         "Harassment or bullying"
            case .scam_or_nonpayment: "Scam or didn\u{2019}t keep their word"
            case .inappropriate:      "Inappropriate content"
            case .other:              "Something else"
            }
        }
    }

    /// Write-only: there's no way to read reports back. The server resolves engraving authors.
    func reportContent(target: ReportTarget, targetId: UUID, reason: ReportReason, details: String?) async throws {
        struct Params: Encodable {
            let p_target_kind: String
            let p_target_id: String
            let p_reason: String
            let p_details: String?
        }
        _ = try await client
            .rpc("report_content", params: Params(p_target_kind: target.rawValue, p_target_id: targetId.uuidString,
                                                 p_reason: reason.rawValue, p_details: details))
            .execute()
    }

    struct BlockResult: Decodable, Sendable {
        let blocked: Bool?
        let cancelled_favors: Int?
    }

    struct BlockedPerson: Decodable, Identifiable, Sendable {
        let user_id: UUID
        let display_name: String?
        let avatar_url: String?
        let blocked_at: String?
        var id: UUID { user_id }
    }

    /// Hides the connection both ways and cancels every open favor between you.
    func blockUser(_ userId: UUID) async throws -> BlockResult {
        struct Params: Encodable { let p_user_id: String }
        let response = try await client
            .rpc("block_user", params: Params(p_user_id: userId.uuidString))
            .execute()
        return try JSONDecoder().decode(BlockResult.self, from: response.data)
    }

    func unblockUser(_ userId: UUID) async throws {
        struct Params: Encodable { let p_user_id: String }
        _ = try await client
            .rpc("unblock_user", params: Params(p_user_id: userId.uuidString))
            .execute()
    }

    func myBlocks() async throws -> [BlockedPerson] {
        let response = try await client.rpc("my_blocks").execute()
        return try JSONDecoder().decode([BlockedPerson].self, from: response.data)
    }

    // MARK: - Account pause (IOS_CONTRACT §19.5)

    /// The signed-in user's active pause. `reason` is deliberately not decoded: it's a
    /// staff-only note that can name the reporter and quote them (§19 iOS handoff §4).
    struct AccountPause: Decodable, Equatable, Sendable {
        let muted_until: String?
        let paused_since: String?

        /// nil = paused until a person lifts it
        var until: Date? { muted_until.flatMap(PairingCode.parseTimestamp) }

        /// Still in force at `date` (an open-ended pause always is)
        func isActive(at date: Date = .now) -> Bool {
            until.map { $0 > date } ?? true
        }
    }

    /// Zero rows when not paused; the function returns a table, so it arrives as an array.
    func myPause() async throws -> AccountPause? {
        let response = try await client.rpc("my_pause").execute()
        return try JSONDecoder().decode([AccountPause].self, from: response.data).first
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
            let avatar_url: String?
            var helper_level: Int? = nil
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
                helped_name: helped?.display_name,
                helper_avatar_url: helper?.avatar_url,
                helped_avatar_url: helped?.avatar_url,
                helper_level: helper?.helper_level,
                helped_level: helped?.helper_level
            )
        }
    }
}

