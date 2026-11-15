# Quests and characters — design spec

Written 2026-11-14. Status: **design only, nothing built.** The backend is owned by the
web agent (see `ANDROID_HANDOFF.md` §1). §9 is a *request* to relay to them, not a
definition. iOS must not create these tables or RPCs itself.

Inspired by the text descriptions of the MUD GemStone III: when you `LOOK` at someone, you
read a short paragraph built from their chosen features, in a fixed order. Favorium borrows
the idea only. **Don't use GemStone's own races, cultures, item names or wording.**

---

## 1. Decisions so far

- Every member can create a **text-only character**. It's free and optional, available
  from install. There are no images, and avatars and frames stay as they are.
- **Race is chosen once and is permanent** for that character. All races are shown together
  on one screen, never split across quests.
- **v1 has one character per account.** The data model plans for more later (§3).
- **Quests** are opt-in challenges. Each one is completed by doing a matching favor, and the
  person helped thanks you with a gem.
- **Rewards are the thank-you gem and one unlock, nothing more.** An unlock is one of:
  a descriptive term, a piece of clothing, a held item, a hairstyle or an action.
  Quests never mint gems; the gem comes from the person helped, as with any favor.
- Quest deadlines are **optional**, set per quest.
- A personal **Quest Board** gets **5 random quests every Monday**. Members accept as
  many as they like (§6).
