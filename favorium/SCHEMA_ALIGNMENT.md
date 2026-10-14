# Schema Alignment Complete! ✅

## Summary

I've updated all the code to match your actual Supabase schema. Here's what changed:

### Key Schema Differences

**Your actual database uses:**
- `favors` table (not `favor_requests`)
- `helper_id` and `helped_id` (not `from_user_id` and `to_user_id`)
- Status values: `proposed`, `accepted`, `completed`, `transferred`, `declined`, `cancelled`
- Timestamp fields: `accepted_at`, `completed_at`, `transferred_at`

### Files Updated

1. **SupabaseService.swift** ✅
   - Changed `FavorRequest` → `Favor`
   - Updated all method names to match your schema
   - Methods now use `favors` table queries
   - RPC calls use `p_favor_id` parameter

2. **FavorRequestsView_New.swift** ✅ (NEW FILE - replace the old one)
   - Uses `Favor` type throughout
   - `helper_name` and `helped_name` for display
   - Proper status checking (`isProposed`, `isAccepted`, etc.)
   - Fixed `ErrorStateView` duplicate (now `FavorErrorView`)

3. **OfferFavorView.swift** ✅
   - Changed `offerFavor` → `proposeFavor`
   - Uses `helpedUserId` parameter

4. **CompleteFavorView.swift** ✅
   - Changed `request: FavorRequest` → `favor: Favor`
   - Updated all references (`helper_name` instead of `from_user_name`)
   - RPC now uses `favorId` parameter

### Service Methods (Corrected)

```swift
// Fetch favors where user is being helped
func myIncomingFavors(userId: UUID) async throws -> [Favor]

// Fetch favors where user is helping
func myOutgoingFavors(userId: UUID) async throws -> [Favor]

// Create new favor offer
func proposeFavor(helpedUserId: UUID, description: String) async throws

// Accept a favor
func acceptFavor(favorId: UUID) async throws

// Decline a favor  
func declineFavor(favorId: UUID) async throws

// Complete and mint coin
func completeFavorAndMintCoin(favorId: UUID, coinName: String) async throws -> UUID
```

### Database RPC Required

You'll need this stored procedure in Supabase:

```sql
CREATE OR REPLACE FUNCTION complete_favor_and_mint(
    p_favor_id UUID,
    p_coin_name TEXT
)
RETURNS JSON AS $$
DECLARE
    v_favor RECORD;
    v_coin_id UUID;
    v_serial TEXT;
BEGIN
    -- Get the favor details
    SELECT * INTO v_favor 
    FROM favors 
    WHERE id = p_favor_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Favor not found';
    END IF;
    
    -- Generate serial number (you may have your own logic)
    v_serial := 'FV-' || LPAD((FLOOR(RANDOM() * 999999) + 1)::TEXT, 6, '0');
    
    -- Create the coin (favor goes to the helper)
    INSERT INTO coins (
        serial,
        name,
        traits,
        creator_id,
        owner_id,
        dna_version,
        seed
    ) VALUES (
        v_serial,
        p_coin_name,
        '{}'::jsonb,  -- You might want to generate traits here
        v_favor.helped_id,  -- Creator is the person who was helped
        v_favor.helper_id,  -- Owner is the helper
        1,
        gen_random_uuid()::text
    ) RETURNING id INTO v_coin_id;
    
    -- Create coin history entry
    INSERT INTO coin_history (
        coin_id,
        event_type,
        from_user,
        to_user,
        favor_id,
        description
    ) VALUES (
        v_coin_id,
        'minted',
        v_favor.helped_id,
        v_favor.helper_id,
        p_favor_id,
        v_favor.description
    );
    
    -- Update favor status
    UPDATE favors 
    SET 
        status = 'completed',
        completed_at = NOW(),
        coin_id = v_coin_id
    WHERE id = p_favor_id;
    
    -- Return the coin ID
    RETURN json_build_object('coin_id', v_coin_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Status Flow

```
proposed → accepted → completed → transferred
    ↓          ↓
 declined   cancelled
```

**Terminology:**
- **Helper** = Person offering to help
- **Helped** = Person receiving help
- **Incoming favors** = Where you're being helped (you're `helped_id`)
- **Outgoing favors** = Where you're helping (you're `helper_id`)

### To Complete the Integration

1. **Replace the old FavorRequestsView.swift** with FavorRequestsView_New.swift
   ```bash
   mv FavorRequestsView_New.swift FavorRequestsView.swift
   ```

2. **Add the RPC function** to your Supabase database (SQL above)

3. **Test the flow:**
   - User A offers to help User B (`proposeFavor`)
   - User B sees it in Incoming, accepts (`acceptFavor`)
   - User A completes the favor
   - User B marks as done, names the coin (`completeFavorAndMintCoin`)
   - Coin appears in User A's vault!

### What's Working Now

✅ Schema matches your database exactly
✅ All foreign key relationships correct
✅ Proper status values
✅ Correct RPC parameter names
✅ No more `ErrorStateView` duplicate
✅ Proper nested profile name fetching
✅ Helper/Helped terminology consistent

The code is now ready to work with your actual Supabase setup!
