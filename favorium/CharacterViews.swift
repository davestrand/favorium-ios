//
//  CharacterViews.swift
//  favorium
//
//  The text-only character (QUESTS_CONTRACT v1.1): the Profile card, the
//  character creator, and another member's description with the Act menu.
//

import SwiftUI

// MARK: - Store

/// Everything the character, board and wardrobe screens read. Owned by the Profile tab.
@Observable
final class CharacterStore {
    var catalog: [CatalogEntry] = []
    var mine: MyCharacter?
    var description: [String] = []
    var board: QuestBoard?
    var history: [Quest] = []
    var inventory: [InventoryItem] = []
    var actionsReceived: [ActionReceived] = []
    var loadError: String?
    var hasLoaded = false

    var character: PlayerCharacter? { mine?.character }

    func entries(_ kind: String) -> [CatalogEntry] { catalog.filter { $0.kind == kind } }
    func entry(_ key: String?) -> CatalogEntry? { key.flatMap { k in catalog.first { $0.key == k } } }

    /// Held actions, for the Act menu
    var actions: [InventoryItem] { inventory.filter { $0.kind == "action" } }

    /// The unlock shown in a slot, if any
    func shown(_ slot: ShownSlot) -> ShownUnlock? { mine?.shown.first { $0.slot == slot.rawValue } }

    @MainActor
    func load(userId: UUID?) async {
        guard let userId else { return }
        let service = SupabaseService.shared
        do {
            if catalog.isEmpty { catalog = try await service.catalog() }
            mine = try await service.myCharacter()
            description = (try? await service.characterDescription(userId: userId)) ?? []
            loadError = nil
        } catch {
            loadError = SupabaseService.errorMessage(error)
        }
        hasLoaded = true
        // Only members with a character have a board or an inventory
        guard character != nil else { return }
        async let board = try? service.myBoard()
        async let history = try? service.myQuests()
        async let inventory = try? service.myInventory()
        async let received = try? service.myActionsReceived()
        if let value = await board { self.board = value }
        if let value = await history { self.history = value }
        if let value = await inventory { self.inventory = value }
        if let value = await received { self.actionsReceived = value }
    }
}

// MARK: - Shared building blocks

/// Navy (or cream) panel with a fine gold rim, matching the Connect screen's cards
struct CharacterCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .stroke(FavoriumTheme.accentMuted.opacity(0.3), lineWidth: 1)
            )
    }
}

/// The rendered `LOOK` text, set like a page from a book
struct CharacterDescriptionText: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.system(size: index == 0 ? 17 : 15, weight: index == 0 ? .semibold : .regular, design: .serif))
                    .foregroundColor(index == 0 ? FavoriumTheme.ivory : FavoriumTheme.ivory.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
    }
}

/// "Quest · Carry something heavy", shown above a favor that carries a quest
struct QuestTag: View {
    let title: String

    var body: some View {
        Label("Quest \u{00B7} \(title)", systemImage: "scroll")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
            .lineLimit(1)
    }
}

struct GoldButtonLabel: View {
    let title: String
    var busy = false

    var body: some View {
        HStack(spacing: 8) {
            if busy { ProgressView().tint(FavoriumTheme.onGold) }
            Text(title).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .metallicGoldCapsule()
    }
}

// MARK: - Profile section

/// "Your character" on the Profile tab: a prompt to create one, or the description
/// with links to the Quest Board and the wardrobe.
struct CharacterSection: View {
    @Environment(AppViewModel.self) private var appVM
    @Bindable var store: CharacterStore
    @State private var showCreator = false

