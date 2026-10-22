//
//  GemDetailView.swift
//  favorium
//
//  Full gem detail + complete journey timeline.
//  Uses coin_journey RPC — no new endpoints.
//

import SwiftUI
import Helpers
import Supabase

// MARK: - View Model

@Observable
final class GemDetailViewModel {
    enum LoadState { case idle, loading, loaded, failed(String) }

    var journey: SupabaseService.CoinJourneyPayload?
    var loadState: LoadState = .idle

    // Controls whether the "earlier exchanges" collapsed block is expanded
    var earlierExpanded: Bool = false

    /// True when a completed favor is waiting for a gem — only then is "Send this gem" offered
    var hasFavorsAwaitingGem: Bool = false

    @MainActor
    func load(coinId: UUID, userId: UUID?) async {
        loadState = .loading
        do {
            // Optional: if this fails the send button simply stays hidden
            async let incomingTask: [SupabaseService.Favor]? = {
                guard let userId else { return nil }
                return try? await SupabaseService.shared.myIncomingFavors(userId: userId)
            }()
            let result = try await SupabaseService.shared.coinJourney(coinID: coinId)
            journey = result
            // Filter on the main actor (Favor's status helpers are main-actor isolated)
            hasFavorsAwaitingGem = ((await incomingTask) ?? []).contains { $0.isCompleted && $0.coin_id == nil }
            loadState = .loaded
        } catch is CancellationError {
            if case .loading = loadState { loadState = .idle }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Main View

struct GemDetailView: View {
    let coinId: UUID
    let coinName: String
    let userId: UUID?

    @State private var vm = GemDetailViewModel()
    @State private var showSend = false
    @State private var showRename = false
    @State private var gemAppeared = false
    @State private var guideTopic: GemGuideView.Topic?
    @State private var showInterior = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
                .background(FavoriumTheme.accentMuted.opacity(0.3))

            ZStack {
                FavoriumTheme.background.ignoresSafeArea()

                switch vm.loadState {
                case .idle, .loading:
                    loadingContent
                case .failed(let msg):
                    errorContent(msg)
                case .loaded:
                    if let j = vm.journey {
                        loadedContent(j)
                    }
                }
            }
        }
        .background(FavoriumTheme.background.ignoresSafeArea())
        .task { await vm.load(coinId: coinId, userId: userId) }
        .sheet(isPresented: $showRename) {
            if let j = vm.journey {
                RenameGemView(coinId: coinId, currentName: j.name,
                              dna: j.dna, transferCount: j.transferCount) { _ in
                    Task { await vm.load(coinId: coinId, userId: userId) }
                }
            }
        }
        .sheet(item: $guideTopic) { topic in
            GemGuideView(initialTopic: topic, dna: vm.journey?.dna,
                         transferCount: vm.journey?.transferCount ?? 0, userId: userId)
        }
        .sheet(isPresented: $showSend) {
            if let j = vm.journey {
                SendGemView(
                    initialGem: GiftableGem(id: coinId, name: j.name,
                                            transferCount: j.transferCount, dna: j.dna,
                                            creatorId: j.isCreator == true ? userId : nil,
                                            restingUntil: j.restingUntil),
                    userId: userId
                ) {
                    Task { await vm.load(coinId: coinId, userId: userId) }
                }
            }
        }
    }

    // MARK: - Loaded content

    private func loadedContent(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Hero gem ──────────────────────────────────────────────
                heroGem(j)
                    .padding(.bottom, 24)

                // ── Gem name + attributes ─────────────────────────────────
                gemMeta(j)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // ── Story (matches the Collection card) ───────────────────
                storyCard(j)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // ── Resting (owner): the 24h cooldown since its last hand-off ─
                if j.isOwner == true, let until = j.restingUntil {
                    restingCard(until: until)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }
                // ── Send button (owner, with a completed favor awaiting a gem) ─
                else if j.isOwner == true && vm.hasFavorsAwaitingGem {
                    sendButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }

                // ── Journey timeline ──────────────────────────────────────
                journeySection(j)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
            // Without this the VStack inside a ScrollView sizes itself to
            // fit content rather than filling the available width, which
            // causes text to be measured against a narrow intrinsic width
            // and then clipped at the scroll view boundary.
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                    .frame(width: 40, height: 40)
                    .background(FavoriumTheme.surface)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Gem journey")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)

            Spacer()

            // Balances the close button so the title stays centred
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(FavoriumTheme.background)
    }

    // MARK: - Hero

    private func heroGem(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        let hue       = j.dna?.resolvedHue ?? 45
        let sat       = j.dna?.resolvedSaturation ?? 0.7
        let glowColor = Color(hue: hue / 360.0, saturation: sat, brightness: 0.9)
        let gemSize: CGFloat = 280

        // Gem — rendered straight from its DNA (family, gem + frame color, trait)
        return FavorGemView(
            dna: j.dna,
            transferCount: j.transferCount,
            size: gemSize,
            showGlow: true,
            showShimmer: true
        )
        .scaleEffect(gemAppeared ? 1.0 : 0.82)
        .opacity(gemAppeared ? 1.0 : 0.0)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.62),
            value: gemAppeared
        )
        // Press and hold to step inside the gem
        .enterGemOnLongPress(
            isPresented: $showInterior,
            interior: { GemInterior(name: j.name, dna: j.dna, transferCount: j.transferCount) },
            dna: j.dna, transferCount: j.transferCount)
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .overlay(alignment: .bottom) {
            Label("Press and hold to step inside", systemImage: "hand.tap")
                .font(FavoriumTheme.captionFont)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 12)
                .allowsHitTesting(false)
        }
        // Decorative gradients live in the background so their oversized
        // frames never widen the layout — on small phones the 448pt glow
        // used to push the whole scroll content (and the Journey) off-screen.
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(hue: hue / 360.0, saturation: 0.3, brightness: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [glowColor.opacity(0.25), Color.clear],
                    center: .center,
                    startRadius: gemSize * 0.18,
                    endRadius: gemSize * 0.9
                )
                .frame(width: gemSize * 1.6, height: gemSize * 1.6)
                .blur(radius: 30)
            }
        }
        .clipped()
        .onAppear { gemAppeared = true }
        .onDisappear { gemAppeared = false }
    }

    // MARK: - Gem meta

    private func gemMeta(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        let tier = Tier.from(transferCount: j.transferCount)
        let family = GemFamily.from(j.dna?.resolvedFamily)

        let isCreator = j.isCreator == true
        let hasStarterName = GemNaming.isStarterName(j.name)

        return VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(j.name)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                    .multilineTextAlignment(.center)
                // Only the creator may rename (enforced by rename_coin)
                if isCreator {
                    Button { showRename = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(FavoriumTheme.accent)
                    }
                    .accessibilityLabel("Rename gem")
                }
            }

            // Nudge creators whose gem still has its auto-generated starter name
            if isCreator && hasStarterName {
                Button { showRename = true } label: {
                    VStack(spacing: 4) {
                        Label("Name your gem", systemImage: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FavoriumTheme.accent)
                        Text("It still has its starter name. Give it one that means something to you.")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(FavoriumTheme.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                            .stroke(FavoriumTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
                }
                .buttonStyle(.plain)
            }

            if j.isCreator == true {
                Text("One of your original gems")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FavoriumTheme.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(FavoriumTheme.gold.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(FavoriumTheme.gold.opacity(0.4), lineWidth: 1))
            }

            Text(holderLabel(j))
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)

            // Tapping either half opens the gem guide at that topic
            HStack(spacing: 6) {
                Button { guideTopic = .families } label: {
                    Text(family.displayName)
                }
                .accessibilityHint("Learn about gem families")
                Circle().frame(width: 3, height: 3)
                Button { guideTopic = .levels } label: {
                    HStack(spacing: 4) {
                        Text(tier.displayName)
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                    }
                }
                .accessibilityHint("Learn about gem levels")
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(tier.defaultColor)

            // Trait label + description — revealed only once the gem reaches Bloom
            if tier != .seed, let trait = GemTrait.from(j.dna?.trait) {
                traitCard(trait)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func traitCard(_ trait: GemTrait) -> some View {
        VStack(spacing: 6) {
            Label(trait.displayName, systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FavoriumTheme.accent)
            Text(trait.description)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(FavoriumTheme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                .stroke(FavoriumTheme.accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Story

    /// The favor this gem remembers. For the holder, that's the favor that brought it
    /// to them (the same story the Collection card shows); otherwise its latest favor.
    private func story(_ j: SupabaseService.CoinJourneyPayload) -> SupabaseService.CoinHistoryItem? {
        let transfers = j.history
            .filter(\.isTransfer)
            .sorted { $0.createdAt > $1.createdAt }
        if j.isOwner == true {
            return transfers.first { $0.isToMe == true }
        }
        return transfers.first
    }

    private func storyCard(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        let item = story(j)
        return VStack(alignment: .leading, spacing: 8) {
            Text(j.isOwner == true ? "How it came to you" : "Its latest story")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FavoriumTheme.accentMuted)
                .textCase(.uppercase)

            if let item {
                Text("\u{201C}\(item.description ?? "A favor")\u{201D}")
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundColor(FavoriumTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                Text(storyCaption(item, isOwner: j.isOwner == true))
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
            } else {
                Text(GemStoryCopy.noStoryTitle)
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundColor(FavoriumTheme.ivoryDim)
                Text(GemStoryCopy.noStoryExplanation)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accentMuted.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Holder: "for Sam · Oct 19" (same as the Collection card).
    /// Others: "Alex helped Sam · Oct 19". The gem goes from the helped person to the helper.
    private func storyCaption(_ item: SupabaseService.CoinHistoryItem, isOwner: Bool) -> String {
        let helped = item.fromName ?? "someone"
        let who = isOwner ? "for \(helped)" : "\(item.toName ?? "Someone") helped \(helped)"
        let date = formattedDate(item.createdAt)
        return date.isEmpty ? who : "\(who) · \(date)"
    }

    private func holderLabel(_ j: SupabaseService.CoinJourneyPayload) -> String {
        let count = j.transferCount
        if j.isOwner == true {
            return "In your possession · \(count) exchanges"
        }
        let holder = j.ownerName ?? "someone"
        return "Currently with \(holder) · \(count) exchanges"
    }

    // MARK: - Send button

    private var sendButton: some View {
        Button { showSend = true } label: {
            HStack {
                Image(systemName: "paperplane")
                Text("Send this gem")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .metallicGoldCapsule()
        }
    }

    /// A gem can change hands once a day; this replaces the send button until then.
    private func restingCard(until: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 18))
                .foregroundColor(FavoriumTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Resting")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                Text("It can move again in \(Text(until, style: .relative)).")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Journey timeline

    private func journeySection(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Journey")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(FavoriumTheme.ivory)
                Spacer()
                Text("Newest first")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
            .padding(.bottom, 16)

            // Divider line with star
            HStack {
                Spacer()
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundColor(FavoriumTheme.accentMuted)
                Spacer()
            }
            .padding(.bottom, 16)

            // The RPC returns history ascending by created_at (oldest first, per
            // the backend contract). Re-sort newest-first so the minted event
            // lands in the tail slot. ISO-8601 timestamps sort lexically.
            let history = j.history.sorted { $0.createdAt > $1.createdAt }

            if let tail = history.last {
                // Split the history into three logical buckets:
                //  head   — first 2 entries (newest), always visible
                //  middle — everything between head and the last entry
                //  tail   — the final entry (creation event), always visible
                //
                // With 1 entry:  head=[], middle=[], tail=[item0]
                // With 2 entries: head=[item0], middle=[], tail=[item1]
                // With 3 entries: head=[item0,item1], middle=[], tail=[item2]
                // With 4+ entries: head=[item0,item1], middle=[item2…n-1], tail=[itemN]

                let headCount  = min(2, max(0, history.count - 1))
                let head       = Array(history.prefix(headCount))
                let middle     = headCount < history.count - 1
                               ? Array(history[headCount ..< history.count - 1])
                               : []

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(head) { item in
                        timelineRow(item, isLast: false)
                    }

                    if !middle.isEmpty {
                        collapseRow(count: middle.count)
                            .animation(.easeInOut(duration: 0.3), value: vm.earlierExpanded)

                        if vm.earlierExpanded {
                            ForEach(middle) { item in
                                timelineRow(item, isLast: false)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    timelineRow(tail, isLast: true)
                }
            } else {
                Text("No exchanges yet.")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Timeline row

    private func timelineRow(_ item: SupabaseService.CoinHistoryItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline spine
            VStack(spacing: 0) {
                if item.isGift {
                    // A gift from Favorium is its own kind of step
                    Image(systemName: "gift.fill")
                        .font(.system(size: 10))
                        .foregroundColor(FavoriumTheme.accent)
                        .frame(width: 10, height: 12)
                        .padding(.top, 3)
                } else {
                    // Hand-offs get a solid dot; a rename is a hollow ring — part of the story, not a step
                    Circle()
                        .fill(item.isRename ? Color.clear : FavoriumTheme.accent)
                        .overlay(Circle().strokeBorder(FavoriumTheme.accent, lineWidth: item.isRename ? 1.5 : 0))
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)
                }
                if !isLast {
                    Rectangle()
                        .fill(FavoriumTheme.accentMuted.opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    // Who this step was with (photo or initials)
                    let person = timelinePerson(item)
                    PersonAvatar(userId: person.id, name: person.name, photo: person.photo, level: person.level, size: 24)
                    // Long names wrap rather than pushing the date off-screen
                    Text(transferLabel(item))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(formattedDate(item.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize()
                }
                if item.isRename, let oldName = item.oldName, let newName = item.newName {
                    // Old name fades and is struck through; the new one carries the gold
                    let before = Text(oldName).strikethrough()
                    let after = Text(newName).foregroundColor(FavoriumTheme.accent).fontWeight(.semibold)
                    Text("\(before)  →  \(after)")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Renamed from \(oldName) to \(newName)")
                } else if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .lineLimit(3)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
    }

    /// The person to picture on a journey step: the other party on your own transfers,
    /// otherwise the recipient (for "minted", that's the creator). A rename shows who renamed it.
    private func timelinePerson(_ item: SupabaseService.CoinHistoryItem) -> (id: UUID?, name: String?, photo: String?, level: Int?) {
        if item.isRename {
            return (item.fromId, item.fromName, item.fromAvatar, item.fromLevel)
        }
        if item.isToMe == true, item.isTransfer {
            return (item.fromId, item.fromName, item.fromAvatar, item.fromLevel)
        }
        return (item.toId, item.toName, item.toAvatar, item.toLevel)
    }

    private func transferLabel(_ item: SupabaseService.CoinHistoryItem) -> String {
        switch item.eventType {
        case "minted":
            return "Brought into the world"
        case "transferred":
            let from = item.fromName ?? "Someone"
            let to   = item.toName   ?? "someone"
            if item.isFromMe == true { return "You → \(to)" }
            if item.isToMe   == true { return "\(from) → You" }
            return "\(from) → \(to)"
        case "renamed":
            return item.isFromMe == true ? "You renamed it" : "\(item.fromName ?? "Someone") renamed it"
        case "gifted":
            return item.isToMe == true ? "Found its way to you" : "Found its way to \(item.toName ?? "someone")"
        default:
            return item.eventType.capitalized
        }
    }

    // MARK: - Collapse row

    private func collapseRow(count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                vm.earlierExpanded.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Spine — matches timelineRow's 10pt column width exactly.
                // The ellipsis badge is centred on the spine line rather than
                // overflowing it, so nothing bleeds outside the column.
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(FavoriumTheme.surface)
                            .frame(width: 20, height: 20)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(FavoriumTheme.accentMuted)
                    }
                    .padding(.top, 4)
                    Rectangle()
                        .fill(FavoriumTheme.accentMuted.opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 10)

                HStack {
                    Text(vm.earlierExpanded ? "Collapse earlier exchanges" : "\(count) earlier exchanges")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(FavoriumTheme.accent)
                    Spacer()
                    Image(systemName: vm.earlierExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(FavoriumTheme.accent)
                }
                .padding(.bottom, 20)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading / Error states

    private var loadingContent: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(FavoriumTheme.accent)
                .scaleEffect(1.4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(FavoriumTheme.amber)
            Text(message)
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                Task { await vm.load(coinId: coinId, userId: userId) }
            }
            .foregroundColor(FavoriumTheme.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Date formatting

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return ""
        }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }
}


#Preview("Gem Detail") {
    NavigationStack {
        GemDetailView(
            coinId: UUID(),
            coinName: "Rainbow Heart",
            userId: UUID?.none
        )
    }
}
