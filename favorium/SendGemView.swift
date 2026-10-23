//
//  SendGemView.swift
//  favorium
//
//  "Give a gem" sheet — the final step of the favor flow. A gem can only move
//  as thanks for a completed favor: the signed-in user must be the *helped*
//  person on a favor in `completed` status that hasn't received a coin yet
//  (enforced server-side by transfer_coin). The gem goes to that favor's helper.
//
//  Can be opened from either side:
//   • from a gem (Collection / gem detail) → the user picks which favor to thank
//   • from a favor (Favors tab)            → the user picks which gem to give
//

import SwiftUI

/// The minimal gem info needed to preview and give a gem.
struct GiftableGem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let transferCount: Int
    let dna: SupabaseService.GemDNA?
    /// Who created the gem — only they may rename it
    let creatorId: UUID?
    /// End of the 24h transfer cooldown, if the gem is still resting
    let restingUntil: Date?

    /// Resting gems can't change hands yet (transfer_coin would refuse)
    var isResting: Bool { restingUntil.map { $0 > .now } ?? false }

    static func == (lhs: GiftableGem, rhs: GiftableGem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(id: UUID, name: String, transferCount: Int, dna: SupabaseService.GemDNA?,
         creatorId: UUID? = nil, restingUntil: Date? = nil) {
        self.id = id
        self.name = name
        self.transferCount = transferCount
        self.dna = dna
        self.creatorId = creatorId
        self.restingUntil = restingUntil
    }

    /// Same gem with a new name (after rename_coin)
    func renamed(_ newName: String) -> GiftableGem {
        GiftableGem(id: id, name: newName, transferCount: transferCount, dna: dna,
                    creatorId: creatorId, restingUntil: restingUntil)
    }

    init(_ coin: SupabaseService.CoinSummary) {
        self.init(id: coin.id, name: coin.name ?? "Gem",
                  transferCount: coin.transfer_count ?? 0, dna: coin.gemDNA,
                  creatorId: coin.creator_id, restingUntil: coin.restingUntil)
    }
}

// MARK: - View Model

@Observable
final class SendGemViewModel {
    enum Step { case choose, review, sending, done, failed(String) }

    var gem: GiftableGem?
    var favor: SupabaseService.Favor?

    /// Options shown when the matching side wasn't provided up front
    var heldGems: [GiftableGem] = []
    var favorsAwaitingGem: [SupabaseService.Favor] = []
    var isLoading = false
    var loadError: String?

    var step: Step = .choose

    var canReview: Bool { (gem.map { !$0.isResting } ?? false) && favor != nil }

    /// Every gem the user holds is in its cooldown, so there's nothing to give yet
    var allGemsResting: Bool { !heldGems.isEmpty && heldGems.allSatisfy(\.isResting) }

    /// The first moment one of the held gems can move again
    var soonestAvailable: Date? { heldGems.compactMap(\.restingUntil).min() }