    var body: some View {
        CharacterCard {
            if !store.hasLoaded {
                ProgressView().tint(FavoriumTheme.accent).frame(maxWidth: .infinity)
            } else if store.character == nil {
                createPrompt
            } else {
                Text("Your character")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                CharacterDescriptionText(lines: store.description)
                VStack(spacing: 1) {
                    link("Quest Board", icon: "scroll", detail: boardDetail) { QuestBoardView(store: store) }
                    link("Wardrobe", icon: "tshirt", detail: "\(store.inventory.count) earned") { WardrobeView(store: store) }
                    if !store.actionsReceived.isEmpty {
                        link("Received", icon: "hand.wave", detail: "\(store.actionsReceived.count)") {
                            ActionsReceivedView(actions: store.actionsReceived)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                Button("Change appearance") { showCreator = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
            }
            if let error = store.loadError {
                Text(error)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.amber)
            }
        }
        .sheet(isPresented: $showCreator, onDismiss: { Task { await store.load(userId: appVM.userId) } }) {
            CharacterCreatorView(store: store)
        }
    }

    private var boardDetail: String {
        let open = store.board?.quests.filter(\.isPosted).count ?? 0
        return open == 0 ? "" : "\(open) new"
    }

    private var createPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create your character")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
            Text("Choose who you are in words: your people, your look. Then take on quests to earn new words, clothes and things to carry.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .fixedSize(horizontal: false, vertical: true)
            Button { showCreator = true } label: { GoldButtonLabel(title: "Begin") }
                .buttonStyle(.plain)
        }
    }

    private func link<Destination: View>(_ title: String, icon: String, detail: String,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(FavoriumTheme.accent)
                    .frame(width: 22)
                Text(title)
                    .font(FavoriumTheme.bodyFont)
                    .foregroundColor(FavoriumTheme.ivory)
                Spacer()
                Text(detail)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(FavoriumTheme.surfaceHigh.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Creator

/// Creates the character, or edits its appearance. Race is chosen once, from every
/// race at the same time, and can't be changed afterwards.
struct CharacterCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM
    let store: CharacterStore

    @State private var pronouns: Pronouns = .they
    @State private var raceKey: String?
    @State private var choices: [AppearanceKind: String] = [:]
    @State private var confirmRace = false
    @State private var isSaving = false
    @State private var error: String?

    private var isEditing: Bool { store.character != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        CharacterCard {
                            sectionTitle("Pronouns")
                            Picker("Pronouns", selection: $pronouns) {
                                ForEach(Pronouns.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }

                        if isEditing {
                            CharacterCard {
                                sectionTitle("Your people")
                                Text(store.entry(store.character?.race_key)?.text.capitalized ?? "")
                                    .font(.system(size: 17, weight: .semibold, design: .serif))
                                    .foregroundColor(FavoriumTheme.ivory)
                                Text("Chosen when you began. It stays with you.")
                                    .font(FavoriumTheme.captionFont)
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                            }
                        } else {
                            racePicker
                        }

                        CharacterCard {
                            sectionTitle("Appearance")
                            Text("All optional. You can change these any time.")
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.ivoryDim)
                            ForEach(AppearanceKind.allCases) { kind in
                                appearanceRow(kind)
                            }
                        }

                        if let error {
                            Text(error)
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.amber)
                        }

                        Button {
                            if isEditing { save() } else { confirmRace = true }
                        } label: {
                            GoldButtonLabel(title: isEditing ? "Save" : "Create character", busy: isSaving)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving || (!isEditing && raceKey == nil))
                        .opacity(!isEditing && raceKey == nil ? 0.45 : 1)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(isEditing ? "Appearance" : "Your character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .confirmationDialog("Your race is permanent", isPresented: $confirmRace, titleVisibility: .visible) {
                Button("Become \(article(for: raceName)) \(raceName)") { save() }
                Button("Not yet", role: .cancel) { }
            } message: {
                Text("Choose the one that feels like you. Everything else can change later.")
            }
            .task { await prepare() }
        }
    }

    private var raceName: String { store.entry(raceKey)?.text ?? "" }

    private var racePicker: some View {
        CharacterCard {
            sectionTitle("Your people")
            Text("Choose once. This one is yours for good.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
            ForEach(store.entries("race")) { race in
                Button { raceKey = race.key } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: raceKey == race.key ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(FavoriumTheme.accent)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(race.text.capitalized)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundColor(FavoriumTheme.ivory)
                            if let flavor = race.flavor {
                                Text(flavor)
                                    .font(FavoriumTheme.captionFont)
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(raceKey == race.key ? .isSelected : [])
            }
        }
    }

    private func appearanceRow(_ kind: AppearanceKind) -> some View {
        HStack {
            Text(kind.label)
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Picker(kind.label, selection: Binding(
                get: { choices[kind] },
                set: { choices[kind] = $0 }
            )) {
                Text("Not set").tag(String?.none)
                ForEach(store.entries(kind.rawValue)) { entry in
                    Text(entry.text).tag(Optional(entry.key))
                }
            }
            .tint(FavoriumTheme.accent)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    private func article(for word: String) -> String {
        guard let first = word.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    @MainActor
    private func prepare() async {
        if store.catalog.isEmpty { await store.load(userId: appVM.userId) }
        guard let character = store.character else { return }
        pronouns = Pronouns(rawValue: character.pronouns ?? "") ?? .they
        for kind in AppearanceKind.allCases {
            choices[kind] = character.key(for: kind)
        }
    }

    private func save() {
        isSaving = true
        error = nil
        Task {
            defer { isSaving = false }
            let params = SupabaseService.AppearanceParams(pronouns: pronouns, choices: choices)
            do {
                if let character = store.character {
                    try await SupabaseService.shared.updateCharacterAppearance(characterId: character.id, appearance: params)
                } else if let raceKey {
                    try await SupabaseService.shared.createCharacter(raceKey: raceKey, appearance: params)
                }
                await store.load(userId: appVM.userId)
                dismiss()
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}

// MARK: - Someone else's character

/// Another member's description, with the Act menu for the actions you've earned.
struct PersonCharacterView: View {
    @Environment(\.dismiss) private var dismiss
    let person: SafetyPerson

    @State private var lines: [String] = []
    @State private var myActions: [InventoryItem] = []
    @State private var catalogLabels: [String: String] = [:]
    @State private var error: String?
    @State private var sentLine: String?
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        CharacterCard {
                            if lines.isEmpty && error == nil {
                                ProgressView().tint(FavoriumTheme.accent).frame(maxWidth: .infinity)
                            } else {
                                CharacterDescriptionText(lines: lines)
                            }
                        }

                        if !myActions.isEmpty {
                            Menu {
                                ForEach(myActions) { action in
                                    Button(actionLabel(action)) { send(action) }
                                }
                            } label: {
                                GoldButtonLabel(title: "Act", busy: isSending)
                            }
                            .disabled(isSending)
                        }

                        if let sentLine {
                            Label(sentLine, systemImage: "checkmark.circle")
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.accent)
                        }
                        if let error {
                            Text(error)
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.amber)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
    }

    /// The sender's wording from the server ("Bow your head"); older rows fall back to
    /// the receiver's text with "their" ("bows their head").
    private func actionLabel(_ action: InventoryItem) -> String {
        action.label ?? catalogLabels[action.key] ?? action.text.replacingOccurrences(of: "{pos}", with: "their")
    }

    @MainActor
    private func load() async {
        do {
            lines = try await SupabaseService.shared.characterDescription(userId: person.id)
        } catch {
            self.error = SupabaseService.errorMessage(error)
        }
        let inventory = (try? await SupabaseService.shared.myInventory()) ?? []
        myActions = inventory.filter { $0.kind == "action" }
        if !myActions.isEmpty, let catalog = try? await SupabaseService.shared.catalog() {
            catalogLabels = Dictionary(catalog.compactMap { e in e.label.map { (e.key, $0) } },
                                       uniquingKeysWith: { first, _ in first })
        }
    }

    private func send(_ action: InventoryItem) {
        isSending = true
        error = nil
        sentLine = nil
        Task {
            defer { isSending = false }
            do {
                sentLine = try await SupabaseService.shared.sendAction(to: person.id, actionUnlockId: action.id) ?? "Sent"
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}
