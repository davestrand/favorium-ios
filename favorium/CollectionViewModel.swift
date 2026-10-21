//
//  CollectionViewModel.swift
//  favorium
//
//  Drives both the "Gems you hold" grid and the "Your original gems" section.
//  Uses SupabaseService exclusively — no new tables or endpoints.
//

import Foundation
import Observation

@Observable
final class CollectionViewModel {

    // MARK: - State

    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    var held: [SupabaseService.CoinSummary]    = []
    var originals: [SupabaseService.CoinSummary] = []
    /// Completed favors I received that still need a gem — drives the "Give a gem" CTA
    var favorsAwaitingGem: [SupabaseService.Favor] = []
    /// The favor that most recently brought each held gem to this user (coin id → favor).
    /// Gems move helped → helper, so this is always a favor *they* did for someone.
    /// Gems with no entry have no story yet (e.g. the ones minted at sign-up).
    var storyByCoin: [UUID: SupabaseService.Favor] = [:]
    var loadState: LoadState                   = .idle

    // Tracks gem IDs being sent so the UI can show a spinner mid-transfer
    var sendingGemId: UUID?

    // MARK: - Load

    @MainActor
    func load(userId: UUID) async {
        // Only show placeholders on the first load — swapping the grid out during
        // pull-to-refresh shrinks the scroll content and cancels the refresh task.
        if case .loaded = loadState {} else {
            loadState = .loading
        }
        do {
            async let heldTask     = SupabaseService.shared.myFavors(userId: userId)
            async let originalTask = SupabaseService.shared.myOriginals(userId: userId)
            // Optional: if this fails the CTA simply stays hidden; the collection still loads
            async let incomingTask = try? SupabaseService.shared.myIncomingFavors(userId: userId)
            // Optional too: without it, cards just read "No story yet"
            async let outgoingTask = try? SupabaseService.shared.myOutgoingFavors(userId: userId)
            let (h, o) = try await (heldTask, originalTask)
            held      = h
            originals = o
            // Filter back on the main actor (Favor's status helpers are main-actor isolated)
            favorsAwaitingGem = (await incomingTask ?? []).filter { $0.isCompleted && $0.coin_id == nil }
            storyByCoin = Self.latestFavorPerCoin((await outgoingTask ?? []).filter(\.isTransferred))
            loadState = .loaded
        } catch is CancellationError {
            // The pull-to-refresh gesture was cancelled (e.g. scroll bounced back
            // before the network call finished). Restore whichever state we were in
            // so the UI doesn't flip to an error banner for something that isn't
            // a real failure.
            if case .loading = loadState {
                loadState = held.isEmpty ? .idle : .loaded
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Keeps the most recent transferred favor for each coin.
    private static func latestFavorPerCoin(_ favors: [SupabaseService.Favor]) -> [UUID: SupabaseService.Favor] {
        var result: [UUID: SupabaseService.Favor] = [:]
        for favor in favors {
            guard let coinId = favor.coin_id else { continue }
            let when = favor.transferred_at ?? favor.created_at
            if let existing = result[coinId],
               (existing.transferred_at ?? existing.created_at) >= when { continue }
            result[coinId] = favor
        }
        return result
    }

    /// True if the user both created and currently holds the gem.
    func isHeldOriginal(_ coin: SupabaseService.CoinSummary, userId: UUID) -> Bool {
        coin.creator_id == userId && coin.owner_id == userId
    }

    /// Original gems that are NOT currently held by this user.
    func awayOriginals(userId: UUID) -> [SupabaseService.CoinSummary] {
        originals.filter { $0.owner_id != userId }
    }

    /// Return the subset of originals that are away (never include held ones twice in the away row).
    /// Gems that are in `held` but also original appear in both sections — that is correct per spec.
    func originalsSection(userId: UUID) -> [SupabaseService.CoinSummary] {
        originals // show all originals, caller distinguishes away vs held
    }
}
