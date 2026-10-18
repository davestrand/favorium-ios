//
//  GemDetailView.swift
//  favorium
//
//  Full gem detail + complete journey timeline.
//  Uses coin_journey RPC — no new endpoints.
//

import SwiftUI
import Helpers

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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            switch vm.loadState {
            case .idle, .loading:
                loadingBody
            case .failed(let msg):
                errorBody(msg)
            case .loaded:
                if let j = vm.journey {
                    loadedBody(j)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task { await vm.load(coinId: coinId) }
        .sheet(isPresented: $showSend) {
            if let j = vm.journey {
                SendGemView(
                    coinId: coinId,
                    coinName: j.name,
                    transferCount: j.transfer_count,
                    userId: userId
                ) {
                    Task { await vm.load(coinId: coinId) }
                }
            }
        }
    }

    // MARK: - Loaded body

    private func loadedBody(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Navigation bar ────────────────────────────────────
                navBar

                // ── Hero gem ─────────────────────────────────────────
                heroGem(j)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                // ── Gem name + attributes ─────────────────────────────
                gemMeta(j)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // ── Send button (only when user is current owner) ─────
                if j.is_owner {
                    sendButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }

                // ── Journey timeline ──────────────────────────────────
                journeySection(j)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
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
        .padding(.top, 56)
    }

    // MARK: - Hero

    private func heroGem(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        let tier = Tier.from(transferCount: j.transfer_count)
        let gemFamily = GemFamily.from(dnaString(j.dna, key: "gemFamily"))
        let hue = dnaDouble(j.dna, key: "primaryHue") ?? 200.0
        let sat = dnaDouble(j.dna, key: "saturation") ?? 0.8
        let gemColor = Color(hue: hue / 360.0, saturation: sat, brightness: 0.9)

        return GeometryReader { geo in
            // Scale the hero relative to screen width so it fits small iPhones.
            // 220pt looks great at 390pt wide (iPhone 15); clamp lower for SE/mini.
            let gemSize = min(220, geo.size.width * 0.56)
            let glowSize = gemSize * 1.55

            ZStack {
                // Radial glow behind the gem
                RadialGradient(
                    colors: [gemColor.opacity(0.20), FavoriumTheme.background],
                    center: .center,
                    startRadius: gemSize * 0.18,
                    endRadius: glowSize * 0.5
                )
                .frame(width: glowSize, height: glowSize)
                .blur(radius: 30)

                AnimatedFavorGemView(
                    gemFamily: gemFamily,
                    tier: tier,
                    gemColor: gemColor,
                    size: gemSize
                )
            }
            .frame(maxWidth: .infinity)
            .frame(width: geo.size.width, height: gemSize * 1.2)
        }
        // Reserve height proportional to screen width so GeometryReader has room
        .frame(height: min(264, UIScreen.main.bounds.width * 0.67))
    }

    // MARK: - Gem meta

    private func gemMeta(_ j: SupabaseService.CoinJourneyPayload) -> some View {
        VStack(spacing: 10) {
            Text(j.name)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
                .multilineTextAlignment(.center)

            // "One of your original gems" badge
            if j.is_creator {
                Text("One of your original gems")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(FavoriumTheme.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(FavoriumTheme.gold.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(FavoriumTheme.gold.opacity(0.4), lineWidth: 1))
            }

            // Current holder
            let tier = Tier.from(transferCount: j.transfer_count)
            Text(holderLabel(j))
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)

            // Family · Tier
            HStack(spacing: 6) {
                Text(GemFamily.from(dnaString(j.dna, key: "gemFamily")).displayName)
                Circle().frame(width: 3, height: 3)
                Text(tier.displayName)
            }
            .font(.system(size: 13))
            .foregroundColor(tier.defaultColor)
        }
        .frame(maxWidth: .infinity)
    }

    private func holderLabel(_ j: SupabaseService.CoinJourneyPayload) -> String {
        if j.is_owner {
            return "In your possession · \(j.transfer_count) exchanges"
        }
        let holder = j.owner_name ?? "someone"
        return "Currently with \(holder) · \(j.transfer_count) exchanges"
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

            // Timeline entries
            let history = j.history  // already ordered newest-first from RPC
            let visibleCutoff = 2    // show first 2, collapse the rest

            if history.isEmpty {
                Text("No exchanges yet.")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Newest two always shown
                    ForEach(history.prefix(visibleCutoff)) { item in
                        timelineRow(item, isLast: false)
                    }

                    // Collapse / expand older entries
                    if history.count > visibleCutoff + 1 {
                        let olderCount = history.count - visibleCutoff - 1  // -1 for creation entry
                        collapseRow(count: olderCount)
                            .animation(.easeInOut(duration: 0.3), value: vm.earlierExpanded)

                        if vm.earlierExpanded {
                            ForEach(history.dropFirst(visibleCutoff).dropLast()) { item in
                                timelineRow(item, isLast: false)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    } else {
                        // Show middle entries when total is small
                        ForEach(history.dropFirst(visibleCutoff).dropLast()) { item in
                            timelineRow(item, isLast: false)
                        }
                    }

                    // Creation entry always at bottom
                    if let last = history.last {
                        timelineRow(last, isLast: true)
                    }
                }
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
                    Text(transferLabel(item))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    Text(formattedDate(item.created_at))
                        .font(.system(size: 12))
                        .foregroundColor(FavoriumTheme.ivoryDim)
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
        switch item.event_type {
        case "created":
            return "Created for you"
        case "transferred":
            let from = item.from_name ?? "Someone"
            let to   = item.to_name   ?? "someone"
            if item.is_from_me == true { return "You → \(to)" }
            if item.is_to_me   == true { return "\(from) → You" }
            return "\(from) → \(to)"
        default:
            return item.event_type.capitalized
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
                // Spine
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(FavoriumTheme.surface)
                            .frame(width: 24, height: 24)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(FavoriumTheme.tealMuted)
                    }
                    .offset(x: -7)
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

    private var loadingBody: some View {
        VStack(spacing: 24) {
            navBar
            Spacer()
            ProgressView()
                .tint(FavoriumTheme.teal)
                .scaleEffect(1.4)
            Spacer()
        }
    }

    private func errorBody(_ message: String) -> some View {
        VStack(spacing: 16) {
            navBar
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

// MARK: - DNA reading helpers
// JSONObject is [String: AnyJSON] from the Supabase Helpers module.
// We extract typed values via the AnyJSON description/Codable round-trip
// rather than pattern-matching internal cases that may change.

private func dnaString(_ dna: JSONObject?, key: String) -> String? {
    guard let dna else { return nil }
    // AnyJSON conforms to CustomStringConvertible; use JSON round-trip for safety
    guard let raw = dna[key] else { return nil }
    if let encoded = try? JSONEncoder().encode(raw),
       let str = String(data: encoded, encoding: .utf8) {
        // Encoded strings arrive as JSON-quoted e.g. `"lightning"` — strip quotes
        return str.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
    return nil
}

private func dnaDouble(_ dna: JSONObject?, key: String) -> Double? {
    guard let dna else { return nil }
    guard let raw = dna[key] else { return nil }
    if let encoded = try? JSONEncoder().encode(raw),
       let d = try? JSONDecoder().decode(Double.self, from: encoded) {
        return d
    }
    return nil
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
