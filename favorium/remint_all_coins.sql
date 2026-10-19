-- =============================================================================
--  remint_all_coins.sql
--  Favorium — one-time test-data repair script
--
--  Run in Supabase SQL Editor (Dashboard → SQL Editor → New query → Run).
--  Safe to run multiple times — re-running the same seed produces the same DNA.
--
--  What it does:
--    • Regenerates the `dna` JSONB blob for every row in `coins` with the
--      full shape required by the iOS app (BACKEND_CONTRACT.md §2).
--    • Preserves: name, serial, transfer_count, creator_id, owner_id, created_at.
--    • Overwrites:  dna, dna_version, seed  (seed is stable — derived from coin id).
--    • Does NOT touch favors or coin_history.
--
--  DNA shape written:
--    {
--      "seed": "<stable-string>",
--      "identity": {
--          "primary_color", "secondary_color", "accent_color",
--          "saturation", "material_family", "base_form",
--          "color_relationship", "secondary_influence", "refraction",
--          "frame_hue", "luster", "transparency", "inner_light",
--          "inclusion_type", "inclusion_density",
--          "facet_count", "facet_pattern", "symmetry", "surface_character"
--      },
--      "personality": {
--          "complexity_bias", "orbital_affinity", "refraction",
--          "evolution_family", "secondary_family"
--      }
--    }
--
--  Valid base_form / evolution_family values (match iOS GemFamily assets):
--    lightning | celestial | victorian | gothic
-- =============================================================================

DO $$
DECLARE
    r            RECORD;
    v_seed       TEXT;
    v_base_form  TEXT;
    v_mat_family TEXT;
    v_col_rel    TEXT;
    v_pri_color  NUMERIC;
    v_sec_color  NUMERIC;
    v_acc_color  NUMERIC;
    v_saturation NUMERIC;
    v_sec_inf    NUMERIC;
    v_refraction NUMERIC;
    v_frame_hue  NUMERIC;
    v_luster     TEXT;
    v_transparency NUMERIC;
    v_inner_light NUMERIC;
    v_incl_type  TEXT;
    v_incl_dens  NUMERIC;
    v_facet_cnt  INT;
    v_facet_pat  TEXT;
    v_symmetry   INT;
    v_surf_char  TEXT;
    v_complex    NUMERIC;
    v_orbital    NUMERIC;
    v_pers_ref   NUMERIC;
    v_evo_family TEXT;
    v_sec_family TEXT;
    v_dna        JSONB;

    -- Lookup arrays — index with modular arithmetic on integer derived from seed hash
    v_base_forms   TEXT[] := ARRAY['lightning', 'celestial', 'victorian', 'gothic'];
    v_mat_families TEXT[] := ARRAY['coloredGemstone', 'opal', 'clearCrystal', 'moonstone',
                                    'metallic', 'translucentMineral', 'pearlescent'];
    v_col_rels     TEXT[] := ARRAY['complementary', 'analogous', 'split', 'core-and-shell',
                                    'refracted', 'veined', 'spectral', 'gradient', 'asymmetric'];
    v_lusters      TEXT[] := ARRAY['vitreous', 'adamantine', 'resinous', 'silky', 'pearly'];
    v_incl_types   TEXT[] := ARRAY['none', 'rutile', 'tourmaline', 'chlorite', 'fluid'];
    v_facet_pats   TEXT[] := ARRAY['brilliant', 'step', 'mixed', 'rose', 'cabochon'];
    v_surf_chars   TEXT[] := ARRAY['smooth', 'crystalline', 'frosted', 'etched'];
    v_evo_fams     TEXT[] := ARRAY['lightning', 'celestial', 'victorian', 'gothic'];

    -- Scratch int for deterministic "random" picks from the seed hash
    v_h BIGINT;

