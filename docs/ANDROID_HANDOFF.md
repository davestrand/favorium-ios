# Favorium for Android — handoff from the iOS app

Written 2026-10-24, from the iOS app as submitted for App Store review (tag `v1.0`,
repo github.com/davestrand/favorium-ios). This document is for the agent building the
Android version. It covers what the app is, how it talks to the backend, the rules that
aren't obvious from the code, and the decisions already made (including features that
were tried and removed).

**Goal: feature parity with iOS 1.0, same backend, same copy.** The iOS source is the
reference implementation; file names below point into `favorium/` in that repo.

---

## 1. Who owns what

- **Backend** (Supabase: Postgres, RPCs, Edge Functions, Storage) is owned by a separate
  "web" agent. Its authoritative docs, `IOS_CONTRACT.md` and `src/crystal/PUSH_CONTRACT.md`,
  live in the **web repo**. Ask the user for them, or ask the web agent for an Android
  contract. **Never redefine backend functions from the app side**; draft a request for
  the user to relay instead.
- **Web app** exists at favorium.app and shares the backend. Accounts work on both.
- **iOS** is SwiftUI, iOS 26.2+, iPhone-only, portrait-only.

Everything the server enforces (who may call what, cooldowns, limits) stays server-side.
The app only mirrors rules for display, and always shows server error text verbatim.

---

## 2. The product in one paragraph

People pair **in person** with a short code or QR. Once paired, one person can **offer a
favor** to the other. The other **accepts**, then later **marks it complete**, then **gives
a gem** from their collection as thanks. Gems are one-of-a-kind (generated from DNA), keep
a **journey** of everyone who has held them, and gain **tier** as they change hands. You can
**follow your original gems** after they leave you ("watch favors from afar"). Long-press a
gem to **step inside** it: a tilt-steered kaleidoscope. Helpers earn **titles** by the number
of distinct people they've helped. Angels and above can **engrave** a short unsigned secret
inside a gem.

---

## 3. Screens (iOS file → what it does)

Root: `ContentView.swift`. AuthView until signed in, then three tabs: **Collection**,
**Favors**, **Profile**.

| iOS file | Screen |
|---|---|
| `AuthView.swift`, `AuthViewModel.swift` | Sign in / sign up, plus a private "Forgot password" sheet |
| `CollectionView.swift`, `CollectionViewModel.swift` | Grid of held gems; "Your original gems — Follow their journeys, wherever they go." |
| `GemDetailsView.swift` | One gem: art, name, tier, journey timeline, rename (creator only), engrave, give |
| `GemInteriorView.swift` + `GemKaleidoscope.metal` | Inside a gem (see §8) |
| `GemGuideView.swift` | Explains families, tiers and traits |
| `FavorsView.swift` | Pending (offers to me, helping me, gems I owe, my offers in flight) + History |
| `FavorDetailView.swift` | One favor's steps, the gem it moved, report/block menu |
| `OfferHelpView.swift` | Offer a favor to a connected person |
| `SendGemView.swift` | Give a gem for a completed favor (pick the gem or the favor) |
| `FavorGivenView.swift` | Celebrations: "Favor given" (giver) and "A gem arrived" (helper) |
| `ConnectView.swift` | Pairing: show your code/QR, redeem someone else's code, your circle |
| `ProfileTabView.swift` | Avatar, stats, notifications, Help/Contact/Privacy/Terms, sign out, delete account |
| `HelperTitles.swift` | Titles, avatar frames, "title earned" celebration |
| `EngraveGemView.swift` | Write a secret into a gem |
| `RenameGemView.swift` | Rename a gem you created |
| `ReportView.swift` | Report sheet, block confirmation, Blocked people list |
| `AccountPauseView.swift` | "Your account is paused" notice (moderation) |
| `FavorNotifications.swift` | Realtime favor updates, in-app banners, the tab badge |
| `PushNotifications.swift` | Push registration, foreground pushes, tap routing |
| `PersonAvatar.swift` | Photo or initials avatar, with a title frame |
| `SupabaseService.swift` | **Every backend call** — the best single file to read |

---

## 4. Backend surface the app uses

