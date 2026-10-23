-- =============================================================================
--  nuke_and_remint.sql
--  Favorium — delete all coins/history/favors and remint fresh ones per user
-- =============================================================================

-- Step 1: Disable security triggers
ALTER TABLE coin_history DISABLE TRIGGER history_guard;
ALTER TABLE coins        DISABLE TRIGGER coins_guard;

-- Step 2: Nuke and remint
DO $$
DECLARE
    r       RECORD;
    v_users INT := 0;
BEGIN
    -- FK order: coin_history → favors → coins
    DELETE FROM coin_history;
    DELETE FROM favors;
    DELETE FROM coins;
    RAISE NOTICE '✅ Cleared coin_history, favors, coins.';

    SELECT COUNT(*) INTO v_users FROM profiles;
    IF v_users = 0 THEN
        RAISE EXCEPTION 'No profiles found — register at least one user first.';
    END IF;
    RAISE NOTICE '   % profile(s) found.', v_users;

    FOR r IN SELECT id, display_name FROM profiles ORDER BY created_at LOOP
        PERFORM mint_coin(r.id);
        PERFORM mint_coin(r.id);
        RAISE NOTICE '   Minted 2 gems for: % (%)', r.display_name, r.id;
    END LOOP;

    RAISE NOTICE '✅ Done — % coins minted across % users.', v_users * 2, v_users;
END $$;

-- Step 3: Re-enable triggers
ALTER TABLE coin_history ENABLE TRIGGER history_guard;
ALTER TABLE coins        ENABLE TRIGGER coins_guard;
