# Favorium — iOS ↔ Supabase / Web Backend Contract

> **Status:** Updated 2026-10-19 after review of the authoritative backend contract.
> The backend contract (sent by the web/Supabase agent) supersedes all earlier
> iOS-authored drafts. This file now summarises what changed and what the iOS
> app currently does, for ongoing coordination.

---

## What the backend contract corrected

| Old iOS assumption | Reality (from backend contract) |
|---|---|
| `dna.gemFamily` (top-level camelCase) | Lives at `dna.identity.base_form` (nested, snake_case) |
| `dna.primaryHue` | `dna.identity.primary_color` |
| `dna.saturation` (top-level) | `dna.identity.saturation` (optional — derive from seed when absent) |
| `dna.trait` = starlight/rainbow/… | **Does not exist.** No trait system in the DB |
| `personality.refraction` | `identity.refraction` |
| `CrystalPersonality` has 3 keys | Has 10 keys including `evolution_family` — strict decode crashed |
| `CrystalIdentity` uses `primary_hue` / `secondary_hue` | `primary_color` / `secondary_color` / `accent_color` |
| Four gem families: lightning/celestial/victorian/gothic | These are iOS *asset* names only; source field is `identity.base_form` |
| `history.event_type == "created"` | Real value is `"minted"` |
| `complete_favor_and_mint` RPC exists | **Does not exist.** `mint_coin(p_owner)` is called at sign-up |
| Tiers: Seed/Bloom/Legacy/Radiance | Newborn/Awakened/Resonant/Radiant/Storied/Legendary (6 stages) |
| Trait assigned at transfer_count == 5 | No trait system anywhere |

All of these have been corrected in the iOS codebase as of this update.

---

## iOS files changed

- **`CrystalEngine.swift`** — `CrystalIdentity` and `CrystalPersonality` structs rewritten to match real schema. `CrystalEngine.derive` updated to read from correct fields and derive optional fields from seed per §4a of backend contract.
- **`GemDetailsView.swift`** — DNA helpers rewritten to read from nested `identity.*` keys. `transferLabel` handles `"minted"`. Trait reading removed.
- **`CollectionView.swift`** — Same DNA helper updates. Trait reading removed throughout.

---

## Remaining iOS ↔ backend items to coordinate

### `GemFamily` asset mapping — RESOLVED
Superseded by `BACKEND_CONTRACT 2.md` (verified against live data). `identity.base_form`
values are exactly `lightning | celestial | victorian | gothic` — the iOS asset family
names. `GemDNA.resolvedFamily` reads Layer 1 `gemFamily`, then `base_form`, then
`"lightning"`, skipping any layer that isn't a known family.

### `CoinJourneyPayload` CodingKeys — DONE
Explicit `CodingKeys` are in place.