All calls go through the Supabase client with the anon key and the user's session. Config
on iOS comes from `SupabaseConfig.plist` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`). Get the
values from the user; don't commit them in a way that ships secrets beyond the anon key.

**RPCs:** `propose_favor`, `respond_to_favor`, `complete_favor`, `transfer_coin`,
`cancel_favor`, `rename_coin`, `coin_journey`, `engrave_coin`, `coin_engravings`,
`hide_engraving`, `my_engraving_status`, `gem_economy_settings`, `create_pairing_code`,
`redeem_pairing_code`, `get_connected_users`, `set_avatar`, `clear_avatar`,
`register_device`, `unregister_device`, `report_content`, `block_user`, `unblock_user`,
`my_blocks`, `my_pause`, `delete_account`.

**Tables read directly:** `coins`, `favors` (with profile joins), `connections`,
`pairing_codes`, `profiles`. **Storage:** public bucket `avatars`, path `{uid}/avatar.jpg`,
512×512 JPEG, under 1 MB.

**Auth:** email + password. Email confirmation is **off**, so sign-up returns a session and
goes straight in (iOS falls back to "check your inbox" only if no session comes back).
Password reset is **web-only**: `resetPasswordForEmail(email, redirectTo:
"https://favorium.app/reset")`. The link opens in the browser, the person sets a new
password there, then signs in normally. **No deep link and no recovery-URL handling.**

---

## 5. The favor flow and who may do what

```
helper:  propose_favor(p_helped_id, p_description)   → proposed
helped:  respond_to_favor(p_favor_id, p_accept)      → accepted / declined
helped:  complete_favor(p_favor_id)                  → completed
helped:  transfer_coin(p_favor_id, p_coin_id)        → transferred (gem goes to helper)
either:  cancel_favor(p_favor_id)                    → cancelled (from proposed/accepted)
```

- **Only offer the actions the role may call.** The helper mostly waits.
- `propose_favor` requires an existing `connections` row (pairing).
- Guard failures all say "Favor not found".
- **Gems only move through a completed favor.** There is no one-tap gift; don't add one.
- Treat **unknown status strings as non-actionable**. The backend also has dormant
  `done` / `disputed` statuses (see §11); never show actions for them.

**Badge** (Favors tab and app icon), counted on the helped side only:
offers to answer (`proposed`) + gems owed (`completed` and `coin_id` is null).
The helper's own outstanding work never counts.

---

## 6. Gem economy rules

- 2 gems minted at sign-up (by the server).
- **A gem may change hands once per rolling 24h**, per gem. A resting gem has
  `available_at` in the future. `transfer_coin` raises an error starting
  `Gem is resting — it can move again at <UTC ISO>`; branch on that prefix. iOS greys out
  resting gems and shows a countdown.
- Users stuck at 0 gems get nudges, then a gift (server-driven pushes `nudge` / `gift`).
- `rename_coin` is **creator only**, any time, 1–40 characters. Starter names are
  "<Family> <Noun>"; `GemNaming.swift` mirrors the server's lists to suggest naming.
- Read tunable values from `gem_economy_settings()`; never hard-code them.

---

## 7. Gem rendering (the biggest port)

Two layers, both deterministic from the gem's DNA so a gem looks identical everywhere:

1. **`CrystalEngine.swift`** turns DNA into a model: phase, colours, material family,
   orbitals. **Its RNG is an exact port from the web** (`xmur3` → `mulberry32`, seeded with
   `"<seed>::<salt>"`). Port it bit-for-bit with unsigned 32-bit arithmetic (Kotlin `UInt`,
   or `Int` with `ushr` and masking), or colours will drift from iOS and web.
2. **`FavorGemView.swift`** draws the gem from image assets plus overlays:
   - **Families:** celestial, gothic, lightning, victorian.
   - **Tiers by transfer count:** seed 0–4, bloom 5–14, legacy 15–29, radiance 30+.
   - **Assets:** `gem_<family>_<tier>` and `frame_<family>_<tier>` (32 images in
     `Assets.xcassets`), tinted by DNA colour, then trait overlays.
   - **Traits:** rolled once at mint and stored in DNA, never changed by transfers.
     **iOS draws trait overlays on purpose**, even though the backend contract says not to.
     That was the user's call; match iOS.

Assets to copy: everything in `Assets.xcassets` (gems, frames, tab icons, `stat_originals`,
app icon). Export at matching densities.

---

## 8. Inside a gem (kaleidoscope)

`GemInteriorView.swift` + `GemKaleidoscope.metal`. Long-press a gem → it lifts, a buzz and
a flash of its colour, then you're inside.

- **Scene:** a living source scene built from the gem's own art and DNA hues. The
  shader folds every pixel into one mirrored wedge. The number of wedges comes from the
  family's geometry, so every gem's interior is unique and always the same for that gem.
- **Shader inputs:** size, segments, rotation, zoom, focus, facetGlow. On Android, port it
  to an **AGSL `RuntimeShader`** (API 33+) applied as a `RenderEffect`, with a simpler
  fallback below 33.
- **Guard the shader:** pass pixels through when the size is under 2 px or rotation/zoom
  aren't finite. NaNs stalled the GPU on iOS.
- **Controls:**
  - drag to turn, pinch to zoom, tap to scatter light;
  - tilt left/right sets spin speed and direction, tilt toward/away sets the drift;
  - the attitude on entry counts as level;
  - wrap shader angles to avoid precision loss over time.
- **Secret reveal:** if the holder's gem has an engraving, the words rise in gold at the
  centre once the person has been still for about 2.2s (no touch and low rotation rate).
  "Hide for me" and "Report" appear under the words.

---

## 9. Pairing, titles, engravings

- **Pairing** (`ConnectView.swift`):
  - `create_pairing_code` returns {code, expires_at}. Codes last 10 minutes and work once;
    reuse a still-live code on relaunch.
  - `redeem_pairing_code(p_code)` returns the other user's id.
  - Your circle comes from the `connections` table, **not** `get_connected_users`, which
    also includes favor counterparties.
- **Titles** (`HelperTitles.swift`), by distinct people helped:
  - Samaritan 3, Saint 6, Angel 10, Seraph 15, Bodhisattva 25.
  - Read from `profiles.helper_level` / `people_helped`; titles never go down.
  - Show the "title earned" celebration once per level per device.
  - Avatars get a frame per title.
- **Engravings** (`EngraveGemView.swift`, IOS_CONTRACT §17):
  - Angel and above, once per rolling 24h, short unsigned text.
  - **One per gem:** engraving again replaces the old message forever, so warn first.
  - Only the current holder can read it; `coin_engravings` returns `[]` to anyone else.
  - The journey shows an `engraved` event, with who engraved it but never the text.
  - Knobs come from `gem_economy_settings().engraving`.

---

## 10. Safety, moderation, account

- **Report and block** (App Store guideline 1.2; Play has similar UGC rules):
  - `report_content(kind user|favor|engraving, id, reason, details ≤500)`.
    Reasons: harassment, scam_or_nonpayment, inappropriate, other.
  - `block_user` returns {blocked, cancelled_favors}. Always confirm first, then say how
    many favors were cancelled.
  - The ••• menu with report and block appears on pending favor cards (including incoming
    offers), the favor detail page and Connect circle rows. "Blocked people" (from
    `my_blocks`) lives on Connect.
- **Pause** (IOS_CONTRACT §19, `AccountPauseView.swift`):
  - `my_pause()` returns zero or one row of {muted_until, reason, paused_since}.
    **Never show, decode or log `reason`**: it can name and quote the reporter.
  - Build the notice from the dates only, and re-check on foreground and about every 60s.
  - A pause blocks only engraving, proposing favors and renaming yourself. Don't grey out
    anything else.
  - The "Write to us" link uses subject "Favorium iOS — my account is paused". Use an
    Android equivalent.
- **Removed content** is just ordinary text: favors read "This request was removed by
  Favorium.", names become "Member" or "Deleted member", and removed engravings return `[]`.
- **Delete account:**
  - `delete_account()` takes no arguments and returns {status: deleted | already_deleted,
    cancelled_favors}. Both statuses are success.
  - Afterwards, sign out locally and don't try to re-authenticate.
  - If a profile ever comes back with `deleted_at` set, sign out.
  - The confirmation should say it's immediate and that shared gems and history stay.
- **Links:**
  - support@favorium.app (pre-addressed with a subject; never pre-fill the user's email)
  - https://favorium.app/help
  - https://favorium.app/privacy
  - https://favorium.app/terms

---

## 11. Decided against — don't rebuild these

- **Escrow / "promise a gem on accept", helper "mark done", disputes, auto-release.** Built
  on iOS, then **rolled back** because the gift-like flow was better and the complications
  (cooldowns, web parity) weren't worth it. The backend still has these, dormant. They
  only activate if an app calls `mark_favor_done` or passes `p_coin_id` to
  `respond_to_favor`. Don't.
- **One-tap gifting** outside a completed favor.
- **Locking gem names** after the first transfer.

---

## 12. Celebrations and local state

- **"A gem arrived"** for the helper:
  - Detect new `transferred` outgoing favors newer than a per-user marker stored locally.
  - On the first run, only set the marker; never celebrate old gems.
  - Record the marker before showing, and celebrate the newest gem plus "N more".
  - Queue it with the title celebration so only one is shown at a time.
- **"Favor given"** ends Give a gem.
- **Local storage holds only:** celebration markers, the push-prompt-dismissed flag and
  similar. Never cache the pause or account state.

---

## 13. Push notifications — needs backend work for Android

iOS registers its APNs token with `register_device(p_token, p_environment, p_platform:
"ios")` and unregisters it on sign-out. **The backend currently sends through APNs.**
Android needs FCM:

- The web agent must add FCM sending (a Firebase service account, an Edge Function
  branch on `platform = "android"`).
- The app registers its FCM token with `p_platform: "android"`.

Payload keys the app reads: `favorId`, `kind`, `route` (`favors` | `collection` |
`profile`). Tapping a push opens that tab.

- **Known kinds:** transferred, title, nudge, gift, plus favor-state pushes.
  Copy is owned by PUSH_CONTRACT; don't reword it in the app.
- **Foreground pushes** become an in-app banner and trigger a refresh.
- **Duplicate banners:** a push and a realtime update can describe the same moment.
  Skip one banner per favorId + status within about 30s.
- **Explain first:** show the in-app card before Android 13's notification permission
  prompt.

Realtime (`FavorNotifications.swift`): subscribe to `favors` inserts and updates filtered
by `helped_id` and `helper_id`. On any change, refresh screens and recount the badge.

---

## 14. Look and feel

Art-deco sci-fi ("Sovereign"). It adapts to light and dark modes: midnight navy with gold
and platinum by night, ivory marble with deep antique gold by day. Tokens are in
`ContentView.swift` → `FavoriumTheme`:

- **Colours:** background, backgroundTop, surface, surfaceHigh, accent, accentMuted,
  silver, sapphire, sapphireGlow, ivory, gold, amber, onGold, goldGradient.
- **Shapes:** cardRadius, rowRadius.
- **Fonts:** title, heading, body, caption. The title uses the system font in expanded
  width; use a wide or extended font for the same feel.

Other pieces live in `DecoStyle.swift`: DecoBackdrop with sunburst rays, StarfieldHeader,
metallic gold capsule buttons, and the shimmer used for loading. The initials avatar colour
comes from a UUID-byte checksum over a 7-colour palette, identical on web and iOS
(`PersonAvatar.swift`), so port it exactly.

---

## 15. Store-readiness checklist (Android equivalents of what iOS needed)

- [ ] In-app account deletion (Play requires it too, plus a web deletion URL in the listing)
- [ ] Report + block for user-generated content
- [ ] Privacy policy link in the app and the listing: https://favorium.app/privacy
- [ ] Play **Data safety** form: email, name, photo, user ID, user content;
      all linked to the account, for app functionality, no tracking, no ads
- [ ] Support email in the app
- [ ] Reviewer demo accounts (the user has mock-data accounts already paired)
- [ ] Forgot password (web page)
- [ ] Portrait phone layout to start (iOS ships iPhone-only, portrait)
- [ ] FCM push (backend dependency, §13)
- [ ] Listing copy: reuse `docs/APP_STORE_LISTING.md`, adapted to Play's 80-character
      short description

---

## 16. Working agreements with the user

- Keep changes scoped to what's asked.
- Show server error messages verbatim and branch on documented prefixes.
- Ask before backend changes, and route them through the web agent.
- The user likes plain-language explanations, and copy that matches the app's actual
  behaviour exactly.
