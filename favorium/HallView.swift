//
//  HallView.swift
//  favorium
//
//  The rooms, laid out as places you stand in (QUESTS_CONTRACT §10.7): the room's
//  own prose, the ways out, the scenery you can examine (and, in one spot, do
//  something with), and who is also here, written as one page with the things in it
//  as gold, tappable words. Everyone comes in through the Hall; the quest board is in
//  the Hall alone. Below the room, a short story of what has happened, and a bar of verbs.
//  Server copy (title, intro, ambience, descriptions, rendered gestures, refusals)
//  is shown verbatim.
//

import SwiftUI

// MARK: - Reward wording

extension QuestUnlock {
    /// "You carry a slender rowan wand", "Known to be strong", "You learn to bow your head"
    func rewardLine(gestureLabels: [String: String]) -> String {
        let readable = text.replacingOccurrences(of: "{pos}", with: "their")
        switch kind {
        case "held":      return "You carry \(readable)"
        case "clothing":  return "You wear \(readable)"
        case "rep_term":  return "Known to be \(readable)"
        case "look_term": return "You appear \(readable)"
        case "hairstyle": return "Your hair \(readable)"
        case "action":
            // The sender's own wording reads naturally after the lead-in
            if let label = gestureLabels[key] {
                return "You learn to \(label.prefix(1).lowercased() + label.dropFirst())"
            }
            return "You learn to \(readable)"
        default:          return readable
        }
    }
}

// MARK: - Story

/// One line in the story under the room: something that happened while you were here.
/// Kept on this device for the rest of the day. Gestures toward you come from the
/// server's log instead.
struct HallEvent: Identifiable, Codable, Sendable {
    var id = UUID()
    var date = Date()
    let text: String
    var isRefusal = false
    /// A room heading ("The Garden"), written when you arrive somewhere
    var isHeading: Bool? = nil
}

// MARK: - Store

/// The room you're in, the gesture menu, the log toward you and today's story. Owned
/// by ContentView so the tab can badge unread gestures.
@Observable
final class HallStore {
    var room: HallRoom?
    var gestures: [HallGesture] = []
    var received: HallReceivedLog?
    var events: [HallEvent] = []
    /// `my_quests()`: your own quests, readable from any room (the board is Hall-only)
    var myQuests: [Quest] = []
    var isRefreshing = false
    var error: String?
    /// The member stepped inside during this visit to the screen; drives heartbeats
    /// and re-entry when the app comes back to the foreground
    var wantsPresence = false
    /// The last sneak choice, reused on re-entry
    var sneak = false
    /// Description lines noticed as new on this visit, by person, for their sheet
    var freshLines: [UUID: Set<String>] = [:]

    private let service = SupabaseService.shared
    private(set) var userId: UUID?
    /// Each person's description as last seen from this device, keyed by user id
    private var knownLooks: [String: [String]] = [:]
    /// The room to come back to after the app was away long enough for presence to lapse
    private var lastRoomKey = "hall"
    /// Titles of rooms seen so far, for "Jo arrives from the Garden."
    private var roomTitles: [String: String] = [:]

    var unseen: Int { received?.unseen ?? 0 }
    var heartbeatSeconds: Int { max(15, room?.heartbeat_seconds ?? 45) }
    var hasCharacter: Bool { room?.hasCharacter ?? false }
    var isPresent: Bool { room?.isPresent ?? false }
    /// Everyone else standing in this room with you; empty outside, by design
    var others: [HallPerson] {
        guard room?.inRoom == true else { return [] }
        return (room?.present ?? []).filter { !$0.isMe }
    }

    func reset() {
        room = nil
        gestures = []
        received = nil
        events = []
        myQuests = []
        error = nil
        wantsPresence = false
        sneak = false
        freshLines = [:]
        knownLooks = [:]
        lastRoomKey = "hall"
        roomTitles = [:]
        userId = nil
    }

