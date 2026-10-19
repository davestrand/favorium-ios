-- Run this first to see the actual trigger names on both tables
SELECT
    trigger_name,
    event_object_table  AS table_name,
    event_manipulation  AS event,
    action_timing       AS timing
FROM information_schema.triggers
WHERE event_object_table IN ('coins', 'coin_history', 'favors')
ORDER BY event_object_table, trigger_name;
