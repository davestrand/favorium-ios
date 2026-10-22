//
//  GemNaming.swift
//  favorium
//
//  Gem naming rules shared across screens. Only a gem's original creator can
//  rename it (enforced server-side by rename_coin), at any time.
//

import Foundation

enum GemNaming {
    /// Matches rename_coin's server-side limit.
    static let maxLength = 40

    /// Starter names come from mint_coin as "<Family> <Noun>". Keep these lists
    /// in sync with the `v_label` cases and `v_nouns` array in mint_coin().
    /// "Gothic" is kept so gems minted before the Darkheart rename still count as starters.
    private static let starterFamilies: Set<String> = ["Lightning", "Celestial", "Victorian", "Darkheart", "Gothic"]
    private static let starterNouns: Set<String> = [
        "Hearth", "Lantern", "Bloom", "Harbor", "Thread", "Echo",
        "Kindle", "Haven", "Promise", "Ripple", "Compass", "Garden"
    ]

    /// True when a gem still carries its auto-generated starter name
    /// (including reminted gems whose starter name no longer matches their family).
    static func isStarterName(_ name: String?) -> Bool {
        guard let name else { return true }
        let words = name.split(separator: " ").map(String.init)
        guard words.count == 2 else { return false }
        return starterFamilies.contains(words[0]) && starterNouns.contains(words[1])
    }

    /// Whether to nudge the signed-in user to name this gem.
    static func shouldSuggestNaming(name: String?, creatorId: UUID?, userId: UUID?) -> Bool {
        guard let creatorId, let userId, creatorId == userId else { return false }
        return isStarterName(name)
    }

    /// Mirrors rename_coin's cleanup so the preview matches what will be saved.
    static func normalized(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Shared wording for a gem's "story" — the favor that brought it to its holder —
/// so the Collection card and the detail page always say the same thing.
enum GemStoryCopy {
    static let noStoryTitle = "No story yet"
    /// Short enough for the narrow Collection card
    static let noStoryHint = "Awaiting a favor"
    static let noStoryExplanation =
        "This gem hasn't been part of a favor yet. Its story begins the first time it's given in thanks."
}
