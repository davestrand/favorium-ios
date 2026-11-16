//
//  HallService.swift
//  favorium
//
//  The rooms (QUESTS_CONTRACT §10, §10.6 and §10.7): the Hall and the rooms off it,
//  presence with sneak and a room key, scenery you can examine and one small act
//  per room, gestures at whoever stands with you, and the log of gestures toward
//  you. All copy is server-authored and shown verbatim.
//

import Foundation
import Supabase

// MARK: - Models

/// Someone standing in the hall. Sneaking members are never listed, except yourself.
struct HallPerson: Decodable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let avatarURL: String?
    let enteredAt: String?
    let isMe: Bool
    let connected: Bool
    let sneaking: Bool
    /// Their drawn gesture as a sentence fragment ("Tips their hat"): identity, not a button
    let signature: String?
    /// `character_description()` verbatim; the first line already carries name and title
    let description: [String]
    /// The room they walked in from, when they came from another room
    let arrivedFrom: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        guard let id = c.first(UUID.self, "user_id") else {
            throw DecodingError.keyNotFound(AnyKey("user_id"), .init(codingPath: c.codingPath, debugDescription: "No user id"))
        }
        self.id = id
        name = c.first(String.self, "name") ?? ""
        avatarURL = c.first(String.self, "avatar_url")
        enteredAt = c.first(String.self, "entered_at")
        isMe = c.first(Bool.self, "is_me") ?? false
        connected = c.first(Bool.self, "connected") ?? false
        sneaking = c.first(Bool.self, "sneaking") ?? false
        signature = c.first(String.self, "signature")
        description = c.first([String].self, "description") ?? []
        arrivedFrom = c.first(String.self, "arrived_from")
    }
}

struct HallMe: Decodable, Sendable {
    var present: Bool? = nil
    var room_key: String? = nil
    /// Standing in the room this payload describes
    var in_room: Bool? = nil
    var sneaking: Bool? = nil
    var has_character: Bool? = nil
}

/// A way out of a room. `label` is authored ("the door back into the Hall").
struct RoomExit: Decodable, Identifiable, Sendable {
    let key: String
    let label: String
    /// On the way back to the Hall: how many new notices are on the board. Never about people.
    var board_new: Int? = nil
    var id: String { key }
}

/// What you see when you examine a piece of scenery
struct RoomObjectLook: Decodable, Sendable {
    let name: String
    let look: String
    var detail: String? = nil
}

/// The one small thing a room lets you do, attached to an object
struct RoomObjectAction: Decodable, Identifiable, Sendable {
    let name: String
    let key: String
    let label: String
    var line: String? = nil
    var id: String { "\(name)|\(key)" }
}

/// `room_view()`: one room, assembled on the server. With no key: the room you're
/// standing in, or the Hall if you aren't anywhere. Board fields only ever come in
/// the Hall, to someone standing in it.
struct HallRoom: Decodable, Sendable {
    var key: String? = nil
    var title: String? = nil
    var intro: [String]? = nil
    var ambience: [String]? = nil
    var week_starts_at: String? = nil
    var next_refresh_at: String? = nil
    var quests: [Quest]? = nil
    var history: [Quest]? = nil
    var visit: Visit? = nil
    var present: [HallPerson]? = nil
    var me: HallMe? = nil
    var free_actions: [String]? = nil
    var stranger_daily_limit: Int? = nil
    var presence_ttl_seconds: Int? = nil
    var heartbeat_seconds: Int? = nil
    var exits: [RoomExit]? = nil
    /// Scenery names, verbatim; looks and acts match them by name
    var objects: [String]? = nil
    var object_looks: [RoomObjectLook]? = nil
    var object_actions: [RoomObjectAction]? = nil
    var act_cooldown_seconds: Int? = nil
    /// New notices on the Hall's board, so a doorway or a side room can hint at it
    var board_new: Int? = nil

    var roomKey: String { key ?? "hall" }
    var isHall: Bool { roomKey == "hall" }
    /// Standing in this room (not just somewhere)
    var inRoom: Bool { me?.in_room ?? (isPresent && (me?.room_key ?? roomKey) == roomKey) }

    var weekStarts: Date? { week_starts_at.flatMap(SupabaseService.PairingCode.parseTimestamp) }
    var nextRefresh: Date? { next_refresh_at.flatMap(SupabaseService.PairingCode.parseTimestamp) }
    var isPresent: Bool { me?.present ?? false }
    var isSneaking: Bool { me?.sneaking ?? false }
    var hasCharacter: Bool { me?.has_character ?? false }
}

/// One entry of the gesture menu. `label` is the sender's wording, `text` the receiver's.
struct HallGesture: Decodable, Identifiable, Sendable {
    let key: String
    let label: String
    let text: String
    var free: Bool? = nil
    var owned: Bool? = nil

    var id: String { key }
    var isFree: Bool { free ?? false }
    var isAvailable: Bool { isFree || (owned ?? false) }
}

struct HallSendResult: Decodable, Sendable {
    /// The receiver's sentence ("…to you.")
    var rendered: String? = nil
    /// The sender's own line, naming the recipient (QUESTS_CONTRACT §7.10)
    var rendered_sender: String? = nil
    var connected: Bool? = nil
    var stranger: Bool? = nil
    var room_key: String? = nil
}