### `coins.traits` (legacy field)
The backend contract says `traits` is `NOT NULL`. iOS does not read it currently (it's decoded as `JSONObject?` but ignored). No action needed unless we implement a `dnaFromTraits` fallback path.

### Minting / onboarding
The iOS app has a `SendGemView` that calls `transfer_coin`. This is correct — no minting happens from iOS. The onboarding flow just shows the two gems that `handle_new_user()` already minted at sign-up.

---

For the full authoritative backend contract, see the document sent by the Supabase/web agent (titled "Favorium — iOS ↔ Supabase Backend Contract (Authoritative)").


---

## 1. The `coins` Table — Required Columns

The iOS app selects these columns from `coins`:

```
id             UUID        primary key
serial         TEXT
name           TEXT
transfer_count INT
creator_id     UUID        → profiles.id
owner_id       UUID        → profiles.id
created_at     TIMESTAMPTZ
dna            JSONB       ← critical for rendering
```

> The `dna` column **must be `jsonb`**, not `text` or `json`.
> The iOS app decodes it as a `JSONObject` ([String: AnyJSON]) via the
> Supabase Swift SDK's `Helpers` module.

---

## 2. The `dna` JSONB Column — Exact Shape

The app reads the following keys from `dna`. **Key names are camelCase** because
the iOS DNA helpers extract them by exact string key.

### 2a. Keys read by `FavorGemView` (every render)

| Key | Type | Values | Used for |
|-----|------|--------|----------|
| `gemFamily` | string | `"lightning"` `"celestial"` `"victorian"` `"gothic"` | Which gem asset set to load |
| `primaryHue` | number | 0 – 360 | Gem tint color (hue channel) |
| `saturation` | number | 0.0 – 1.0 | Gem tint color (saturation) |
| `trait` | string \| null | see §2b | Visual overlay effect |

**If any of these keys are missing or `null`, the app falls back gracefully:**
- `gemFamily` → falls back to `"lightning"`
- `primaryHue` / `saturation` → falls back to tier's default color (no crash)
- `trait` → no overlay (nil, which is fine for Seed-tier gems)

### 2b. Valid `trait` values

These map directly to `GemTrait.rawValue` in Swift:

| Value | Effect |
|-------|--------|
| `"starlight"` | Pinpoint sparkles triggered by pendulum tilt |
| `"rainbow"` | Full-spectrum rotating colour wash |
| `"iridescent"` | Butterfly-wing shimmer riding the pendulum |
| `"charged"` | Crackling electric arcs sweeping across the gem |
| `"ember"` | Pulsing inner fire / heat glow |
| *(omit key or null)* | No trait — appropriate for Seed tier |

**Seed-tier gems (transfer_count 0–4) should have `trait` omitted or null.**
Bloom tier and above (transfer_count ≥ 5) should be assigned one trait
at mint time that never changes.

### 2c. Keys read by `CrystalEngine` (procedural rendering — MagicalCrystalView)

The full DNA also drives the procedural renderer used in `MagicalCrystalView`.
These are nested under the same top-level `dna` object but use snake_case
because `CrystalDNA` / `CrystalIdentity` are `Codable` with explicit
`CodingKeys`.

```jsonc
{
  // ── Asset renderer keys (camelCase, read by dnaString/dnaDouble helpers)
  "gemFamily":   "lightning",
  "primaryHue":  210.0,
  "saturation":  0.78,
  "trait":       "starlight",

  // ── Procedural renderer keys (snake_case, decoded by CrystalDNA Codable)
  "identity": {
    "primary_hue":        210.0,
    "secondary_hue":      40.0,
    "saturation":         0.78,
    "material_family":    "coloredGemstone",
    "base_form":          "lightning",
    "color_relationship": "complementary",
    "secondary_influence": 0.5,
    "gem_family":         "lightning",
    "frame_family":       "lightning",
    "frame_hue":          47.3
  },
  "personality": {
    "complexity_bias":  0.7,
    "orbital_affinity": 0.8,
    "refraction":       0.7
  },
  "seed": "<uuid-string>"
}
```

> ⚠️ The top-level camelCase keys (`gemFamily`, `primaryHue`, `saturation`,
> `trait`) and the nested snake_case `identity` block **both need to be
> present** for both renderers to work correctly.

---

## 3. The `coin_journey` RPC — Required Output

The iOS detail view calls `coin_journey(p_coin_id)` and decodes:

```swift
struct CoinJourneyPayload: Decodable {
    let id: UUID
    let serial: String
    let name: String
    let traits: JSONObject?    // reserved, not yet read
    let dna: JSONObject?       // same shape as §2 above
    let seed: String?
    let dna_version: Int
    let transfer_count: Int
    let created_at: String
    let creator_name: String?
    let owner_name: String?
    let is_owner: Bool
    let is_creator: Bool
    let history: [CoinHistoryItem]
}

struct CoinHistoryItem: Decodable {
    let id: Int64
    let event_type: String     // "created" | "transferred"
    let description: String?
    let created_at: String     // ISO 8601
    let from_name: String?
    let to_name: String?
    let is_from_me: Bool?
    let is_to_me: Bool?
}
```

The `dna` field in the RPC response must have the same shape as §2.

---

## 4. Minting — What the RPC Must Write

When a gem is minted (via `complete_favor_and_mint` or equivalent), the
`dna` column **must be populated** at INSERT time. Here is the minimum
required SQL logic to generate valid DNA:

```sql
-- Deterministic gem family and trait assignment
v_families := ARRAY['lightning', 'celestial', 'victorian', 'gothic'];
v_traits   := ARRAY['starlight', 'rainbow', 'iridescent', 'charged', 'ember'];

-- transfer_count at mint time is always 0 (first owner is the creator/helper)
-- Traits are only assigned for Bloom+ (transfer_count >= 5), so omit at mint.
-- The trait will need to be assigned on the FIRST transfer that crosses the
-- Bloom threshold (transfer_count reaches 5). See §5.

v_gem_family  := v_families[1 + floor(random() * 4)::int];
v_primary_hue := round((random() * 360)::numeric, 1);
v_saturation  := round((0.60 + random() * 0.40)::numeric, 2);

v_dna := jsonb_build_object(
    -- Asset renderer keys
    'gemFamily',   v_gem_family,
    'primaryHue',  v_primary_hue,
    'saturation',  v_saturation,
    -- trait intentionally omitted at mint (Seed tier)

    -- Procedural renderer keys
    'identity', jsonb_build_object(
        'primary_hue',          v_primary_hue,
        'secondary_hue',        round(((v_primary_hue + 30 + random() * 60)::numeric % 360), 1),
        'saturation',           v_saturation,
        'material_family',      'coloredGemstone',
        'base_form',            v_gem_family,
        'color_relationship',   'complementary',
        'secondary_influence',  round((0.3 + random() * 0.5)::numeric, 2),
        'gem_family',           v_gem_family,
        'frame_family',         v_gem_family,  -- frame always matches gem
        'frame_hue',            round((random() * 360)::numeric, 1)  -- unique frame color per gem
    ),
    'personality', jsonb_build_object(
        'complexity_bias',   round((0.4 + random() * 0.6)::numeric, 2),
        'orbital_affinity',  round((0.4 + random() * 0.6)::numeric, 2),
        'refraction',        round((0.4 + random() * 0.6)::numeric, 2)
    ),
    'seed', gen_random_uuid()::text
);

INSERT INTO coins (serial, name, dna, dna_version, creator_id, owner_id, transfer_count, seed)
VALUES (v_serial, p_coin_name, v_dna, 1, v_creator_id, v_owner_id, 0, v_dna->>'seed');
```

---

## 5. Trait Assignment on First Bloom Transfer

A gem has no trait at Seed tier. When `transfer_coin` increments
`transfer_count` to 5 (crossing into Bloom), the RPC should assign a
random trait if one is not already set:

```sql
-- Inside transfer_coin RPC, after incrementing transfer_count:
IF NEW.transfer_count = 5 AND (NEW.dna->>'trait') IS NULL THEN
    v_traits := ARRAY['starlight','rainbow','iridescent','charged','ember'];
    v_trait  := v_traits[1 + floor(random() * 5)::int];

    NEW.dna := NEW.dna || jsonb_build_object('trait', v_trait);
END IF;
```

---

## 6. Data Reset Procedure

To wipe all data and start fresh (run in Supabase SQL Editor with service role):

```sql
-- 1. Transactional data (FK order)
DELETE FROM coin_history;
DELETE FROM coins;
DELETE FROM favors;

-- 2. Profiles
DELETE FROM profiles;

-- 3. Auth users (requires service role or Dashboard SQL editor)
DELETE FROM auth.users;
```

> After resetting, re-register users through the app. The sign-up flow
> passes `display_name` in user metadata, which a trigger should use to
> create the `profiles` row automatically.

---

## 7. Gem Family & Frame Family Valid Values

These must match `GemFamily.rawValue` and `FrameFamily.rawValue` in Swift exactly (all lowercase):

| Value | Asset files needed |
|-------|--------------------|
| `lightning` | `gem_lightning_{seed,bloom,legacy,radiance}.png` + matching frames |
| `celestial` | `gem_celestial_{seed,bloom,legacy,radiance}.png` + matching frames |
| `victorian` | `gem_victorian_{seed,bloom,legacy,radiance}.png` + matching frames |
| `gothic` | `gem_gothic_{seed,bloom,legacy,radiance}.png` + matching frames |

The frame family always matches the gem family. Any unknown value falls
back to `lightning` in the app.

---

## 8. Tier Thresholds (for reference)

| Tier | `transfer_count` range | Has trait? |
|------|------------------------|------------|
| Seed | 0 – 4 | No |
| Bloom | 5 – 14 | Yes (assigned at count = 5) |
| Legacy | 15 – 29 | Yes (assigned earlier) |
| Radiance | 30+ | Yes (assigned earlier) |

---

## 9. Summary Checklist for Backend Agent

- [ ] `coins.dna` column is type `jsonb` (not `text`)
- [ ] Minting RPC writes `gemFamily`, `primaryHue`, `saturation` to `dna` at INSERT
- [ ] Minting RPC writes the full nested `identity` / `personality` / `seed` block to `dna`
- [ ] Minting RPC writes `frame_hue` (0–360, one decimal place) inside `dna.identity` at INSERT
- [ ] `trait` is **not** written at mint (Seed tier)
- [ ] `transfer_coin` RPC assigns a random `trait` when `transfer_count` first reaches 5
- [ ] `coin_journey` RPC returns `dna` as a JSON object (not a string)
- [ ] `coin_journey` RPC returns `is_owner` and `is_creator` booleans
- [ ] `coin_journey` RPC returns `history` array with `event_type`, `from_name`, `to_name`, `is_from_me`, `is_to_me`
- [ ] `get_connected_users` RPC exists and returns `id`, `display_name`, `created_at`
- [ ] User sign-up trigger creates a `profiles` row from `display_name` metadata
