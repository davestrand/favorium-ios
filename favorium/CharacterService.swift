//
//  CharacterService.swift
//  favorium
//
//  Characters, the Quest Board, inventory and actions (QUESTS_CONTRACT v1.1).
//  Everything is server-owned: the words, the board draw and the rendered
//  description all come from Postgres, so iOS, web and Android read the same text.
//  Server error texts are shown verbatim.
//

import Foundation
import Supabase

// MARK: - Lenient decoding

/// Lets a decoder try several key spellings. Some v1.1 payloads (inventory, actions
/// received, quest history) aren't pinned down in the contract yet, so these models
/// accept the likely names instead of failing the whole screen.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where Key == AnyKey {
    func first<T: Decodable>(_ type: T.Type, _ keys: String...) -> T? {
        for key in keys {
            if let value = try? decodeIfPresent(T.self, forKey: AnyKey(key)) { return value }
        }
        return nil
    }
}

// MARK: - Models

/// One word or item from `catalog()`. `key` is permanent; `text` may change.
struct CatalogEntry: Decodable, Identifiable, Hashable, Sendable {
    let key: String
    let kind: String
    let text: String
    var flavor: String? = nil
    var slot: String? = nil
    var rarity: String? = nil
    var directed: Bool? = nil
    var sort: Int? = nil
    var active: Bool? = nil

    var id: String { key }
}

/// The kinds every member may choose from at creation (free)
enum AppearanceKind: String, CaseIterable, Identifiable {
    case height, build, eyes, skin, hair_color, hair_length
    var id: String { rawValue }

    var label: String {
        switch self {
        case .height:      "Height"
        case .build:       "Build"
        case .eyes:        "Eyes"
        case .skin:        "Skin"
        case .hair_color:  "Hair color"
        case .hair_length: "Hair length"
        }
    }
}

enum Pronouns: String, CaseIterable, Identifiable {
    case he, she, they
    var id: String { rawValue }
    var label: String {
        switch self {
        case .he:   "He / him"
        case .she:  "She / her"
        case .they: "They / them"
        }
    }
}

/// The places an unlock can be shown on the description
enum ShownSlot: String, CaseIterable, Identifiable {
    case look, rep_1, rep_2, hairstyle, outer, head, accessory, held
    var id: String { rawValue }

    var label: String {
        switch self {
        case .look:      "Look"
        case .rep_1:     "Known to be"
        case .rep_2:     "Known to be (second)"
        case .hairstyle: "Hairstyle"
        case .outer:     "Cloak or coat"
        case .head:      "Headwear"
        case .accessory: "Accessory"
        case .held:      "Holding"
        }
    }

    /// Whether an unlock of this catalog kind (and clothing slot) fits here
    func accepts(kind: String, slot: String?) -> Bool {
        switch self {
        case .look:                     kind == "look_term"
        case .rep_1, .rep_2:            kind == "rep_term"
        case .hairstyle:                kind == "hairstyle"
        case .outer, .head, .accessory: kind == "clothing" && slot == rawValue
        case .held:                     kind == "held"
        }
    }
}

struct PlayerCharacter: Decodable, Identifiable, Sendable {
    let id: UUID
    var pronouns: String? = nil
    var race_key: String? = nil
    var height_key: String? = nil
    var build_key: String? = nil
    var eyes_key: String? = nil
    var skin_key: String? = nil
    var hair_color_key: String? = nil
    var hair_length_key: String? = nil

    func key(for kind: AppearanceKind) -> String? {
        switch kind {
        case .height:      height_key
        case .build:       build_key
        case .eyes:        eyes_key
        case .skin:        skin_key
        case .hair_color:  hair_color_key
        case .hair_length: hair_length_key
        }
    }
}

struct ShownUnlock: Decodable, Sendable {
    let slot: String
    let unlock_id: UUID
    var unlock_key: String? = nil
    var kind: String? = nil
    var text: String? = nil
}

struct MyCharacter: Decodable, Sendable {
    let character: PlayerCharacter?
    var shown: [ShownUnlock] = []

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        character = c.first(PlayerCharacter.self, "character")
        shown = c.first([ShownUnlock].self, "shown") ?? []
    }
}

struct QuestUnlock: Decodable, Hashable, Sendable {
    let key: String
    let kind: String
    let text: String
    var rarity: String? = nil
}

/// `quest_payload`: the same shape wherever the server returns a quest
struct Quest: Decodable, Identifiable, Sendable {
    let user_quest_id: UUID
    let status: String          // posted | accepted | completed | not_taken | expired | abandoned
    let title: String
    let prompt: String
    var expires_at: String? = nil
    var completed_at: String? = nil
    var favor_id: UUID? = nil
    var visit_label: String? = nil
    let unlock: QuestUnlock

    var id: UUID { user_quest_id }
    var isPosted: Bool { status == "posted" }
    var isAccepted: Bool { status == "accepted" }
    var expiresAt: Date? { expires_at.flatMap(SupabaseService.PairingCode.parseTimestamp) }
}

struct Visit: Decodable, Sendable {
    let name: String
    let intro: String
    let label: String
    let ends_at: String
    var grace_ends_at: String? = nil
    var quests: [Quest] = []

