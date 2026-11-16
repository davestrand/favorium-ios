//
//  HallSheets.swift
//  favorium
//
//  What opens from the rooms: the quest board (Hall only), looking at someone who
//  is here, ME (yourself, your pack and your open quests), LISTEN, and the
//  first-run gifts.
//

import SwiftUI

// MARK: - Shared

/// Where an object shows on the description: held things in the hand, clothing in its slot
func shownSlot(for item: InventoryItem) -> ShownSlot? {
    if item.kind == "held" { return .held }
    guard item.kind == "clothing", let raw = item.slot else { return nil }
    return ShownSlot(rawValue: raw)
}

private func sheetHeading(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(FavoriumTheme.accent)
        .textCase(.uppercase)
        .accessibilityAddTraits(.isHeader)
}

private func readable(_ text: String) -> String {
    text.replacingOccurrences(of: "{pos}", with: "their")
}

// MARK: - The quest board

/// The board as an object in the room: this week's notices, the visitor's, what's
/// still open from earlier weeks, and (collapsed) what you've already done.
struct HallBoardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM
    @Bindable var store: HallStore

    @State private var showHistory = false
    @State private var busyQuest: UUID?
    @State private var settingAside: Quest?
    /// The accepted quest being offered as a favor
    @State private var offering: Quest?
    @State private var error: String?

    private var room: HallRoom? { store.room }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let error {
                            Text(error)
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.amber)
                        }
                        weekSection
                        if let visit = room?.visit { visitSection(visit) }
                        if !stillOpen.isEmpty {
                            section("Still open", subtitle: "Taken on in an earlier week") {
                                ForEach(stillOpen) { questRow($0) }
                            }
                        }
                        if !alreadyDone.isEmpty { historySection }
                    }
                    .padding(16)
                }
                .refreshable { await store.refresh() }
            }
            .navigationTitle("The quest board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .sheet(item: $offering, onDismiss: { Task { await store.refresh() } }) { quest in
            OfferHelpView(userId: appVM.userId, quest: quest, onComplete: {})
                .environment(appVM)
        }
        .confirmationDialog("Set this quest aside?", isPresented: Binding(
            get: { settingAside != nil }, set: { if !$0 { settingAside = nil } }
        ), titleVisibility: .visible, presenting: settingAside) { quest in
            Button("Set it aside", role: .destructive) { abandon(quest) }
            Button("Keep it", role: .cancel) { }
        } message: { quest in
            Text("\u{201C}\(quest.title)\u{201D} will leave your open quests.")
        }
    }

    // MARK: Sections

    private var weekSection: some View {
        let quests = room?.quests ?? []
        return VStack(alignment: .leading, spacing: 10) {
            section("This week", subtitle: weekLine) {
                if quests.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("The board is bare this week")
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundColor(FavoriumTheme.ivory)
                        Text("Nothing has been chalked up yet. The hall keeps its own hours \u{2014} come back, and something will have been written.")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(quests) { questRow($0) }
            }
            Text("A quest is completed inside a favor, never on your own. Take one on here, then carry it out with someone you are connected to.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    /// "Week of Nov 16 · Redrawn Monday, Nov 23"
    private var weekLine: String? {
        var parts: [String] = []
        if let start = room?.weekStarts {
            parts.append("Week of \(start.formatted(.dateTime.month(.abbreviated).day()))")
        }
        if let next = room?.nextRefresh {
            parts.append("Redrawn \(next.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private func visitSection(_ visit: Visit) -> some View {
        let leaves = visit.endsAt.map { "Leaves \($0.formatted(.relative(presentation: .named)))" }
        return section(visit.name, subtitle: leaves) {
            Text(visit.intro)
                .font(.system(size: 15, design: .serif))
                .foregroundColor(FavoriumTheme.ivory.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(visit.quests) { questRow($0) }
        }
    }

    /// Accepted in an earlier week: `quests` holds this week's draw only
    private var stillOpen: [Quest] {
        let onBoard = Set((room?.quests ?? []).map(\.id) + (room?.visit?.quests ?? []).map(\.id))
        return (room?.history ?? []).filter { $0.isAccepted && !onBoard.contains($0.id) }
    }

    /// A record of what you did, never a list of what you missed
    private var alreadyDone: [Quest] {
        (room?.history ?? []).filter { !$0.isAccepted }
    }

    private var historySection: some View {
        CharacterCard {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showHistory.toggle() }
            } label: {
                HStack {
                    Text("What you\u{2019}ve already done")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    Text("\(alreadyDone.count)")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.accent)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .rotationEffect(.degrees(showHistory ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(showHistory ? "Expanded" : "Collapsed")

            if showHistory {
                ForEach(alreadyDone) { questRow($0) }
            }
        }
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

    // MARK: A notice

    private var gestureLabels: [String: String] {
        Dictionary(store.gestures.map { ($0.key, $0.label) }, uniquingKeysWith: { first, _ in first })
    }

    private func questRow(_ quest: Quest) -> some View {
        let inert = quest.status == "expired" || quest.status == "abandoned"
        return VStack(alignment: .leading, spacing: 8) {
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
            Label(quest.unlock.rewardLine(gestureLabels: gestureLabels), systemImage: "sparkle")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .fixedSize(horizontal: false, vertical: true)
            questActions(quest)
        }
        .padding(.vertical, 6)
        .opacity(inert ? 0.55 : 1)
    }

    @ViewBuilder
    private func questActions(_ quest: Quest) -> some View {
        switch quest.status {
        case "posted":
            // Without a character the board is read-only; the room offers the creator
            if store.hasCharacter {
                Button { accept(quest) } label: {
                    HStack(spacing: 6) {
                        if busyQuest == quest.id { ProgressView().tint(FavoriumTheme.onGold) }
                        Text("Take this on").fontWeight(.semibold)
                    }
                    .padding(.horizontal, 22)
                    .frame(minHeight: 44)
                    .metallicGoldCapsule()
                }
                .buttonStyle(.plain)
                .disabled(busyQuest != nil)
            }
        case "accepted":
            if quest.favor_id != nil {
                Label("In a favor", systemImage: "hands.sparkles")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.accent)
            } else {
                if let due = quest.expiresAt {
                    Text("Taken on \u{00B7} ends \(due.formatted(.relative(presentation: .named)))")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.accent)
                }
                HStack(spacing: 16) {
                    // Carried out with someone in your circle
                    Button { offering = quest } label: {
                        Label("Offer as a favor", systemImage: "hand.raised.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .metallicGoldCapsule()
                    }
                    .buttonStyle(.plain)
                    Button("Set it aside") { settingAside = quest }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .frame(minHeight: 44)
                }
            }
        case "completed":
            let when = quest.completed_at.flatMap(SupabaseService.PairingCode.parseTimestamp)
            Label(when.map { "Completed \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Completed",
                  systemImage: "checkmark.seal.fill")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.accent)
        case "expired":
            Text("Expired")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        case "abandoned":
            Text("Set aside")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        default:
            EmptyView()
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
                store.note("You take on \u{201C}\(quest.title)\u{201D}.")
                await store.refresh()
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
                store.note("You set \u{201C}\(quest.title)\u{201D} aside.")
                await store.refresh()
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}

// MARK: - Looking at someone

/// Someone standing here: their description, their signature, and what you may make to them.
struct HallPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: HallStore
    let person: HallPerson

    @State private var sending: String?
    /// The outcome of the last gesture or offer: the rendered line, or the refusal verbatim
    @State private var outcome: HallEvent?
    @State private var offering: Quest?
    @State private var isOffering = false

    /// Quests are carried out inside a favor with a connection, so only they get offers
    private var offerable: [Quest] {
        person.connected && store.hasCharacter ? store.openQuests : []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 14) {
                            PersonAvatar(userId: person.id, name: person.name, photo: person.avatarURL, size: 48)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 8) {
                                HallDescription(lines: person.description, fresh: store.freshLines[person.id] ?? [])
                                if let signature = person.signature {
                                    Text(signature)
                                        .font(.system(size: 15, design: .serif).italic())
                                        .foregroundColor(FavoriumTheme.accent)
                                }
                                if person.connected {
                                    Label("In your circle", systemImage: "link")
                                        .font(FavoriumTheme.captionFont)
                                        .foregroundColor(FavoriumTheme.ivoryDim)
                                }
                            }
                        }

                        let menu = store.hasCharacter ? store.gestures(for: person) : []
                        if !menu.isEmpty {
                            DecoDivider()
                            sheetHeading("Gesture")
                            FlowButtons(gestures: menu, sending: sending) { send($0) }
                        }

                        if !offerable.isEmpty {
                            DecoDivider()
                            sheetHeading("A quest to carry out together")
                            Text("\(person.name) receives it as a favor offer, worded exactly as the quest.")
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.ivoryDim)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(offerable) { quest in
                                Button { offering = quest } label: {
                                    HStack(spacing: 8) {
                                        if isOffering && offering?.id == quest.id {
                                            ProgressView().controlSize(.small).tint(FavoriumTheme.onGold)
                                        }
                                        Image(systemName: "hand.raised.fill")
                                        Text("Offer \u{201C}\(quest.title)\u{201D}")
                                            .fontWeight(.semibold)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                                    .metallicGoldCapsule()
                                }
                                .buttonStyle(.plain)
                                .disabled(isOffering)
                            }
                        }

                        if let outcome {
                            Label(outcome.text, systemImage: outcome.isRefusal ? "exclamationmark.circle" : "checkmark.circle")
                                .font(.system(size: 15, design: .serif))
                                .foregroundColor(outcome.isRefusal ? FavoriumTheme.amber : FavoriumTheme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .hallPage()
                    .padding(20)
                }
            }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { if person.connected { await store.loadMyQuests() } }
        }
        .presentationDetents([.medium, .large])
        .confirmationDialog("Offer this quest to \(person.name)?", isPresented: Binding(
            get: { offering != nil && !isOffering }, set: { if !$0 && !isOffering { offering = nil } }
        ), titleVisibility: .visible, presenting: offering) { quest in
            Button("Offer it as a favor") { offer(quest) }
            Button("Not now", role: .cancel) { }
        } message: { quest in
            Text(quest.prompt)
        }
    }

    private func offer(_ quest: Quest) {
        isOffering = true
        outcome = nil
        Task {
            defer { isOffering = false; offering = nil }
            do {
                _ = try await SupabaseService.shared.proposeQuestFavor(helpedUserId: person.id, userQuestId: quest.id)
                store.note("You offer to carry out \u{201C}\(quest.title)\u{201D} for \(person.name).")
                outcome = store.events.last
                await store.loadMyQuests()
                // A natural moment to ask: they'll want to hear back
                if PushManager.shared.canAskPermission { await PushManager.shared.requestAuthorization() }
            } catch {
                outcome = HallEvent(text: SupabaseService.errorMessage(error), isRefusal: true)
            }
        }
    }

    private func send(_ gesture: HallGesture) {
        sending = gesture.key
        outcome = nil
        Task {
            defer { sending = nil }
            await store.send(gesture, to: person)
            outcome = store.events.last
        }
    }
}

/// A description with any lines that are new since this device last saw them picked out
private struct HallDescription: View {
    let lines: [String]
    let fresh: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isFresh = fresh.contains(line)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if isFresh {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11))
                            .foregroundColor(FavoriumTheme.accent)
                            .accessibilityLabel("New")
                    }
                    Text(line)
                        .font(.system(size: index == 0 ? 17 : 15, weight: index == 0 ? .semibold : .regular, design: .serif))
                        .foregroundColor(isFresh ? FavoriumTheme.accent
                                         : (index == 0 ? FavoriumTheme.ivory : FavoriumTheme.ivory.opacity(0.9)))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
    }
}

/// The gesture menu as a wrapping set of outlined capsules, each ≥ 44 pt tall
private struct FlowButtons: View {
    let gestures: [HallGesture]
    let sending: String?
    let action: (HallGesture) -> Void

    var body: some View {
        // A vertical list reads better than a grid for sentence-length labels
        VStack(alignment: .leading, spacing: 8) {
            ForEach(gestures) { gesture in
                Button { action(gesture) } label: {
                    HStack(spacing: 8) {
                        if sending == gesture.key { ProgressView().controlSize(.small).tint(FavoriumTheme.accent) }
                        Text(gesture.label)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                        Spacer(minLength: 0)
                        if !gesture.isFree {
                            Image(systemName: "sparkle")
                                .font(.system(size: 11))
                                .accessibilityLabel("Earned")
                        }
                    }
                    .foregroundColor(FavoriumTheme.accent)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .overlay(Capsule().stroke(FavoriumTheme.accent.opacity(0.5), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(sending != nil)
            }
        }
    }
}

// MARK: - Looking at yourself

/// Your own description as others read it, what's in your pack, and the wardrobe.
struct HallSelfSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM
    @Bindable var store: HallStore
    @Bindable var characterStore: CharacterStore

    @State private var dressing: UUID?
    @State private var error: String?

    private var packItems: [InventoryItem] { characterStore.inventory.filter(\.isInBackpack) }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        CharacterDescriptionText(lines: characterStore.description)
                        if store.room?.isSneaking == true {
                            Label("You keep to the shadows. Nobody else sees you here.", systemImage: "eye.slash")
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.ivoryDim)
                        }

                        DecoDivider()
                        sheetHeading("In your pack")
                        if packItems.isEmpty {
                            Text("Your pack is empty.")
                                .font(.system(size: 15, design: .serif).italic())
                                .foregroundColor(FavoriumTheme.ivoryDim)
                        } else {
                            Text("Nobody sees these until you put them on.")
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.ivoryDim)
                            ForEach(packItems) { item in
                                HStack {
                                    Text(readable(item.text))
                                        .font(.system(size: 16, design: .serif))
                                        .foregroundColor(FavoriumTheme.ivory)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    if shownSlot(for: item) != nil {
                                        Button { putOn(item) } label: {
                                            HStack(spacing: 6) {
                                                if dressing == item.id { ProgressView().controlSize(.small) }
                                                Text("Put it on")
                                            }
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(FavoriumTheme.accent)
                                            .frame(minHeight: 44)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(dressing != nil)
                                    }
                                }
                            }
                        }
                        if let error {
                            Text(error)
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.amber)
                        }

                        // The board is in the Hall, but quests you've taken on go wherever you go
                        let open = store.myQuests.filter(\.isAccepted)
                        if !open.isEmpty {
                            DecoDivider()
                            sheetHeading("Quests you\u{2019}ve taken on")
                            ForEach(open) { quest in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(quest.title)
                                        .font(.system(size: 16, weight: .semibold, design: .serif))
                                        .foregroundColor(FavoriumTheme.ivory)
                                    Text(quest.prompt)
                                        .font(FavoriumTheme.captionFont)
                                        .foregroundColor(FavoriumTheme.ivoryDim)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if quest.favor_id != nil {
                                        Text("In a favor")
                                            .font(FavoriumTheme.captionFont)
                                            .foregroundColor(FavoriumTheme.accent)
                                    }
                                }
                            }
                        }

                        NavigationLink {
                            WardrobeView(store: characterStore)
                        } label: {
                            Label("Open the wardrobe", systemImage: "tshirt")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(FavoriumTheme.accent)
                                .frame(minHeight: 44)
                        }
                    }
                    .hallPage()
                    .padding(20)
                }
            }
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task {
                await characterStore.load(userId: appVM.userId)
                await store.loadMyQuests()
            }
        }
    }

    private func putOn(_ item: InventoryItem) {
        guard let character = characterStore.character, let slot = shownSlot(for: item) else { return }
        dressing = item.id
        error = nil
        Task {
            defer { dressing = nil }
            do {
                try await SupabaseService.shared.setShown(characterId: character.id, slot: slot, unlockId: item.id)
                store.note("You put on \(readable(item.text)).")
                await characterStore.load(userId: appVM.userId)
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}

// MARK: - Listen

/// Voices from each room: counts only, never names, and never anyone sneaking. A room
/// is a door only if it's one of this room's exits, so we never offer a walk the server
/// would refuse.
struct HallListenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: HallStore

    @State private var listen: RoomListen?
    @State private var error: String?

    private var exits: [RoomExit] { store.room?.exits ?? [] }
    private var here: String? { listen?.here ?? store.room?.roomKey }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("You stand still and listen.")
                            .font(.system(size: 17, design: .serif).italic())
                            .foregroundColor(FavoriumTheme.ivory)
                        if let error {
                            Text(error)
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.amber)
                        } else if listen == nil {
                            ProgressView().tint(FavoriumTheme.accent)
                        }
                        ForEach(listen?.rooms ?? []) { row($0) }
                        // The way back to the board, from wherever you are
                        if let way = listen?.way_to_hall, exits.contains(where: { $0.key == "hall" }) {
                            Button {
                                dismiss()
                                Task { await store.move(to: "hall", via: way) }
                            } label: {
                                Label(way, systemImage: "arrow.uturn.backward")
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                    .foregroundColor(FavoriumTheme.accent)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 6)
                        }
                    }
                    .hallPage()
                    .padding(20)
                }
            }
            .navigationTitle("Listen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func row(_ row: RoomListen.Row) -> some View {
        let exit = exits.first { $0.key == row.key }
        let content = HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(exit == nil ? FavoriumTheme.ivory : FavoriumTheme.accent)
                if row.key == here {
                    Text("You are here")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
            }
            Spacer()
            Text(voices(row.voices ?? 0))
                .font(.system(size: 14, design: .serif).italic())
                .foregroundColor(FavoriumTheme.ivoryDim)
            if exit != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())

        if let exit {
            Button {
                dismiss()
                Task { await store.move(to: exit.key, via: exit.label) }
            } label: { content }
            .buttonStyle(.plain)
            .accessibilityHint("Walk there")
        } else {
            content
        }
    }

    private func voices(_ count: Int) -> String {
        switch count {
        case 0:  "quiet"
        case 1:  "one voice"
        default: "\(count) voices"
        }
    }

    private func load() async {
        do {
            let result = try await SupabaseService.shared.roomListen()
            store.remember(result)
            listen = result
        } catch {
            self.error = SupabaseService.errorMessage(error)
        }
    }
}

