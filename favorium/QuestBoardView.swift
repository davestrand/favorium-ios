//
//  QuestBoardView.swift
//  favorium
//
//  The Quest Board (5 quests every Monday, plus any visitor's), the wardrobe
//  that chooses what the description shows, and actions received.
//  QUESTS_CONTRACT v1.1. A quest completes when the person helped gives a gem
//  for a favor that carries it; that favor link is still to come on the server.
//

import SwiftUI

// MARK: - Reward wording

extension QuestUnlock {
    /// "the word strong", "a slender rowan wand…", "the action “bows their head”"
    var rewardPhrase: String {
        let readable = text.replacingOccurrences(of: "{pos}", with: "their")
        switch kind {
        case "look_term", "rep_term": return "the word \u{201C}\(readable)\u{201D}"
        case "hairstyle":             return "the hairstyle \u{201C}\(readable)\u{201D}"
        case "action":                return "the action \u{201C}\(readable)\u{201D}"
        default:                      return readable
        }
    }
}

private func rarityLabel(_ rarity: String?) -> String? {
    switch rarity {
    case "uncommon": "Uncommon"
    case "rare":     "Rare"
    default:         nil
    }
}

private func relative(_ date: Date?) -> String? {
    date.map { $0.formatted(.relative(presentation: .named)) }
}

// MARK: - Board

struct QuestBoardView: View {
    @Environment(AppViewModel.self) private var appVM
    @Bindable var store: CharacterStore
    @State private var push = PushManager.shared
    @State private var busyQuest: UUID?
    @State private var abandoning: Quest?
    @State private var error: String?
    @AppStorage("questPushEnabled") private var questPush = false