BEGIN
    FOR r IN SELECT id, seed AS existing_seed FROM coins LOOP

        -- ── 1. Stable seed: reuse existing if present, else derive from coin id ──
        IF r.existing_seed IS NOT NULL AND r.existing_seed != '' THEN
            v_seed := r.existing_seed;
        ELSE
            v_seed := r.id::TEXT;
        END IF;

        -- ── 2. Derive a stable integer hash from the seed ─────────────────────
        --   We use hashtext() (PostgreSQL built-in) which is deterministic within
        --   a session. ABS() to keep it positive; BIGINT to avoid overflow.
        v_h := ABS(hashtext(v_seed)::BIGINT);

        -- ── 3. Pick gem identity fields ───────────────────────────────────────
        v_base_form  := v_base_forms  [1 + (v_h          % array_length(v_base_forms,  1))::INT];
        v_mat_family := v_mat_families[1 + ((v_h / 7)    % array_length(v_mat_families, 1))::INT];
        v_col_rel    := v_col_rels    [1 + ((v_h / 13)   % array_length(v_col_rels,    1))::INT];
        v_luster     := v_lusters     [1 + ((v_h / 17)   % array_length(v_lusters,     1))::INT];
        v_incl_type  := v_incl_types  [1 + ((v_h / 23)   % array_length(v_incl_types,  1))::INT];
        v_facet_pat  := v_facet_pats  [1 + ((v_h / 29)   % array_length(v_facet_pats,  1))::INT];
        v_surf_char  := v_surf_chars  [1 + ((v_h / 31)   % array_length(v_surf_chars,  1))::INT];
        v_evo_family := v_evo_fams    [1 + ((v_h / 37)   % array_length(v_evo_fams,    1))::INT];
        v_sec_family := v_evo_fams    [1 + ((v_h / 41)   % array_length(v_evo_fams,    1))::INT];

        -- Colors — spread evenly across the hue wheel using different offsets
        v_pri_color  := ROUND(((v_h % 3600)::NUMERIC / 10.0), 1);              -- 0.0–360.0
        v_sec_color  := ROUND((((v_h / 43 + 120) % 360)::NUMERIC), 1);         -- offset +120°
        v_acc_color  := ROUND((((v_h / 47 + 240) % 360)::NUMERIC), 1);         -- offset +240°
        v_frame_hue  := ROUND((((v_h / 53)        % 360)::NUMERIC), 1);

        -- Continuous parameters — map hash bands to valid ranges
        v_saturation  := ROUND(0.55 + ((v_h / 59  % 100)::NUMERIC / 100.0) * 0.42, 2); -- 0.55–0.97
        v_sec_inf     := ROUND(0.22 + ((v_h / 61  % 100)::NUMERIC / 100.0) * 0.66, 2); -- 0.22–0.88
        v_refraction  := ROUND(0.30 + ((v_h / 67  % 100)::NUMERIC / 100.0) * 0.65, 2); -- 0.30–0.95
        v_transparency:= ROUND(0.10 + ((v_h / 71  % 100)::NUMERIC / 100.0) * 0.80, 2); -- 0.10–0.90
        v_inner_light := ROUND(0.00 + ((v_h / 73  % 100)::NUMERIC / 100.0) * 0.60, 2); -- 0.00–0.60
        v_incl_dens   := ROUND(0.00 + ((v_h / 79  % 100)::NUMERIC / 100.0) * 0.70, 2); -- 0.00–0.70
        v_complex     := ROUND(0.40 + ((v_h / 83  % 100)::NUMERIC / 100.0) * 0.58, 2); -- 0.40–0.98
        v_orbital     := ROUND(0.30 + ((v_h / 89  % 100)::NUMERIC / 100.0) * 0.68, 2); -- 0.30–0.98
        v_pers_ref    := ROUND(0.35 + ((v_h / 97  % 100)::NUMERIC / 100.0) * 0.60, 2); -- 0.35–0.95

        v_facet_cnt   := 6  + (v_h / 101 % 19)::INT;   -- 6–24
        v_symmetry    := 3  + (v_h / 103 % 6)::INT;    -- 3–8

        -- ── 4. Assemble the DNA blob ──────────────────────────────────────────
        v_dna := jsonb_build_object(
            -- ── Top-level seed (required for CrystalDNA Codable decode) ────
            'seed', v_seed,

            -- ── identity block ──────────────────────────────────────────────
            'identity', jsonb_build_object(
                'primary_color',      v_pri_color,
                'secondary_color',    v_sec_color,
                'accent_color',       v_acc_color,
                'saturation',         v_saturation,
                'material_family',    v_mat_family,
                'base_form',          v_base_form,
                'color_relationship', v_col_rel,
                'secondary_influence',v_sec_inf,
                'refraction',         v_refraction,
                'frame_hue',          v_frame_hue,
                'luster',             v_luster,
                'transparency',       v_transparency,
                'inner_light',        v_inner_light,
                'inclusion_type',     v_incl_type,
                'inclusion_density',  v_incl_dens,
                'facet_count',        v_facet_cnt,
                'facet_pattern',      v_facet_pat,
                'symmetry',           v_symmetry,
                'surface_character',  v_surf_char
            ),

            -- ── personality block ────────────────────────────────────────────
            'personality', jsonb_build_object(
                'complexity_bias',   v_complex,
                'orbital_affinity',  v_orbital,
                'refraction',        v_pers_ref,
                'evolution_family',  v_evo_family,
                'secondary_family',  v_sec_family
            )
        );

        -- ── 5. Write back to coins ────────────────────────────────────────────
        UPDATE coins
        SET
            dna         = v_dna,
            dna_version = 1,
            seed        = v_seed
        WHERE id = r.id;

    END LOOP;

    RAISE NOTICE '✅ remint_all_coins complete — % coins updated.', v_count;
    RAISE NOTICE '   Pull-to-refresh the iOS app to see the new gems.';
END $$;

-- =============================================================================
--  Verification query — run this separately after the script to spot-check:
-- =============================================================================
--
-- SELECT
--     id,
--     name,
--     seed,
--     dna->>'seed'                            AS dna_seed,
--     dna->'identity'->>'primary_color'       AS primary_color,
--     dna->'identity'->>'base_form'           AS base_form,
--     dna->'identity'->>'material_family'     AS material_family,
--     dna->'identity'->>'color_relationship'  AS color_relationship,
--     dna->'personality'->>'complexity_bias'  AS complexity_bias,
--     dna_version
-- FROM coins
-- ORDER BY created_at;

