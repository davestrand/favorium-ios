# Favorium — iOS ↔ Backend Sync Report
**Date:** 2026-10-19  
**From:** iOS team  
**For:** Backend / Supabase / Web agent

---

## What happened today (test data repair session)

We had a full debug session to get gem color variation working in the iOS app.
Here is everything we discovered and the current state of things.

---

## 1. Root cause of missing colors

The `mint_coin()` function **does not write a `dna` column value**.  
Coins are being created with `name`, `serial`, `transfer_count`, `creator_id`, `owner_id` — but `dna` is `NULL`.

The iOS app requires `dna` to be a fully-populated JSONB blob at the time of INSERT.
Without it, every gem falls back to the same default green asset and looks identical.

**This is the #1 backend task: update `mint_coin()` to write `dna` at INSERT time.**
See Section 4 below for the exact shape required.

---

## 2. Triggers discovered on the coins tables

We found the following row-level security triggers that block direct data manipulation:

| Table          | Trigger name    | What it does                                    |
|----------------|-----------------|--------------------------------------------------|
| `coins`        | `coins_guard`   | Blocks ownership changes outside transfer RPC   |
| `coin_history` | `history_guard` | Blocks any DELETE / UPDATE (append-only)        |

These are good security — keep them. Any future admin repair scripts need to:
```sql
ALTER TABLE coins        DISABLE TRIGGER coins_guard;
ALTER TABLE coin_history DISABLE TRIGGER history_guard;
-- ... do work ...
ALTER TABLE coins        ENABLE TRIGGER coins_guard;
ALTER TABLE coin_history ENABLE TRIGGER history_guard;
```

---

## 3. Foreign key delete order

When deleting test data, the correct FK-safe order is:
```sql
DELETE FROM coin_history;   -- references coins
DELETE FROM favors;          -- references coins (favors_current_coin_fkey)
DELETE FROM coins;           -- now safe to delete
```

`favors` has a FK to `coins` via `favors_current_coin_fkey`. This caught us off guard.

---

## 4. The `dna` JSONB shape the iOS app requires

Every coin **must** have this structure in its `dna` column at INSERT time.
The iOS `CrystalDNA` Swift struct decodes this directly via `Codable`.

```jsonc
{
  // ── Required top-level key ─────────────────────────────────────────────────
  "seed": "<stable UUID string — can be gen_random_uuid()::text>",

  // ── identity: drives the procedural gem renderer ──────────────────────────
  "identity": {
    "primary_color":       210.0,      // hue 0–360  (REQUIRED)
    "secondary_color":     40.0,       // hue 0–360  (REQUIRED)
    "accent_color":        330.0,      // hue 0–360  (REQUIRED)
    "saturation":          0.78,       // 0.0–1.0    (REQUIRED)
    "material_family":     "coloredGemstone",  // see §4a
    "base_form":           "lightning",        // see §4b  (REQUIRED)
    "color_relationship":  "complementary",    // see §4c
    "secondary_influence": 0.50,       // 0.0–1.0
    "refraction":          0.65,       // 0.0–1.0
    "frame_hue":           47.3,       // hue 0–360 for the decorative frame
    "luster":              "vitreous",
    "transparency":        0.70,
    "inner_light":         0.30,
    "inclusion_type":      "none",
    "inclusion_density":   0.10,
    "facet_count":         12,
    "facet_pattern":       "brilliant",
    "symmetry":            6,
    "surface_character":   "smooth"
  },

  // ── personality: drives orbital / complexity calculations ──────────────────
  "personality": {
    "complexity_bias":   0.70,   // 0.0–1.0  (REQUIRED)
    "orbital_affinity":  0.80,   // 0.0–1.0  (REQUIRED)
    "refraction":        0.65,   // 0.0–1.0  (personality copy — optional but good to have)
    "evolution_family":  "lightning",
    "secondary_family":  "celestial"
  }
}
```

### 4a. Valid `material_family` values
```
coloredGemstone | opal | clearCrystal | moonstone |
metallic | translucentMineral | pearlescent | smoky |
spectral | cosmic | glass | hybrid
```

### 4b. Valid `base_form` values (must match iOS GemFamily asset names exactly)
```
lightning | celestial | victorian | gothic
```
Any other value will fall back to `lightning` assets in the app.

### 4c. Valid `color_relationship` values
```
complementary | analogous | split | core-and-shell |
refracted | veined | spectral | gradient | asymmetric
```

---

## 5. Recommended `mint_coin()` implementation

Here is a drop-in update to whatever `mint_coin(p_owner UUID)` currently does.
Add the DNA generation block before the INSERT:

