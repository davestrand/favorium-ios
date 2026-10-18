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

    enum LoadState { case idle, loading, loaded, failed(String) }

    var held: [SupabaseService.CoinSummary]    = []
    var originals: [SupabaseService.CoinSummary] = []
    var loadState: LoadState                   = .idle

    // Tracks gem IDs being sent so the UI can show a spinner mid-transfer
    var sendingGemId: UUID?

    // MARK: - Load

    @MainActor
    func load(userId: UUID) async {
        loadState = .loading
        do {
            async let heldTask     = SupabaseService.shared.myFavors(userId: userId)
            async let originalTask = SupabaseService.shared.myOriginals(userId: userId)
            let (h, o) = try await (heldTask, originalTask)
            held      = h
            originals = o
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

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
