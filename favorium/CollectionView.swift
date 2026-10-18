//
//  CollectionView.swift
//  favorium
//
//  "Collection" tab — two-column grid of held gems + original gems section.
//  All data from SupabaseService; no new backend calls invented.
//

import SwiftUI

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
                    }
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
                    // Subtle arc glow
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [FavoriumTheme.teal.opacity(0.08), .clear],
                                center: .center, startRadius: 5, endRadius: 180
                            )
                        )
                        .frame(width: 300, height: 80)
                        .blur(radius: 18)
                        .offset(x: 0, y: -10)

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

    private var tier: Tier { Tier.from(transferCount: coin.transfer_count ?? 0) }
    private var gemColor: Color { tier.defaultColor }
    private var gemFamily: GemFamily { .lightning }  // fallback until DNA decoded from coin

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    // Gem
                    FavorGemView(
                        gemFamily: gemFamily,
                        tier: tier,
                        gemColor: gemColor,
                        size: 110,
                        showGlow: true,
                        showShimmer: false
                    )
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

    private var tier: Tier { Tier.from(transferCount: coin.transfer_count ?? 0) }
    private var gemColor: Color { tier.defaultColor }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                FavorGemView(
                    gemFamily: .lightning,
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
        return "\(exchangeLabel)"   // owner_name not available in CoinSummary; journey will show it
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
                            FavorGemView(
                                gemFamily: .lightning,
                                tier: tier,
                                gemColor: tier.defaultColor,
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

#Preview("Collection") {
    @Previewable @State var appVM = AppViewModel()
    CollectionView()
        .environment(appVM)
}
