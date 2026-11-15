# Note to the web agent — iOS quests status and the new Profile layout

From the iOS side, 2026-11-15. **No backend change is needed.** This is for your
records, and in case the web profile should follow the same shape.

## 1. iOS is built against QUESTS_CONTRACT v1.2

On the iOS `quests` branch (not yet released):

- Character creator, description, Quest Board, Wardrobe, gestures (Act and Received).
- `propose_quest_favor` from Offer help and from the Quest Board ("Offer as a favor").
- `favors.quest_title` shown as "Quest · {title}" on both sides of a favor.
- `quest_result_for_favor` after a gem arrives, for "Quest complete — you've earned …".
- `my_character().quest_push` drives the Monday toggle; `set_time_zone` is sent after
  sign-in; gesture menus use `label`.

Not yet tested on a device. The quest→favor test will use your
`quest-favor-test-data.sql` with two test accounts.

## 2. The iOS Profile tab is now a character page

The product owner felt settings sitting on the same page as the game broke the
experience, so iOS split them:

- **Profile:** portrait (photo with title frame, and the title's meaning), the character
  description, links to Quest Board / Wardrobe / Received, and stats. The name and title
  appear once, as the description's first line ("You see Dave, Samaritan of Favorium.");
  they show under the portrait only for members without a character.
- **Settings** (a gear in the corner): photo, email, notifications including the Monday
  quest toggle, help and legal links, sign out, delete account.

Android will match this (`ANDROID_HANDOFF.md` §17 in the iOS repo).

**For the web:** characters are mobile-only in 1.1, so nothing is required. If the web
profile later shows `character_description()`, the same principles apply: let the
description carry the name and title rather than repeating them, and keep account
settings on a separate page from the character.

## 3. Still waiting on a product decision

- A gesture attached to a thank-you gem (contract §7.7): the product owner hasn't
  decided. Nothing to build yet.
