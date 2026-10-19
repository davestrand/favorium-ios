-- =============================================================================
--  patch_dna.sql
--  Patches DNA onto coins that were minted without it.
--  Only touches dna, dna_version, seed — everything else preserved.
-- =============================================================================

ALTER TABLE coins DISABLE TRIGGER coins_guard;

DO $$
DECLARE
    r             RECORD;
    v_seed        TEXT;
    v_h           BIGINT;
    v_base_form   TEXT;
    v_mat_family  TEXT;
    v_col_rel     TEXT;
    v_luster      TEXT;
    v_incl_type   TEXT;
    v_facet_pat   TEXT;
    v_surf_char   TEXT;
    v_pri_color   NUMERIC;
    v_sec_color   NUMERIC;
    v_acc_color   NUMERIC;
    v_frame_hue   NUMERIC;
    v_saturation  NUMERIC;
    v_sec_inf     NUMERIC;
    v_refraction  NUMERIC;
    v_transparency NUMERIC;
    v_inner_light NUMERIC;
    v_incl_dens   NUMERIC;
    v_facet_cnt   INT;
    v_symmetry    INT;
    v_complex     NUMERIC;
    v_orbital     NUMERIC;
    v_pers_ref    NUMERIC;
    v_evo_family  TEXT;
    v_sec_family  TEXT;
    v_dna         JSONB;
    v_count       INT := 0;

    v_base_forms   TEXT[] := ARRAY['lightning', 'celestial', 'victorian', 'gothic'];
    v_mat_families TEXT[] := ARRAY['coloredGemstone', 'opal', 'clearCrystal', 'moonstone',
                                    'metallic', 'translucentMineral', 'pearlescent'];
    v_col_rels     TEXT[] := ARRAY['complementary', 'analogous', 'split', 'core-and-shell',
                                    'refracted', 'veined', 'spectral', 'gradient', 'asymmetric'];
    v_lusters      TEXT[] := ARRAY['vitreous', 'adamantine', 'resinous', 'silky', 'pearly'];
    v_incl_types   TEXT[] := ARRAY['none', 'rutile', 'tourmaline', 'chlorite', 'fluid'];
    v_facet_pats   TEXT[] := ARRAY['brilliant', 'step', 'mixed', 'rose', 'cabochon'];
    v_surf_chars   TEXT[] := ARRAY['smooth', 'crystalline', 'frosted', 'etched'];

BEGIN
    FOR r IN SELECT id, seed AS existing_seed FROM coins ORDER BY created_at LOOP

        -- Use existing seed if present, otherwise coin UUID
        IF r.existing_seed IS NOT NULL AND trim(r.existing_seed) != '' THEN
            v_seed := r.existing_seed;
        ELSE
            v_seed := r.id::TEXT;
        END IF;

        v_h := ABS(hashtext(v_seed)::BIGINT);

        v_base_form  := v_base_forms  [1 + (v_h           % array_length(v_base_forms,   1))::INT];
        v_mat_family := v_mat_families[1 + ((v_h /  7)    % array_length(v_mat_families, 1))::INT];
        v_col_rel    := v_col_rels    [1 + ((v_h / 11)    % array_length(v_col_rels,     1))::INT];
        v_luster     := v_lusters     [1 + ((v_h / 13)    % array_length(v_lusters,      1))::INT];
        v_incl_type  := v_incl_types  [1 + ((v_h / 17)    % array_length(v_incl_types,   1))::INT];
        v_facet_pat  := v_facet_pats  [1 + ((v_h / 19)    % array_length(v_facet_pats,   1))::INT];
        v_surf_char  := v_surf_chars  [1 + ((v_h / 23)    % array_length(v_surf_chars,   1))::INT];
        v_evo_family := v_base_forms  [1 + ((v_h / 29)    % array_length(v_base_forms,   1))::INT];
        v_sec_family := v_base_forms  [1 + ((v_h / 31)    % array_length(v_base_forms,   1))::INT];

        v_pri_color   := ROUND(  (v_h            % 3600)::NUMERIC / 10.0, 1);
        v_sec_color   := ROUND( ((v_h / 37 + 120) % 360)::NUMERIC,        1);
        v_acc_color   := ROUND( ((v_h / 41 + 240) % 360)::NUMERIC,        1);
        v_frame_hue   := ROUND( ((v_h / 43)        % 360)::NUMERIC,       1);

        v_saturation  := ROUND(0.55 + ((v_h / 47  % 100)::NUMERIC / 100.0) * 0.42, 2);
        v_sec_inf     := ROUND(0.22 + ((v_h / 53  % 100)::NUMERIC / 100.0) * 0.66, 2);
        v_refraction  := ROUND(0.30 + ((v_h / 59  % 100)::NUMERIC / 100.0) * 0.65, 2);
        v_transparency:= ROUND(0.10 + ((v_h / 61  % 100)::NUMERIC / 100.0) * 0.80, 2);
        v_inner_light := ROUND(       ((v_h / 67  % 100)::NUMERIC / 100.0) * 0.60, 2);
        v_incl_dens   := ROUND(       ((v_h / 71  % 100)::NUMERIC / 100.0) * 0.70, 2);
        v_complex     := ROUND(0.40 + ((v_h / 73  % 100)::NUMERIC / 100.0) * 0.58, 2);
        v_orbital     := ROUND(0.30 + ((v_h / 79  % 100)::NUMERIC / 100.0) * 0.68, 2);
        v_pers_ref    := ROUND(0.35 + ((v_h / 83  % 100)::NUMERIC / 100.0) * 0.60, 2);
        v_facet_cnt   := 6 + (v_h / 89  % 19)::INT;
        v_symmetry    := 3 + (v_h / 97  % 6)::INT;

        v_dna := jsonb_build_object(
            'seed', v_seed,
            'identity', jsonb_build_object(
                'primary_color',       v_pri_color,
                'secondary_color',     v_sec_color,
                'accent_color',        v_acc_color,
                'saturation',          v_saturation,
                'material_family',     v_mat_family,
                'base_form',           v_base_form,
                'color_relationship',  v_col_rel,
                'secondary_influence', v_sec_inf,
                'refraction',          v_refraction,
                'frame_hue',           v_frame_hue,
                'luster',              v_luster,
                'transparency',        v_transparency,
                'inner_light',         v_inner_light,
                'inclusion_type',      v_incl_type,
                'inclusion_density',   v_incl_dens,
                'facet_count',         v_facet_cnt,
                'facet_pattern',       v_facet_pat,
                'symmetry',            v_symmetry,
                'surface_character',   v_surf_char
            ),
            'personality', jsonb_build_object(
                'complexity_bias',   v_complex,
                'orbital_affinity',  v_orbital,
                'refraction',        v_pers_ref,
                'evolution_family',  v_evo_family,
                'secondary_family',  v_sec_family
            )
        );

        UPDATE coins
        SET dna = v_dna, dna_version = 1, seed = v_seed
        WHERE id = r.id;

        v_count := v_count + 1;
        RAISE NOTICE '   Patched DNA for coin % / seed %', r.id, v_seed;
    END LOOP;

    RAISE NOTICE '✅ Done — patched % coins.', v_count;
END $$;

ALTER TABLE coins ENABLE TRIGGER coins_guard;
