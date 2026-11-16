# Quests & characters — backend contract (v1.2, favor integration live)

Authoritative for iOS and Android. Built 2026-11-15 from `QUESTS_WEB_HANDOFF.md`.
**Revised 2026-11-15:** favor integration shipped, read shapes pinned for the app
teams, quest pushes added, action sender labels added. See §7.
**Revised again 2026-11-15:** gestures are **uncapped**, and their push ignores the
quest-toggle; an item is worn by **one character at a time**, and wearing moves it out of
the backpack. See §7.4, §7.8 and §9.
**Revised 2026-11-15 (scheduling):** `run_quest_schedules()` now runs hourly via pg_cron
(`quest-schedules-hourly`, `22 * * * *`), so `visitor_leaving` fires, expired quests are
retired, and missed visitor quests are marked. No client change needed. See §6.
**One-page companion for today's changes:** `APP_HANDOFF_2026-11-15_TRAITS.md` — traits vs
objects, the backpack, and uncapped gestures, with a client checklist. Send that one if you want
the app team to read one page instead of this whole contract.
**Mobile handoff (2026-11-16):** `APP_HANDOFF_2026-11-16_HALL.md` — the native design brief for the
Hall and the gesture log. Send that one to the iOS and Android agents; §10.2, §10.6 and §10.7 below
stay authoritative for the server shapes.
**Rooms handoff (2026-11-16):** `APP_HANDOFF_2026-11-16_ROOMS.md` — the companion page for rooms, the
scenery line, examining an object, and `room_act` with its soft cooldown refusal. Send it **with** the
Hall brief, not instead of it; §10.7 below stays authoritative for the server shapes.
**Filed from iOS 2026-11-15:** `WEB_NOTE_2026-11-15_PROFILE.md` — what iOS built against v1.2
(untested on device), and the new Profile / Settings split. It produced **no backend change**;
every call it names was verified against the live schema.
**Decisions closed 2026-11-15 (product owner):** gestures are **never** attached to a thank-you
gem (§7.7), an unaccepted quest simply disappears rather than showing as missed (`not_taken` stays
internal — §3 and §6.1), and the 24-hour `visitor_leaving` reminder stays as written.
**Revised 2026-11-15 (overnight):** `board_push_local_time` is now **live**. The `quest_board` push
is no longer queued by the draw; it is delivered in the member's own local morning and never
between 22:00 and 07:00. No client change. See §6, §7.4 and §7.9.
**Revised 2026-11-15 (per-member morning hour):** the morning hour is now **each member's own**,
not one global `08:00`. New `my_quest_push_hour()` reads it and `set_quest_push_hour(p_hour)`
writes it; `my_character()` returns it alongside `quest_push`. Members who never choose inherit
the shared default, so nothing changes for them. See §3, §6 and §7.5.
**Revised 2026-11-16 (the sender's own line):** `hall_send_action` now also returns
**`rendered_sender`** — the same act, addressed to the recipient by name, for the sender's own story.
No client needs to rewrite `rendered` any more. See §7.10. The reply sent back to iOS is
`APP_REPLY_2026-11-16_GESTURE_SENDER.md`.

**v1.2 in one paragraph — if your copy still says v1.1, these are the deltas.** A quest is
completed **only inside a Favor** (§7): `propose_quest_favor` carries it, `quest_result_for_favor`
reports it. Quest and gesture pushes exist with final copy (§7.4). `my_character()` returns
`quest_push` (§7.5). Actions carry a sender-facing `label` beside the receiver-facing `text`
(§7.6). Gestures have **no daily cap** (§7.8). And an object is worn by **one character at a
time** and leaves the backpack while worn (§9). The read shapes in §3 are pinned — `my_board()`
is this week only, and `my_quests()` / `my_inventory()` / `my_actions_received()` are **bare
arrays**, never objects of arrays.

This layer is **server-owned**: all copy, all drawing and all rendering happen in Postgres so
every client reads the same words.

## 1. Decisions settled with the product owner

| Question | Answer |
|---|---|
| What the helped person sees on a favor carrying a quest | The quest's **title**, and the favor text is **locked** to the quest's prompt so both parties know what the favor must be. (Favor integration lands in the next step — see §7.) |
| Giving unlocks to friends | **Not in 1.1.** Unlocks are earned only. Dropping is allowed. |
| Character + board on favorium.app | **Superseded 2026-11-16 by §10.** The board now lives in the Authored Hall on the web, and the Hall replaces the apps' quest screens in the same release. `character_description()` is still the only reading of another member. |
| Quest history visible | Yes — `my_quests()` returns the member's own history. Nothing is shown on other people's profiles. |
| Are gestures capped per day | **No.** A gesture is acquired and kept, like an unlock, so a daily ceiling was the wrong shape. Ownership, connection and blocking are the only gates. See §7.8. |

## 2. Vocabulary

`catalog_entries` holds every word a character can use. 102 entries seeded (11 of them races).

Kinds: `race`, `height`, `build`, `eyes`, `skin`, `hair_color`, `hair_length` (free for everyone)
and `look_term`, `rep_term`, `clothing`, `held`, `hairstyle`, `action` (quest rewards only).

**Races are data, not code.** `catalog()` returns them in `sort` order, so a new race needs no app
release and no client change — render whatever comes back and never hard-code the list. The current
set, in order, is:

| `key` | `text` |
|---|---|
| `race_human` | human |
| `race_elf` | elf |
| `race_dwarf` | dwarf |
| `race_orc` | orc |
| `race_goblin` | goblin |
| `race_gnome` | gnome |
| `race_satyr` | satyr |
| `race_dryad` | dryad |
| `race_giant` | giant |
| `race_tideborn` | tide-born |
| `race_halfling` | halfling — added 2026-11-15, `sort` 110 |

Race is chosen once at `create_character` and is immutable (`update_character_appearance` has no race
parameter), so a build that offers only the older ten is not broken — it just cannot offer Halfling to
a new character. `text` is inserted mid-sentence, so it is lower case and there is no `article`.

`key` is **permanent** — never rename or reuse one, even if the text changes.
Read them all with `catalog()`.

**Editing the vocabulary needs no SQL.** The admin console's *Catalog* tab writes through
`admin_catalog_data()` (read) and `admin_catalog_save(p_key, p_kind, p_text, p_flavor, p_sort,
_p_active, p_rarity, p_slot)` — both `SECURITY DEFINER`, both `is_admin()`-gated. A new `race` row is a
new race for every client that renders the list from `catalog()`; a reworded one reads differently
everywhere while its `key` stays put. Deactivating a row removes it from `catalog()` (so it is no
longer offered) but never changes the key of anyone already carrying it. Reward kinds delegate to
`admin_reward_save`, so the prefix/slot/article rules cannot drift between the two screens.

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
  **An item is worn by one character at a time** (§9): wearing a `clothing` or `held`
  unlock that another of your characters is already wearing raises
  *"Another of your characters has that. Take it off them first."* Filling an occupied
  slot replaces whatever was there; the replaced item returns to the backpack.
- `my_character() → jsonb` — `{character: {…} | null, shown: [{slot, unlock_id, unlock_key, kind, text}], quest_push: boolean, quest_push_hour: integer, quest_push_hour_is_custom: boolean, quest_push_default_hour: integer}`
  `character` is the whole `characters` row as JSON, so it always carries
  `id, pronouns, race_key, height_key, build_key, eyes_key, skin_key, hair_color_key,
  hair_length_key` — no more, no fewer. `quest_push` was added 2026-11-15 (§7.5); the three
  `quest_push_hour` fields were added the same day, so a settings screen needs **one** call
  for the toggle and the hour.
- `character_description(p_user_id) → text[]` — see §4.

Board and quests
- `my_board() → jsonb` — `{week_starts_at, next_refresh_at, quests: […], visit: {name, intro, label, ends_at, grace_ends_at, quests: […] } | null}`
  **`quests` is this week's draw only** (`posted_at >= week_starts_at`, no visitor).
  A quest taken on in an earlier week and still open is *not* here — it is in
  `my_quests()`, which is what a “Still open” section should read. Before
  2026-11-15 the board leaked older weeks, so a client that de-duplicated was
  quietly hiding a duplicate that should never have been sent.
- `my_quests() → jsonb` — **a bare array** of `quest_payload`, newest first, all
  statuses (`accepted`, `completed`, `expired`, `abandoned`). Never an object of
  arrays. **`posted` and `not_taken` are deliberately absent** — a quest that was
  never taken on disappears when its week or visit ends instead of appearing in
  history as missed. Do not build a "missed" section, and do not branch on a status
  that can never arrive. See §6.1.
- `accept_quest(p_user_quest_id) → jsonb`
- `abandon_quest(p_user_quest_id) → jsonb` — refuses while a live favor is attached.
- `quest_settings() → jsonb` — `max_characters`, `board_size`, `rarity_weights`, `visit_grace_days`, `board_push_local_time`, and `action_daily_limit`, which is **deprecated and ignored** (§7.8). `board_push_local_time` is now only the **shared fallback**: each member's own hour is `profiles.quest_push_hour` (§6).
- `set_time_zone(p_tz)` — validated IANA name.
- `set_quest_push(p_enabled)` — the on/off toggle.
- `set_quest_push_hour(p_hour integer) → jsonb` — **the member's own morning hour**, 7–21
  inclusive (`7` means 07:00 local). `p_hour = null` clears the personal choice and returns
  them to the shared default. Out of range raises *"Pick an hour between 7 and 21."* Returns
  the same shape as `my_quest_push_hour()` below.
- `my_quest_push_hour() → jsonb` — `{quest_push_hour, quest_push_hour_is_custom, quest_push_default_hour}`.
  `quest_push_hour` is the **effective** hour to display, always non-null; `quest_push_hour_is_custom`
  is false when they are inheriting the default; `quest_push_default_hour` is the shared fallback
  (currently `8`) so a picker can label it *"Default (08:00)"*.

Quest payload (`quest_payload`, used everywhere a quest is returned):
`{user_quest_id, status, title, prompt, expires_at, completed_at, favor_id, visit_label, unlock:{key, kind, text, rarity}}`

Inventory and actions
- `my_inventory() → jsonb` — **a bare array**, newest earned first, of
  `{unlock_id, id, unlock_key, key, kind, text, label, slot, rarity, earned_at,
  quest_title, visit_label, shown_slot, shown_in, worn_by_character_id, equipped}`.
  - `unlock_id` and `id` are the same value; `unlock_key` and `key` are the same
    value. Both spellings are returned so no client has to guess.
  - `slot` is the catalog's clothing slot (`outer` / `head` / `accessory`), null
    for every other kind. It is where the thing *may* be worn.
  - `shown_slot` (also returned as `shown_in`) is the description slot currently
    showing it, null when it is in the backpack and not worn.
  - **`worn_by_character_id`** (added 2026-11-15) is the character currently
    carrying or wearing it, null when it is in the backpack. `equipped` is the
    same fact as a boolean, and is true only when the character you are looking
    at is the one holding it.
  - `label` is the sender's wording for an action (§7.6), null otherwise.
- `drop_unlock(p_unlock_id)` — keeps the row for history, unshows it.
- `send_action(p_to_user_id, p_action_unlock_id) → {rendered}` — requires connection,
  no block either way, not paused, and that you actually hold the gesture.
  **No daily cap** (§7.8). Report `rendered` verbatim.
- `my_actions_received() → jsonb` — **a bare array**, newest first, of
  `{id, from_user_id, from_name, rendered, created_at}`. `id` was missing before
  2026-11-15; use it as the list identity.

The Hall and its rooms (built 2026-11-16 — full model in §10.7, room shapes in §10.7 *Reading a room*)
- `room_view(p_room_key text default null) → jsonb` — **the one call for a room.** `null` means the
  room you are standing in, or the Hall if you are not present. Returns `{key, title, intro,
  ambience, exits, objects, object_looks, object_actions, act_cooldown_seconds, week_starts_at,
  next_refresh_at, quests, history, visit, present, board_new, me: {present, room_key, in_room,
  sneaking, has_character}, free_actions, stranger_daily_limit, presence_ttl_seconds,
  heartbeat_seconds}`. **The board fields are Hall-only** — from another room `quests` and `history`
  come back `[]`, `visit` `null`, `board_new` `0` ("not asked for", never "nothing to do"), while
  `week_starts_at` and `next_refresh_at` are always present. Branch on `me.in_room`, not
  `me.present`. **`hall_room()` is an alias for `room_view('hall')`** — one body, so it returns room
  fields too and pre-rooms builds keep working; new work calls `room_view`.
- `room_move(p_room_key text) → jsonb` — walks through a live exit and returns the destination's
  **full `room_view` payload**, so no follow-up read is needed. Refuses with **`Step inside first.`**
  when presence has lapsed and **`You can't get there from here.`** when the room is not an exit of
  the room you are standing in. Show both verbatim. A member is in at most one room at a time, so a
  move is also a departure.
- Also in §10.7 and not repeated here: `hall_enter` / `hall_leave` / `hall_heartbeat` (entry, exit and
  presence, unchanged apart from carrying `room_key`), `room_act(p_object, p_action_key)`, and
  `room_listen()`. `hall_send_action` is now **room-scoped** — see §10.2 and §10.3.

## 4. Description rendering

`character_description()` returns lines in the handoff's §6 order, omitting empty parts. Verified output:

```
You see Dave, Samaritan of Favorium.
They appear to be a menacing orc.
They are short and have a sturdy build.
They have hazel eyes and ruddy skin. They have shoulder-length chestnut hair braided into a crown.
They are known to be strong and courteous.
They are wearing a moss-green traveling cloak with silver clasps.
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
- `Only a quest you have taken on can be carried by a Favor.`
- `That quest is already part of a Favor.`
- `That quest has run out of time.`
- `That quest cannot be offered as a Favor.`
- ~~`You have already sent them as many actions as one day allows.`~~ — **retired
  2026-11-15.** Gestures are uncapped (§7.8) and this will never be raised again.
  Branch off it, and delete any sends-left counter.
- `Another of your characters has that. Take it off them first.`
- `That is not a time zone we know.`
- `Pick an hour between 7 and 21.` — `set_quest_push_hour` range check.
- `Not found` — another member's data, a block in either direction, or a dropped unlock.

## 6. Scheduling

`run_quest_schedules()` is idempotent and returns counts. It:
draws each member's board for their current local week, posts live visitors' quests,
marks missed visitor quests `not_taken` at `ends_at`, expires accepted quests with no
attached favor, and queues the `visitor_leaving` push ~24 h before a visit ends.

**It now runs hourly — `pg_cron` job `quest-schedules-hourly`, `22 * * * *`.** Before
2026-11-15 nothing called it, which meant `visitor_leaving` never fired, accepted quests
past `expires_at` were never expired (they stayed on the board, then `propose_quest_favor`
refused them with *"That quest has run out of time."*), and a finished visit's unanswered
quests were never marked `not_taken`. All three now clear within the hour.

The full job list, for reference — nothing else changed:

| Job | Schedule | Routine |
|---|---|---|
| `zero-balance-daily` | `0 9 * * *` | `run_zero_balance_jobs()` |
| `push-queue-drain` | `* * * * *` | `dispatch_push_queue()` |
| `favor-auto-release` | `7 * * * *` | `release_due_favors()` |
| `favor-release-reminders` | `12 * * * *` | `send_release_reminders()` |
| `favor-settle-confirmed` | `*/5 * * * *` | `settle_confirmed_favors()` |
| `quest-schedules-hourly` | `22 * * * *` | `run_quest_schedules()` |
| `quest-board-push-morning` | `*/10 * * * *` | `queue_due_board_pushes()` |

The routine is safe to run repeatedly: the `not_taken` and `expired` sweeps are plain
`update … where status = …`, the leaving push is stamped on `visits.leaving_pushed_at`
so each visit is announced once, and `quest_boards` (user, week) makes the draw
bulletproof against double-running.

### 6.1 `not_taken` is internal, on purpose

`quest_draw_board()` and `run_quest_schedules()` do mark a finished week's or visit's
unclaimed quests `not_taken`, but that status is a **server-side bookkeeping flag, not a
user-visible state**. `my_quests()` does not return it (nor `posted`), so a quest nobody
accepted simply disappears when its week or visit ends. This is a settled product decision
(2026-11-15): quest history records what you did, not what you missed. **Do not add a
"missed" section, and do not branch on a status that can never arrive.**

**`board_push_local_time` is honoured, and the `quest_board` push is server-side — settled
2026-11-15.** Drawing a board and announcing it are now two separate steps.

- `quest_draw_board()` **no longer queues anything.** It draws, and stops there.
- `queue_due_board_pushes()` is the only thing that queues `quest_board`, running every ten
  minutes (`quest-board-push-morning`). For each member it queues **at most one** push per
  local week, and only when all of these hold: `quest_push` is on and they have an active
  character; their board exists for their current local week and was drawn within the last
  24 hours; there are quests on it; no `quest_board` row already exists for that week; and
  their **local clock is at or after their morning hour and before 22:00**.
- **The morning hour is the member's own.** `profiles.quest_push_hour` (set by
  `set_quest_push_hour`, 7–21) wins; when it is `null` the shared
  `quest_config.board_push_local_time` (currently `08:00`) applies. Both are clamped into
  `07:00–22:00`, so no value a member can pick — and no value an admin can type — can push
  overnight. Changing the shared default therefore moves only the members who never chose.
- Delivery therefore lands **in their own morning**, typically within ten minutes of their
  hour, and **never between 22:00 and 07:00 local**.

The push still arrives **while the app is closed** — it is queued and drained by the server,
not by opening the app. `push-queue-drain` (`* * * * *`) does the sending.

Idempotency is safe on two counts: sent `push_queue` rows are marked, never deleted, so the
queue is itself the ledger (**one per member per local week**), and a board drawn days ago is
not treated as news, so a late deploy cannot produce a catch-up burst.

**One deliberate behaviour change from the earlier design:** before this fix the push was
queued the moment the board was drawn, which — once the hourly job existed — meant roughly
**00:22 local** for a member whose week starts at midnight. That is gone.

One thing this does **not** affect: `my_board()` also calls `quest_ensure_current()`, so a
member is never dependent on cron having run — the first read after Monday midnight still
draws their board. The only difference is that cron gets there first, which is what queues
the push.

## 7. Favor integration — live since 2026-11-15

A quest is completed by doing it inside a Favor. Nothing else completes one.

### 7.1 Proposing a Favor that carries a quest

`propose_quest_favor(p_helped_id uuid, p_user_quest_id uuid) → uuid` (the new
favor's id). It is a **separate call** from `propose_favor` — the plain one takes
free text and carries no quest.

What it does: checks the connection both ways, checks the quest is yours and
`accepted`, not already in a Favor, not out of time, and that the quest is still
offered; then writes the Favor with the quest's **prompt verbatim** as its
description, so neither party can reword what is being asked. It also stamps
`favors.user_quest_id` and `favors.quest_title`, and sets
`user_quests.favor_id`.

Errors it can raise:

| Message | Meaning |
|---|---|
| `Connect with this person first` | no connection |
| `Favor not found` | blocked pair, or you are the helped person |
| `Not found` | the quest id is not yours |
| `Only a quest you have taken on can be carried by a Favor.` | status is not `accepted` |
| `That quest is already part of a Favor.` | it already has a `favor_id` |
| `That quest has run out of time.` | `expires_at` has passed |
| `That quest is no longer offered.` | the quest row was deactivated |
| `That quest cannot be offered as a Favor.` | prompt empty or over 280 characters |

### 7.2 Reading the quest on a Favor

`favors` itself carries `user_quest_id` and `quest_title`, so any existing favor
read that selects those columns now gets both for free. `quest_title` is the same
string on both sides, which is what the helped person sees instead of free text.

`quest_result_for_favor(p_favor_id uuid) → jsonb | null` — call this **after** a
transfer to celebrate. Returns `null` when the Favor carries no quest, otherwise:

```jsonc
{
  "favor_id": "…",
  "user_quest_id": "…",
  "quest_title": "Carry the water uphill",
  "quest": { /* the ordinary quest_payload, status now "completed" */ }
}
```

It only answers for a party to the Favor (`Favor not found` otherwise) and works
for both sides, so the helper can render the same celebration.

### 7.3 What `transfer_coin` reports

`transfer_coin(p_favor_id, p_coin_id) → bigint` is **unchanged** — it still
returns the `coin_history` row id, and it stays the shape the web already uses.
It does not tell you a quest finished. That happens underneath it, so a bigint
return could never carry it without breaking every existing caller.

The quest is completed inside the transfer, and the reward is granted there,
idempotently. To know it happened: call `quest_result_for_favor(favor_id)` right
after a successful transfer. A `status` of `completed` in the payload means the
quest is done; `quest.unlock` is the thing just earned, and the `quest_complete`
push (§7.4) arrives separately as the durable record.

### 7.4 Pushes

Queued by the database into `push_queue` and drained by `notify-gem` — the same
drain as the gem pushes, so there is nothing new to configure. All quest kinds
carry `route: "profile"`, so tapping any of them opens Profile.

| `kind` | when | Title | Body |
|---|---|---|---|
| `quest_board` | in the member's local morning, at or after their own `quest_push_hour` (shared default when unset) and never 22:00–07:00 (§6) | `Your quests are ready` | `N new quests are on your board this week.` (`1 new quest` for one) |
| `visitor_arrived` | a live visitor's quests land on your board | `{visitor} has arrived` | `{visit label} — their quests are on your board, but only until {2 Jan}.` |
| `visitor_leaving` | ~24 h before a visit ends, to anyone still holding an unanswered quest from it | `{visitor} leaves tomorrow` | `{visit label} ends {2 Jan}. The quests still on your board from it will go unanswered.` |
| `quest_complete` | the Favor carrying the quest settles | `Quest complete` | `{quest title} — you have earned a {unlock text}.` |
| `action` | someone sends you an action | `An action for you` | the already-rendered sentence, e.g. `Dave bows their head to you.` |

All of them except the last are suppressed unless `profiles.quest_push` is true,
which is what `set_quest_push` writes. **`action` is the exception** (§7.8): a
gesture is a deliberate personal message rather than a board digest, so it is
queued through `queue_gesture_push()` and reaches the device even with quest
pushes switched off. `favorId` is always null on these; `thread-id` is the route.
The bodies are final copy — display them verbatim.

### 7.5 Reading the push toggle

`set_quest_push(p_enabled) → {quest_push}` writes it.
**`my_character()` now returns `quest_push`** at the top level, beside `character`
and `shown`. Read the truth from there on load instead of remembering it on the
device.

**The morning hour lives in the same call** (added 2026-11-15): `quest_push_hour`
(the effective hour, an integer), `quest_push_hour_is_custom` (false while they are
inheriting the shared default), and `quest_push_default_hour` (the fallback, so the
picker can label it *Default*). Write it with `set_quest_push_hour(p_hour)`, 7–21;
passing `null` restores the default. The hour only affects `quest_board` — every
other quest push still ignores quiet hours (§7.9).

### 7.6 Action wording — sender vs receiver

`catalog_entries.label` is new. For an action it holds the **sender's** wording,
imperative and second person — `Bow your head`, `Tip your hat` — while `text`
stays the third-person sentence the receiver sees (`bows {pos} head`, rendered as
`Dave bows his head to you.`).

- `catalog()` returns `label` with every row (it returns the table row, so the
  column came along automatically). It is null for every kind except `action`.
- Render the sender's menu from `label`, falling back to `text` if it is null,
  and the received line from `rendered` / `text`. Never derive one from the other:
  `{pos}` cannot become an imperative.
- `my_inventory()` also returns `label`, so a menu built from held actions needs
  one call.
- Editable in the admin console's **Catalog** tab, in the action's *Wording* form.

### 7.10 The sender's own line — built 2026-11-16

`rendered` addresses the **recipient** (`Dave raises his hand in greeting to you.`). Shown to the
sender it reads as if someone greeted *them*, and the contract forbids deriving one wording from the
other, so there was no sender-side sentence at all. iOS worked around it by replacing the last whole
word `you` in `rendered` with the recipient's name — a string swap that would break on authored text
using "you" anywhere else.

**The server now composes both lines.** `hall_send_action` returns one extra field:

```jsonc
{ "rendered":        "Dave raises his hand in greeting to you.",          // receiver, unchanged
  "rendered_sender": "Dave raises his hand in greeting to Jellybean.",   // new
  "connected": true, "stranger": false, "room_key": "hall" }
```

- Both are built from the **same** sentence body (`display_name` + the catalog's `text` with `{pos}`
  resolved). Only the ending differs: `… to you` for the recipient, `… to {recipient display_name}`
  for the sender. Neither is derived from the other, so `{pos}` handling and the verb can never drift.
- **A gesture that addresses nobody** (`directed = false`, e.g. `clasps {pos} hands together`) returns
  the **same string** in both fields, because there is no recipient to name.
- A recipient with no display name is named `them`, so the sentence never breaks.
- **`actions_sent.rendered` still stores the receiver's line**, and the `action` push body (§7.4) is
  unchanged. Only the call's return grew — an additive field, so existing decoders keep working.
- **Show `rendered_sender` in the sender's own story and drop the string swap.** The web Hall already
  does; it reads `rendered_sender` and falls back to `rendered` if an old build answers.
- The sender's own name still leads the sentence, as the product owner chose: third person, never a
  MUD-style *You raise your hand…*.

### 7.7 What is still not built

1. **An action attached to a thank-you gem** (`transfer_coin(…, p_action_unlock_id)`) —
   **decided against, 2026-11-15.** The product owner will not attach gestures to gems:
   a gesture stays something you send from someone's profile. `transfer_coin` keeps its
   `p_action_unlock_id` parameter for compatibility but no gem will ever carry one, so
   **do not build a gesture-on-a-gem path, and do not read an action out of a transfer.**
   This one is closed, not pending — remove it from any "waiting on product" list.
2. **Web reading surface** — a member's description wherever the web shows a person. When
   that is built, follow the iOS layout rule (filed in `WEB_NOTE_2026-11-15_PROFILE.md`): the
   description's first line already carries the name and title, so do not repeat them beside
   the portrait, and keep account settings on their own page rather than under the character.
3. **Nothing else is open.** The overnight-push gap this list used to carry is fixed (§6, §7.9).

### 7.8 Gestures are uncapped — changed 2026-11-15

`send_action` no longer enforces a daily limit. It previously allowed **five per
recipient per rolling 24 hours**, from `quest_config.action_daily_limit`.

Why it went: a gesture is *acquired*, like an unlock. It is earned from a quest,
kept forever, and performed as often as its owner likes. A daily ceiling treats it
like a free ping that must be rationed, which is the wrong shape for something
earned. The remaining gates:

| Gate | Error |
|---|---|
| signed in | `Not signed in` |
| not paused | `Your account is paused from sending actions.` |
| recipient is someone else | `You cannot send that to yourself.` |
| no block in either direction | `Not found` |
| a real connection | `Connect with this person first` |
| you actually own that gesture | `Not found` |

Three consequences for clients:

- **`quest_settings().action_daily_limit` is deprecated.** It still returns with
  its old value so no decoder breaks, but nothing reads it and it can no longer be
  edited. Ignore it and do not render a sends-left counter. It will be removed in a
  later version.
- **The daily-limit error is retired.** Delete any branch that switches on
  `You have already sent them as many actions as one day allows.`
- **The gesture push is not gated by `quest_push`** (§7.4). Nothing else about it
  changed: `kind: "action"`, `route: "profile"`, title `An action for you`.

### 7.9 Overnight delivery — fixed 2026-11-15

Settled with the product owner (2026-11-15): **no quest notification arrives overnight.** The
chosen shape was the stronger one — **hold until the member's morning setting** in their own
`profiles.time_zone`, rather than only skipping late hours. `board_push_local_time` finally does
something, and the mechanic is described in §6.

The result, in one line: a member whose local week begins at midnight no longer gets a push at
00:22; they get *"Your quests are ready"* in their morning, once per week, and not at all if
they have turned quest pushes off.

**Each member then picks their own hour — 2026-11-15.** The first version of this fix reused one
global `08:00` for everyone, which is a guess about when people wake up. `profiles.quest_push_hour`
now overrides it per member (7–21, `set_quest_push_hour`), and the shared setting is only the
fallback for members who never chose. The clamp means the window cannot be opened up from either
side: a member cannot ask to be woken at 03:00, and an admin editing the shared default cannot
create an overnight send either.

No client change was needed for the overnight fix itself. The iOS toggle's wording ("New quests
on Mondays", no time) stays correct either way; a picker is an **optional, additive** screen — the
backend is ready for it and members who ignore it keep the old behaviour.

**`visitor_leaving` is unchanged** and still fires ~24 h before a visit ends regardless of the
member's local hour — that one is time-critical, so it deliberately does not respect quiet hours.
`visitor_arrived`, `quest_complete` and `action` are likewise untouched: they respond to
something that just happened and are never batched into a digest.

No client change was needed. The iOS toggle's wording ("New quests on Mondays", no time) stays
correct: the delivery hour comes from data, not from anything the app promises.


## 8. Seed content shipped

13 weekly quests (common/uncommon/rare), one visitor (`lantern_maker`, *"A lantern-maker"*) with a
**Winter solstice 2026** visit (18 Dec 2026 → 2 Jan 2027, grace to 9 Jan) and three exclusive quests.
A second visitor (`traveling_merchant`) exists with no visit yet, ready for the admin console.

## 9. Inventory scope, and the multi-character question

**Unlocks are never given between members.** No routine moves a `user_unlocks` row to
another `user_id`, and none ever should. The only thing handed from one member to another
is a **gem** (`coins` / `transfer_coin`). An unlock is earned, worn, and — if the owner
chooses — dropped.

**Inventory belongs to the account, not a character.** `user_unlocks.user_id` references
`profiles`; there is no character column anywhere in it. *Wearing* is the character-level
thing: `character_shown` is keyed `(character_id, slot)`.

**Inventory is a backpack; wearing takes the thing out of it.** `my_inventory()` still
returns every live unlock, and where it is, is read from `worn_by_character_id` and
`shown_slot`: null means **in the backpack**, non-null means a character is carrying it.
An item that is on a character is not offered from the backpack — it is offered from the
equipped slots (`my_character().shown`). Take it off and it drops back into the backpack.
Nothing is ever in both places at once.

**One wardrobe, one wearer — settled with the product owner 2026-11-15.** The account holds
exactly one live copy of a thing (`user_unlocks_held` is unique on
`(user_id, unlock_key) WHERE dropped_at IS NULL`), and **only one character can have it on
at a time**. The vest scenario:

1. Take the vest off — `set_shown(character, 'outer', null)`. The row leaves that
   character's slot and the vest returns to the backpack.
2. `my_inventory()` returns it with `worn_by_character_id: null` — in the backpack.
3. Wear it on the other character — `set_shown(other_character, 'outer', unlock_id)`.

Skipping step 1 is refused: *"Another of your characters has that. Take it off them
first."* The check lives inside `set_shown` and covers `clothing` and `held` only.
Traits — `look_term`, `rep_term`, `hairstyle` — are not objects, so they are deliberately
**not** exclusive: two characters may share a bearing, a reputation word or a hairstyle.
`character_shown` has RLS on with no policies, so the RPC is the only write path and the
rule cannot be sidestepped by writing to the table directly.

Filling an already-occupied slot replaces what was there; the replaced item simply goes
back to the backpack. Nothing is lost by trying something else on.

Still open, and neither bites until `max_characters` rises above 1:

- **Activating a character.** `set_shown` refuses any character that is not `is_active`,
  and `my_character()` reads the active one. There is no routine to activate a different
  character, and `create_character` refuses past `max_characters` (currently 1) with
  *"You already have a character."* Multi-character needs `activate_character(p_character_id)`
  before any of the above can be reached at all.
- **Dropping destroys it everywhere.** `drop_unlock` stamps `dropped_at` and deletes the
  unlock from every character's slots. Right for "destroyed" — but it means dropping can
  undress a character you are not currently looking at.

## 10. The Authored Hall (built 2026-11-16)

**Decisions closed with the product owner, 2026-11-16.** The Hall is the only quest surface on
the web **and** replaces both apps' quest screens in the same release — one surface, one set of
words. The invite/pairing code remains the only way to become connected: the Hall is a place to
be seen doing your own thing, not a place to collect strangers.

The reason it can be the only door is the sneak option. A sneaking visitor still sees everyone
and still registers a visit, but is invisible to everybody else. So an empty room is never an
outage — you can always read your board.

### 10.1 Where presence lives

Table DDL is blocked on the hosted project, so presence rides on `profiles` rather than a
dedicated table:

| Column | Meaning |
|---|---|
| `hall_seen_at` | last heartbeat. Non-null and within `hall_presence_ttl_seconds` = standing here |
| `hall_entered_at` | when the current stay began (kept across heartbeats) |
| `hall_sneaking` | hidden from other people's presence lists |

Known limitation: these columns are readable by anyone who can read `profiles`. The app never
exposes them, but a dedicated RLS-protected table is the right home as soon as table DDL is
available; only `room_view()` would need to change.

### 10.2 RPCs

- `room_view(p_room_key text default null) → jsonb` — one call for a room. `null` means **the room you
  are standing in**, or the Hall if you are not present (§10.7).
  **`hall_room()` is an alias for `room_view('hall')`** — literally the same body, not a second copy of
  the room code. It returns exactly `room_view('hall')`, including the room fields below, so a build
  written before rooms existed keeps working; from another room it answers with the Hall's copy,
  `me.in_room: false` and no board. New work calls `room_view`, and `hall_room()` should be treated as
  the compatibility name rather than the way in.
  Payload: `{key, title, intro: text[], ambience: text[], exits, objects: text[], object_looks,
  object_actions, act_cooldown_seconds, week_starts_at, next_refresh_at, quests, history, visit,
  present, board_new, me: {present, room_key, in_room, sneaking, has_character}, free_actions,
  stranger_daily_limit, presence_ttl_seconds, heartbeat_seconds}`.
  `quests` and `visit` match `my_board()` exactly; `history` is `my_quests()` (a bare array).
  **`week_starts_at` and `next_refresh_at` are always returned, but `quests`, `history`, `visit` and
  `board_new` are filled only in the Hall** — elsewhere they are `[]`, `[]`, `null` and `0`, which is
  "not asked for", never "nothing to do". Each `present` entry is `{user_id, name, avatar_url,
  entered_at, arrived_from, is_me, connected, sneaking, signature, description}` where `description` is
  `character_description(user_id)` verbatim, and `sneaking` is only ever true on your own entry.
- `hall_enter(p_sneak boolean default false)` — refuses without an active character
  (*"Make a character before you take a place in the hall."*). Creates or refreshes presence.
- `hall_leave()` — clears presence for the caller.
- `hall_heartbeat(p_sneak boolean default null)` — refreshes `hall_seen_at`; `null` leaves the
  sneak state alone. Clients should call it every `heartbeat_seconds`.
- `hall_gestures() → jsonb` — a bare array of `{key, label, text, free, owned}`. Free greetings
  come back for everyone, owned gestures in addition.
- `hall_send_action(p_to_user_id, p_action_key) → {rendered, rendered_sender, connected, stranger,
  room_key}` — the Hall's gesture path. **`send_action` is untouched**, because both apps call it and
  its contract is an unlock *row id*. `rendered` addresses the recipient; `rendered_sender` names them
  for the sender's own story. See §7.10.

### 10.3 Gesture rules in the Hall

| Gate | Result |
|---|---|
| target not present, hidden, or blocked | `They are no longer in the hall.` / `Not found` |
| gesture is a greeting in `hall_free_actions` | allowed to anyone present |
| gesture is earned and the pair is connected | allowed, uncapped |
| gesture is earned and the pair is **not** connected | `Keep that gesture for someone you are connected to.` |
| second greeting to the same unconnected person within 24 h | `You have already greeted them today. Connect with them to say more.` |

Free greetings are `action_bowhead`, `action_nodgrave`, `action_incline`,
`action_raisehand` — greetings are free, intimacies are earned. This is config, not granted
rows: a brand-new member owns nothing and can still nod. Strangers therefore hear greetings
only; the cap is `hall_stranger_daily_limit` (1).

### 10.4 The starter kit

`grant_starter_kit(p_character_id)` is called at the end of `create_character`, so the Hall's
front door is character creation:

1. **One signature gesture** drawn at random from `hall_signature_actions`
   (`offerhand`, `tiphat`, `crackknuckles`, `clasphands`, `laugh`), granted as a real unlock.
   It sits *outside* the free greetings, so it reads as identity rather than vocabulary.
2. **One starter wearable** drawn at random from any of `hall_starter_slots`
   (`held`, `outer`, `head`, `accessory`), **common or uncommon only** — rare stays a quest
   prize. It is granted but **not worn**, deliberately: the first lesson is that a thing in the
   backpack is not yet something other people can see. `set_shown` is how it goes on.

Both steps are idempotent (they skip if the member already holds any signature gesture or any
wearable), so the routine is safe to re-run and existing characters were backfilled with it.

### 10.5 What the Hall is not

- **Not a connection path.** No pairing, no introductions. Two people who already know each
  other pair elsewhere and meet here.
- **Not proof of company.** The room's creaks and draughts are uncorrelated with presence: they
  play whether the hall is empty, full, or full of sneaking people. Ambience must never become
  a tell, or sneak becomes presence with plausible deniability.
- **Not a gate.** `my_board`, `accept_quest` and `abandon_quest` stay callable, so a slow Hall
  degrades the apps instead of breaking them.

### 10.6 Gestures toward you — the log (built 2026-11-16)

A gesture is a message, not a toast. It is written to `actions_sent` the instant it is sent, so a
nod given while the recipient's tab was closed is still there when they come back. The Hall reads
and acknowledges it with two routines of its own; **`my_actions_received()` is unchanged**, so no
app decoder moves.

- `actions_sent.seen_at` (new, nullable `timestamptz`) is the read marker. Null = not yet seen.
  Index `actions_sent_to_user_created_idx (to_user_id, created_at desc)` backs the read.
- `hall_received_actions(p_limit integer default 20) → jsonb` —
  `{items: [{id, from_user_id, from_name, from_avatar, unlock_key, rendered, created_at, seen,
  connected}], unseen}`, newest first, capped at 50. Rows from people you have blocked are
  excluded from both the list and the `unseen` count, so a block never leaves a lingering badge.
  `connected` lets the panel label a gesture without a second call.
- `hall_mark_actions_seen() → integer` — stamps `seen_at = now()` on every unseen gesture addressed
  to the caller (blocked senders excluded) and returns how many were marked.

**Judgement calls.** The log lists the last 20 regardless of age — nothing is deleted, so there is
no expiry to explain. Reading is **explicit**, never triggered by scrolling or by opening the
page: the whole point is that a returning member sees which gestures are new, so an automatic
acknowledge would erase the very fact it is trying to preserve. `rendered` is shown **verbatim** —
the sentence already carries the sender's name and the right pronoun, so the client never
composes it.

### 10.7 Rooms from the start (built 2026-11-16)

`room_view` and `room_move` are also listed with the other calls in **§3**, so a client team can find
them without reading this section end to end; this section stays authoritative for their shapes.

**Settled with the product owner, 2026-11-16, in answer to the iOS room request.** The Hall is the
**first of several rooms**, and the rooms exist from this release. This section supersedes the
"one room" framing in §10.2 and the "board while unseen" wording in §10.

The model: a member enters through the **Hall**, presence then carries a **`room_key`**, and each
room's exits move them. A person is in **at most one room at a time** — moving takes them out of the
room they were in. **The quest board is an object in the Hall and is readable only from inside it.**
Other rooms hint that it is there, and never hint about people.

**Table DDL is available again** (the hosted project accepted it on 2026-11-16), so rooms are content
in their own table rather than config columns:

`public.rooms (key text pk, title text, intro text[], ambience text[], exits jsonb, objects text[],
object_looks jsonb, object_actions jsonb, active boolean, sort integer)`. RLS is on with **no policies** — the RPCs are the only read path, so
the authored copy cannot drift between clients. Seeded: `hall`, `garden`, `library`, `snack_bar`.
The Hall is the hub with one exit to each side room, and each side room has an exit back to the Hall,
so nobody is ever more than one step from the board.

Presence gains two columns on `profiles`: **`hall_room_key`** (non-null while present) and
**`hall_arrived_from`** (the room you came from, null on a fresh arrival). Both are cleared by
`hall_leave()`. The "presence belongs in its own table" note in §10.1 still stands.

#### Reading a room

`room_view(p_room_key text default null) → jsonb`. Null means **the room you are standing in**, or the
Hall if you are not present.

```jsonc
{
  "key": "garden",
  "title": "The Garden",
  "intro": ["…"],                  // authored, verbatim
  "ambience": ["…"],               // authored; rotate on a timer, as before
  "exits": [ { "key": "hall", "label": "the door back into the Hall", "board_new": 4 } ],
  "objects": ["a stone bench"],    // "You also see …" — names only
  "object_looks": [                // what each name says when examined
    { "name": "a stone bench",     // matches an entry in `objects` verbatim
      "look": "The bench has settled a little into the ground…",
      "detail": "Someone scratched a date into the armrest…" }   // or null
  ],
  "object_actions": [              // the one small thing this room lets you do
    { "name": "a stone bench",     // matches an entry in `objects` verbatim
      "key": "sit",               // stable verb key
      "label": "sit for a moment", // the button, second person
      "line": "You sit. The stone is colder than the air…" }
  ],
  "act_cooldown_seconds": 6,       // how long the server makes you wait before repeating
  "present": [ /* person shape, plus arrived_from */ ],
  "board_new": 4,
  "me": { "present": true, "room_key": "garden", "in_room": true,
          "sneaking": false, "has_character": true },
  "heartbeat_seconds": 45, "presence_ttl_seconds": 150
  // plus board fields ONLY when in the Hall: week_starts_at, next_refresh_at, quests, history, visit
}
```

- **`present` is empty unless the caller is standing in that room**, and only ever contains people in
  that room. This closes the doorway loophole: nobody can read who is inside without their visit being
  recorded. A sneaking member is absent from everyone else's list, present in their own.
- **The board is not readable from outside.** Someone who is not in the Hall gets `quests: []`,
  `history: []`, `visit: null` — but still gets `board_new` so the doorway can say *make your
  character, and the board is just inside*. Members without a character cannot step in at all.
- `hall_room()` is an alias for `room_view('hall')` — one function, one body — so existing builds keep
  working. Called from another room it returns the Hall's copy with `me.in_room: false` and no board.
  The brief's §2 payload block shows this same shape; where the two ever disagree, this section wins.
- `me.in_room` is the flag to branch on. `me.present` only says you are somewhere.

#### Moving

- `hall_enter(p_sneak boolean default false)` — unchanged behaviour, and now always places you in the
  Hall (`room_key = 'hall'`). **It is the only way in from outside.** Entering from another room
  stamps `hall_arrived_from` with that room and refreshes `entered_at`. Still refuses without a
  character. Sneak is set on entry and travels with you from room to room.
- `room_move(p_room_key text) → jsonb` — returns the new `room_view` of the destination. Refuses with
  **`Step inside first.`** when not present, and **`You can't get there from here.`** when the room is
  not a live exit of the room you are standing in. Show both verbatim.
- `hall_heartbeat` and `hall_leave` are unchanged apart from also returning/clearing `room_key`; a
  heartbeat never moves you. TTL decay is unchanged, so a closed tab simply stops being anywhere.
- **Returning to the foreground (§3.3 of the iOS request): yes, resume.** Call `hall_enter`, then
  `room_move(lastRoom)` if the member was elsewhere; the backend does not remember a room across an
  expired TTL, so a member whose presence expired starts again in the Hall. Backgrounding past the TTL
  is a departure, not a pause.

#### Gestures are room-scoped

`hall_send_action` succeeds only if sender and recipient are **standing in the same room**. The
refusal is **`They aren't here.`** — use that verbatim; the older "no longer in the hall" wording is
retired for this path. The stranger daily limit and the connection rule are unchanged. The gesture
log (`hall_received_actions`) is **not** room-scoped: a gesture is a message, and it waits for you
wherever you are.

The call returns **both** readings of the sentence (§7.10): `rendered` addresses the recipient,
`rendered_sender` names them for the sender's own story. Compare the payload's `room_key` with the
room you are drawing to confirm the gesture stayed where you were standing.

#### LISTEN

`room_listen() → jsonb`, present members only (`Step inside first.` otherwise):

```jsonc
{ "here": "library",
  "rooms": [ { "key": "hall", "title": "The Authored Hall", "voices": 1, "board_new": 4 } ],
  "way_to_hall": "the door back into the Hall" }
```

Counts, never names — names only come from standing in the room, or LISTEN becomes the same
watch-from-elsewhere loophole the room gate closes. Sneaking members are never counted, and nor is
the caller. The room you are in is omitted. `way_to_hall` is null in the Hall.

#### The board hint and ambience

The exit back to the Hall carries **`board_new`** — the count of your own `posted` quests for the
current week — and nothing else. The client appends its own phrase ("where fresh notices are
pinned"); we do not ship a `hint` string. This hint is about **quests only**, never about people.

Ambience per room follows the standing rule: it is never tied to who is present, so sneak never
becomes a tell.

#### The web room UI (built 2026-11-16)

The web now renders the room model instead of staying in the Hall. Four rules are visible in the
layout, and any client should read them the same way:

- **An "Obvious exits" line** under the room's prose, drawn from `room_view().exits` and shown only
  while `me.present`. Each exit is the label verbatim and walks with `room_move`. The Hall exit
  carries `board_new` as a `N new` chip — the client adds no sentence of its own beyond those two
  words. Nothing on that line counts people.
- **A quiet "You also see …" line** follows the prose, drawn from `room_view().objects` and shown
  only while `me.present` — objects belong to a room you are standing in, so a doorway never lists
  them. Items are joined as *a bench*, *a bench and a lamp*, *a bench, a lamp, and the shelves*; an
  object authored without an article gets `the` in front (the Hall's `board` reads *the board*).
  The sentence is one line of small text, not a list. `objects` stays a plain string array —
  **names unchanged** — and `object_looks` carries what each name says, matched by `name`. An
  object with no matching look renders as plain text rather than a button that would do nothing,
  so a room can gain scenery before it gains prose. The sentence is never counted or clickable
  except for the names themselves.
- **Clicking an object name examines it.** Its line unfolds underneath, one object at a time,
  with a single italic sentence and — when authored — a smaller close-in `detail` beneath it. It
  is a disclosure, not a new call: everything came in the same `room_view` payload. Looking
  away, or walking into another room, closes it. `object_looks` is therefore authored copy, and
  belongs on the server with the rest of the room's words.
- **One object per room is also something you can do, not only look at.** Clicking the name still
  examines it; inside that unfolded panel sits a single verb from `object_actions` — *warm your
  hands* at the snack bar's stove, *sit for a moment* on the garden bench, *trace the coast* in the
  library, *press the corner flat* at the Hall's board. Pressing it calls `room_act` and shows the
  returned `rendered` line beneath the button, in the room's voice. The act is **repeatable**, with
  a short server-enforced pause; the button rests for `cooldown_seconds` and the client counts down
  rather than failing. An object with actions but no `look` is still clickable — the panel exists
  for the verb alone — so a room can gain a small doing before it gains a description.
- **The board is drawn only when `me.in_room` and the room is the Hall.** Standing anywhere else —
  or not standing at all — replaces the board with the doorway panel, which names the room you are
  in, says the board is through the door, and offers the exit back. The doorway repeats the rule in
  words: notices only, never who is inside.
- **LISTEN runs as its own panel**, refreshed every 30 s while the tab is visible and again on every
  room change. Rows show `title` and `voices` only. A row is a door **only when that room appears in
  the current `exits`**; unreachable rooms are listed as counts with no door, so the web never offers
  a walk the server will refuse. `way_to_hall` becomes the quiet button at the foot of the panel.

`present` is only rendered while `me.in_room`, because outside the room the list is empty by design
and an empty human list would read as "nobody is around" rather than "you are not there".

#### Doing something in a room

`room_act(p_object text, p_action_key text) → jsonb`. It finds the act in the room the caller is
**standing in** (never one passed in from outside), so the object name and key must both match that
room's `object_actions` exactly.

```jsonc
{ "ok": true, "room_key": "snack_bar", "object": "a stove", "action_key": "warm",
  "label": "warm your hands", "rendered": "You hold your hands over the back plate…",
  "at": "2026-11-16T20:14:03Z", "cooldown_seconds": 6 }
```

- Success returns `ok: true` and the authored `line` as `rendered` — show it **verbatim**, the
  client never composes it.
- **The pause is a soft refusal, not an error.** Pressing again too soon returns HTTP 200 with
  `{ok: false, message: "You just did that. Give it a moment.", cooldown_seconds, retry_after_seconds}`.
  Render `message` quietly near the button; do not raise it as a failure banner. Disable the verb for
  `cooldown_seconds` (or `retry_after_seconds` when present) so the refusal is rarely seen at all.
- Hard errors, same wording as the rest of the Hall: **`Step inside first.`** when presence has
  lapsed, **`Nothing here does that.`** when the object or key is not in this room's authored acts.
  `Not found` covers a room that is no longer active.
- **Acts are private flavour and are recorded, not published.** `public.room_acts` logs
  `(user_id, room_key, object_name, action_key, rendered, created_at)` with RLS on and **no
  policies**, so the pause is enforced from the ledger and nothing about who warmed their hands is
  readable by anyone else. Acts never touch quests, coins, favors or presence, and must never appear
  in another member's room payload.

#### Open, and not decided here

- **A push when a connection enters** (opt-in, at most once a day per connection, never for a sneaking
  member). Product decision about noise; nothing is built.
- **Room prose varying by time of day or season.** Content, not schema — `rooms.intro`/`rooms.ambience`
  can hold it whenever it is authored.
- `my_quests()` **stays callable outside the Hall** for ME/self views (§3.2 of the request confirmed).
  Only the board — this week, the visitor, history — is Hall-only.