    var body: some View {
        ZStack {
            DecoBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error {
                        Text(error)
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.amber)
                    }

                    if let visit = store.board?.visit {
                        visitSection(visit)
                    }

                    weekSection

                    if !olderAccepted.isEmpty {
                        section("Still open", subtitle: "Accepted in earlier weeks") {
                            ForEach(olderAccepted) { questRow($0) }
                        }
                    }

                    if !completed.isEmpty {
                        section("Completed", subtitle: nil) {
                            ForEach(completed) { quest in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quest.title)
                                        .font(.system(size: 15, weight: .semibold, design: .serif))
                                        .foregroundColor(FavoriumTheme.ivory)
                                    Text("Earned \(quest.unlock.rewardPhrase)")
                                        .font(FavoriumTheme.captionFont)
                                        .foregroundColor(FavoriumTheme.ivoryDim)
                                }
                            }
                        }
                    }

                    pushCard
                }
                .padding(16)
            }
            .refreshable { await store.load(userId: appVM.userId) }
        }
        .navigationTitle("Quest Board")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load(userId: appVM.userId) }
        .confirmationDialog("Abandon this quest?", isPresented: Binding(
            get: { abandoning != nil }, set: { if !$0 { abandoning = nil } }
        ), titleVisibility: .visible, presenting: abandoning) { quest in
            Button("Abandon", role: .destructive) { abandon(quest) }
            Button("Keep it", role: .cancel) { }
        } message: { quest in
            Text("\u{201C}\(quest.title)\u{201D} will leave your board.")
        }
    }

    // MARK: Sections

    private var weekSection: some View {
        let quests = store.board?.quests ?? []
        let refresh = relative(store.board?.nextRefresh).map { "New quests \($0)" }
        return section("This week", subtitle: refresh) {
            if quests.isEmpty {
                Text(store.hasLoaded ? "No quests on your board right now." : "")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
            ForEach(quests) { questRow($0) }
        }
    }

    private func visitSection(_ visit: Visit) -> some View {
        let leaves = relative(visit.endsAt).map { "Leaves \($0)" }
        return section("\(visit.name) \(visit.intro)", subtitle: leaves) {
            ForEach(visit.quests) { questRow($0) }
        }
    }

    /// Accepted quests the board no longer lists (drawn in an earlier week)
    private var olderAccepted: [Quest] {
        let onBoard = Set((store.board?.quests ?? []).map(\.id) + (store.board?.visit?.quests ?? []).map(\.id))
        return store.history.filter { $0.isAccepted && !onBoard.contains($0.id) }
    }

    private var completed: [Quest] {
        store.history.filter { $0.status == "completed" }
    }

    private func section<Content: View>(_ title: String, subtitle: String?,
                                        @ViewBuilder content: () -> Content) -> some View {
        CharacterCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.accent)
                }
            }
            content()
        }
    }

    private func questRow(_ quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(quest.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                Spacer()
                if let rarity = rarityLabel(quest.unlock.rarity) {
                    Text(rarity)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FavoriumTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(FavoriumTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            Text(quest.prompt)
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivory.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text("Reward: the gem they thank you with, and \(quest.unlock.rewardPhrase).")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .fixedSize(horizontal: false, vertical: true)

            if quest.isPosted {
                Button { accept(quest) } label: {
                    HStack(spacing: 6) {
                        if busyQuest == quest.id { ProgressView().tint(FavoriumTheme.onGold) }
                        Text("Accept").fontWeight(.semibold)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
                    .metallicGoldCapsule()
                }
                .buttonStyle(.plain)
                .disabled(busyQuest != nil)
            } else if quest.isAccepted {
                HStack {
                    Label(acceptedNote(quest), systemImage: "checkmark.seal")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.accent)
                    Spacer()
                    if quest.favor_id == nil {
                        Button("Abandon") { abandoning = quest }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func acceptedNote(_ quest: Quest) -> String {
        if quest.favor_id != nil { return "Underway in a favor" }
        if let due = relative(quest.expiresAt) { return "Accepted · ends \(due)" }
        return "Accepted"
    }

    // MARK: Monday push opt-in

    private var pushCard: some View {
        CharacterCard {
            Toggle(isOn: Binding(get: { questPush }, set: { setPush($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tell me on Mondays")
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivory)
                    Text("A notification when new quests are posted, and when a visitor comes to town.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(FavoriumTheme.accent)
        }
    }

    // MARK: Actions

    private func accept(_ quest: Quest) {
        busyQuest = quest.id
        error = nil
        Task {
            defer { busyQuest = nil }
            do {
                try await SupabaseService.shared.acceptQuest(quest.id)
                await store.load(userId: appVM.userId)
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }

    private func abandon(_ quest: Quest) {
        error = nil
        Task {
            do {
                try await SupabaseService.shared.abandonQuest(quest.id)
                await store.load(userId: appVM.userId)
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }

    /// The server can't report this setting back yet, so the device remembers what was chosen.
    private func setPush(_ enabled: Bool) {
        let previous = questPush
        questPush = enabled
        error = nil
        Task {
            do {
                try await SupabaseService.shared.setQuestPush(enabled)
                if enabled, push.canAskPermission { await push.requestAuthorization() }
            } catch {
                questPush = previous
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}

// MARK: - Wardrobe

/// Choose what the description shows, and keep the inventory tidy by dropping things.
struct WardrobeView: View {
    @Environment(AppViewModel.self) private var appVM
    @Bindable var store: CharacterStore
    @State private var dropping: InventoryItem?
    @State private var error: String?

    var body: some View {
        ZStack {
            DecoBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error {
                        Text(error)
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.amber)
                    }

                    CharacterCard {
                        heading("Shown on your character")
                        ForEach(ShownSlot.allCases) { slotRow($0) }
                    }

                    if store.inventory.isEmpty {
                        CharacterCard {
                            heading("Everything you\u{2019}ve earned")
                            Text("Nothing yet. Complete a quest to earn your first.")
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.ivoryDim)
                        }
                    }
                    // Objects are one-of-a-kind: in the backpack, on this character, or on
                    // another of your characters (QUESTS_CONTRACT v1.2). Traits and gestures
                    // are simply yours.
                    group("Backpack", store.inventory.filter(\.isInBackpack))
                    group("Wearing", store.inventory.filter { $0.isObject && isOnActive($0) })
                    group("With another of your characters",
                          store.inventory.filter { $0.isObject && $0.wornByCharacterId != nil && !isOnActive($0) })
                    group("Traits", store.inventory.filter(\.isTrait))
                    group("Gestures", store.inventory.filter(\.isGesture))
                }
                .padding(16)
            }
            .refreshable { await store.load(userId: appVM.userId) }
        }
        .navigationTitle("Wardrobe")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Drop this?", isPresented: Binding(
            get: { dropping != nil }, set: { if !$0 { dropping = nil } }
        ), titleVisibility: .visible, presenting: dropping) { item in
            Button("Drop", role: .destructive) { drop(item) }
            Button("Keep it", role: .cancel) { }
        } message: { item in
            Text("Drop \u{201C}\(readable(item.text))\u{201D}? It\u{2019}s taken off whoever has it, and you can earn it again if its quest comes back.")
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    private func readable(_ text: String) -> String {
        text.replacingOccurrences(of: "{pos}", with: "their")
    }

    private func isOnActive(_ item: InventoryItem) -> Bool {
        item.wornByCharacterId != nil && item.wornByCharacterId == store.character?.id
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [InventoryItem]) -> some View {
        if !items.isEmpty {
            CharacterCard {
                heading(title)
                ForEach(items) { itemRow($0) }
            }
        }
    }

    private func slotRow(_ slot: ShownSlot) -> some View {
        // Traits can be shared; objects can only be put on from the backpack.
        // Choosing one for a full slot simply swaps, and the old one returns to the backpack.
        let options = store.inventory.filter {
            slot.accepts(kind: $0.kind, slot: $0.slot) && ($0.isTrait || $0.isInBackpack)
        }
        let current = store.shown(slot)
        return HStack {
            Text(slot.label)
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Menu {
                Button("Nothing") { show(nil, in: slot) }
                ForEach(options) { item in
                    Button(readable(item.text)) { show(item.id, in: slot) }
                }
            } label: {
                Text(current?.text.map(readable) ?? (options.isEmpty ? "None available" : "Nothing"))
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(current == nil ? FavoriumTheme.ivoryDim : FavoriumTheme.accent)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .disabled(options.isEmpty && current == nil)
            .accessibilityLabel("\(slot.label): \(current?.text.map(readable) ?? "nothing")")
        }
    }

    private func itemRow(_ item: InventoryItem) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(readable(item.text))
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                Text(provenance(item))
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Menu {
                Button("Drop", systemImage: "trash", role: .destructive) { dropping = item }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More for \(readable(item.text))")
        }
    }

    /// "From “Carry something heavy”, Winter solstice 2026 · Rare · Shown"
    private func provenance(_ item: InventoryItem) -> String {
        var parts: [String] = []
        if let quest = item.questTitle { parts.append("From \u{201C}\(quest)\u{201D}") }
        if let visit = item.visitLabel { parts.append(visit) }
        if let rarity = rarityLabel(item.rarity) { parts.append(rarity) }
        return parts.joined(separator: " · ")
    }

    private func show(_ unlockId: UUID?, in slot: ShownSlot) {
        guard let character = store.character else { return }
        error = nil
        Task {
            do {
                try await SupabaseService.shared.setShown(characterId: character.id, slot: slot, unlockId: unlockId)
                await store.load(userId: appVM.userId)
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }

    private func drop(_ item: InventoryItem) {
        error = nil
        Task {
            do {
                try await SupabaseService.shared.dropUnlock(item.id)
                await store.load(userId: appVM.userId)
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}

// MARK: - Actions received

struct ActionsReceivedView: View {
    let actions: [ActionReceived]

    var body: some View {
        ZStack {
            DecoBackdrop()
            ScrollView {
                CharacterCard {
                    ForEach(actions) { action in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.rendered)
                                .font(.system(size: 15, design: .serif))
                                .foregroundColor(FavoriumTheme.ivory)
                            if let date = action.createdAt.flatMap(SupabaseService.PairingCode.parseTimestamp) {
                                Text(date.formatted(.relative(presentation: .named)))
                                    .font(FavoriumTheme.captionFont)
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Received")
        .navigationBarTitleDisplayMode(.inline)
    }
}
