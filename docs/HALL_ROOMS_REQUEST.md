# Request to the web agent — Rooms from the start

> **From:** the iOS agent, on behalf of the product owner. **Date:** 2026-11-16.
> **Builds on:** `QUESTS_CONTRACT.md` §10 / §10.6 and the Hall design brief (2026-11-16).
> **Status:** decided by the product owner; needs a contract update before iOS builds against it.

---

## 1. The decision

The Hall is the **first of several rooms**, and the rooms exist from the first release, not later.

- Every member **enters through the Hall**. Their presence then carries a **room key**, and they can
  move from room to room through each room's exits.
- In any room you see **that room's** description and **only the people standing in it**.
- A person is in **at most one room at a time**. Moving into a room takes you out of the one you were in.
- **The quest board lives in the Hall only.** It is an object in that room, not a feature of every room.
  **You cannot read it from anywhere else**, and that includes from outside. Other rooms *hint* that it's
  there, so people walk to the Hall (§2.5).
- **First rooms: the Hall, the Garden, the Library and the Snack Bar.**

iOS has already laid the Hall out as a MUD-style room: prose, *You also see …*, *Also here: …*,
*Obvious exits: …*, plus a story of arrivals, departures and gestures. Rooms slot straight into that
shape: the exits line becomes real links.

---

## 2. What we need from the backend

### 2.1 Presence carries a room

- Presence row gains `room_key` (non-null while present). One row per member, as now.
- `hall_enter(p_sneak boolean default false)` keeps working and always places you in the Hall
  (`room_key = 'hall'`). It is the only way in from outside.
- New: `room_move(p_room_key text)` moves a present member to a room that is an exit of their
  current room. Refuses if not present or if the room isn't reachable from where they stand.
  Suggested refusals, in the house voice: `You can't get there from here.` / `Step inside first.`
- `hall_heartbeat` and `hall_leave` are unchanged; leaving clears presence wherever you are.
- Sneak stays per stay and travels with you from room to room.
- TTL decay is unchanged.

### 2.2 Reading a room

`room_view(p_room_key text default null) → jsonb`. Null means the room I'm standing in, or the Hall if
I'm not present. Server-assembled as `hall_room()` is today:

```jsonc
{
  "key": "hall",
  "title": "The Authored Hall",
  "intro": ["…"],                 // authored, verbatim
  "ambience": ["…"],              // authored, rotated by the client on a timer, as now
  "exits": [ { "key": "garden", "label": "a door to the garden" } ],   // authored link text
  "objects": [ "board" ],          // what "You also see" lists; the board only appears in the hall
  "present": [ /* same person shape as today */ ],   // ONLY people in THIS room, and ONLY if I am in it
  "me": { "present": true, "room_key": "hall", "sneaking": false, "has_character": true },
  "heartbeat_seconds": 45, "presence_ttl_seconds": 150
}
```

- **`present` is empty unless the caller is standing in that room.** Someone outside, or in another
  room, sees nobody. This also closes the loophole we found: today anyone can read who's in the Hall
  from the doorway without their visit being recorded, which undercuts the reason sneak records visits.
- Board data (`quests`, `history`, `visit`, `week_starts_at`, `next_refresh_at`) is **only** in the
  Hall's payload, or behind a separate `hall_board()`, whichever you prefer. Other rooms carry none of it.
- `hall_room()` can stay as an alias for `room_view('hall')` so the current web and iOS builds keep working.

### 2.3 Gestures are room-scoped

`hall_send_action` succeeds only if sender and recipient are **in the same room**. The refusal text
can stay `They are no longer in the hall.` or become `They aren't here.`. Tell us which, and we'll show
it verbatim. The stranger daily limit and the connection rule are unchanged. The gesture log
(`hall_received_actions`) is unchanged and is not room-scoped.

### 2.4 Rooms are content

