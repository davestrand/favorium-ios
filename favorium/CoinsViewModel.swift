//
//  CoinsViewModel.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import Foundation
import Observation

@Observable
final class CoinsViewModel {
    enum Tab { case myFavors, myOriginals }

    var selected: Tab = .myFavors
    var isLoading: Bool = false
    var errorMessage: String?

    var myFavors: [SupabaseService.CoinSummary] = []
    var myOriginals: [SupabaseService.CoinSummary] = []

    @MainActor
    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let favors = SupabaseService.shared.myFavors(userId: userId)
            async let originals = SupabaseService.shared.myOriginals(userId: userId)
            let (f, o) = try await (favors, originals)
            self.myFavors = f
            self.myOriginals = o
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
