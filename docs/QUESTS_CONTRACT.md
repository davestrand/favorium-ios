<!--
iOS-side copy of the web agent's Quests contract (v1.2), pasted by the user on 2026-11-15.
The authoritative version lives in the web repo. If they differ, the web repo wins;
replace this file when a newer version arrives.
-->

# Quests & characters — backend contract (v1.2, favor integration live)

Authoritative for iOS and Android. Built 2026-11-15 from `QUESTS_WEB_HANDOFF.md`.
**Revised 2026-11-15:** favor integration shipped, read shapes pinned for the app
teams, quest pushes added, action sender labels added. See §7.
**Revised again 2026-11-15:** gestures are **uncapped**, and their push ignores the
quest-toggle; an item is worn by **one character at a time**, and wearing moves it out of
the backpack. See §7.4, §7.8 and §9.
**One-page companion for today's changes:** `APP_HANDOFF_2026-11-15_TRAITS.md` — traits vs
objects, the backpack, and uncapped gestures, with a client checklist. Send that one if you want
the app team to read one page instead of this whole contract.

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
| Character + board on favorium.app | **Mobile only** for 1.1. The web only ever *reads* `character_description()`. |
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
- `my_character() → jsonb` — `{character: {…} | null, shown: [{slot, unlock_id, unlock_key, kind, text}], quest_push: boolean}`
  `character` is the whole `characters` row as JSON, so it always carries
  `id, pronouns, race_key, height_key, build_key, eyes_key, skin_key, hair_color_key,
  hair_length_key` — no more, no fewer. `quest_push` was added 2026-11-15 (§7.5).
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
  arrays.
- `accept_quest(p_user_quest_id) → jsonb`
- `abandon_quest(p_user_quest_id) → jsonb` — refuses while a live favor is attached.
- `quest_settings() → jsonb` — `max_characters`, `board_size`, `rarity_weights`, `visit_grace_days`, `board_push_local_time`, and `action_daily_limit`, which is **deprecated and ignored** (§7.8).
- `set_time_zone(p_tz)` — validated IANA name.
- `set_quest_push(p_enabled)`.

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
- `Not found` — another member's data, a block in either direction, or a dropped unlock.

## 6. Scheduling

`run_quest_schedules()` is idempotent and returns counts. It:
draws each member's board for their current local week, posts live visitors' quests,
marks missed visitor quests `not_taken` at `ends_at`, and expires accepted quests with no
attached favor.

`my_board()` also calls `quest_ensure_current()`, so a member is never dependent on cron
having run — the first read after Monday midnight draws their board. `quest_boards`
(user, week) makes the draw bulletproof against double-running.

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
| `quest_board` | a new week's draw has quests | `Your quests are ready` | `N new quests are on your board this week.` (`1 new quest` for one) |
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

### 7.7 What is still not built

1. **An action attached to a thank-you gem** (`transfer_coin(…, p_action_unlock_id)`)
   — not implemented. The cap conflict that made it undecided is **gone** (§7.8):
   with gestures uncapped, a gem-borne gesture needs no special rule — it is simply
   a gift that arrives with a sentence. It still needs a product yes before anyone
   builds it, so do not build against it yet.
2. **Web reading surface** — a member's description wherever the web shows a person.

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

## Addendum (relayed 2026-11-15, after v1.2): the Monday push hour

The web repo's copy has the full text; this is the summary iOS built against.

- `set_quest_push_hour(p_hour)`: the member's own hour, **7–21**. `null` clears it and
  returns them to the shared default. Out of range raises `Pick an hour between 7 and 21.`
- `my_quest_push_hour()` → `{quest_push_hour, quest_push_hour_is_custom,
  quest_push_default_hour}`. The same three fields come back from `my_character()`
  beside `quest_push`.
- `quest_config.board_push_local_time` is now only the shared fallback (08:00). The
  member's hour wins; both are clamped to 07:00–22:00, so no quest push arrives overnight.
- `not_taken` stays internal: quests nobody accepted just leave the board. Gestures on a
  thank-you gem: **decided against** by the product owner.