A `rooms` table (key, title, intro[], ambience[], exits, objects, active, sort), authored server-side
like the catalog. We'll render whatever exists.

**First rooms, decided:** `hall`, `garden`, `library`, `snack_bar`. Suggested layout: the Hall is the
hub, with one exit to each of the other three, and each of those has an exit back to the Hall, so
nobody is ever more than one step from the board. Extra links between the side rooms (say Garden ↔
Snack Bar) are optional. The room prose is yours to author, in the Hall's voice.

### 2.5 The board's hint, and a LISTEN overview

**Board hint.** In every room but the Hall, the exit back to the Hall should be able to say the board
is there, and whether it has anything new. Either authored exit text plus a number, e.g.
`{ "key": "hall", "label": "the door to the Hall", "board_new": 5 }`, so the client can append
*"where fresh notices are pinned"*, or an authored `hint` string you assemble. Your choice; tell us which.
This hint is about **quests only**, never about people.

**LISTEN** (new verb; the product owner asked for an overview so people don't get lost).
`room_listen() → jsonb`, for present members only (it counts as being somewhere):

```jsonc
{
  "here": "library",
  "rooms": [ { "key": "garden", "title": "The Garden", "voices": 3 },
             { "key": "snack_bar", "title": "The Snack Bar", "voices": 1 },
             { "key": "hall", "title": "The Authored Hall", "voices": 0, "board_new": 5 } ],
  "way_to_hall": "the door to the Hall"      // or null when you're in the Hall
}
```

- **Counts, never names.** Names only come from standing in the room. Otherwise LISTEN becomes the
  watch-from-elsewhere loophole that §2.2 closes.
- **Sneaking members are never counted**, and nor is the caller.
- Like ambience, it is not a creak: it's an explicit thing you asked for, and the numbers are the
  same ones you'd get by walking in.

---

## 3. Questions to settle in the contract

1. **The board is not readable from outside: decided.** This replaces the brief's "presence is optional,
   the board is not". Please say what `hall_room()` / `room_view('hall')` returns to someone who isn't
   inside: no `quests`/`history`/`visit`, but perhaps `board_new` so the doorway can hint at it. Members
   without a character can't step inside, so the doorway is where character creation is offered: *make
   your character, and the board is just inside.*
2. **Your own open quests away from the Hall.** Quests you've taken on are carried out through favors,
   anywhere. iOS plans to show *your* open quests in the self view (renamed **ME**; the room is always on
   screen, so a MUD-style LOOK is redundant) in every room. The board itself (this week, the visitor,
   history) stays in the Hall only. Please confirm that `my_quests()` stays callable outside the Hall for this.
3. **Returning to the foreground.** If a member backgrounds the app in the garden and comes back within
   the TTL, do they resume in the garden? (iOS assumes yes: re-enter, then move back to the last room.)
   If presence expired, they start again in the Hall.
4. **Arrivals with direction.** Could `present` entries carry `arrived_from` (room key or null), so the
   story can say *Jo arrives from the garden.*? Optional, but it makes the rooms feel connected.
5. **Ambience per room**, under the same rule: never tied to who is present.

---

## 4. Also raised (from the Hall review)

- **A push when a connection enters** (opt-in, at most once a day per connection, never for sneaking
  members). This is the strongest fix for the empty-room problem. It's a product decision about noise.
- **Room prose that varies by time of day or season**, authored server-side so every app reads the same room.

---

## 5. What iOS will do

- Until the contract lands, the single-room Hall stays as built.
- Once it lands: `HallView` becomes a room view keyed by `room_key`. The exits line moves you between
  rooms with `room_move`, and the exit back to the Hall carries the board hint. The board appears only
  in the Hall and only once you're inside. Verbs become **BOARD** (Hall only) · **LISTEN** · **GESTURE** ·
  **ME** · **SNEAK** · **IN/OUT**. The story notes room changes and, if `arrived_from` exists, where
  people came from.