- **Visitors** are limited-time events (e.g. a traveling merchant at Hallowe'en) with
  exclusive quests. They **return** on later occasions, so their items are rare but not
  gone forever (§6).
- Members can **drop** anything from their inventory (§5). **No selling**: there is no
  currency, and gems only move through completed favors.
- The character's display shows a **limited number** of worn and held items. Everything
  else stays in an **inventory**. **Actions can be used any time.**
- Descriptive terms can be playful or dark ("menacing") because **you earn and choose
  them yourself**. Nobody tags anyone else.

---

## 2. What others see

The description is the character's `LOOK`. It appears on the owner's Profile tab and on
another person's profile (reached from the Connect circle and from favor detail).

```
You see Dave, Saint of Favorium.
He appears to be a menacing orc.
He is short and has a sturdy build.
He has hazel eyes and ruddy skin. He has shoulder-length chestnut hair braided into a crown.
He is known to be strong and courteous.
He is wearing a moss-green traveling cloak with silver clasps.
He is holding a slender rowan wand that smells faintly of rain.
```

### Sentence order (fixed, and lines are skipped when empty)

| # | Line | Source |
|---|---|---|
| 1 | `You see <name>[, <title> of Favorium].` | Display name + helper title (`HelperTitles.swift`) |
| 2 | `<P> appear(s) to be <a/an> [<look term>] <race>.` | Character race + one shown look term |
| 3 | `<P> <is/are> <height> and <has/have> a <build> build.` | Appearance |
| 4 | `<P> <has/have> <eyes> eyes and <skin> skin. <P> <has/have> <length> <hair color> hair[ <hairstyle>].` | Appearance + shown hairstyle |
| 5 | `<P> <is/are> known to be <rep term>[ and <rep term>].` | Up to 2 shown reputation terms |
| 6 | `<P> <is/are> wearing <item>[, <item>] and <item>.` | Worn slots (§5) |
| 7 | `<P> <is/are> holding <item>.` | Held slot |

Grammar rules every client must follow (or the server does it, see §9):

- **Pronouns:** he / she / they. *They* takes plural verbs ("They appear", "They are",
  "They have"). Without a character, line 1 is the whole description.
- **Articles:** "a" / "an" go with the *first word that follows* ("an orc", "a menacing
  orc", "an ancient elf").
- **Lists:** two items are joined with "and"; three or more use commas, then "and" before
  the last.
- A line whose parts are all unset is omitted. Never print "unknown" or blanks.

---

## 3. Characters

### v1

- One character per account, created from Profile ("Create your character") or from a
  card after sign-up. It can be skipped and done later.
- Required: name source (the profile display name), **pronouns**, **race**.
  Everything else is optional.
- Race can't be changed after saving. Show it clearly before confirming:
  "Your race is permanent. Choose the one that feels like you."
- Appearance (height, build, eyes, skin, hair color, hair length) **can** be edited any
  time. Only race is locked.

### Planned for later: multiple characters

The model already allows it:

- `characters` belong to a user and have their own `id`. Exactly one is `is_active`.
- **Unlocks belong to the account, not to a character.** Favors are done by the real
  person, so every character can use everything that person earned.
- What a character **shows** (worn and held items, shown terms, hairstyle) is stored per
  character.
- Others always see the **active** character.
- A server setting `max_characters` (v1 = 1) gates creating another one, so the iOS UI
  can turn the feature on without a migration.

---

## 4. Character-creation vocabulary (free for everyone)

These are first drafts; the server catalog (§9) is the source of truth. Every entry has a
stable `key` (never renamed) and a display `text`.

**Races** (each shown with a one-line flavor text):

| key | text | flavor |
|---|---|---|
| `human` | human | Restless, curious, at home anywhere. |
| `elf` | elf | Long-lived and unhurried, with a memory for kindness. |
| `half_elf` | half-elf | Belonging to two peoples, welcomed by both. |
| `dwarf` | dwarf | Stubborn as stone and twice as dependable. |
| `halfling` | halfling | Small, cheerful, and never far from a second breakfast. |
| `gnome` | gnome | Tinkerer, gardener, keeper of odd little secrets. |
| `orc` | orc | Fierce in looks, fiercer in loyalty. |
| `half_orc` | half-orc | Strong hands, soft heart. |
| `giantkin` | giantkin | Gentle, enormous, and careful where they step. |
| `sprite` | sprite | Quick and bright, rarely seen standing still. |

**Height:** very short, short, of average height, tall, very tall
(the line becomes "He is tall" or "He is of average height").
**Build:** slender, wiry, lithe, sturdy, stocky, broad-shouldered, soft, rangy
**Eyes:** brown, dark brown, hazel, green, grey, blue, ice-blue, amber, violet, black, mismatched
**Skin:** pale, fair, freckled, olive, golden, tan, ruddy, brown, deep brown, ebony,
plus fantasy tones: moss-green, ash-grey, moon-pale, bark-brown (offered to every race)
**Hair color:** black, raven, dark brown, chestnut, auburn, copper, red, golden, blond,
flaxen, silver, white, grey, plus fantasy shades: moss-green, midnight-blue, rose
**Hair length:** shaved, cropped, short, chin-length, shoulder-length, long, waist-length

Pronouns are separate from appearance and don't limit any choice.

---

## 5. Unlocks (earned only from quests)

| Kind | Shown how | Limit on the description |
|---|---|---|
| **Look term** | Before the race (line 2) | 1 shown |
| **Reputation term** | "known to be…" (line 5) | 2 shown |
| **Clothing** | "wearing…" (line 6) | 1 per slot: `outer`, `head`, `accessory` |
| **Held item** | "holding…" (line 7) | 1 (`held` slot) |
| **Hairstyle** | After the hair (line 4) | 1 |
| **Action** | Used on people (§7), never in the description | Use any time |

Everything earned but not shown stays in **Inventory** (a Profile screen): terms, clothing,
held items, hairstyles and actions, each with the quest it came from and the date
(and the visitor, if any).

**Dropping.** Anything in the inventory can be **dropped** to keep it tidy. Confirm first
("Drop the moss-green traveling cloak? You can earn it again if its quest comes back.").
A shown unlock is unshown when dropped. A dropped unlock can be re-earned when its quest
is posted again (weekly board, or the visitor's next visit). **There is no selling**:
there is no currency, and gems only move through completed favors.

**Starter examples:**

- Look terms: menacing, merry, moonlit, weathered, radiant, wild-eyed, serene, brooding
- Reputation terms: strong, courteous, wise, patient, generous, brave, steady, kind-hearted
- Clothing: *a moss-green traveling cloak with silver clasps* (outer),
  *a wide-brimmed hat with a single crow feather* (head),
  *a braided cord bracelet strung with river stones* (accessory)
- Held: *a slender rowan wand that smells faintly of rain*,
  *a gnarled oak staff wound with ivy*,
  *a short sword in a battered leather sheath*,
  *a lantern of moonsilver that never quite goes out*
- Hairstyles: braided into a crown, swept back in a loose tail, wild and windblown,
  tied with a green ribbon, in a crest of spikes
- Actions: cracks his knuckles, bows respectfully, tips her hat, grins wolfishly,
  offers a firm handshake, hums a little tune, salutes smartly

Actions have **pronoun forms** (`cracks his/her/their knuckles`). Store them as templates
with a `{pos}` placeholder (`cracks {pos} knuckles`).

**Rarity** (`common`, `uncommon`, `rare`) is a label in the inventory, and decides how
often a quest offering that item appears. It has no other effect.

---

## 6. Quests

### The weekly Quest Board

- Every member has a personal **Quest Board**. **Every Monday** (local time) the server
  posts **5 quests** drawn at random from the large pool. Monday starts the work week,
  so favors happen during the week rather than on the weekend.
- The draw is weighted by rarity (draft: common 70%, uncommon 25%, rare 5%) and **skips
  quests whose unlock the member already owns**.
- **Accept as many as you like.** There's no cap.
- Quests not accepted **leave the board at the next Monday refresh**. Accepted quests stay
  until completed, abandoned or past their own deadline.
- A new member gets a first board **right after creating their character**, without
  waiting for Monday.
- **Push, after opt-in only:** one push each Monday, *"New quests are posted on your
  board."* There's no push per quest. The first time, the board is introduced with an
  **in-app card** with "Yes, tell me on Mondays". Apple's rules don't allow promotional
  pushes without opt-in.

### Visitors (limited-time events)

- A **visitor** is an event with fixed start and end dates, the same for everyone:
  *"A traveling merchant has come to town. Leaves in 6 days."*
- It appears in its own section at the top of the board, with a countdown. Its quests and
  unlocks **never appear in the weekly pool**. That's what makes them rare.
- **Visitors come back.** An event recurs (yearly, or whenever its theme fits, e.g. a
  rain-themed visitor in a wet week). Its unlocks can be earned again then. If you see
  someone holding an umbrella, you wait for the next rain visitor to get one.
- **Grace period:** an event quest accepted during the visit can be completed until
  **7 days after the visitor leaves** (server setting). Completion depends on someone
  else giving a gem, and gems rest 24h.
- Each unlock records its **provenance**: *"From the traveling merchant, Hallowe'en 2026."*
- Pushes (opt-in): one when a visitor arrives, and optionally one a day before it leaves.
- Drafts: traveling merchant (Hallowe'en), lantern-maker (winter solstice), seed-seller
  (spring), rain-singer (rainy season), wandering bard (Favorium's anniversary).

### Lifecycle

```
posted → accepted → (favor proposed with quest attached) → completed
       ↘ not taken (next Monday)   ↘ expired (deadline / grace ended)   ↘ abandoned
```

1. **Posted.** On the weekly board, or by a visitor.
   Copy: *"Help one person carry something heavy. Reward: the gem they thank you with,
   and the word* strong. *Do you accept?"*
2. **Accepted.** Accepting does nothing visible to anyone else.
3. **Doing it.** When the helper offers a favor (`OfferHelpView`), they can attach an
   accepted quest, which pre-fills the description ("Carry something heavy"). What the
   helped person sees about the quest is an open question (§10).
4. **Completed.** When the helped person gives the gem (`transfer_coin`) for that favor,
   the server grants the unlock to the helper. The helper sees the usual "A gem arrived"
   celebration plus "Quest complete — you are now known to be **strong**."
   A favor that's cancelled or declined frees the quest to be attached again.
5. **Expired.** If the quest has a deadline (`expires_at`) and no attached favor has been
   completed by then, the quest ends. No penalty.

### Rules

- **No limit** on accepted quests.
- You can't hold two copies of an unlock. A quest whose unlock you already own isn't
  posted to your board. If you **dropped** it (§5), it can be posted and earned again.
- One favor can complete **one** quest.
- Only the gem confirms a quest. There's no self-reporting and no "mark done" (keep to
  `ANDROID_HANDOFF.md` §11).
- The helped person must be a pairing connection, as with any favor.

### First batch (draft)

| Quest | Unlock |
|---|---|
| Carry something heavy for someone | reputation: *strong* |
| Hold a door or let someone go first | reputation: *courteous* |
| Tell someone a scary story | look: *menacing* |
| Make someone laugh out loud | look: *merry* |
| Teach someone something you know | reputation: *wise* |
| Help someone outdoors after dark | look: *moonlit* |
| Wait with someone who's waiting | reputation: *patient* |
| Help someone with their garden | hairstyle: *tied with a green ribbon* |
| Help someone get ready for a trip | clothing: *a moss-green traveling cloak with silver clasps* |
| Fix something that was broken | action: *cracks {pos} knuckles* |
| Welcome someone new | action: *bows respectfully* |
| Help someone through a hard day (rare) | held: *a lantern of moonsilver that never quite goes out* |

---

## 7. Actions

Text only. An action is sent **to a person in your circle**:

- From their profile: an **Act** button, then pick an action.
- When giving a gem: optionally attach one. It shows on their celebration as
  "Dave cracks his knuckles and hands you a gem."

The other person gets an in-app note (and a push if they allow it):
*"Dave bows respectfully to you."*

Safety: circle only, blocked people can't send actions either way, and there's a daily
limit per sender → recipient (server setting, e.g. 5). Actions are fixed text, so no
moderation of content is needed. Report and block still work on the sender.

---

## 8. iOS screens (built)

The Profile tab became a character page with settings behind a gear. The full layout,
for Android parity, is in `ANDROID_HANDOFF.md` §17.

| Screen | Where | What |
|---|---|---|
| Character card | Profile | Description, Quest Board / Wardrobe / Received links, Change appearance |
| Character creator | Profile ("Begin" / "Change appearance") | Pronouns, race (all at once, permanent), appearance |
| Another member's character | Connect circle menu → View character | Their description, Act menu |
| Quest Board | Profile → Quest Board | Visitor, this week, still open, completed, Monday toggle, Offer as a favor |
| Wardrobe | Profile → Wardrobe | Slots; backpack, wearing, traits, gestures; drop |
| Offer help | Favors → Offer a favor, or Quest Board | "Carry a quest?" picker; prompt locked |
| Settings | Profile → gear | Photo, email, notifications (incl. Monday quests), help and legal, sign out, delete |

---|---|---|
| Character creator | Profile + post-sign-up card | Pronouns, race (all at once, permanent), appearance |
| Character description | Profile, other person's profile | Rendered `LOOK` text |
| Wardrobe / Inventory | Profile | Choose shown terms, slots, hairstyle; see everything earned |
| Quests | Profile (or a Favors section) | Offered / accepted / completed, deadline countdowns |
| Quest offer | In-app card, push | Accept / decline |
| Offer help | Existing `OfferHelpView` | "Attach a quest" picker |
| Act | Other person's profile, `SendGemView` | Pick an action |

---

## 9. Request for the web agent (backend)

To relay to the web agent. Names are suggestions; their contract is authoritative.
**The full handoff is `docs/QUESTS_WEB_HANDOFF.md`**: schema, RPCs, jobs, rendering
rules and pushes. The list below is a summary.

**Catalog** (server-owned, read by every client):
- `catalog_entries(key, kind, text, flavor, slot, rarity, sort)` where `kind` is one of
  race, height, build, eyes, skin, hair_color, hair_length, look_term, rep_term,
  clothing, held, hairstyle, action. Keys are stable forever.

**Characters:**
- `characters(id, user_id, is_active, pronouns, race_key, height_key, build_key,
  eyes_key, skin_key, hair_color_key, hair_length_key, hairstyle_key, created_at)`.
  `race_key` can't be updated once set.
- `character_shown(character_id, kind, slot, unlock_key)`: what's displayed.
- Setting `max_characters` (1 for v1).

**Unlocks:**
- `user_unlocks(user_id, unlock_key, quest_id, visitor_id, earned_at, dropped_at)`,
  account-level. Dropping sets `dropped_at` (keep the row for history) and clears it from
  `character_shown`. Re-earning creates a new row.

**Quests:**
- `quests(id, title, prompt, unlock_key, rarity, visitor_id, active)`. Quests with a
  `visitor_id` are only posted during that visitor's visits, never in the weekly draw.
- `visitors(id, key, name, intro)` and `visits(id, visitor_id, starts_at, ends_at,
  grace_ends_at)`. A visitor returns by adding another `visits` row.
- `user_quests(id, user_id, quest_id, visit_id, status, posted_at, accepted_at,
  expires_at, completed_at, favor_id)`. Status: posted, accepted, completed, not_taken,
  expired, abandoned.
- **Weekly job:** every Monday 00:00 in each member's local time, mark untaken `posted`
  rows `not_taken` and post 5 new quests (weighted by rarity, skipping unlocks the member
  holds and not dropped). Also post a first board on `create_character`.
- Needs the member's time zone: `profiles.time_zone` (IANA name), sent by the app, e.g.
  `set_time_zone(p_tz)` on launch.
- `favors.quest_id` (nullable), set through `propose_favor(..., p_user_quest_id)`.
- On `transfer_coin` for a favor with a quest: complete the quest and grant the unlock,
  in the same transaction.
- Settings: `board_size` (5), rarity weights, `visit_grace_days` (7), action daily limit.
  No accepted-quest cap.

**RPCs:**
- `create_character(...)`, `update_character_appearance(...)`
- `set_shown(...)`
- `character_description(p_user_id)`: returns the rendered lines (§2). **Recommended:**
  render on the server so iOS, web and Android always match word for word.
- `my_board()` (this week's posts + current visitor and its quests), `my_quests()`
  (accepted and history)
- `accept_quest(p_user_quest_id)`, `abandon_quest(p_user_quest_id)`
- `my_inventory()`, `drop_unlock(p_unlock_id)`
- `send_action(p_to_user_id, p_action_key)`, `my_actions_received()`
- `set_quest_push(p_enabled)`

**Pushes (PUSH_CONTRACT):** `quest_board` (Mondays, ~8:00 local, opt-in only),
`visitor_arrived`, `visitor_leaving` (opt-in only), `quest_complete`, `action`, all with
`route: profile`.

Pausing an account (§19) should also block sending actions and accepting quests.

---

## 10. Open questions

To be settled by the user with the web agent (also listed in the handoff, §9):

- What does the helped person see on a favor with a quest attached: the title, a
  "Quest" label, or nothing?
- Can unlocks be **given** to a friend?
- Should the description also appear on the **web** profile at launch?
- Should there be a Quest Log history ("Completed: Carry something heavy, 12 Nov")?
