//
//  FavorNotifications.swift
//  favorium
//
//  Live, in-app favor notifications via Supabase Realtime. While the app is
//  open, changes to the user's favors arrive instantly: a banner slides in,
//  screens refresh themselves, and the Favors tab shows how many favors are
//  waiting on the user.
//
//  Requires the `favors` table in the `supabase_realtime` publication:
//    alter publication supabase_realtime add table public.favors;
//

import Foundation
import Observation
import Supabase
import SwiftUI

/// A one-line, human message about a favor change.
struct FavorBanner: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String?
    let icon: String
}

@Observable
final class FavorNotificationCenter {

    /// The banner currently on screen (auto-dismisses)
    private(set) var banner: FavorBanner?
    /// Bumps on every favor change so screens know to reload
    private(set) var changeToken = 0
    /// Favors waiting on this user (contract §8): offers to answer + gems you owe
    private(set) var actionCount = 0

    private var userId: UUID?
    private var channel: RealtimeChannelV2?
    private var listenTasks: [Task<Void, Never>] = []
    private var dismissTask: Task<Void, Never>?
    private var nameCache: [UUID: String] = [:]
    /// Favors the user just changed themselves — don't notify them about their own action
    private var locallyChanged: Set<UUID> = []
    /// Recently shown "favorId-status" events, so a push and a live update for the same
    /// change don't both show a banner
    private var recentlyShown: [String: Date] = [:]

    // MARK: - Lifecycle

    @MainActor
    func start(userId: UUID) async {
        guard self.userId != userId else { return }
        await stop()
        self.userId = userId

        let client = SupabaseManager.shared.client
        let channel = client.channel("favors-\(userId.uuidString)")

        // Streams must be registered before subscribing.
        let offersToMe   = channel.postgresChange(InsertAction.self, table: "favors",
                                                  filter: .eq("helped_id", value: userId))
        let changesAsHelped = channel.postgresChange(UpdateAction.self, table: "favors",
                                                     filter: .eq("helped_id", value: userId))
        let changesAsHelper = channel.postgresChange(UpdateAction.self, table: "favors",
                                                     filter: .eq("helper_id", value: userId))

        listenTasks = [
            Task { [weak self] in
                for await action in offersToMe { await self?.handle(record: action.record, iAmHelper: false, isInsert: true) }
            },
            Task { [weak self] in
                for await action in changesAsHelped { await self?.handle(record: action.record, iAmHelper: false, isInsert: false) }
            },
            Task { [weak self] in
                for await action in changesAsHelper { await self?.handle(record: action.record, iAmHelper: true, isInsert: false) }
            },
        ]

        self.channel = channel
        do {
            try await channel.subscribeWithError()
        } catch {
            // Live updates are a convenience; screens still refresh on appear / pull,
            // and pushes received in the foreground also trigger a refresh.
            print("⚠️ Favor live updates unavailable: \(error)")
        }
        await refreshActionCount()
    }

    @MainActor
    func stop() async {
        listenTasks.forEach { $0.cancel() }
        listenTasks = []
        if let channel {
            await SupabaseManager.shared.client.removeChannel(channel)
        }
        channel = nil
        userId = nil
        banner = nil
        actionCount = 0
    }

    /// Call right before the user changes a favor themselves (accept, cancel, …)
    func noteLocalAction(_ favorId: UUID) {
        locallyChanged.insert(favorId)
    }

    /// Re-sync after the app returns to the foreground (events may have been missed)
    @MainActor
    func appBecameActive() async {
        guard userId != nil else { return }
        changeToken += 1
        await refreshActionCount()
    }

    @MainActor
    func dismissBanner() {
        dismissTask?.cancel()
        banner = nil
    }

    // MARK: - Events

    @MainActor
    private func handle(record: [String: AnyJSON], iAmHelper: Bool, isInsert: Bool) async {
        changeToken += 1
        await refreshActionCount()

        guard let favorId = record["id"]?.stringValue.flatMap(UUID.init(uuidString:)),
              let status = record["status"]?.stringValue else { return }

        // Skip the user's own actions (cancel_favor records who cancelled; the local
        // set covers the moment before the row update arrives)
        if locallyChanged.remove(favorId) != nil { return }
        if status == "cancelled",
           let cancelledBy = record["cancelled_by"]?.stringValue.flatMap(UUID.init(uuidString:)),
           cancelledBy == userId { return }

        let otherKey = iAmHelper ? "helped_id" : "helper_id"
        let otherId = record[otherKey]?.stringValue.flatMap(UUID.init(uuidString:))
        let name = await displayName(otherId)
        let description = record["description"]?.stringValue

        // "A Favor arrived" names the gem
        var gemName: String?
        if status == "transferred", let coinId = record["coin_id"]?.stringValue.flatMap(UUID.init(uuidString:)) {
            gemName = (try? await SupabaseService.shared.coinName(coinId: coinId)) ?? nil
        }

        guard let message = Self.message(status: status, iAmHelper: iAmHelper, isInsert: isInsert,
                                         name: name, description: description, gemName: gemName) else { return }
        show(message, key: "\(favorId.uuidString.lowercased())-\(status)")
    }