// MARK: - First-run gifts

/// Shown once, straight after creating a character: the signature greeting and the
/// starter item. The item is granted but not worn; putting it on is the first lesson.
struct HallGiftsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appVM
    @Bindable var store: HallStore
    @Bindable var characterStore: CharacterStore

    @State private var dressing: UUID?
    @State private var error: String?

    /// The signature gesture drawn at creation sits outside the free greetings
    private var signature: HallGesture? { store.gestures.first { !$0.isFree && ($0.owned ?? false) } }
    private var packItems: [InventoryItem] { characterStore.inventory.filter(\.isInBackpack) }

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Two things are yours now: a greeting of your own, and something in your pack.")
                            .font(.system(size: 17, design: .serif))
                            .foregroundColor(FavoriumTheme.ivory)
                            .fixedSize(horizontal: false, vertical: true)
                        if let signature {
                            CharacterCard {
                                sheetHeading("Your greeting")
                                Text(signature.label)
                                    .font(.system(size: 17, weight: .semibold, design: .serif))
                                    .foregroundColor(FavoriumTheme.ivory)
                            }
                        }
                        ForEach(packItems) { item in
                            CharacterCard {
                                sheetHeading("In your pack")
                                Text(readable(item.text))
                                    .font(.system(size: 17, weight: .semibold, design: .serif))
                                    .foregroundColor(FavoriumTheme.ivory)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Nobody sees it while it\u{2019}s in your pack. Put it on and it appears in your description.")
                                    .font(FavoriumTheme.captionFont)
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                                    .fixedSize(horizontal: false, vertical: true)
                                if shownSlot(for: item) != nil {
                                    Button { putOn(item) } label: {
                                        GoldButtonLabel(title: "Put it on", busy: dressing == item.id)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(dressing != nil)
                                }
                            }
                        }
                        if let error {
                            Text(error)
                                .font(FavoriumTheme.captionFont)
                                .foregroundColor(FavoriumTheme.amber)
                        }
                    }
                    .hallPage()
                    .padding(16)
                }
            }
            .navigationTitle("Welcome to the hall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func putOn(_ item: InventoryItem) {
        guard let character = characterStore.character, let slot = shownSlot(for: item) else { return }
        dressing = item.id
        error = nil
        Task {
            defer { dressing = nil }
            do {
                try await SupabaseService.shared.setShown(characterId: character.id, slot: slot, unlockId: item.id)
                store.note("You put on \(readable(item.text)).")
                await characterStore.load(userId: appVM.userId)
                await store.refresh()
                dismiss()
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
        }
    }
}