    /// Restores today's story and the looks remembered for this account
    func signedIn(_ id: UUID) {
        guard id != userId else { return }
        reset()
        userId = id
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.storyKey(id)),
           let saved = try? JSONDecoder().decode([HallEvent].self, from: data) {
            events = saved.filter { Calendar.current.isDateInToday($0.date) }
        }
        knownLooks = defaults.dictionary(forKey: Self.looksKey(id)) as? [String: [String]] ?? [:]
    }

    private static func storyKey(_ id: UUID) -> String { "hall.story.\(id.uuidString)" }
    private static func looksKey(_ id: UUID) -> String { "hall.looks.\(id.uuidString)" }

    func note(_ text: String, refusal: Bool = false, heading: Bool = false) {
        // Today's story, not an archive
        events = events.filter { Calendar.current.isDateInToday($0.date) }
        // Arriving in the room you're already in isn't a new heading
        if heading, let last = events.last(where: { $0.isHeading == true }), last.text == text { return }
        events.append(HallEvent(text: text, isRefusal: refusal, isHeading: heading ? true : nil))
        if events.count > 40 { events.removeFirst(events.count - 40) }
        if let userId, let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: Self.storyKey(userId))
        }
    }

    /// Accepted quests that can still be offered as a favor, from any room
    var openQuests: [Quest] {
        let all = myQuests + (room?.quests ?? []) + (room?.visit?.quests ?? [])
        var seen = Set<UUID>()
        return all.filter { quest in
            quest.isAccepted && quest.favor_id == nil
                && (quest.expiresAt.map { $0 > .now } ?? true)
                && seen.insert(quest.id).inserted
        }
    }

    func loadMyQuests() async {
        if let quests = try? await service.myQuests() { myQuests = quests }
    }

    /// Reads the room you're in again (or the Hall, from outside), keeping what's on
    /// screen if the read fails
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            show(try await service.roomView(), comings: true)
            error = nil
        } catch {
            // A read cut short by leaving the screen isn't worth reporting
            if !Task.isCancelled { self.error = SupabaseService.errorMessage(error) }
        }
        await refreshReceived()
        if gestures.isEmpty, hasCharacter { await reloadGestures() }
    }

    /// Puts a freshly read room on screen. Arrivals and departures are only worked out
    /// between two reads of the same room, so walking somewhere doesn't read as everyone
    /// else arriving.
    private func show(_ next: HallRoom, comings: Bool) {
        let before = room
        let beforeOthers = others
        room = next
        if let title = next.title { roomTitles[next.roomKey] = title }
        if next.inRoom { lastRoomKey = next.roomKey }
        if comings, let before, before.inRoom, next.inRoom, before.roomKey == next.roomKey {
            noteComings(from: beforeOthers, to: others)
        }
        noticeNewLooks(others)
    }

    /// Sneaking members are never in `present`, so they never arrive or leave here
    private func noteComings(from before: [HallPerson], to after: [HallPerson]) {
        let beforeIds = Set(before.map(\.id))
        let afterIds = Set(after.map(\.id))
        for person in after where !beforeIds.contains(person.id) {
            if let from = person.arrivedFrom, from != room?.roomKey {
                note("\(person.name) arrives from \(roomName(from)).")
            } else {
                note("\(person.name) arrives.")
            }
        }
        for person in before where !afterIds.contains(person.id) { note("\(person.name) leaves.") }
    }

    /// "the Garden", from "The Garden"; an unseen room falls back to its key
    private func roomName(_ key: String) -> String {
        let title = roomTitles[key] ?? key.replacingOccurrences(of: "_", with: " ")
        return title.hasPrefix("The ") ? "the" + title.dropFirst(3) : title
    }

    func remember(_ listen: RoomListen) {
        for row in listen.rooms ?? [] { roomTitles[row.key] = row.title }
    }

    /// Showing off should be noticed: a line that wasn't in someone's description the
    /// last time this device saw them goes into the story and is highlighted on their
    /// sheet. The first sighting is only remembered. Lines taken away pass silently.
    private func noticeNewLooks(_ people: [HallPerson]) {
        var changed = false
        for person in people where !person.description.isEmpty {
            let key = person.id.uuidString
            if let before = knownLooks[key], before != person.description {
                let fresh = person.description.filter { !before.contains($0) }
                if !fresh.isEmpty {
                    freshLines[person.id, default: []].formUnion(fresh)
                    note("You notice something new about \(person.name): \u{201C}\(fresh.prefix(2).joined(separator: " "))\u{201D}")
                }
            }
            if knownLooks[key] != person.description {
                knownLooks[key] = person.description
                changed = true
            }
        }
        if changed, let userId { UserDefaults.standard.set(knownLooks, forKey: Self.looksKey(userId)) }
    }

    func refreshReceived() async {
        if let log = try? await service.hallReceivedActions() { received = log }
    }

    func reloadGestures() async {
        if let menu = try? await service.hallGestures() { gestures = menu }
    }

    /// Always into the Hall: it's the only way in from outside
    func enter(sneak: Bool) async throws {
        try await service.hallEnter(sneak: sneak)
        self.sneak = sneak
        wantsPresence = true
        lastRoomKey = "hall"
        await refresh()
        if let title = room?.title { note(title, heading: true) }
        note(sneak ? "You slip inside, keeping to the shadows." : "You step inside.")
    }

    /// Back after presence lapsed: in through the Hall, then on to the room you were in
    func resume() async {
        guard (try? await service.hallEnter(sneak: sneak)) != nil else { return }
        if lastRoomKey != "hall", let next = try? await service.roomMove(to: lastRoomKey) {
            show(next, comings: false)
        }
    }

    /// Walks through an exit; the reply is the destination, already rendered
    func move(to key: String, via label: String?) async {
        do {
            let next = try await service.roomMove(to: key)
            note(label.map { "You go through \($0)." } ?? "You make your way to \(roomName(key)).")
            if let title = next.title { note(title, heading: true) }
            show(next, comings: false)
        } catch {
            note(SupabaseService.errorMessage(error), refusal: true)
        }
    }

    /// Clears presence now, so the card goes when the member walks away
    func leave() async {
        wantsPresence = false
        try? await service.hallLeave()
    }

    func setSneak(_ value: Bool) async throws {
        sneak = value
        guard isPresent else { return }
        try await service.hallHeartbeat(sneak: value)
        note(value ? "You draw back into the shadows." : "You step out of the shadows.")
        await refresh()
    }

    /// One beat while the screen is up and the app foregrounded. If presence lapsed
    /// anyway (a long pause), come back in and return to the same room.
    func tick() async {
        if wantsPresence {
            if room?.isPresent == false {
                await resume()
            } else {
                try? await service.hallHeartbeat()
            }
        }
        await refresh()
    }

    func act(_ action: RoomObjectAction) async throws -> RoomActResult {
        try await service.roomAct(object: action.name, actionKey: action.key)
    }

    /// Greetings go to anyone standing here; earned gestures only to a connection
    func gestures(for person: HallPerson) -> [HallGesture] {
        gestures.filter { $0.isAvailable && ($0.isFree || person.connected) }
    }

    /// Sends, and writes the outcome into the story: the rendered line, or the refusal verbatim
    func send(_ gesture: HallGesture, to person: HallPerson) async {
        do {
            let result = try await service.hallSendAction(to: person.id, actionKey: gesture.key)
            // Until the server sends the sender's own line (docs/WEB_REQUEST_2026-11-16_GESTURE_SENDER.md)
            note(result.rendered_sender ?? result.rendered.map { Self.sendersView($0, to: person.name) } ?? gesture.label)
        } catch {
            note(SupabaseService.errorMessage(error), refusal: true)
        }
    }

    /// `rendered` is the receiver's sentence ("Dave bows his head to you."). In the
    /// sender's own story the closing "you" is the person it went to; the server's verb
    /// and pronoun are kept as they are.
    static func sendersView(_ rendered: String, to name: String) -> String {
        guard let range = rendered.range(of: #"\byou\b"#, options: [.regularExpression, .backwards]) else {
            return rendered
        }
        return rendered.replacingCharacters(in: range, with: name)
    }

    func markSeen() async throws {
        try await service.hallMarkActionsSeen()
        await refreshReceived()
    }
}