```sql
CREATE OR REPLACE FUNCTION mint_coin(p_owner UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_coin_id    UUID := gen_random_uuid();
    v_seed       TEXT := gen_random_uuid()::TEXT;
    v_serial     TEXT;
    v_name       TEXT;
    v_base_forms TEXT[] := ARRAY['lightning','celestial','victorian','gothic'];
    v_mat_fams   TEXT[] := ARRAY['coloredGemstone','opal','clearCrystal','moonstone',
                                  'metallic','translucentMineral','pearlescent'];
    v_col_rels   TEXT[] := ARRAY['complementary','analogous','split','core-and-shell',
                                  'refracted','veined','spectral','gradient','asymmetric'];
    v_base_form  TEXT;
    v_mat_fam    TEXT;
    v_col_rel    TEXT;
    v_pri        NUMERIC;
    v_sec        NUMERIC;
    v_acc        NUMERIC;
    v_sat        NUMERIC;
    v_dna        JSONB;
BEGIN
    -- Pick gem identity randomly
    v_base_form := v_base_forms[1 + floor(random() * array_length(v_base_forms,1))::INT];
    v_mat_fam   := v_mat_fams  [1 + floor(random() * array_length(v_mat_fams,  1))::INT];
    v_col_rel   := v_col_rels  [1 + floor(random() * array_length(v_col_rels,  1))::INT];

    v_pri := ROUND((random() * 360)::NUMERIC, 1);
    v_sec := ROUND(((v_pri + 120 + random() * 60) % 360)::NUMERIC, 1);
    v_acc := ROUND(((v_pri + 240 + random() * 30) % 360)::NUMERIC, 1);
    v_sat := ROUND((0.55 + random() * 0.42)::NUMERIC, 2);

    v_dna := jsonb_build_object(
        'seed', v_seed,
        'identity', jsonb_build_object(
            'primary_color',       v_pri,
            'secondary_color',     v_sec,
            'accent_color',        v_acc,
            'saturation',          v_sat,
            'material_family',     v_mat_fam,
            'base_form',           v_base_form,
            'color_relationship',  v_col_rel,
            'secondary_influence', ROUND((0.22 + random() * 0.66)::NUMERIC, 2),
            'refraction',          ROUND((0.30 + random() * 0.65)::NUMERIC, 2),
            'frame_hue',           ROUND((random() * 360)::NUMERIC, 1),
            'luster',              'vitreous',
            'transparency',        ROUND((0.10 + random() * 0.80)::NUMERIC, 2),
            'inner_light',         ROUND((random() * 0.60)::NUMERIC, 2),
            'inclusion_type',      'none',
            'inclusion_density',   0.0,
            'facet_count',         6 + floor(random() * 19)::INT,
            'facet_pattern',       'brilliant',
            'symmetry',            3 + floor(random() * 6)::INT,
            'surface_character',   'smooth'
        ),
        'personality', jsonb_build_object(
            'complexity_bias',   ROUND((0.40 + random() * 0.58)::NUMERIC, 2),
            'orbital_affinity',  ROUND((0.30 + random() * 0.68)::NUMERIC, 2),
            'refraction',        ROUND((0.35 + random() * 0.60)::NUMERIC, 2),
            'evolution_family',  v_base_form,
            'secondary_family',  v_base_forms[1 + floor(random() * array_length(v_base_forms,1))::INT]
        )
    );

    -- Generate serial + default name
    v_serial := 'FV-' || LPAD(floor(random() * 999999 + 1)::TEXT, 6, '0');
    v_name   := 'Gem ' || substr(v_seed, 1, 6);  -- placeholder; UI lets user rename

    INSERT INTO coins (id, serial, name, dna, dna_version, seed, creator_id, owner_id, transfer_count)
    VALUES            (v_coin_id, v_serial, v_name, v_dna, 1, v_seed, p_owner, p_owner, 0);

    -- Write the minted history entry
    INSERT INTO coin_history (coin_id, event_type, to_user, description)
    VALUES (v_coin_id, 'minted', p_owner, 'Gem brought into the world.');

    RETURN v_coin_id;
END;
$$;
```

---

## 6. Current workaround in place

Until `mint_coin()` is updated, we have `patch_dna.sql` in the iOS repo that can
be run in the Supabase SQL Editor to inject DNA into any coins that are missing it.
It disables/re-enables `coins_guard` correctly and uses a stable `hashtext()` seed
so re-running it produces the same visual for each coin.

---

## 7. iOS app status

| Feature | Status |
|---------|--------|
| Pull-to-refresh crash (`CancellationError`) | ✅ Fixed |
| Gem color variation (MagicalCrystalView) | ✅ Working once DNA is present |
| `parseCrystalDNA` resilience (missing top-level seed) | ✅ Fixed |
| `mint_coin()` writing DNA | ❌ Needs backend update (see §5) |
| `transfer_coin()` assigning trait at transfer_count=5 | ⚠️ Not yet implemented |

---

## 8. Questions for the backend agent

1. **Does `mint_coin()` already generate gem names, or should the iOS app pass a name?**  
   Currently the iOS onboarding just shows whatever coins `handle_new_user()` minted —
   the user never names their initial gems. Is a default name acceptable, or should
   we add a naming step to onboarding?

2. **Does `coin_journey` RPC exist and return the shape in §3 of BACKEND_CONTRACT.md?**  
   The gem detail view calls it. If it's not deployed yet the detail screen will always show a loading spinner.

3. **What is the intended `coins.name` strategy at mint time?**  
   The RPC in SCHEMA_ALIGNMENT.md passes `p_coin_name` but the current `mint_coin(p_owner)`
   takes only an owner. Do we need `mint_coin(p_owner, p_name)` or should names be auto-generated?
