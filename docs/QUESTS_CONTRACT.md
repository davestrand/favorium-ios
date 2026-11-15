<!--
iOS-side copy of the web agent's Quests contract, pasted by the user on 2026-11-15.
The authoritative version lives in the web repo. If they differ, the web repo wins;
replace this file when a newer version arrives.
-->

# Quests & characters — backend contract (v1.1, foundation)

Authoritative for iOS and Android. Built 2026-11-15 from `QUESTS_WEB_HANDOFF.md`.
This layer is **server-owned**: all copy, all drawing and all rendering happen in Postgres so
every client reads the same words.

## 1. Decisions settled with the product owner

| Question | Answer |
|---|---|
| What the helped person sees on a favor carrying a quest | The quest's **title**, and the favor text is **locked** to the quest's prompt so both parties know what the favor must be. (Favor integration lands in the next step — see §7.) |
| Giving unlocks to friends | **Not in 1.1.** Unlocks are earned only. Dropping is allowed. |
| Character + board on favorium.app | **Mobile only** for 1.1. The web only ever *reads* `character_description()`. |
| Quest history visible | Yes — `my_quests()` returns the member's own history. Nothing is shown on other people's profiles. |

## 2. Vocabulary

`catalog_entries` holds every word a character can use. 101 entries seeded.

Kinds: `race`, `height`, `build`, `eyes`, `skin`, `hair_color`, `hair_length` (free for everyone)
and `look_term`, `rep_term`, `clothing`, `held`, `hairstyle`, `action` (quest rewards only).

`key` is **permanent** — never rename or reuse one, even if the text changes.
Read them all with `catalog()`.

## 3. RPCs (all `SECURITY DEFINER`, self-scoped unless stated)

Characters
- `create_character(p_pronouns, p_race_key, p_height_key, p_build_key, p_eyes_key, p_skin_key, p_hair_color_key, p_hair_length_key) → jsonb`
  Creates the active character, posts the **first board**, and posts any live visitor's quests.
  Fails at `max_characters` with *"You already have a character."*
- `update_character_appearance(p_character_id, p_pronouns, …same minus race) → jsonb`
  Race is immutable — it has no parameter at all.
- `set_shown(p_character_id, p_slot, p_unlock_id) → jsonb` — `p_unlock_id = null` clears the slot.
  Slots: `look`, `rep_1`, `rep_2`, `hairstyle`, `outer`, `head`, `accessory`, `held`.
  Mis-slotted unlocks raise *"That is worn elsewhere."* / *"That is not a reputation."* etc.
  `rep_1` and `rep_2` can never hold the same unlock.
- `my_character() → jsonb` — `{character: {…} | null, shown: [{slot, unlock_id, unlock_key, kind, text}]}`
- `character_description(p_user_id) → text[]` — see §4.

Board and quests
- `my_board() → jsonb` — `{week_starts_at, next_refresh_at, quests: […], visit: {name, intro, label, ends_at, grace_ends_at, quests: […] } | null}`
- `my_quests() → jsonb` — accepted plus history (completed / expired / abandoned).
- `accept_quest(p_user_quest_id) → jsonb`
- `abandon_quest(p_user_quest_id) → jsonb` — refuses while a live favor is attached.
- `quest_settings() → jsonb` — `max_characters`, `board_size`, `rarity_weights`, `visit_grace_days`, `action_daily_limit`, `board_push_local_time`.
- `set_time_zone(p_tz)` — validated IANA name.
- `set_quest_push(p_enabled)`.

Quest payload (`quest_payload`, used everywhere a quest is returned):
`{user_quest_id, status, title, prompt, expires_at, completed_at, favor_id, visit_label, unlock:{key, kind, text, rarity}}`

Inventory and actions
- `my_inventory() → jsonb` — held unlocks with provenance and the slot showing each one.
- `drop_unlock(p_unlock_id)` — keeps the row for history, unshows it.
- `send_action(p_to_user_id, p_action_unlock_id) → {rendered}` — requires connection, no block either way, not paused, under the daily limit.
- `my_actions_received() → jsonb`

## 4. Description rendering

`character_description()` returns lines in the handoff's §6 order, omitting empty parts. Verified output:

```
You see Dave, Samaritan of Favorium.
They appear to be a menacing orc.
They are short and have a sturdy build.
They have hazel eyes and ruddy skin. They have shoulder-length chestnut hair braided into a crown.
They are known to be strong and courteous.
They are wearing a moss-green travelling cloak with silver clasps.
They are holding a slender rowan wand that smells faintly of rain.
```

A member with no character returns only the first line. Blocked either way, or a deleted
account, returns *"Not found"*.

## 5. Error strings the apps may branch on

- `Your account is paused from taking on quests.`
- `Your account is paused from sending actions.`
- `You already have a character.`
- `That quest is no longer offered.`
- `That visitor has already left.`
- `That quest is part of an open Favor.`
- `Connect with this person first`
- `You have already sent them as many actions as one day allows.`
- `That is not a time zone we know.`
- `Not found` — another member's data, a block in either direction, or a dropped unlock.

## 6. Scheduling

`run_quest_schedules()` is idempotent and returns counts. It:
draws each member's board for their current local week, posts live visitors' quests,
marks missed visitor quests `not_taken` at `ends_at`, and expires accepted quests with no
attached favor.

`my_board()` also calls `quest_ensure_current()`, so a member is never dependent on cron
having run — the first read after Monday midnight draws their board. `quest_boards`
(user, week) makes the draw bulletproof against double-running.

## 7. Still to build (next steps)

1. **Favor integration** — `favors.user_quest_id`, `propose_favor(…, p_user_quest_id)` locking the
   description to the quest prompt, detach on decline/cancel, and quest completion + unlock grant
   inside `transfer_coin`. Nothing can complete a quest until this lands.
2. **Pushes** — `quest_board`, `visitor_arrived`, `visitor_leaving`, `quest_complete`, `action`.
3. **Admin console** — a *Quests* tab to author weekly rewards, preview a board as a member, and
   switch a visit on for testing.
4. **Web reading surface** — a member's description wherever the web shows a person.

## 8. Seed content shipped

13 weekly quests (common/uncommon/rare), one visitor (`lantern_maker`, *"A lantern-maker"*) with a
**Winter solstice 2026** visit (18 Dec 2026 → 2 Jan 2027, grace to 9 Jan) and three exclusive quests.
A second visitor (`traveling_merchant`) exists with no visit yet, ready for the admin console.
