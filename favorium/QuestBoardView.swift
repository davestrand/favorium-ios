//
//  QuestBoardView.swift
//  favorium
//
//  Shared quest wording, the wardrobe that chooses what the description shows,
//  and actions received. The board itself now lives in the Hall (HallView).
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

func rarityLabel(_ rarity: String?) -> String? {
    switch rarity {
    case "uncommon": "Uncommon"
    case "rare":     "Rare"
    default:         nil
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