    var endsAt: Date? { SupabaseService.PairingCode.parseTimestamp(ends_at) }
}

struct QuestBoard: Decodable, Sendable {
    var week_starts_at: String? = nil
    var next_refresh_at: String? = nil
    var quests: [Quest] = []
    var visit: Visit? = nil

    var nextRefresh: Date? { next_refresh_at.flatMap(SupabaseService.PairingCode.parseTimestamp) }
}

/// One held unlock, with where it came from (`my_inventory`)
struct InventoryItem: Decodable, Identifiable, Sendable {
    let id: UUID
    let key: String
    let kind: String
    let text: String
    let slot: String?           // clothing slot from the catalog
    let rarity: String?
    let questTitle: String?
    let visitLabel: String?
    let earnedAt: String?
    let shownIn: String?        // the description slot currently showing it
    /// Which of your characters has this object on; nil = in the backpack. Traits and
    /// gestures are never "worn by" anyone in this sense.
    let wornByCharacterId: UUID?

    /// Traits are things a character *is*: any number of characters may share one
    var isTrait: Bool { ["look_term", "rep_term", "hairstyle"].contains(kind) }
    /// Objects are single physical things: one character at a time (QUESTS_CONTRACT v1.2)
    var isObject: Bool { kind == "clothing" || kind == "held" }
    var isGesture: Bool { kind == "action" }
    var isInBackpack: Bool { isObject && wornByCharacterId == nil }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard let id = c.first(UUID.self, "unlock_id", "id") else {
            throw DecodingError.keyNotFound(AnyKey("unlock_id"), .init(codingPath: c.codingPath, debugDescription: "No unlock id"))
        }
        self.id = id
        key = c.first(String.self, "unlock_key", "key") ?? ""
        kind = c.first(String.self, "kind") ?? ""
        text = c.first(String.self, "text") ?? ""
        slot = c.first(String.self, "catalog_slot", "slot")
        rarity = c.first(String.self, "rarity")
        questTitle = c.first(String.self, "quest_title")
        visitLabel = c.first(String.self, "visit_label")
        earnedAt = c.first(String.self, "earned_at")
        shownIn = c.first(String.self, "shown_slot", "shown_in")
        wornByCharacterId = c.first(UUID.self, "worn_by_character_id")
    }
}

struct ActionReceived: Decodable, Identifiable, Sendable {
    let id: String
    let fromUserId: UUID?
    let fromName: String?
    let rendered: String
    let createdAt: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        fromUserId = c.first(UUID.self, "from_user_id")
        fromName = c.first(String.self, "from_name")
        rendered = c.first(String.self, "rendered", "text") ?? ""
        createdAt = c.first(String.self, "created_at")
        id = c.first(UUID.self, "id")?.uuidString ?? "\(fromUserId?.uuidString ?? "")-\(createdAt ?? rendered)"
    }
}

struct QuestSettings: Decodable, Sendable {
    var max_characters: Int = 1
    var board_size: Int = 5
}

// MARK: - RPCs

extension SupabaseService {
    func catalog() async throws -> [CatalogEntry] {
        let response = try await client.rpc("catalog").execute()
        return try JSONDecoder().decode([CatalogEntry].self, from: response.data)
            .filter { $0.active ?? true }
            .sorted { ($0.sort ?? 0) < ($1.sort ?? 0) }
    }

    func questSettings() async throws -> QuestSettings {
        let response = try await client.rpc("quest_settings").execute()
        return try JSONDecoder().decode(QuestSettings.self, from: response.data)
    }

    func myCharacter() async throws -> MyCharacter {
        let response = try await client.rpc("my_character").execute()
        return try JSONDecoder().decode(MyCharacter.self, from: response.data)
    }

    /// Appearance parameters shared by create and update. Unset choices go as null.
    struct AppearanceParams: Encodable {
        let p_pronouns: String
        let p_height_key: String?
        let p_build_key: String?
        let p_eyes_key: String?
        let p_skin_key: String?
        let p_hair_color_key: String?
        let p_hair_length_key: String?

        init(pronouns: Pronouns, choices: [AppearanceKind: String]) {
            p_pronouns = pronouns.rawValue
            p_height_key = choices[.height]
            p_build_key = choices[.build]
            p_eyes_key = choices[.eyes]
            p_skin_key = choices[.skin]
            p_hair_color_key = choices[.hair_color]
            p_hair_length_key = choices[.hair_length]
        }

