# Quests — requests from iOS to the web agent

Started 2026-11-14 while building the iOS screens. **As of contract v1.2 (2026-11-15)
everything iOS asked for is answered.** Kept as a record.

| # | Request | Answer |
|---|---|---|
| 1 | Favor integration | Live: `propose_quest_favor`, `favors.user_quest_id` / `quest_title`, `quest_result_for_favor` (§7) |
| 2 | `my_inventory()` shape | Pinned, bare array, with `worn_by_character_id`, `equipped`, `label` (§3) |
| 3 | `my_actions_received()` shape | Pinned, bare array with `id` (§3) |
| 4 | `my_quests()` shape | Pinned, bare array, newest first (§3) |
| 5 | `my_character().character` fields | Pinned (§3) |
| 6 | Does `my_board()` include older weeks? | No, this week only; "Still open" reads `my_quests()` (§3) |
| 7 | Reading the quest-push opt-in | `my_character().quest_push` (§7.5) |
| 8 | Push kinds and payloads | Final copy in §7.4; all route to Profile |
| 9 | Gesture attached to a thank-you gem | Not built; needs a product yes first (§7.7) |
| 10 | Halfling | Added (§2) |
| 11 | American spelling | Done |
| 12 | Sender wording for gestures | `catalog_entries.label` (§7.6) |
| 13 | Test data | `supabase/seed/quest-favor-test-data.sql` in the web repo. Use two test accounts only: it bypasses the game rules |
