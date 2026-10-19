-- =============================================================================
--  nuke_and_remint.sql
--  Favorium — delete all coins/history/favors and remint fresh ones per user
--
--  Run in Supabase SQL Editor (Dashboard → SQL Editor → New query → Run).
-- =============================================================================

-- Step 1: Disable security triggers so we can delete freely
ALTER TABLE coin_history DISABLE TRIGGER guard_history;
ALTER TABLE coins        DISABLE TRIGGER guard_coins;

-- Step 2: Nuke and remint inside a single transaction
DO $$
DECLARE
    r       RECORD;
    v_users INT := 0;
BEGIN
    DELETE FROM coin_history;
    DELETE FROM coins;
    DELETE FROM favors;
    RAISE NOTICE '✅ Step 1 — coin_history, coins, favors cleared.';

    SELECT COUNT(*) INTO v_users FROM profiles;
    RAISE NOTICE '   % profile(s) found.', v_users;
    IF v_users = 0 THEN
        RAISE EXCEPTION 'No profiles found — register at least one user first.';
    END IF;

    FOR r IN SELECT id, display_name FROM profiles ORDER BY created_at LOOP
        PERFORM mint_coin(r.id);
        PERFORM mint_coin(r.id);
        RAISE NOTICE '   Minted 2 gems for: % (%)', r.display_name, r.id;
    END LOOP;

    RAISE NOTICE '✅ Done — minted % coins across % users.', v_users * 2, v_users;
END $$;

-- Step 3: Re-enable both triggers
ALTER TABLE coin_history ENABLE TRIGGER guard_history;
ALTER TABLE coins        ENABLE TRIGGER guard_coins;
