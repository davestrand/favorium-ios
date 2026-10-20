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
    /// Favors waiting on this user: offers to answer, favors to confirm, gems to give
    private(set) var actionCount = 0

    private var userId: UUID?
    private var channel: RealtimeChannelV2?
    private var listenTasks: [Task<Void, Never>] = []
    private var dismissTask: Task<Void, Never>?
    private var nameCache: [UUID: String] = [:]
    /// Favors the user just changed themselves — don't notify them about their own action
    private var locallyChanged: Set<UUID> = []

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
            // Live updates are a convenience; screens still refresh on appear / pull.
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

        // Skip the user's own actions
        if locallyChanged.remove(favorId) != nil { return }

        let otherKey = iAmHelper ? "helped_id" : "helper_id"
        let otherId = record[otherKey]?.stringValue.flatMap(UUID.init(uuidString:))
        let name = await displayName(otherId)
        let description = record["description"]?.stringValue

        guard let message = Self.message(status: status, iAmHelper: iAmHelper, isInsert: isInsert,
                                         name: name, description: description) else { return }
        show(message)
    }

    /// What to tell this user about a favor change — nil when it's their own move.
    /// The helped person accepts, declines, completes and gives gems; either side may cancel.
    static func message(status: String, iAmHelper: Bool, isInsert: Bool,
                        name: String, description: String?) -> FavorBanner? {
        let quoted = description.map { "\u{201C}\($0)\u{201D}" }
        if iAmHelper {
            switch status {
            case "accepted":    return FavorBanner(title: "\(name) accepted your offer", detail: quoted, icon: "hand.thumbsup.fill")
            case "declined":    return FavorBanner(title: "\(name) declined your offer", detail: quoted, icon: "hand.raised.slash")
            case "completed":   return FavorBanner(title: "\(name) marked your favor complete", detail: quoted, icon: "checkmark.seal.fill")
            case "transferred": return FavorBanner(title: "\(name) gave you a gem", detail: quoted, icon: "gift.fill")
            case "cancelled":   return FavorBanner(title: "\(name) cancelled the favor", detail: quoted, icon: "xmark.circle")
            default:            return nil
            }
        } else {
            if isInsert && status == "proposed" {
                return FavorBanner(title: "\(name) offered to help", detail: quoted, icon: "hand.raised.fill")
            }
            // The helped person makes every other move themselves, except a helper cancelling
            if status == "cancelled" {
                return FavorBanner(title: "\(name) withdrew their offer", detail: quoted, icon: "xmark.circle")
            }
            return nil
        }
    }

    @MainActor
    private func show(_ message: FavorBanner) {
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

    /// Counts favors waiting on this user (the Favors tab badge).
    @MainActor
    private func refreshActionCount() async {
        guard let userId else { return }
        guard let incoming = try? await SupabaseService.shared.myIncomingFavors(userId: userId) else { return }
        actionCount = incoming.filter { $0.isProposed || $0.isAccepted || ($0.isCompleted && $0.coin_id == nil) }.count
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
                            .font(.system(size: 13, design: .serif))
                            .italic()
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .lineLimit(1)
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
