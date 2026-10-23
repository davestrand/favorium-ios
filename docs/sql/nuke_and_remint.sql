-- =============================================================================
--  nuke_and_remint.sql
--  Favorium — delete all coins/history/favors and remint fresh ones per user
--
--  Run in Supabase SQL Editor (Dashboard → SQL Editor → New query → Run).
--
--  What it does:
--    1. Deletes all coin_history, coins, and favors rows (test data only).
--    2. Keeps all auth.users and profiles rows intact — no re-registering needed.
--    3. Calls mint_coin() for each profile to give every user 2 fresh gems,
--       exactly as the handle_new_user() trigger does at sign-up.
--
--  Prerequisites:
--    • A mint_coin(p_owner UUID) function exists in your database.
--      (This is what handle_new_user() calls at sign-up.)
--    • If your minting function has a different name or signature, update
--      the call in Step 3 below.
-- =============================================================================

BEGIN;

-- ── Step 1: Wipe all transactional data (FK order) ───────────────────────────
DELETE FROM coin_history;
DELETE FROM coins;
DELETE FROM favors;

RAISE NOTICE '✅ Step 1 complete — coin_history, coins, favors cleared.';

-- ── Step 2: Verify profiles are still intact ─────────────────────────────────
DO $$
DECLARE
    v_profile_count INT;
BEGIN
    SELECT COUNT(*) INTO v_profile_count FROM profiles;
    RAISE NOTICE '   % profile(s) found — will remint for each.', v_profile_count;

    IF v_profile_count = 0 THEN
        RAISE EXCEPTION 'No profiles found! Have you registered any users?';
    END IF;
END $$;

-- ── Step 3: Remint 2 coins per user ──────────────────────────────────────────
-- This mirrors what handle_new_user() does at sign-up.
-- Adjust the number of SELECT mint_coin(...) calls if your trigger mints
-- a different number of gems per user.
DO $$
DECLARE
    r           RECORD;
    v_count     INT := 0;
BEGIN
    FOR r IN SELECT id, display_name FROM profiles ORDER BY created_at LOOP
        -- Mint coin 1
        PERFORM mint_coin(r.id);
        -- Mint coin 2
        PERFORM mint_coin(r.id);

        v_count := v_count + 1;
        RAISE NOTICE '   Minted 2 gems for: % (%)', r.display_name, r.id;
    END LOOP;

    RAISE NOTICE '✅ Step 3 complete — minted 2 coins × % users = % coins total.',
        v_count, v_count * 2;
END $$;

COMMIT;

-- =============================================================================
--  Verification — run after the script to confirm:
-- =============================================================================
--
-- SELECT
--     c.name,
--     p.display_name     AS owner,
--     c.dna->>'seed'     AS seed,
--     c.dna->'identity'->>'primary_color'  AS primary_color,
--     c.dna->'identity'->>'base_form'      AS base_form,
--     c.transfer_count,
--     c.created_at
-- FROM coins c
-- JOIN profiles p ON p.id = c.owner_id
-- ORDER BY c.created_at;
