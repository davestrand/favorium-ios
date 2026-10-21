//
//  CollectionView.swift
//  favorium
//
//  "Collection" tab — two-column grid of held gems + original gems section.
//  All data from SupabaseService; no new backend calls invented.
//

import SwiftUI
import Supabase

struct CollectionView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(FavorNotificationCenter.self) private var notifications
    @State private var vm = CollectionViewModel()
    @State private var selectedCoin: SupabaseService.CoinSummary?
    @State private var showSendPicker = false
    /// Flips just after the first load lands so gems fade in one after another
    /// instead of popping in. Stays true, so lazily re-created cells show immediately.
    @State private var gemsRevealed = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ───────────────────────────────────────
                        headerView
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // ── Held gems grid ───────────────────────────────
                        heldSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)
                            .frame(maxWidth: .infinity)

                        // ── Give a gem CTA (only when a completed favor is waiting for one) ───
                        if !vm.held.isEmpty && !vm.favorsAwaitingGem.isEmpty {
                            sendCTAButton
                                .fadeInOnFirstAppear()
                                .padding(.horizontal, 16)
                                .padding(.bottom, 32)
                        }

                        // ── Original gems ────────────────────────────────
                        originalsSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)  // anchor the VStack to scroll view width
                }
                // Content fades in over the fixed backdrop on the tab's first visit
                .fadeInOnFirstAppear()
                .refreshable {
                    if let uid = appVM.userId {
                        await vm.load(userId: uid)
                    }
                }
            }
            .navigationBarHidden(true)
            .onChange(of: vm.loadState) { _, state in
                guard case .loaded = state, !gemsRevealed else { return }
                Task {
                    // Let the cells render transparent first, or the fade is skipped
                    try? await Task.sleep(for: .milliseconds(60))
                    gemsRevealed = true
                }
            }
            // Live updates: a gem received or a favor completed elsewhere shows up immediately
            .onChange(of: notifications.changeToken) { _, _ in
                if let uid = appVM.userId { Task { await vm.load(userId: uid) } }
            }
            .task {
                if let uid = appVM.userId, case .idle = vm.loadState {
                    await vm.load(userId: uid)
                }
            }
            .sheet(item: $selectedCoin, onDismiss: {
                // Pick up anything changed on the detail page (e.g. a new name)
                if let uid = appVM.userId { Task { await vm.load(userId: uid) } }
            }) { coin in
                GemDetailView(coinId: coin.id, coinName: coin.name ?? "Gem", userId: appVM.userId)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        // Centered under the backdrop's gold arch, matching Favors and Profile
        VStack(spacing: 8) {
            Text("Favorium")
                .font(FavoriumTheme.titleFont)
                .foregroundColor(FavoriumTheme.ivory)
                .decoTitle()
            DecoDivider()
            subtitleLine
                .backdropLegible()
        }
        .backdropHalo()
        .frame(maxWidth: .infinity)
        .padding(.top, 36) // below status bar; subtitle clears the backdrop arch
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var subtitleLine: some View {
        switch vm.loadState {
        case .loaded where !vm.favorsAwaitingGem.isEmpty:
            // Someone finished helping — the one moment a gem can actually be given
            let owed = vm.favorsAwaitingGem.count
            Text(owed == 1 ? "1 favor to thank with a gem" : "\(owed) favors to thank with a gem")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.accent)
        case .loaded where !vm.held.isEmpty:
            // Gems wait here until someone helps you
            let count = vm.held.count
            Text(count == 1 ? "1 gem, saved for your next thank-you" : "\(count) gems, saved for your next thank-you")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivory)
        default:
            Text("Your collection")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivory)
        }
    }

    // MARK: - Held Gems Grid

    @ViewBuilder
    private var heldSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Gems you hold",
                count: vm.held.isEmpty ? nil : vm.held.count
            )

            switch vm.loadState {
            case .idle, .loading:
                loadingGrid
            case .failed(let msg):
                errorBanner(msg)
            case .loaded:
                if vm.held.isEmpty {
                    emptyHeld
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(vm.held.enumerated()), id: \.element.id) { index, coin in
                            GemGridCell(
                                coin: coin,
                                isOriginal: coin.creator_id == appVM.userId,
                                story: vm.storyByCoin[coin.id],
                                onTap: { selectedCoin = coin }
                            )
                            // Staggered reveal (capped so off-screen gems don't wait long);
                            // scoped so only opacity and scale animate, never grid layout
                            .animation(.easeOut(duration: 0.6).delay(Double(min(index, 8)) * 0.08)) {
                                $0.opacity(gemsRevealed ? 1 : 0)
                                    .scaleEffect(gemsRevealed ? 1 : 0.94)
                            }
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }

    private var loadingGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .fill(FavoriumTheme.surface)
                    .frame(height: 190)
                    .shimmer()
            }
        }
    }

    private var emptyHeld: some View {
        VStack(spacing: 10) {
            Image(systemName: "diamond")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(FavoriumTheme.accentMuted)
            Text("No gems yet")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - Send CTA

    /// Names the helper when there's exactly one favor to thank, otherwise counts them.
    private var sendCTALabel: String {
        let awaiting = vm.favorsAwaitingGem
        if awaiting.count == 1 {
            return "Thank \(awaiting[0].helper_name ?? "your helper") with a gem"
        }
        return "Give a gem · \(awaiting.count) favors"
    }

    private var sendCTAButton: some View {
        Button {
            // The give-a-gem sheet lets the user pick both the gem and the favor
            showSendPicker = true
        } label: {
            HStack {
                Image(systemName: "gift")
                Text(sendCTALabel)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .metallicGoldCapsule()
        }
        .sheet(isPresented: $showSendPicker) {
            SendGemView(userId: appVM.userId) {
                // Refresh after a gem is given (one fewer gem owed → badge drops)
                Task {
                    if let uid = appVM.userId {
                        await vm.load(userId: uid)
                    }
                    await notifications.refreshActionCount()
                }
            }
        }
    }

    // MARK: - Originals Section

    @ViewBuilder
    private var originalsSection: some View {
        if case .loaded = vm.loadState, !vm.originals.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Your original gems")
                Text("Follow their journeys, wherever they go.")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .padding(.bottom, 4)

                VStack(spacing: 8) {
                    ForEach(vm.originalsSection(userId: appVM.userId ?? UUID())) { coin in
                        OriginalGemRow(
                            coin: coin,
                            isAway: coin.owner_id != appVM.userId,
                            onTap: { selectedCoin = coin }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .fadeInOnFirstAppear()
        }
    }

    // MARK: - Helpers

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(FavoriumTheme.amber)
            Text(message)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivory)
        }
        .padding()
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
    }
}

// MARK: - Gem Grid Cell

private struct GemGridCell: View {
    let coin: SupabaseService.CoinSummary
    let isOriginal: Bool
    /// The favor that brought this gem to the user, or nil if it has no story yet
    let story: SupabaseService.Favor?
    let onTap: () -> Void

    private var transferCount: Int { coin.transfer_count ?? 0 }
    private var tier: Tier { Tier.from(transferCount: transferCount) }
    private var resolvedDNA: SupabaseService.GemDNA? { coin.gemDNA }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    // Gem — asset-based renderer
                    Group {
                        FavorGemView(
                            dna: resolvedDNA,
                            transferCount: transferCount,
                            size: 110
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

                    // Trait badge — revealed from Bloom onward
                    if tier != .seed, let trait = GemTrait.from(resolvedDNA?.trait) {
                        Text(trait.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(FavoriumTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(FavoriumTheme.surface.opacity(0.9))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(FavoriumTheme.accent.opacity(0.3), lineWidth: 1))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    // Original indicator dot
                    if isOriginal {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(FavoriumTheme.gold)
                            .padding(6)
                            .background(FavoriumTheme.surface)
                            .clipShape(Circle())
                            .padding(8)
                    }
                }

                Divider().background(FavoriumTheme.accentMuted.opacity(0.3))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(coin.name ?? "Gem")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                            .lineLimit(1)
                        // Creator's gem still wearing its starter name
                        if isOriginal && GemNaming.isStarterName(coin.name) {
                            NameItTag()
                        }
                    }
                    storyText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .stroke(FavoriumTheme.accentMuted.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Story

    /// The favor this gem remembers, or a gentle note that it has none yet.
    /// Always two-plus-one lines tall so cards in the grid line up.
    @ViewBuilder
    private var storyText: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let story {
                Text("\u{201C}\(story.description)\u{201D}")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundColor(FavoriumTheme.ivory.opacity(0.85))
                    .lineLimit(2, reservesSpace: true)
                Text(storyCaption(story))
                    .font(.system(size: 11))
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } else {
                Text(GemStoryCopy.noStoryTitle)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .lineLimit(2, reservesSpace: true)
                Text(GemStoryCopy.noStoryHint)
                    .font(.system(size: 11))
                    .foregroundColor(FavoriumTheme.accentMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    /// "for Sam · Oct 19"
    private func storyCaption(_ favor: SupabaseService.Favor) -> String {
        let who = "for \(favor.helped_name ?? "someone")"
        let raw = favor.transferred_at ?? favor.completed_at ?? favor.created_at
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return who }
        return "\(who) · \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

// MARK: - Original Gem Row

/// Small nudge shown on a creator's gem that still has its starter name.
private struct NameItTag: View {
    var body: some View {
        Label("Name it", systemImage: "pencil")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(FavoriumTheme.accent.opacity(0.12))
            .clipShape(Capsule())
            .fixedSize()
            .accessibilityLabel("Needs a name")
    }
}

private struct OriginalGemRow: View {
    let coin: SupabaseService.CoinSummary
    let isAway: Bool
    let onTap: () -> Void

    private var transferCount: Int { coin.transfer_count ?? 0 }
    private var tier: Tier { Tier.from(transferCount: transferCount) }
    private var resolvedDNA: SupabaseService.GemDNA? { coin.gemDNA }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                FavorGemView(
                    dna: resolvedDNA,
                    transferCount: transferCount,
                    size: 54
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(coin.name ?? "Gem")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                        // Every row here is the user's own original
                        if GemNaming.isStarterName(coin.name) {
                            NameItTag()
                        }
                    }
                    HStack(spacing: 6) {
                        Text(holderSubtitle)
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                        if tier != .seed, let trait = GemTrait.from(resolvedDNA?.trait) {
                            Text(trait.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(FavoriumTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FavoriumTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                if isAway {
                    awayBadge
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                    .stroke(FavoriumTheme.accentMuted.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var holderSubtitle: String {
        let count = coin.transfer_count ?? 0
        let exchangeLabel = count == 1 ? "1 exchange" : "\(count) exchanges"
        return "\(exchangeLabel)"
    }

    private var awayBadge: some View {
        Text("Away")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(FavoriumTheme.gold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(FavoriumTheme.gold.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(FavoriumTheme.gold.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Shared reusable subviews

struct SectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(FavoriumTheme.ivory)
            if let count {
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(FavoriumTheme.accent.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Shimmer modifier

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.06), location: 0.4),
                            .init(color: .white.opacity(0.12), location: 0.5),
                            .init(color: .white.opacity(0.06), location: 0.6),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - DNA helpers
// CoinSummary carries dna as a JSONObject. Decode it once into GemDNA
// (which handles both Layer-1 flat keys and Layer-2 nested identity).

private func dnaString(_ dna: JSONObject?, nestedKey: String) -> String? {
    guard let dna,
          let identityRaw = dna["identity"],
          let identityEncoded = try? JSONEncoder().encode(identityRaw),
          let identityObj = try? JSONDecoder().decode([String: AnyJSON].self, from: identityEncoded),
          let raw = identityObj[nestedKey],
          let encoded = try? JSONEncoder().encode(raw),
          let str = String(data: encoded, encoding: .utf8)
    else { return nil }
    return str.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
}

private func dnaDouble(_ dna: JSONObject?, nestedKey: String) -> Double? {
    guard let dna,
          let identityRaw = dna["identity"],
          let identityEncoded = try? JSONEncoder().encode(identityRaw),
          let identityObj = try? JSONDecoder().decode([String: AnyJSON].self, from: identityEncoded),
          let raw = identityObj[nestedKey],
          let encoded = try? JSONEncoder().encode(raw),
          let d = try? JSONDecoder().decode(Double.self, from: encoded)
    else { return nil }
    return d
}

/// Decode the full CrystalDNA from a coin's JSONObject blob.
/// Returns nil when the blob is missing or malformed so callers can fall back gracefully.
///
/// Resilience rules (in order):
/// 1. Try a straight decode of the blob — works when the backend writes `seed` at the top level.
/// 2. If that fails because `seed` is absent (older rows / legacy minting), inject the
///    coin's own `id` string as the seed and try again via JSONSerialization.
/// 3. If `identity` or `personality` are missing entirely, give up and return nil so
///    the caller can fall back to the asset-based renderer.
func parseCrystalDNA(_ dna: JSONObject?, seed: String) -> CrystalDNA? {
    guard let dna,
          let encoded = try? JSONEncoder().encode(dna) else { return nil }

    // 1. Happy path — backend populates top-level seed correctly.
    if let decoded = try? JSONDecoder().decode(CrystalDNA.self, from: encoded) {
        return decoded
    }

    // 2. seed missing at the top level — patch it in using JSONSerialization and retry.
    guard var rawDict = (try? JSONSerialization.jsonObject(with: encoded)) as? [String: Any],
          rawDict["identity"] != nil,
          rawDict["personality"] != nil
    else { return nil }

    rawDict["seed"] = seed  // inject fallback seed

    guard let patched = try? JSONSerialization.data(withJSONObject: rawDict),
          let decoded = try? JSONDecoder().decode(CrystalDNA.self, from: patched)
    else { return nil }

    return decoded
}

#Preview("Collection") {
    @Previewable @State var appVM = AppViewModel()
    CollectionView()
        .environment(appVM)
        .environment(FavorNotificationCenter())
}