        // Nulls are sent explicitly so a cleared choice is cleared on the server
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: AnyKey.self)
            try c.encode(p_pronouns, forKey: AnyKey("p_pronouns"))
            try c.encode(p_height_key, forKey: AnyKey("p_height_key"))
            try c.encode(p_build_key, forKey: AnyKey("p_build_key"))
            try c.encode(p_eyes_key, forKey: AnyKey("p_eyes_key"))
            try c.encode(p_skin_key, forKey: AnyKey("p_skin_key"))
            try c.encode(p_hair_color_key, forKey: AnyKey("p_hair_color_key"))
            try c.encode(p_hair_length_key, forKey: AnyKey("p_hair_length_key"))
        }
    }

    /// Race is permanent: it's only ever sent here.
    func createCharacter(raceKey: String, appearance: AppearanceParams) async throws {
        struct Params: Encodable {
            let race: String
            let appearance: AppearanceParams
            func encode(to encoder: Encoder) throws {
                try appearance.encode(to: encoder)
                var c = encoder.container(keyedBy: AnyKey.self)
                try c.encode(race, forKey: AnyKey("p_race_key"))
            }
        }
        _ = try await client.rpc("create_character", params: Params(race: raceKey, appearance: appearance)).execute()
    }

    func updateCharacterAppearance(characterId: UUID, appearance: AppearanceParams) async throws {
        struct Params: Encodable {
            let id: UUID
            let appearance: AppearanceParams
            func encode(to encoder: Encoder) throws {
                try appearance.encode(to: encoder)
                var c = encoder.container(keyedBy: AnyKey.self)
                try c.encode(id.uuidString, forKey: AnyKey("p_character_id"))
            }
        }
        _ = try await client.rpc("update_character_appearance", params: Params(id: characterId, appearance: appearance)).execute()
    }

    /// `unlockId == nil` clears the slot
    func setShown(characterId: UUID, slot: ShownSlot, unlockId: UUID?) async throws {
        struct Params: Encodable {
            let p_character_id: String
            let p_slot: String
            let p_unlock_id: String?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: AnyKey.self)
                try c.encode(p_character_id, forKey: AnyKey("p_character_id"))
                try c.encode(p_slot, forKey: AnyKey("p_slot"))
                try c.encode(p_unlock_id, forKey: AnyKey("p_unlock_id"))
            }
        }
        _ = try await client
            .rpc("set_shown", params: Params(p_character_id: characterId.uuidString, p_slot: slot.rawValue,
                                             p_unlock_id: unlockId?.uuidString))
            .execute()
    }

    /// The rendered `LOOK` lines. A member with no character gets just "You see <name>."
    func characterDescription(userId: UUID) async throws -> [String] {
        struct Params: Encodable { let p_user_id: String }
        let response = try await client
            .rpc("character_description", params: Params(p_user_id: userId.uuidString))
            .execute()
        return try JSONDecoder().decode([String].self, from: response.data)
    }

    // Board and quests

    func myBoard() async throws -> QuestBoard {
        let response = try await client.rpc("my_board").execute()
        return try JSONDecoder().decode(QuestBoard.self, from: response.data)
    }

    /// Accepted quests plus history. Accepts either a flat array or an object of arrays.
    func myQuests() async throws -> [Quest] {
        let response = try await client.rpc("my_quests").execute()
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([Quest].self, from: response.data) { return list }
        let groups = try decoder.decode([String: [Quest]].self, from: response.data)
        return groups.values.flatMap { $0 }
    }

    func acceptQuest(_ id: UUID) async throws {
        struct Params: Encodable { let p_user_quest_id: String }
        _ = try await client.rpc("accept_quest", params: Params(p_user_quest_id: id.uuidString)).execute()
    }

    func abandonQuest(_ id: UUID) async throws {
        struct Params: Encodable { let p_user_quest_id: String }
        _ = try await client.rpc("abandon_quest", params: Params(p_user_quest_id: id.uuidString)).execute()
    }

    /// The board refreshes at the member's local Monday midnight, so the server needs the zone.
    func setTimeZone(_ identifier: String) async throws {
        struct Params: Encodable { let p_tz: String }
        _ = try await client.rpc("set_time_zone", params: Params(p_tz: identifier)).execute()
    }

    /// Opt-in for the Monday and visitor pushes (promotional, so off by default)
    func setQuestPush(_ enabled: Bool) async throws {
        struct Params: Encodable { let p_enabled: Bool }
        _ = try await client.rpc("set_quest_push", params: Params(p_enabled: enabled)).execute()
    }

    // Inventory and actions

    func myInventory() async throws -> [InventoryItem] {
        let response = try await client.rpc("my_inventory").execute()
        return try JSONDecoder().decode([InventoryItem].self, from: response.data)
    }

    func dropUnlock(_ id: UUID) async throws {
        struct Params: Encodable { let p_unlock_id: String }
        _ = try await client.rpc("drop_unlock", params: Params(p_unlock_id: id.uuidString)).execute()
    }

    /// Returns the rendered line, e.g. "Dave bows his head to you."
    func sendAction(to userId: UUID, actionUnlockId: UUID) async throws -> String? {
        struct Params: Encodable { let p_to_user_id: String; let p_action_unlock_id: String }
        struct Result: Decodable { let rendered: String? }
        let response = try await client
            .rpc("send_action", params: Params(p_to_user_id: userId.uuidString, p_action_unlock_id: actionUnlockId.uuidString))
            .execute()
        return (try? JSONDecoder().decode(Result.self, from: response.data))?.rendered
    }

    func myActionsReceived() async throws -> [ActionReceived] {
        let response = try await client.rpc("my_actions_received").execute()
        return try JSONDecoder().decode([ActionReceived].self, from: response.data)
    }
}