    /// Load whichever side the user still needs to pick.
    @MainActor
    func loadOptions(userId: UUID?, needGems: Bool, needFavors: Bool) async {
        guard let userId else { loadError = "You need to be signed in."; return }
        isLoading = true
        defer { isLoading = false }
        do {
            if needFavors {
                // Favors I received, confirmed complete, and not yet thanked with a gem
                favorsAwaitingGem = try await SupabaseService.shared.myIncomingFavors(userId: userId)
                    .filter { $0.isCompleted && $0.coin_id == nil }
            }
            if needGems {
                heldGems = try await SupabaseService.shared.myFavors(userId: userId).map(GiftableGem.init)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    @MainActor
    func send() async {
        guard let gem, let favor else { return }
        step = .sending
        do {
            try await SupabaseService.shared.transferCoin(favorId: favor.id, coinId: gem.id)
            step = .done
        } catch {
            if let until = SupabaseService.restingUntil(from: error) {
                // Our copy of the cooldown was stale; record it so the picker greys this gem out
                let resting = GiftableGem(id: gem.id, name: gem.name, transferCount: gem.transferCount,
                                          dna: gem.dna, creatorId: gem.creatorId, restingUntil: until)
                self.gem = resting
                heldGems = heldGems.map { $0.id == gem.id ? resting : $0 }
                step = .failed("\(gem.name) is resting. A gem can only change hands once a day. It can move again \(until.formatted(.relative(presentation: .named))).")
            } else {
                step = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Main View

struct SendGemView: View {
    /// Pre-selected gem (opened from Collection / gem detail), or nil to pick one.
    let initialGem: GiftableGem?
    /// Pre-selected favor (opened from the Favors tab), or nil to pick one.
    let initialFavor: SupabaseService.Favor?
    let userId: UUID?
    let onComplete: () -> Void

    @State private var vm = SendGemViewModel()
    @State private var showRename = false
    // A farewell engraving, offered to eligible holders before the gem leaves
    @State private var canEngrave = false
    @State private var gemHasEngraving = false
    @State private var engravedNow = false
    @State private var showEngrave = false
    @Environment(\.dismiss) private var dismiss

    init(
        initialGem: GiftableGem? = nil,
        initialFavor: SupabaseService.Favor? = nil,
        userId: UUID?,
        onComplete: @escaping () -> Void
    ) {
        self.initialGem = initialGem
        self.initialFavor = initialFavor
        self.userId = userId
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            switch vm.step {
            case .choose:
                chooseView
            case .review:
                reviewView
            case .sending:
                VStack(spacing: 20) {
                    ProgressView().tint(FavoriumTheme.accent).scaleEffect(1.6)
                    Text("Giving your gem…")
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
            case .done:
                doneView
            case .failed(let msg):
                failureView(msg)
            }
        }
        .sheet(isPresented: $showRename) {
            if let gem = vm.gem {
                RenameGemView(coinId: gem.id, currentName: gem.name,
                              dna: gem.dna, transferCount: gem.transferCount) { newName in
                    vm.gem = gem.renamed(newName)
                }
            }
        }
        .sheet(isPresented: $showEngrave) {
            if let gem = vm.gem {
                EngraveGemView(coinId: gem.id, gemName: gem.name, dna: gem.dna, transferCount: gem.transferCount,
                               isReplacing: gemHasEngraving) {
                    engravedNow = true
                    canEngrave = false
                }
            }
        }
        .task(id: vm.gem?.id) {
            guard let gem = vm.gem else { return }
            async let status = try? SupabaseService.shared.myEngravingStatus()
            async let existing = try? SupabaseService.shared.coinEngravings(coinId: gem.id)
            canEngrave = await status?.eligible ?? false
            gemHasEngraving = !(await existing ?? []).isEmpty
        }
        .task {
            vm.gem = initialGem
            vm.favor = initialFavor
            await vm.loadOptions(userId: userId,
                                 needGems: initialGem == nil,
                                 needFavors: initialFavor == nil)
        }
    }

    // MARK: - Choose step

    private var chooseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                navBar(title: "Give a gem", leading: "xmark") { dismiss() }

                if let gem = vm.gem {
                    gemPreview(gem)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .topTrailing) {
                            if initialGem == nil {
                                changeButton { vm.gem = nil }
                            }
                        }
                    if let until = gem.restingUntil, gem.isResting {
                        restingNotice(name: gem.name, until: until)
                    }
                } else {
                    gemPicker
                }

                if let favor = vm.favor {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("For")
                        favorRow(favor, isSelected: true)
                            .overlay(alignment: .topTrailing) {
                                if initialFavor == nil {
                                    changeButton { vm.favor = nil }.padding(8)
                                }
                            }
                    }
                } else {
                    favorPicker
                }

                if let error = vm.loadError {
                    Text(error)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.amber)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { vm.step = .review }
                } label: {
                    HStack {
                        Text("Review gift")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
                    .opacity(vm.canReview ? 1.0 : 0.4)
                }
                .disabled(!vm.canReview)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Favor picker

    @ViewBuilder
    private var favorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Which favor are you thanking them for?")

            if vm.isLoading {
                ProgressView().tint(FavoriumTheme.accent).frame(maxWidth: .infinity)
            } else if vm.favorsAwaitingGem.isEmpty {
                // Explain how gems are earned instead of showing an empty list
                VStack(alignment: .leading, spacing: 8) {
                    Label("No favors waiting for a gem", systemImage: "hourglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Text("Gems are given to thank someone for a favor they did for you. When someone offers to help, accept it in the Favors tab, then confirm it's done. It will show up here.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            } else {
                ForEach(vm.favorsAwaitingGem) { favor in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.favor = favor }
                    } label: {
                        favorRow(favor, isSelected: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func favorRow(_ favor: SupabaseService.Favor, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(favor.helper_name ?? "Someone") helped you")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
            Text(favor.description)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                .stroke(isSelected ? FavoriumTheme.accent.opacity(0.6) : FavoriumTheme.accentMuted.opacity(0.25),
                        lineWidth: 1)
        )
    }

    // MARK: - Gem picker

    @ViewBuilder
    private var gemPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Which gem will you give?")

            if vm.isLoading {
                ProgressView().tint(FavoriumTheme.accent).frame(maxWidth: .infinity)
            } else if vm.heldGems.isEmpty {
                Text("You don't hold any gems right now.")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
            } else {
                if vm.allGemsResting, let soonest = vm.soonestAvailable {
                    // Not a dead end: the favor stays complete and can be thanked later
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Every gem is resting", systemImage: "moon.zzz.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                        Text("A gem can only change hands once a day. The first one is ready in \(Text(soonest, style: .relative)). This favor will wait for you.")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FavoriumTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
                }
                ForEach(vm.heldGems) { gem in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.gem = gem }
                    } label: {
                        HStack(spacing: 14) {
                            gemImage(gem, size: 46, animated: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gem.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(FavoriumTheme.ivory)
                                if let until = gem.restingUntil, gem.isResting {
                                    Text("Resting · ready in \(Text(until, style: .relative))")
                                        .font(FavoriumTheme.captionFont)
                                        .foregroundColor(FavoriumTheme.ivoryDim)
                                } else {
                                    Text(Tier.from(transferCount: gem.transferCount).displayName)
                                        .font(FavoriumTheme.captionFont)
                                        .foregroundColor(FavoriumTheme.ivoryDim)
                                }
                            }
                            Spacer()
                            if gem.isResting {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                            }
                        }
                        .padding(12)
                        .background(FavoriumTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                        .opacity(gem.isResting ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(gem.isResting)
                }
            }
        }
    }

    // MARK: - Gem rendering

    private func gemColor(_ gem: GiftableGem) -> Color {
        gem.dna?.gemColor ?? Tier.from(transferCount: gem.transferCount).defaultColor
    }

    /// The outer glow is reserved for Gem Details; `animated` keeps the shimmer on the featured gem.
    private func gemImage(_ gem: GiftableGem, size: CGFloat, animated: Bool) -> some View {
        FavorGemView(
            dna: gem.dna,
            transferCount: gem.transferCount,
            size: size,
            showShimmer: animated
        )
    }

    private func gemPreview(_ gem: GiftableGem) -> some View {
        let tier   = Tier.from(transferCount: gem.transferCount)
        let family = GemFamily.from(gem.dna?.resolvedFamily)
        return VStack(spacing: 10) {
            ZStack {
                RadialGradient(
                    colors: [gemColor(gem).opacity(0.18), .clear],
                    center: .center, startRadius: 20, endRadius: 130
                )
                .frame(width: 260, height: 260)
                .blur(radius: 20)

                // Same renderer as the detail page so the gem looks identical
                gemImage(gem, size: 180, animated: true)
            }
            .frame(height: 220)
            Text(gem.name)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
            Text("\(family.displayName) · \(tier.displayName)")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(tier.defaultColor)
        }
    }

    // MARK: - Review step

    private var reviewView: some View {
        VStack(spacing: 0) {
            navBar(title: "Review gift", leading: "chevron.left") {
                withAnimation(.easeInOut(duration: 0.25)) { vm.step = .choose }
            }
            .padding(.horizontal, 20)

            if let gem = vm.gem, let favor = vm.favor {
                ScrollView {
                    VStack(spacing: 20) {
                        gemPreview(gem)

                        VStack(alignment: .leading, spacing: 12) {
                            reviewRow(label: "To", value: favor.helper_name ?? "Your helper")
                            reviewRow(label: "For", value: favor.description)
                        }
                        .padding(16)
                        .background(FavoriumTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))

                        // Last chance for the creator to name a gem before it leaves
                        if GemNaming.shouldSuggestNaming(name: gem.name, creatorId: gem.creatorId, userId: userId) {
                            Button { showRename = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "pencil.line")
                                        .foregroundColor(FavoriumTheme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Name it first?")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(FavoriumTheme.ivory)
                                        Text("You created this gem and it still has its starter name.")
                                            .font(FavoriumTheme.captionFont)
                                            .foregroundColor(FavoriumTheme.ivoryDim)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(FavoriumTheme.ivoryDim)
                                }
                                .padding(14)
                                .background(FavoriumTheme.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                            }
                            .buttonStyle(.plain)
                        }

                        if canEngrave || engravedNow {
                            Button { showEngrave = true } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: engravedNow ? "checkmark.seal.fill" : "seal.fill")
                                        .foregroundColor(FavoriumTheme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(engravedNow ? "Your words are sealed inside"
                                                         : "Engrave a message before it leaves you")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(FavoriumTheme.ivory)
                                        Text(engravedNow ? "\(favor.helper_name ?? "They") can find them by stepping inside."
                                             : gemHasEngraving ? "It already holds a secret; yours would replace it."
                                             : "A few unsigned words for whoever holds it next.")
                                            .font(FavoriumTheme.captionFont)
                                            .foregroundColor(FavoriumTheme.ivoryDim)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    if !engravedNow {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(FavoriumTheme.ivoryDim)
                                    }
                                }
                                .padding(14)
                                .background(FavoriumTheme.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                            }
                            .buttonStyle(.plain)
                            .disabled(engravedNow)
                        }

                        Text("Once given, this gem belongs to \(favor.helper_name ?? "them") and continues its journey from there.")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                }
            }

            Button {
                Task { await vm.send() }
            } label: {
                HStack {
                    Image(systemName: "gift.fill")
                    Text("Give gem")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .metallicGoldCapsule()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func reviewRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(FavoriumTheme.ivory)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Done / Failure

    private var doneView: some View {
        FavorGivenView(
            given: FavorGiven(gem: vm.gem, helperName: vm.favor?.helper_name ?? "them"),
            onDone: onComplete
        )
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(FavoriumTheme.amber)
            Text("Couldn't give this gem")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(FavoriumTheme.ivory)
            Text(message)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    withAnimation { vm.step = .choose }
                } label: {
                    Text("Back")
                        .fontWeight(.semibold)
                        .foregroundColor(FavoriumTheme.ivory)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FavoriumTheme.surface)
                        .clipShape(Capsule())
                }
                Button {
                    Task { await vm.send() }
                } label: {
                    Text("Try again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .metallicGoldCapsule()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Shared pieces

    private func navBar(title: String, leading: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button(action: action) {
                Image(systemName: leading)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                    .frame(width: 40, height: 40)
                    .background(FavoriumTheme.surface)
                    .clipShape(Circle())
            }
            Spacer()
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(FavoriumTheme.ivoryDim)
    }

    /// Shown when the chosen gem is still in its 24h cooldown
    private func restingNotice(name: String, until: Date) -> some View {
        Label {
            Text("\(name) is resting. A gem can only change hands once a day. It can move again in \(Text(until, style: .relative)).")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "moon.zzz.fill")
        }
        .font(FavoriumTheme.captionFont)
        .foregroundColor(FavoriumTheme.ivoryDim)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
    }

    private func changeButton(_ action: @escaping () -> Void) -> some View {
        Button("Change", action: action)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
    }
}

#Preview("Give a gem") {
    SendGemView(
        initialGem: GiftableGem(id: UUID(), name: "Rainbow Heart", transferCount: 8, dna: nil),
        userId: nil,
        onComplete: {}
    )
}