    /// What to tell this user about a favor change — nil when it's their own move.
    /// The helped person accepts, declines, completes and gives gems; either side may cancel.
    /// Copy is owned by the backend contract (PUSH_CONTRACT.md): §7 for the two pushed
    /// moments (offer, gem), §7.1 for the in-app-only transitions. Don't reword here —
    /// change it in the contract first so web, iOS and push stay identical.
    static func message(status: String, iAmHelper: Bool, isInsert: Bool,
                        name: String, description: String?, gemName: String? = nil) -> FavorBanner? {
        let desc = "\u{201C}\(clipped(description))\u{201D}"
        if iAmHelper {
            // The helped person performs accept / decline / complete / give, so only the helper hears
            switch status {
            case "accepted":
                return FavorBanner(title: "Offer accepted",
                                   detail: "\(name) said yes to \(desc). Show up and make it count.",
                                   icon: "hand.thumbsup.fill")
            case "declined":
                return FavorBanner(title: "Offer declined",
                                   detail: "\(name) passed on \(desc). No harm — there are other offers to make.",
                                   icon: "hand.raised.slash")
            case "completed":
                return FavorBanner(title: "It\u{2019}s done",
                                   detail: "\(name) marked \(desc) complete. They owe you a Favor now.",
                                   icon: "checkmark.seal.fill")
            case "transferred":
                return FavorBanner(title: "A Favor arrived",
                                   detail: "\(name) gave you \(gemName ?? "a gem").",
                                   icon: "gift.fill")
            case "cancelled":
                return FavorBanner(title: "Offer called off",
                                   detail: "\(name) cancelled \(desc). Nothing left to do here.",
                                   icon: "xmark.circle")
            default:
                return nil
            }
        } else {
            if isInsert && status == "proposed" {
                return FavorBanner(title: "A new Favor offer",
                                   detail: "\(name) offered to help you: \(desc)",
                                   icon: "hand.raised.fill")
            }
            // Everything else on this side is the helped person's own move, except a helper withdrawing
            if status == "cancelled" {
                return FavorBanner(title: "Offer withdrawn",
                                   detail: "\(name) withdrew \(desc). You can offer one back if you like.",
                                   icon: "xmark.circle")
            }
            return nil
        }
    }

    /// Whitespace-collapsed and clipped at 90 characters, as the contract specifies.
    static func clipped(_ description: String?) -> String {
        let collapsed = (description ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > 90 else { return collapsed.isEmpty ? "your favor" : collapsed }
        return String(collapsed.prefix(89)).trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }

    /// A push arrived while the app is open (the system banner is suppressed). Treat it
    /// as a change signal so screens refresh even if Realtime isn't delivering, and show
    /// the in-app banner with the push's own (contract) wording.
    @MainActor
    func receivedForegroundPush(title: String, body: String?, favorId: String?, kind: String?) async {
        changeToken += 1
        await refreshActionCount()
        // "gift" is the zero-balance safety valve, "nudge" points back to helping (PUSH_CONTRACT §7.2),
        // "title" announces a new helper title
        let icon = switch kind {
        case "transferred", "gift": "gift.fill"
        case "title":               "sparkles"
        default:                    "hand.raised.fill"
        }
        let key = favorId.map { "\($0.lowercased())-\(kind ?? "")" }
        show(FavorBanner(title: title, detail: body, icon: icon), key: key)
    }

    @MainActor
    private func show(_ message: FavorBanner, key: String? = nil) {
        if let key {
            let now = Date()
            recentlyShown = recentlyShown.filter { now.timeIntervalSince($0.value) < 30 }
            if recentlyShown[key] != nil { return }   // already shown via the other channel
            recentlyShown[key] = now
        }
        banner = message
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }

    // MARK: - Helpers

    @MainActor
    private func displayName(_ id: UUID?) async -> String {
        guard let id else { return "Someone" }
        if let cached = nameCache[id] { return cached }
        let name = (try? await SupabaseService.shared.displayName(userId: id)) ?? nil
        let resolved = (name?.isEmpty == false ? name : nil) ?? "Someone"
        nameCache[id] = resolved
        return resolved
    }

    /// Recounts favors waiting on this user (Favors tab badge) and writes it to the app
    /// icon. Call after anything that can change the count — including the user's own
    /// accept / decline / give actions, which don't always arrive as live updates.
    @MainActor
    func refreshActionCount() async {
        guard let userId else { return }
        guard let incoming = try? await SupabaseService.shared.myIncomingFavors(userId: userId) else { return }
        // Contract §8 (same rule as the push badge and the web Favors badge):
        // offers to answer + gems you owe
        actionCount = incoming.filter { $0.isProposed || ($0.isCompleted && $0.coin_id == nil) }.count
        // Always write it, even if unchanged: pushes set the icon badge from the server
        // and can leave it higher than the real count.
        PushManager.shared.updateBadge(actionCount)
    }
}

// MARK: - Banner view

/// Slide-in banner for a favor change. Tap to open the Favors tab; swipe up to dismiss.
struct FavorBannerView: View {
    let banner: FavorBanner
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: banner.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(FavoriumTheme.onGold)
                    .frame(width: 36, height: 36)
                    .background(FavoriumTheme.goldGradient)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                        .lineLimit(2)
                    if let detail = banner.detail {
                        Text(detail)
                            .font(.system(size: 13))
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(FavoriumTheme.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .stroke(FavoriumTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .gesture(
            DragGesture(minimumDistance: 10).onEnded { value in
                if value.translation.height < -10 { onDismiss() }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Favors")
    }
}

#Preview("Favor banner") {
    ZStack(alignment: .top) {
        FavoriumTheme.background.ignoresSafeArea()
        VStack(spacing: 12) {
            if let offer = FavorNotificationCenter.message(status: "proposed", iAmHelper: false, isInsert: true,
                                                           name: "Alex", description: "Help move the couch upstairs") {
                FavorBannerView(banner: offer, onTap: {}, onDismiss: {})
            }
            if let gem = FavorNotificationCenter.message(status: "transferred", iAmHelper: true, isInsert: false,
                                                         name: "Sam", description: "Walked the dog") {
                FavorBannerView(banner: gem, onTap: {}, onDismiss: {})
            }
        }
        .padding(12)
    }
}
