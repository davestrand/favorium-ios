# Quests and characters — backend handoff for the web agent

Written 2026-11-14 by the iOS side, for the web agent that owns the Favorium backend
(Supabase: Postgres, RPCs, Edge Functions, Storage). **Nothing here exists yet.** This is
a request, not a definition. Names and shapes are suggestions. Once you've built it, your
`IOS_CONTRACT.md` section is authoritative and iOS will follow it.

The product reasoning, copy and vocabulary drafts are in `docs/QUESTS.md` (iOS repo).
This file is the backend-facing version and should stand on its own.

---

## 1. The feature in one paragraph

Every member can create a **text-only character**: pronouns, a **permanent race** and an
appearance. Others read it as a short generated description, like a MUD's `LOOK`. Every
Monday each member's personal **Quest Board** gets 5 random quests. A quest is completed by
doing a matching **favor** through the existing favor flow. When the helped person **gives
the gem** for that favor, the helper earns the quest's **unlock**: a descriptive term,
clothing, a held item, a hairstyle or an action (a short emote sent to someone).
Limited-time **visitors** (e.g. a Hallowe'en merchant) post exclusive quests and come back
on later occasions. Unlocks can be shown on the character, kept in an inventory, or
**dropped**. There is no currency and no selling.

---

## 2. Rules that must hold server-side

1. **Quests never mint gems.** The only gem involved is the normal thank-you gem from the
   helped person via `transfer_coin`. Gem economy rules are unchanged.
2. **Only the gem completes a quest.** No self-reporting, no "mark done", no disputes.
3. **Race is permanent** per character. Updating `race_key` once set must fail.
4. **v1: one character per account**, enforced by a setting `max_characters = 1`. The
   schema must already support more than one (see §3).
5. **Unlocks belong to the account**, not the character. What's *shown* belongs to the
   character.
6. **No duplicate unlocks:** at most one *held* (not dropped) row per user per unlock key.
7. **No cap** on accepted quests.
8. **One favor completes at most one quest.**
9. **All character text is fixed vocabulary.** No free text, so there's nothing new to
   moderate. The display name is the existing profile name.
10. **Pause (IOS_CONTRACT §19)** also blocks: accepting quests, attaching quests to favors
    (already blocked via proposing) and sending actions. It does not block viewing, editing
    appearance, or dropping.
11. **Blocks** apply both ways to actions and to viewing each other's description.

---

## 3. Schema (suggested)

### Catalog

```
catalog_entries
  key          text primary key        -- stable forever, never renamed or reused
  kind         text not null           -- race | height | build | eyes | skin | hair_color |
                                       -- hair_length | look_term | rep_term | clothing |
                                       -- held | hairstyle | action
  text         text not null           -- "orc", "a slender rowan wand…", "cracks {pos} knuckles"
  flavor       text                    -- races: one-line description for the picker
  slot         text                    -- clothing: outer | head | accessory; held: held
  rarity       text                    -- unlocks only: common | uncommon | rare
  article      text                    -- optional override: 'a' | 'an' (see §6)
  sort         int not null default 0
  active       boolean not null default true
```

Appearance kinds (race … hair_length) are **free for everyone**. Unlock kinds (look_term …
action) are only obtainable through quests. Readable by any authenticated user.

### Characters

```
characters
  id              uuid primary key
  user_id         uuid not null references profiles
  is_active       boolean not null
  pronouns        text not null          -- he | she | they
  race_key        text not null references catalog_entries   -- immutable after insert
  height_key, build_key, eyes_key, skin_key,
  hair_color_key, hair_length_key        text null references catalog_entries
  created_at      timestamptz not null default now()
  unique (user_id) where is_active       -- exactly one active character

character_shown
  character_id    uuid references characters on delete cascade
  slot            text not null          -- look | rep_1 | rep_2 | hairstyle |
                                         -- outer | head | accessory | held
  unlock_id       uuid not null references user_unlocks
  primary key (character_id, slot)
```

Validate in `set_shown`: the unlock's kind fits the slot, it belongs to the caller, and
it isn't dropped. `rep_1` and `rep_2` can't hold the same unlock.

### Unlocks

```
user_unlocks
  id            uuid primary key
  user_id       uuid not null
  unlock_key    text not null references catalog_entries
  quest_id      uuid references quests
  visit_id      uuid references visits   -- provenance, null for weekly quests
  favor_id      uuid references favors   -- the favor that earned it
  earned_at     timestamptz not null default now()
  dropped_at    timestamptz
  unique (user_id, unlock_key) where dropped_at is null
```

Dropping sets `dropped_at` and deletes any `character_shown` rows pointing at it. Keep
the row for history. Re-earning inserts a new row.

### Quests and visitors

```
quests
  id           uuid primary key
  key          text unique not null
  title        text not null              -- "Carry something heavy"
  prompt       text not null              -- "Help one person carry something heavy."
  unlock_key   text not null references catalog_entries
  rarity       text not null              -- common | uncommon | rare (draw weight)
  visitor_id   uuid references visitors   -- null = weekly pool; set = visitor-only
  deadline_days int                        -- optional: accepted quest expires after N days
  active       boolean not null default true

visitors
  id     uuid primary key
  key    text unique not null             -- traveling_merchant
  name   text not null                    -- "A traveling merchant"
  intro  text not null                    -- "has come to town."

visits
  id             uuid primary key
  visitor_id     uuid not null references visitors
  label          text not null            -- "Hallowe'en 2026" (shown as provenance)
  starts_at      timestamptz not null
  ends_at        timestamptz not null
  grace_ends_at  timestamptz not null     -- default ends_at + visit_grace_days
```

A visitor **returns** by adding another `visits` row. Its quests are posted again and
their unlocks can be earned again (except by members already holding them).

```
user_quests
  id            uuid primary key
  user_id       uuid not null
  quest_id      uuid not null references quests
  visit_id      uuid references visits
  status        text not null   -- posted | accepted | completed | not_taken |
                                --   expired | abandoned
  posted_at     timestamptz not null
  accepted_at   timestamptz
  expires_at    timestamptz     -- set on accept: min(now()+deadline_days, grace_ends_at)
  completed_at  timestamptz
  favor_id      uuid references favors    -- the favor currently attached, if any
```

### Changes to existing tables

- `favors.user_quest_id uuid null references user_quests`.
- `profiles.time_zone text` (IANA, e.g. `America/Chicago`). The app will send it.
- `profiles.quest_push boolean not null default false`. Opt-in for Monday/visitor pushes.

### Settings

Expose through a read RPC (`quest_settings()`, or a `quests` key inside
`gem_economy_settings()`, whichever you prefer):

| Setting | Draft value |
|---|---|
| `max_characters` | 1 |
| `board_size` | 5 |
| `rarity_weights` | common 70, uncommon 25, rare 5 |
| `visit_grace_days` | 7 |
| `action_daily_limit` | 5 per sender → recipient per rolling 24h |
| `board_push_local_time` | 08:00 |

---

## 4. RPCs (suggested)

Errors: raise readable messages. iOS shows server error text verbatim (existing
convention). Guard failures that would reveal another user's data should say
"Not found", as favors do today.

### Catalog and characters

| RPC | Who | Does | Returns |
|---|---|---|---|
| `catalog()` | any | All active catalog entries | rows of `catalog_entries` |
| `create_character(p_pronouns, p_race_key, p_height_key, p_build_key, p_eyes_key, p_skin_key, p_hair_color_key, p_hair_length_key)` | self | Creates the character (active). Fails if at `max_characters`. Posts the member's **first board** (§5). | the character row |
| `update_character_appearance(p_character_id, …same minus race)` | owner | Updates appearance and pronouns. Race can't be passed. | the character row |
| `set_shown(p_character_id, p_slot, p_unlock_id)` | owner | Shows an unlock in a slot; `p_unlock_id = null` clears it | the character's shown rows |
| `my_character()` | self | Active character + shown rows | row(s) |
| `character_description(p_user_id)` | any, unless blocked either way | Rendered lines (§6) for that user's active character | `text[]` |

**`character_description` should render on the server** so iOS, web and Android read
word for word the same. For a user with no character it returns just line 1
("You see Dave."). Deleted or blocked users: "Not found".

### Board and quests

| RPC | Who | Does | Returns |
|---|---|---|---|
| `my_board()` | self | This week's `posted` and `accepted` weekly quests, plus the current visit (if any) with its quests for this member | `{week_starts_at, next_refresh_at, quests[], visit: {visitor name, intro, label, ends_at, grace_ends_at, quests[]} \| null}` |
| `my_quests()` | self | Accepted quests, plus history (completed / expired / abandoned) | rows joined with quest + unlock text |
| `accept_quest(p_user_quest_id)` | owner | `posted` → `accepted`, sets `expires_at` | row |
| `abandon_quest(p_user_quest_id)` | owner | `accepted` → `abandoned`. Fails if attached to a live favor. | row |
| `set_time_zone(p_tz)` | self | Validates an IANA name and stores it | — |
| `set_quest_push(p_enabled)` | self | Opt in or out of Monday and visitor pushes | — |

Each quest in a response should carry: `user_quest_id, status, title, prompt,
unlock {key, kind, text, rarity}, expires_at, favor_id`.

### Inventory

| RPC | Who | Does | Returns |
|---|---|---|---|
| `my_inventory()` | self | Held (not dropped) unlocks with provenance: quest title, visit label, earned_at, and which slot shows it, if any | rows |
| `drop_unlock(p_unlock_id)` | owner | Sets `dropped_at`, unshows it | — |

### Actions

| RPC | Who | Does | Returns |
|---|---|---|---|
| `send_action(p_to_user_id, p_action_unlock_id)` | sender | Sender must hold the action (not dropped), be **connected** (pairing `connections`) to the recipient, not blocked either way, not paused, and under `action_daily_limit`. Stores it and pushes the recipient. | `{rendered}` e.g. "Dave bows respectfully to you." |
| `my_actions_received()` | self | Recent actions received, newest first | rows `{from_user_id, from_name, rendered, created_at}` |

Table: `actions_sent(id, from_user_id, to_user_id, unlock_key, created_at)`.

`transfer_coin` gains an optional `p_action_unlock_id`. When set, it's validated the
same way, and the gem celebration can read "Dave cracks his knuckles and hands you a gem."
**This may be postponed** if it complicates `transfer_coin`. Say so and iOS will ship
without it.

### Changes to existing favor RPCs

- `propose_favor(p_helped_id, p_description, p_user_quest_id default null)`:
  - the quest must be the caller's, `accepted`, not expired, with no live favor attached.
  - Set `favors.user_quest_id` and `user_quests.favor_id`.
- `respond_to_favor(..., false)` (declined), `cancel_favor`, and blocking/pausing that
  cancels favors: **detach** the quest (`user_quests.favor_id = null`). It stays
  `accepted` and can be attached again.
- `transfer_coin` on a favor with `user_quest_id`: **in the same transaction**,
  - mark the quest `completed`,
  - insert the `user_unlocks` row (with quest, visit and favor provenance),
  - send the helper a `quest_complete` push.
  - If the helper already holds that unlock (possible if they earned it another way in
    between), complete the quest anyway and grant nothing.
- `favors` reads: include `user_quest_id` and the quest `title`, so both sides can show
  it. **How much the helped person sees is an open question (§9).**

---

## 5. Scheduled jobs

Run hourly. Each step must be **idempotent** (safe to run twice).

1. **Weekly board** (for each member whose local time just passed **Monday 00:00**; null
   time zone: use UTC):
   - `posted` weekly quests from the previous week → `not_taken`.
   - Draw `board_size` active weekly-pool quests (`visitor_id is null`), weighted by
     `rarity_weights`. Exclude quests whose unlock the member holds (not dropped), quests
     they currently have `accepted`, and duplicates within the draw.
   - Insert them as `posted`.
   - If the pool runs dry for that member, post fewer. Never repeat.
   - Only for members **with a character**. Skip paused and deleted members.
2. **First board:** the same draw, run inside `create_character`.
3. **Visits:**
   - when a visit starts, post its quests to every member with a character, skipping
     unlocks they hold;
   - members who create a character during a visit get them too.
   - Unaccepted visitor quests → `not_taken` at `ends_at`.
4. **Expiry:** `accepted` quests past `expires_at` with no attached favor → `expired`.
   If a favor *is* attached at expiry, let it finish. Completing it still grants the
   unlock.
5. **Pushes** (only to `quest_push = true`):
   - `quest_board`: Monday at `board_push_local_time` local.
   - `visitor_arrived`: at visit start, at a sensible local hour.
   - `visitor_leaving`: about 24h before `ends_at`.

---

## 6. Rendering the description

Output is an array of lines, in this order. **Omit a line when all its parts are unset.**
`<P>` is the pronoun subject (He / She / They), capitalised at the start of a sentence.

| # | Line | Notes |
|---|---|---|
| 1 | `You see <name>, <Title> of Favorium.` | Title from `helper_level` (Samaritan, Saint, Angel, Seraph, Bodhisattva). No title: `You see <name>.` Always present. |
| 2 | `<P> appear(s) to be <a/an> [<look>] <race>.` | `look` = shown `look` slot |
| 3 | `<P> is/are <height> and has/have a <build> build.` | Only height: `<P> is tall.` Only build: `<P> has a sturdy build.` |
| 4a | `<P> has/have <eyes> eyes and <skin> skin.` | Either half alone is fine: `He has hazel eyes.` |
| 4b | `<P> has/have <length> <hair color> hair[ <hairstyle>].` | `shaved` length: `<P> has a shaved head.` (hair color ignored, hairstyle ignored). Only hairstyle: `<P> has hair <hairstyle>.` |
| 5 | `<P> is/are known to be <rep_1>[ and <rep_2>].` | |
| 6 | `<P> is/are wearing <list>.` | Order: outer, head, accessory |
| 7 | `<P> is/are holding <held>.` | |

Lines 4a and 4b are one paragraph line, joined with a space.

**Verbs:** he/she → appears, is, has. they → appear, are, have.
**Possessive** (actions): his / her / their, substituted for `{pos}`.
**Article:** `an` when the next word starts with a vowel letter, else `a`. The catalog
`article` column overrides this for exceptions (e.g. a word starting with "u" pronounced
"you"). It applies to the first word after the article: `an orc`, `a menacing orc`,
`an ancient elf`.
**Lists:** `A`; `A and B`; `A, B and C` (no Oxford comma).
**Item texts** already include their own article ("a moss-green traveling cloak…").

**Actions render as** `<sender name> <action text with {pos} for the sender's pronouns>
to you.` For example: "Dave bows respectfully to you." / "Dave cracks his knuckles."
Actions whose text doesn't take an object (`cracks {pos} knuckles`) shouldn't get
"to you". Add a catalog flag `directed boolean` to control it.

Worked example:

```
You see Dave, Saint of Favorium.
He appears to be a menacing orc.
He is short and has a sturdy build.
He has hazel eyes and ruddy skin. He has shoulder-length chestnut hair braided into a crown.
He is known to be strong and courteous.
He is wearing a moss-green traveling cloak with silver clasps.
He is holding a slender rowan wand that smells faintly of rain.
```

---

## 7. Pushes (for PUSH_CONTRACT)

All existing payload conventions apply: `kind`, `route`. iOS routes `profile` to the
Profile tab, where the board, inventory and character live.

| kind | When | Draft copy | Opt-in |
|---|---|---|---|
| `quest_board` | Monday ~08:00 local | "New quests are posted on your board." | `quest_push` |
| `visitor_arrived` | Visit starts | "A traveling merchant has come to town." (`name` + `intro`) | `quest_push` |
| `visitor_leaving` | ~24h before end | "The traveling merchant leaves tomorrow." | `quest_push` |
| `quest_complete` | `transfer_coin` completes a quest | "Quest complete — you are now known to be strong." | normal pushes |
| `action` | `send_action` | "Dave bows respectfully to you." | normal pushes |

Extra payload keys: `userQuestId` (quest_complete), `fromUserId` (action).

`quest_board` and the visitor pushes are promotional under Apple's rules. They **must
not** be sent without `quest_push = true`. The iOS app asks with an in-app card first.

---

## 8. Seed content

- Starter vocabulary (10 races, appearance words, terms, clothing, held items,
  hairstyles, actions) and the first 12 quests are drafted in `docs/QUESTS.md` §4–§6.
  Adjust freely, but **keys are permanent once shipped**.
- Don't use GemStone (the MUD that inspired this) races, cultures or item names.
- First visitor drafts: traveling merchant (Hallowe'en), lantern-maker (winter
  solstice), seed-seller (spring), rain-singer (rainy weeks), wandering bard (Favorium's
  anniversary).

---

## 9. Open questions — for the user and the web agent to settle

The iOS side has not decided these. Please work them out with the user and record the
answers in the contract:

1. **What does the helped person see** on a favor with a quest attached: the quest's
   title, just a "Quest" label, or nothing?
2. **Giving unlocks to friends**: allowed or not?
3. **Web profile**: does the character description appear on favorium.app at launch?
4. **Quest log**: is there a visible history of completed quests (and on whose profile)?

---

## 10. What iOS needs back

When it's built, please send (or add to IOS_CONTRACT):

- final RPC names, parameters and return shapes;
- error message texts the app may branch on (as with "Gem is resting —");
- the settings RPC;
- push kinds and payloads;
- answers to §9;
- a test account with a character, a few unlocks and an active board. Ideally also a
  test visit that can be switched on.