/// A gesture someone made toward you; it waits here until you mark it read.
struct HallReceivedAction: Decodable, Identifiable, Sendable {
    let id: UUID
    var from_user_id: UUID? = nil
    var from_name: String? = nil
    var from_avatar: String? = nil
    var unlock_key: String? = nil
    let rendered: String
    var created_at: String? = nil
    var seen: Bool? = nil
    var connected: Bool? = nil

    var isNew: Bool { !(seen ?? true) }
    var createdAt: Date? { created_at.flatMap(SupabaseService.PairingCode.parseTimestamp) }
}

struct HallReceivedLog: Decodable, Sendable {
    var unseen: Int? = nil
    var items: [HallReceivedAction]? = nil
}

/// `room_listen()`: voices per room, counts only, never names. The room you're in is left out.
struct RoomListen: Decodable, Sendable {
    struct Row: Decodable, Identifiable, Sendable {
        let key: String
        let title: String
        var voices: Int? = nil
        var id: String { key }
    }
    var here: String? = nil
    var rooms: [Row]? = nil
    /// The exit label back to the Hall; null in the Hall
    var way_to_hall: String? = nil
}

struct RoomActResult: Decodable, Sendable {
    let ok: Bool
    var rendered: String? = nil
    var message: String? = nil
    var cooldown_seconds: Int? = nil
    var retry_after_seconds: Int? = nil
}

// MARK: - RPCs

extension SupabaseService {
    func hallRoom() async throws -> HallRoom {
        let response = try await client.rpc("hall_room").execute()
        return try JSONDecoder().decode(HallRoom.self, from: response.data)
    }

    /// Creates or refreshes presence; refuses without an active character
    func hallEnter(sneak: Bool) async throws {
        struct Params: Encodable { let p_sneak: Bool }
        _ = try await client.rpc("hall_enter", params: Params(p_sneak: sneak)).execute()
    }

    func hallLeave() async throws {
        _ = try await client.rpc("hall_leave").execute()
    }

    /// `sneak == nil` leaves the sneak state alone
    func hallHeartbeat(sneak: Bool? = nil) async throws {
        if let sneak {
            struct Params: Encodable { let p_sneak: Bool }
            _ = try await client.rpc("hall_heartbeat", params: Params(p_sneak: sneak)).execute()
        } else {
            _ = try await client.rpc("hall_heartbeat").execute()
        }
    }

    func hallGestures() async throws -> [HallGesture] {
        let response = try await client.rpc("hall_gestures").execute()
        return try JSONDecoder().decode([HallGesture].self, from: response.data)
    }

    /// Returns the finished sentence, e.g. "Dave bows his head to you."
    func hallSendAction(to userId: UUID, actionKey: String) async throws -> HallSendResult {
        struct Params: Encodable { let p_to_user_id: String; let p_action_key: String }
        let response = try await client
            .rpc("hall_send_action", params: Params(p_to_user_id: userId.uuidString, p_action_key: actionKey))
            .execute()
        return (try? JSONDecoder().decode(HallSendResult.self, from: response.data)) ?? HallSendResult()
    }

    /// Newest first; blocked senders are already left out, server-side
    func hallReceivedActions(limit: Int = 20) async throws -> HallReceivedLog {
        struct Params: Encodable { let p_limit: Int }
        let response = try await client.rpc("hall_received_actions", params: Params(p_limit: limit)).execute()
        return try JSONDecoder().decode(HallReceivedLog.self, from: response.data)
    }

    /// The room you're in (or the Hall), or a named room
    func roomView(_ key: String? = nil) async throws -> HallRoom {
        let response: PostgrestResponse<Void>
        if let key {
            struct Params: Encodable { let p_room_key: String }
            response = try await client.rpc("room_view", params: Params(p_room_key: key)).execute()
        } else {
            response = try await client.rpc("room_view").execute()
        }
        return try JSONDecoder().decode(HallRoom.self, from: response.data)
    }

    /// Walks through an exit and returns the destination, already rendered
    func roomMove(to key: String) async throws -> HallRoom {
        struct Params: Encodable { let p_room_key: String }
        let response = try await client.rpc("room_move", params: Params(p_room_key: key)).execute()
        return try JSONDecoder().decode(HallRoom.self, from: response.data)
    }

    func roomListen() async throws -> RoomListen {
        let response = try await client.rpc("room_listen").execute()
        return try JSONDecoder().decode(RoomListen.self, from: response.data)
    }

    /// Does the room's one thing. A pause comes back as `ok: false`, not as an error.
    func roomAct(object: String, actionKey: String) async throws -> RoomActResult {
        struct Params: Encodable { let p_object: String; let p_action_key: String }
        let response = try await client
            .rpc("room_act", params: Params(p_object: object, p_action_key: actionKey))
            .execute()
        return try JSONDecoder().decode(RoomActResult.self, from: response.data)
    }

    @discardableResult
    func hallMarkActionsSeen() async throws -> Int {
        let response = try await client.rpc("hall_mark_actions_seen").execute()
        return (try? JSONDecoder().decode(Int.self, from: response.data)) ?? 0
    }
}
