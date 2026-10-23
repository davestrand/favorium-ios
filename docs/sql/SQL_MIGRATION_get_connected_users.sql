-- SQL Migration: Add get_connected_users RPC function
-- This function returns users that the current user has interacted with via favors
-- Ordered by most recent interaction

CREATE OR REPLACE FUNCTION get_connected_users(
    p_user_id UUID,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
    -- Get unique users from favors where current user was either helper or helped
    -- Exclude the current user themselves
    SELECT DISTINCT 
        p.id,
        p.display_name,
        p.created_at
    FROM profiles p
    INNER JOIN favors f ON (
        (f.helper_id = p.id AND f.helped_id = p_user_id) OR
        (f.helped_id = p.id AND f.helper_id = p_user_id)
    )
    WHERE p.id != p_user_id
    ORDER BY f.created_at DESC
    LIMIT p_limit;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_connected_users TO authenticated;
