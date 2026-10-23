-- =============================================================================
--  nuke_and_remint.sql
--  Favorium — delete all coins/history/favors and remint fresh ones per user
--
--  Run in Supabase SQL Editor (Dashboard → SQL Editor → New query → Run).
-- =============================================================================

DO $$
DECLARE
    r       RECORD;
    v_users INT := 0;
BEGIN
    -- ── Step 1: Wipe all transactional data (FK order) ────────────────────────
    DELETE FROM coin_history;
    DELETE FROM coins;
    DELETE FROM favors;
    RAISE NOTICE '✅ Step 1 — coin_history, coins, favors cleared.';

    -- ── Step 2: Safety check ──────────────────────────────────────────────────
    SELECT COUNT(*) INTO v_users FROM profiles;
    RAISE NOTICE '   % profile(s) found.', v_users;
    IF v_users = 0 THEN
        RAISE EXCEPTION 'No profiles found — register at least one user first.';
    END IF;

    -- ── Step 3: Remint 2 coins per user ───────────────────────────────────────
    FOR r IN SELECT id, display_name FROM profiles ORDER BY created_at LOOP
        PERFORM mint_coin(r.id);
        PERFORM mint_coin(r.id);
        RAISE NOTICE '   Minted 2 gems for: % (%)', r.display_name, r.id;
    END LOOP;

    RAISE NOTICE '✅ Done — minted % coins across % users.', v_users * 2, v_users;
END $$;

-- =============================================================================
--  Verification — uncomment and run separately to confirm:
-- =============================================================================
--
-- SELECT
--     c.name,
--     p.display_name                       AS owner,
--     c.dna->'identity'->>'primary_color'  AS primary_color,
--     c.dna->'identity'->>'base_form'      AS base_form,
--     c.transfer_count,
--     c.created_at
-- FROM coins c
-- JOIN profiles p ON p.id = c.owner_id
-- ORDER BY c.created_at;