// MARK: - Screen

struct HallView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var store: HallStore

    /// For the creator, your own description, the pack and the wardrobe
    @State private var characterStore = CharacterStore()
    @State private var ambienceLine: String?
    @State private var showBoard = false
    @State private var showSelf = false
    @State private var showListen = false
    @State private var lookingAt: HallPerson?
    @State private var showCreator = false
    @State private var createdCharacter = false
    @State private var showGifts = false
    @State private var presenceBusy = false
    /// The examined piece of scenery: one at a time, closed by walking elsewhere
    @State private var openObject: String?
    /// "Earlier today" unfolded
    @State private var storyExpanded = false

    private var room: HallRoom? { store.room }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                if let room {
                    page(room)
                } else if let error = store.error {
                    unreachable(error)
                } else {
                    ProgressView().tint(FavoriumTheme.accent)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { verbBar }
            .overlay(alignment: .top) { statusBarFade }
            .toolbar(.hidden, for: .navigationBar)
        }
        // The heartbeat runs only while this screen is up and the app is in front:
        // a member who isn't looking at the room isn't in it
        .task(id: scenePhase != .background) {
            await stayInRoom(foreground: scenePhase != .background)
        }
        // Walking away clears the card now, rather than when the TTL runs out
        .onDisappear {
            if store.wantsPresence { Task { await store.leave() } }
        }
        .task(id: room?.ambience ?? []) { await rotateAmbience() }
        // The thing you were looking at isn't in the next room
        .onChange(of: room?.roomKey) { _, _ in openObject = nil }
        .onChange(of: room?.inRoom) { _, _ in openObject = nil }
        .sheet(isPresented: $showBoard, onDismiss: {
            Task {
                await store.refresh()
                await store.loadMyQuests()
            }
        }) {
            HallBoardSheet(store: store).environment(appVM)
        }
        .sheet(item: $lookingAt) { person in
            HallPersonSheet(store: store, person: person)
        }
        .sheet(isPresented: $showSelf, onDismiss: { Task { await store.refresh() } }) {
            HallSelfSheet(store: store, characterStore: characterStore).environment(appVM)
        }
        .sheet(isPresented: $showListen) {
            HallListenSheet(store: store)
        }
        .sheet(isPresented: $showCreator, onDismiss: afterCreator) {
            CharacterCreatorView(store: characterStore, onCreated: { createdCharacter = true })
                .environment(appVM)
        }
        .sheet(isPresented: $showGifts) {
            HallGiftsSheet(store: store, characterStore: characterStore).environment(appVM)
        }
        // The gold words in the room are links into the room itself
        .environment(\.openURL, OpenURLAction { url in
            follow(url)
            return .handled
        })
    }

    // MARK: The page

    private func page(_ room: HallRoom) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                roomTitle(room)
                roomProse(room)
                DecoDivider()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                story
                    .hallPage()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .refreshable {
            await store.refresh()
            await characterStore.load(userId: appVM.userId)
        }
    }

    /// The room itself, set as one page so the backdrop's rays don't run through the
    /// words. Title, then intro, then the ways out, then the scenery (QUESTS_CONTRACT §10.7).
    private func roomProse(_ room: HallRoom) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array((room.intro ?? []).enumerated()), id: \.offset) { _, paragraph in
                prose(paragraph)
            }
            ambience
            if room.inRoom {
                prose(exitsLine(room))
                if let scenery = sceneryLine(room) { prose(scenery) }
                if let openObject { RoomObjectPanel(store: store, room: room, name: openObject) }
                prose(alsoHereLine)
                prose(standingLine(room))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    prose(doorwayLine(room))
                    if store.sneak && room.hasCharacter {
                        Text("Sneak \u{2014} You still see everyone and your visit still counts. Nobody sees your card.")
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if room.hasCharacter { prose(inwardLine) }
            }
            if let error = store.error {
                Text(error)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.amber)
            }
        }
        .hallPage()
    }

    private func roomTitle(_ room: HallRoom) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("\u{2726}").foregroundColor(FavoriumTheme.accent)
                Text(room.title ?? "")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("\u{2726}").foregroundColor(FavoriumTheme.accent)
            }
            .overlay(alignment: .trailing) {
                // Quiet: the room stays on screen while it's read again
                if store.isRefreshing {
                    ProgressView().controlSize(.small).tint(FavoriumTheme.accent).offset(x: 28)
                }
            }
            DecoDivider()
        }
        .backdropLegible()
        .backdropHalo()
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private func prose(_ text: String) -> some View {
        prose(AttributedString(text))
    }

    private func prose(_ text: AttributedString) -> some View {
        Text(text)
            .font(.system(size: 17, design: .serif))
            .foregroundColor(FavoriumTheme.ivory.opacity(0.94))
            .tint(FavoriumTheme.accent)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Atmosphere only: rotates on a timer, never on who comes or goes
    @ViewBuilder
    private var ambience: some View {
        if let ambienceLine {
            ZStack(alignment: .leading) {
                Text(ambienceLine)
                    .id(ambienceLine)
                    .transition(.opacity)
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 18)
            }
            .accessibilityHidden(true)
        }
    }

    /// Text scrolling up fades out before it reaches the clock and battery
    private var statusBarFade: some View {
        LinearGradient(colors: [FavoriumTheme.background, FavoriumTheme.background.opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 12)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }

    // MARK: Room lines

    /// "Obvious exits: the door to the garden and the door back into the Hall 4 new."
    private func exitsLine(_ room: HallRoom) -> AttributedString {
        let exits = room.exits ?? []
        guard !exits.isEmpty else { return AttributedString("There is no obvious way out but back the way you came.") }
        var line = AttributedString("Obvious exits: ")
        for (index, exit) in exits.enumerated() {
            if index > 0 { line += AttributedString(index == exits.count - 1 ? " and " : ", ") }
            line += link(exit.label, "exit/\(exit.key)")
            // About the board only, never about people
            if let fresh = exit.board_new, fresh > 0 { line += chip("\(fresh) new") }
        }
        line += AttributedString(".")
        return line
    }

    /// Scenery reads as one sentence; only names with a look, an act (or the board) are tappable
    private func sceneryLine(_ room: HallRoom) -> AttributedString? {
        let objects = room.objects ?? []
        guard !objects.isEmpty else { return nil }
        var line = AttributedString("You also see ")
        for (index, name) in objects.enumerated() {
            if index > 0 {
                line += AttributedString(index == objects.count - 1 ? " and " : ", ")
            }
            let text = Self.withArticle(name)
            if isBoard(name, in: room) {
                line += link(text, "board")
            } else if RoomObjectPanel.isExaminable(name, in: room) {
                line += link(text, "object/\(index)")
            } else {
                line += AttributedString(text)
            }
        }
        line += AttributedString(".")
        return line
    }

    private func isBoard(_ name: String, in room: HallRoom) -> Bool {
        room.isHall && name.lowercased() == "board"
    }

    /// An object authored without an article reads with "the": `board` → "the board"
    static func withArticle(_ name: String) -> String {
        let determiners: Set<String> = ["a", "an", "the", "some", "one", "two", "three", "four", "five",
                                        "six", "seven", "eight", "nine", "ten", "several", "many", "few"]
        let first = name.split(separator: " ").first.map { $0.lowercased() } ?? ""
        return determiners.contains(first) ? name : "the \(name)"
    }

    /// "Also here: Jo, Quest Tester and Wren."
    private var alsoHereLine: AttributedString {
        let others = store.others
        guard !others.isEmpty else { return AttributedString("You see no one else here.") }
        var line = AttributedString("Also here: ")
        for (index, person) in others.enumerated() {
            if index > 0 { line += AttributedString(index == others.count - 1 ? " and " : ", ") }
            line += link(person.name, "person/\(person.id.uuidString)")
        }
        line += AttributedString(".")
        return line
    }

    private func standingLine(_ room: HallRoom) -> AttributedString {
        AttributedString(room.isSneaking ? "You keep to the shadows, unseen." : "You are standing here.")
    }

    /// Outside: nobody is visible, and the board is only hinted at
    private func doorwayLine(_ room: HallRoom) -> AttributedString {
        var line = AttributedString(store.sneak && room.hasCharacter
                                    ? "You are standing in the doorway, keeping to the shadows. The board is just inside"
                                    : "You are standing in the doorway. The board is just inside")
        if let fresh = room.board_new, fresh > 0 { line += chip("\(fresh) new") }
        line += AttributedString(".")
        if !room.hasCharacter {
            line += AttributedString(" Before you can step inside, ")
            line += link("make your character", "create")
            line += AttributedString(".")
        }
        return line
    }

    private var inwardLine: AttributedString {
        var line = AttributedString("Obvious paths: ")
        line += link("into the hall", "in")
        line += AttributedString(".")
        return line
    }

    private func link(_ text: String, _ path: String) -> AttributedString {
        var run = AttributedString(text)
        run.link = URL(string: "favorium-hall://\(path)")
        run.font = .system(size: 17, weight: .semibold, design: .serif)
        return run
    }

    /// A small "N new" mark set into the prose
    private func chip(_ text: String) -> AttributedString {
        var run = AttributedString("\u{00A0}\u{00A0}\(text)")
        run.font = .system(size: 12, weight: .semibold)
        run.foregroundColor = FavoriumTheme.amber
        return run
    }

    private func follow(_ url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        switch url.host() {
        case "board":  showBoard = true
        case "create": showCreator = true
        case "in":     enter()
        case "exit":
            guard let key = parts.first else { return }
            let label = room?.exits?.first { $0.key == key }?.label
            Task { await store.move(to: key, via: label) }
        case "object":
            let objects = room?.objects ?? []
            guard let index = parts.first.flatMap(Int.init), objects.indices.contains(index) else { return }
            let name = objects[index]
            // One at a time; tapping the open one folds it away
            withAnimation(.easeInOut(duration: 0.2)) { openObject = openObject == name ? nil : name }
        case "person":
            let id = UUID(uuidString: parts.first ?? "")
            lookingAt = store.others.first { $0.id == id }
        default: break
        }
    }

    // MARK: Story

    private struct StoryLine: Identifiable {
        let id: String
        let date: Date
        let text: String
        var isNew = false
        var isRefusal = false
        var isHeading = false
        /// Gestures toward you: who made it, for a return gesture
        var fromUserId: UUID?
    }

    /// How many recent lines show before the rest fold behind "Earlier today"
    private static let recentCount = 5

    /// Gestures toward you (kept by the server) woven with what happened on this visit, oldest first
    private var storyLines: [StoryLine] {
        let received = (store.received?.items ?? []).map {
            StoryLine(id: "r-\($0.id)", date: $0.createdAt ?? .distantPast, text: $0.rendered,
                      isNew: $0.isNew, fromUserId: $0.from_user_id)
        }
        let local = store.events.map {
            StoryLine(id: "e-\($0.id)", date: $0.date, text: $0.text, isRefusal: $0.isRefusal,
                      isHeading: $0.isHeading ?? false)
        }
        return (received + local).sorted { $0.date < $1.date }
    }

    /// The latest few lines, and every unread gesture however old (they stay until marked
    /// read). Unfolded, everything. A room heading shows only above lines that show.
    private func visibleStory(_ lines: [StoryLine]) -> (shown: [StoryLine], earlier: Int) {
        let content = lines.filter { !$0.isHeading }
        let keep: Set<String> = storyExpanded
            ? Set(content.map(\.id))
            : Set(content.suffix(Self.recentCount).map(\.id) + content.filter(\.isNew).map(\.id))
        var shown: [StoryLine] = []
        var heading: StoryLine?
        for line in lines {
            if line.isHeading { heading = line; continue }
            guard keep.contains(line.id) else { continue }
            if let pending = heading {
                shown.append(pending)
                heading = nil
            }
            shown.append(line)
        }
        return (shown, content.count - keep.count)
    }

    private var story: some View {
        let lines = storyLines
        let (shown, earlier) = visibleStory(lines)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("What has passed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                if store.unseen > 0 {
                    Text("\(store.unseen) new")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FavoriumTheme.onGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FavoriumTheme.amber)
                        .clipShape(Capsule())
                }
                Spacer()
                // Reading is explicit: opening or scrolling never marks anything read
                if store.unseen > 0 {
                    Button("Mark these as read") { Task { try? await store.markSeen() } }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FavoriumTheme.accent)
                        .frame(minHeight: 44)
                }
            }
            if lines.isEmpty {
                Text("When someone nods to you here, it stays on this list \u{2014} even if you close the app before you see it.")
                    .font(.system(size: 14, design: .serif).italic())
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if earlier > 0 || storyExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { storyExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: storyExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                        Text(storyExpanded ? "Only the latest" : "Earlier today \u{00B7} \(earlier)")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ForEach(shown) { line in
                if line.isHeading { storyHeading(line.text) } else { storyRow(line) }
            }
        }
    }

    /// "— The Garden —": where the lines below it happened
    private func storyHeading(_ title: String) -> some View {
        Text("\u{2014} \(title) \u{2014}")
            .font(.system(size: 12, weight: .semibold, design: .serif))
            .foregroundColor(FavoriumTheme.accent)
            .tracking(1)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }

    /// A gesture toward you can be returned while its sender is still standing here
    @ViewBuilder
    private func storyRow(_ line: StoryLine) -> some View {
        if store.hasCharacter, let from = line.fromUserId,
           let person = store.others.first(where: { $0.id == from }),
           case let menu = store.gestures(for: person), !menu.isEmpty {
            Menu {
                Section("Return the gesture to \(person.name)") {
                    ForEach(menu) { gesture in
                        Button(gesture.label) { Task { await store.send(gesture, to: person) } }
                    }
                }
            } label: {
                storyText(line, canReply: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Return a gesture to \(person.name)")
        } else {
            storyText(line, canReply: false)
        }
    }

    private func storyText(_ line: StoryLine, canReply: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\u{203A}")
                .foregroundColor(line.isNew ? FavoriumTheme.amber : FavoriumTheme.accentMuted)
            Text(line.text)
                .font(.system(size: 15, design: .serif))
                .foregroundColor(line.isRefusal ? FavoriumTheme.amber : FavoriumTheme.ivory.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if canReply {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
            }
            if line.isNew {
                Text("New")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(FavoriumTheme.amber)
            }
        }
        .padding(.vertical, line.isNew ? 6 : 0)
        .padding(.horizontal, line.isNew ? 8 : 0)
        .background(line.isNew ? FavoriumTheme.amber.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func unreachable(_ error: String) -> some View {
        VStack(spacing: 12) {
            Text(error)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.amber)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await store.refresh() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(FavoriumTheme.accent)
                .frame(minHeight: 44)
        }
        .padding(32)
    }

    // MARK: Verbs

    @ViewBuilder
    private var verbBar: some View {
        if let room {
            HStack(spacing: 0) {
                if !room.hasCharacter {
                    verb("Begin", icon: "person.crop.circle.badge.plus", highlighted: true) { showCreator = true }
                } else if room.isPresent {
                    // The board is an object in the Hall, and nowhere else
                    if room.isHall && room.inRoom {
                        verb("Board", icon: "scroll") { showBoard = true }
                    }
                    verb("Listen", icon: "ear") { showListen = true }
                    gestureVerb
                    verb("Me", icon: "person") { showSelf = true }
                    sneakVerb(room)
                    verb("Out", icon: "door.left.hand.open") { leave() }
                } else {
                    verb("Me", icon: "person") { showSelf = true }
                    sneakVerb(room)
                    verb("In", icon: "door.left.hand.closed", highlighted: true) { enter() }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(FavoriumTheme.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(FavoriumTheme.accentMuted.opacity(0.3)).frame(height: 1)
            }
            .compositingGroup()
            .disabled(presenceBusy)
        }
    }

    private func sneakVerb(_ room: HallRoom) -> some View {
        let on = room.isPresent ? room.isSneaking : store.sneak
        return verb(on ? "Sneaking" : "Sneak", icon: on ? "eye.slash.fill" : "eye.slash", highlighted: on) {
            toggleSneak()
        }
        .accessibilityHint("You still see everyone and your visit still counts. Nobody sees your card.")
    }

    private func verb(_ title: String, icon: String, highlighted: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) { verbLabel(title, icon: icon, highlighted: highlighted) }
            .buttonStyle(.plain)
    }

    private func verbLabel(_ title: String, icon: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 17)).frame(height: 22)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(highlighted ? FavoriumTheme.accent : FavoriumTheme.ivory.opacity(0.85))
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }

    /// Who is here, then what you may make to them
    private var gestureVerb: some View {
        Menu {
            ForEach(store.others) { person in
                let menu = store.gestures(for: person)
                if !menu.isEmpty {
                    Menu(person.name) {
                        ForEach(menu) { gesture in
                            Button(gesture.label) { Task { await store.send(gesture, to: person) } }
                        }
                    }
                }
            }
        } label: {
            verbLabel("Gesture", icon: "hand.wave")
        }
        .disabled(store.others.isEmpty)
        .opacity(store.others.isEmpty ? 0.4 : 1)
    }

    // MARK: Lifecycle

    @MainActor
    private func stayInRoom(foreground: Bool) async {
        guard foreground else { return }
        // Back from the background while still on this screen: in again, and on to the
        // room you were in
        if store.wantsPresence { await store.resume() }
        await store.refresh()
        // Standing somewhere from moments ago (say, a relaunch): keep standing, same sneak
        if let room = store.room, room.isPresent, !store.wantsPresence {
            store.wantsPresence = true
            store.sneak = room.isSneaking
        }
        if !characterStore.hasLoaded { await characterStore.load(userId: appVM.userId) }
        await store.loadMyQuests()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(store.heartbeatSeconds))
            if Task.isCancelled { break }
            await store.tick()
        }
    }

    @MainActor
    private func rotateAmbience() async {
        let lines = store.room?.ambience ?? []
        guard !lines.isEmpty else { ambienceLine = nil; return }
        if ambienceLine.map({ !lines.contains($0) }) ?? true { ambienceLine = lines.randomElement() }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(11))
            if Task.isCancelled { break }
            // A random line, never the one just shown
            let next = lines.filter { $0 != ambienceLine }.randomElement() ?? lines.first
            withAnimation(.easeInOut(duration: 0.5)) { ambienceLine = next }
        }
    }

    private func afterCreator() {
        Task {
            await characterStore.load(userId: appVM.userId)
            await store.reloadGestures()
            await store.refresh()
            if createdCharacter {
                createdCharacter = false
                showGifts = true
            }
        }
    }

    // MARK: Presence

    private func enter() {
        guard !presenceBusy else { return }
        presenceBusy = true
        Task {
            defer { presenceBusy = false }
            do {
                try await store.enter(sneak: store.sneak)
            } catch {
                store.note(SupabaseService.errorMessage(error), refusal: true)
            }
        }
    }

    private func leave() {
        guard !presenceBusy else { return }
        presenceBusy = true
        Task {
            defer { presenceBusy = false }
            await store.leave()
            store.note("You step back out.")
            await store.refresh()
        }
    }

    private func toggleSneak() {
        let value = !(room?.isPresent == true ? (room?.isSneaking ?? false) : store.sneak)
        guard room?.isPresent == true else {
            store.sneak = value
            return
        }
        presenceBusy = true
        Task {
            defer { presenceBusy = false }
            do {
                try await store.setSneak(value)
            } catch {
                store.note(SupabaseService.errorMessage(error), refusal: true)
            }
        }
    }
}

