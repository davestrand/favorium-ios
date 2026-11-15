# Quests v1.1 — requests from iOS to the web agent

Written 2026-11-14 while building the iOS screens against `QUESTS_CONTRACT.md` (v1.1).
iOS has built the character creator, the description, the Quest Board, the wardrobe and
actions. These are the points where iOS had to guess, or is blocked.

## Blocking

1. **Favor integration (contract §7.1).** Nothing can complete a quest until it lands.
   When it ships, iOS needs:
   - `propose_favor`'s new parameter name, and the error texts it can raise for a quest;
   - the field(s) on `favors` reads that carry the quest: `user_quest_id`, plus the quest
     **title** for both sides (a column, or a join name to select);
   - how `transfer_coin` reports a completed quest, so the helper's "A gem arrived"
     celebration can say "Quest complete — you are now known to be strong". A field on the
     favor, the `quest_complete` push, or both.

## Shapes iOS had to guess (please confirm or correct)

iOS decodes these leniently, but a wrong guess shows up as blank text.

2. ~~`my_inventory()`~~ **Answered (v1.2 trait/backpack note):** field names confirmed;
   iOS now reads `worn_by_character_id`. Still unconfirmed: are `quest_title` and
   `visit_label` included for provenance?
3. **`my_actions_received()`**: `id`, `from_user_id`, `from_name`, `rendered`, `created_at`.
   Is it a bare array, newest first?
4. **`my_quests()`**: iOS accepts either a bare array of `quest_payload`, or an object
   whose values are arrays (e.g. `{accepted: […], history: […]}`). Which is it?
5. **`my_character().character`**: iOS reads `id, pronouns, race_key, height_key,
   build_key, eyes_key, skin_key, hair_color_key, hair_length_key`.
6. **`my_board().quests`**: only this week's posts (posted + accepted from this week's
   draw)? iOS currently shows quests accepted in **earlier** weeks from `my_quests()`, in a
   "Still open" section, and removes duplicates by `user_quest_id`.

## Missing

7. **Reading the quest-push opt-in.** There's `set_quest_push` but nothing returns the
   current value, so iOS remembers the toggle on the device only. Could `my_character()`
   (or `my_board()`) include `quest_push`?
8. **Pushes (§7.2):** final kinds and payload keys for `quest_board`, `visitor_arrived`,
   `visitor_leaving`, `quest_complete` and `action`. iOS will route them all to Profile.
9. ~~Gesture attached to a thank-you gem~~ **Answered:** not built; needs a product
   decision first: yours to make.

## Content (for the product owner)

10. **Races — decided:** add **halfling** to the catalog.
11. **Spelling — decided** (2026-11-15: one left, `outer_mosscloak` still says
    "travelling"): use **American** spelling in all catalog and quest text
    ("traveling", "color", "defense"). Keys stay as they are; only `text` changes.
12. **Action menu wording.** iOS lists actions with `{pos}` replaced by "their"
    ("bows their head"). If you'd like a better label for the sender's menu (e.g.
    "Bow your head"), a `label` field in the catalog would do it.

## Test data

13. A way to give the iOS test account a few unlocks of each kind, and to switch a visit
    on, so the wardrobe and visitor section can be checked before favor integration ships.

## Also needed

14. **The v1.2 contract itself.** iOS has v1.1 (`docs/QUESTS_CONTRACT.md`). Please send the
    v1.2 text so the iOS copy can be replaced.
