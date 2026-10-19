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

    @MainActor
    func load(coinId: UUID) async {
        loadState = .loading
        do {
            let result = try await SupabaseService.shared.coinJourney(coinID: coinId)
            journey = result
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
    @State private var gemAppeared = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
                .background(FavoriumTheme.tealMuted.opacity(0.3))

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
        .task { await vm.load(coinId: coinId) }
        .sheet(isPresented: $showSend) {
            if let j = vm.journey {
                SendGemView(
                    coinId: coinId,
                    coinName: j.name,
                    transferCount: j.transferCount,
                    userId: userId
                ) {
                    Task { await vm.load(coinId: coinId) }
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

                // ── Send button (only when user is current owner) ─────────
                if j.isOwner == true {
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

            // Placeholder for future share/menu action
            Button { } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                    .frame(width: 40, height: 40)
                    .background(FavoriumTheme.surface)
                    .clipShape(Circle())
            }
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
        let family    = GemFamily.from(j.dna?.resolvedFamily)
        let tier      = Tier.from(transferCount: j.transferCount)
        let gemSize: CGFloat = 280

        // Gem — same call as the generator: FavorGemView with glow + shimmer
        return FavorGemView(
            gemFamily: family,
            tier: tier,
            gemColor: glowColor,
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
        .frame(maxWidth: .infinity)
        .frame(height: 360)
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

        return VStack(spacing: 10) {
            Text(j.name)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
                .multilineTextAlignment(.center)

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

            HStack(spacing: 6) {
                Text(family.displayName)
                Circle().frame(width: 3, height: 3)
                Text(tier.displayName)
            }
            .font(.system(size: 13))
            .foregroundColor(tier.defaultColor)

            // Trait badge — appears at Bloom tier
            if let trait = j.dna?.trait {
                Text(trait.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FavoriumTheme.teal)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(FavoriumTheme.teal.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
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
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(FavoriumTheme.teal)
            .clipShape(Capsule())
        }
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
                    .foregroundColor(FavoriumTheme.tealMuted)
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
                Circle()
                    .fill(FavoriumTheme.teal)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(FavoriumTheme.tealMuted.opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
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
                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .lineLimit(3)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
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
                            .foregroundColor(FavoriumTheme.tealMuted)
                    }
                    .padding(.top, 4)
                    Rectangle()
                        .fill(FavoriumTheme.tealMuted.opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 10)

                HStack {
                    Text(vm.earlierExpanded ? "Collapse earlier exchanges" : "\(count) earlier exchanges")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(FavoriumTheme.teal)
                    Spacer()
                    Image(systemName: vm.earlierExpanded ? "chevron.up" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(FavoriumTheme.teal)
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
                .tint(FavoriumTheme.teal)
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
                Task { await vm.load(coinId: coinId) }
            }
            .foregroundColor(FavoriumTheme.teal)
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