// MARK: - Page

extension View {
    /// A soft page of the background color behind Hall prose, quieting the backdrop's
    /// rays and arch where words sit, without boxing the room into a card
    func hallPage() -> some View {
        padding(.vertical, 14)
            .padding(.horizontal, 4)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(FavoriumTheme.background.opacity(0.88))
                    .padding(.horizontal, -12)
                    .blur(radius: 14)
                    .accessibilityHidden(true)
            }
    }
}

// MARK: - Examining scenery

/// What unfolds under the scenery line when you tap a name: its look, a quieter
/// detail, and the room's one act if it belongs to this object. Everything came in
/// the room payload, so opening it makes no request.
struct RoomObjectPanel: View {
    @Bindable var store: HallStore
    let room: HallRoom
    let name: String

    /// The rendered line of each act done here; it stays until you leave the room
    @State private var lines: [String: String] = [:]
    /// A soft "give it a moment", shown quietly beside the verb
    @State private var pauses: [String: String] = [:]
    @State private var restUntil: [String: Date] = [:]
    @State private var acting: String?

    static func isExaminable(_ name: String, in room: HallRoom) -> Bool {
        (room.object_looks ?? []).contains { $0.name == name }
            || (room.object_actions ?? []).contains { $0.name == name }
    }

    private var look: RoomObjectLook? { room.object_looks?.first { $0.name == name } }
    private var actions: [RoomObjectAction] { (room.object_actions ?? []).filter { $0.name == name } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let look {
                Text(look.look)
                    .font(.system(size: 16, design: .serif).italic())
                    .foregroundColor(FavoriumTheme.ivory.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = look.detail {
                    Text(detail)
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // A list, though there's one act per room today, so a second needs no release
            ForEach(actions) { action in actRow(action) }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle().fill(FavoriumTheme.accent.opacity(0.5)).frame(width: 2)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func actRow(_ action: RoomObjectAction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = restUntil[action.id].map { Int(ceil($0.timeIntervalSince(context.date))) } ?? 0
                HStack(spacing: 10) {
                    Button { act(action) } label: {
                        HStack(spacing: 6) {
                            if acting == action.id { ProgressView().controlSize(.small).tint(FavoriumTheme.accent) }
                            Text(action.label)
                                .font(.system(size: 15, weight: .semibold, design: .serif))
                            if left > 0 {
                                Text("\(left)")
                                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                            }
                        }
                        .foregroundColor(FavoriumTheme.accent)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(Capsule().stroke(FavoriumTheme.accent.opacity(left > 0 ? 0.25 : 0.6), lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(left > 0 || acting != nil)
                    // Nothing went wrong: the room just asks you to wait
                    if let pause = pauses[action.id], left > 0 {
                        Text(pause)
                            .font(.system(size: 13, design: .serif).italic())
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let line = lines[action.id] {
                Text(line)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
    }

    private func act(_ action: RoomObjectAction) {
        acting = action.id
        pauses[action.id] = nil
        Task {
            defer { acting = nil }
            do {
                let result = try await store.act(action)
                let rest = result.retry_after_seconds ?? result.cooldown_seconds ?? room.act_cooldown_seconds ?? 6
                restUntil[action.id] = Date().addingTimeInterval(TimeInterval(rest))
                if result.ok {
                    withAnimation(.easeInOut(duration: 0.3)) { lines[action.id] = result.rendered }
                } else {
                    pauses[action.id] = result.message
                }
            } catch {
                let message = SupabaseService.errorMessage(error)
                store.note(message, refusal: true)
                // Presence lapsed: come back in to the same room, then the verb is offered again
                if message == "Step inside first." {
                    await store.resume()
                    await store.refresh()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Garden") {
    @Previewable @State var appVM = AppViewModel()
    @Previewable @State var store: HallStore = {
        let store = HallStore()
        let json = """
        {"key":"garden","title":"The Garden",
         "intro":["Gravel paths wander between beds that nobody seems to weed, and the walls hold the warmth of the afternoon long after it has gone."],
         "ambience":["A bee works the lavender, unhurried.","Somewhere a gate swings shut."],
         "exits":[{"key":"hall","label":"the door back into the Hall","board_new":4}],
         "objects":["a stone bench","a stand of lavender"],
         "object_looks":[{"name":"a stone bench","look":"The bench has settled a little into the ground, as though it decided years ago to stay.","detail":"Someone scratched a date into the armrest and then rubbed at it with a thumb until the numbers went soft."}],
         "object_actions":[{"name":"a stone bench","key":"sit","label":"sit for a moment","line":"You sit."}],
         "act_cooldown_seconds":6,
         "present":[{"user_id":"00000000-0000-0000-0000-0000000000a1","name":"Jo","connected":true,"description":["You see Jo, Saint of Favorium."],"signature":"Tips their hat","arrived_from":"hall"}],
         "board_new":4,
         "me":{"present":true,"room_key":"garden","in_room":true,"sneaking":false,"has_character":true}}
        """
        store.room = try? JSONDecoder().decode(HallRoom.self, from: Data(json.utf8))
        store.note("The Authored Hall", heading: true)
        store.note("You step inside.")
        store.note("Wren arrives.")
        store.note("Wren leaves.")
        store.note("You take on \u{201C}Carry something heavy\u{201D}.")
        store.note(HallStore.sendersView("Dave raises his hand in greeting to you.", to: "Jellybean"))
        store.note("You go through the door to the garden.")
        store.note("The Garden", heading: true)
        store.note("Jo arrives from the Hall.")
        return store
    }()
    HallView(store: store).environment(appVM)
}
