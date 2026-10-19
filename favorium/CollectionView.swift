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
    @State private var vm = CollectionViewModel()
    @State private var selectedCoin: SupabaseService.CoinSummary?
    @State private var showSendPicker = false
    @State private var sendGem: SupabaseService.CoinSummary?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                FavoriumTheme.background.ignoresSafeArea()

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

                        // ── Send a gem CTA (only when user holds gems) ───
                        if !vm.held.isEmpty {
                            sendCTAButton
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
                .refreshable {
                    if let uid = appVM.userId {
                        await vm.load(userId: uid)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                if let uid = appVM.userId, case .idle = vm.loadState {
                    await vm.load(userId: uid)
                }
            }
            .navigationDestination(item: $selectedCoin) { coin in
                GemDetailView(coinId: coin.id, coinName: coin.name ?? "Gem", userId: appVM.userId)
            }
            .sheet(item: $sendGem) { gem in
                SendGemView(
                    coinId: gem.id,
                    coinName: gem.name ?? "Gem",
                    transferCount: gem.transfer_count ?? 0,
                    userId: appVM.userId
                ) {
                    // Refresh after a successful send
                    Task {
                        if let uid = appVM.userId {
                            await vm.load(userId: uid)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // Decorative arc + stars via overlay
                ZStack(alignment: .leading) {
                    // Subtle arc glow — use relative sizing so it never overflows
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [FavoriumTheme.teal.opacity(0.08), .clear],
                                center: .center, startRadius: 5, endRadius: 180
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .blur(radius: 18)
                        .offset(x: 0, y: -10)
                        .clipped()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Favorium")
                            .font(FavoriumTheme.titleFont)
                            .foregroundColor(FavoriumTheme.ivory)
                        subtitleLine
                    }
                }
            }
            Spacer()
            // Settings gear (placeholder — preserves room for future nav)
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(FavoriumTheme.ivoryDim)
                .padding(.top, 6)
        }
        .padding(.top, 56) // below status bar
    }

    @ViewBuilder
    private var subtitleLine: some View {
        switch vm.loadState {
        case .loaded:
            let readyCount = vm.held.count
            let label = readyCount == 1 ? "1 gem ready to give" : "\(readyCount) gems ready to give"
            Text(label)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.teal)
        default:
            Text("Your collection")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
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
                        ForEach(vm.held) { coin in
                            GemGridCell(
                                coin: coin,
                                isOriginal: coin.creator_id == appVM.userId,
                                onTap: { selectedCoin = coin }
                            )
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
                .foregroundColor(FavoriumTheme.tealMuted)
            Text("No gems yet")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - Send CTA

    private var sendCTAButton: some View {
        Button {
            // Open a picker sheet to choose which gem to send
            showSendPicker = true
        } label: {
            HStack {
                Image(systemName: "paperplane")
                Text("Send a gem")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(FavoriumTheme.teal)
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showSendPicker) {
            GemPickerForSendView(coins: vm.held) { chosen in
                sendGem = chosen
                showSendPicker = false
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
    let onTap: () -> Void

    private var transferCount: Int { coin.transfer_count ?? 0 }
    private var tier: Tier { Tier.from(transferCount: transferCount) }
    private var resolvedDNA: SupabaseService.GemDNA? { coin.gemDNA }
    private var gemFamily: GemFamily { GemFamily.from(resolvedDNA?.resolvedFamily) }
    private var gemColor: Color {
        guard let dna = resolvedDNA else { return tier.defaultColor }
        return Color(hue: dna.resolvedHue / 360.0, saturation: dna.resolvedSaturation, brightness: 0.9)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    // Gem — asset-based renderer
                    Group {
                        FavorGemView(
                            gemFamily: gemFamily,
                            tier: tier,
                            gemColor: gemColor,
                            size: 110,
                            showGlow: true,
                            showShimmer: false
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)

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

                Divider().background(FavoriumTheme.tealMuted.opacity(0.3))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coin.name ?? "Gem")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                            .lineLimit(1)
                        Text("\(gemFamily.displayName) · \(tier.displayName)")
                            .font(.system(size: 11))
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .stroke(FavoriumTheme.tealMuted.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Original Gem Row

private struct OriginalGemRow: View {
    let coin: SupabaseService.CoinSummary
    let isAway: Bool
    let onTap: () -> Void

    private var transferCount: Int { coin.transfer_count ?? 0 }
    private var tier: Tier { Tier.from(transferCount: transferCount) }
    private var resolvedDNA: SupabaseService.GemDNA? { coin.gemDNA }
    private var gemFamily: GemFamily { GemFamily.from(resolvedDNA?.resolvedFamily) }
    private var gemColor: Color {
        guard let dna = resolvedDNA else { return tier.defaultColor }
        return Color(hue: dna.resolvedHue / 360.0, saturation: dna.resolvedSaturation, brightness: 0.9)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                FavorGemView(
                    gemFamily: gemFamily,
                    tier: tier,
                    gemColor: gemColor,
                    size: 54,
                    showGlow: false,
                    showShimmer: false
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(coin.name ?? "Gem")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Text(holderSubtitle)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
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
                    .stroke(FavoriumTheme.tealMuted.opacity(0.2), lineWidth: 1)
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

// MARK: - Gem Picker Sheet (for Send CTA)

private struct GemPickerForSendView: View {
    let coins: [SupabaseService.CoinSummary]
    let onSelect: (SupabaseService.CoinSummary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FavoriumTheme.background.ignoresSafeArea()
                List(coins) { coin in
                    Button {
                        onSelect(coin)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            let tier = Tier.from(transferCount: coin.transfer_count ?? 0)
                            let dna  = coin.gemDNA
                            let family = GemFamily.from(dna?.resolvedFamily)
                            let gemColor = dna.map {
                                Color(hue: $0.resolvedHue / 360.0, saturation: $0.resolvedSaturation, brightness: 0.9)
                            } ?? tier.defaultColor
                            FavorGemView(
                                gemFamily: family,
                                tier: tier,
                                gemColor: gemColor,
                                size: 46,
                                showGlow: false,
                                showShimmer: false
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coin.name ?? "Gem")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(FavoriumTheme.ivory)
                                Text(tier.displayName)
                                    .font(FavoriumTheme.captionFont)
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                            }
                        }
                    }
                    .listRowBackground(FavoriumTheme.surface)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose a gem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FavoriumTheme.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
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
                    .foregroundColor(FavoriumTheme.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(FavoriumTheme.teal.opacity(0.15))
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
}
