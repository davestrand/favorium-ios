# Favorium - Offer/Accept/Done Workflow

## Overview
This document describes the complete workflow for offering, accepting, and completing favors in the Favorium iOS app.

## The Complete Flow

### 1. **Offer a Favor** (Helper's Perspective)
**File:** `OfferFavorView.swift`

The helper initiates by offering to help someone:
- Search for users by display name
- Describe what they're offering to help with
- Send the offer

**Features:**
- Debounced user search (300ms delay)
- Character limit (500 chars)
- Real-time validation
- Success animation with auto-dismiss
- Loading overlay during submission

**User Experience:**
```
Tap "+" → Search for recipient → Type description → Send Offer
     ↓
"Favor Offered!" → Auto-dismiss after 2 seconds
```

---

### 2. **View & Accept Requests** (Recipient's Perspective)
**File:** `FavorRequestsView.swift`

Recipients see incoming favor offers and can manage them:
- **Incoming Tab:** Offers from others (things they'll receive help with)
- **Outgoing Tab:** Offers they've made (things they'll help with)

**Incoming Request Actions:**
- **Pending:** Accept or Decline
- **Accepted:** Mark as Done & Give Favor (opens completion flow)
- **Completed:** Shows completion badge
- **Declined:** Hidden from view

**Features:**
- Status badges (color-coded by state)
- Relative timestamps ("2 days ago")
- Pull-to-refresh
- Empty states with helpful messages
- Segmented control for Incoming/Outgoing

---

### 3. **Complete & Give Favor** (Recipient's Perspective)
**File:** `CompleteFavorView.swift`

After the favor is completed, the recipient creates a beautiful Favor coin:
- Review what the helper did
- Name the Favor with a poetic name (e.g., "Amber Hearth")
- See a preview of the coin
- Create and give the Favor

**Features:**
- Beautiful gradient animations
- Name suggestions for inspiration
- Real-time preview with procedurally colored gem
- Character limit (50 chars)
- Success animation with auto-dismiss
- Loading state during creation

**User Experience:**
```
Mark as Done → Name the Favor → Preview → Create & Give
         ↓
"Favor Given!" → Coin minted → Auto-dismiss after 2.5 seconds
```

---

## Service Layer Integration

### New Methods in `SupabaseService.swift`

#### Favor Requests
```swift
// Fetch incoming offers (where you're the recipient)
func myIncomingRequests(userId: UUID) async throws -> [FavorRequest]

// Fetch outgoing offers (where you're the helper)
func myOutgoingRequests(userId: UUID) async throws -> [FavorRequest]

// Create a new favor offer
func offerFavor(toUserId: UUID, description: String) async throws

// Accept an incoming request
func acceptFavorRequest(requestId: UUID) async throws

// Decline an incoming request
func declineFavorRequest(requestId: UUID) async throws

// Complete favor and mint coin (calls RPC)
func completeFavorAndMintCoin(requestId: UUID, coinName: String) async throws -> UUID
```

#### User Management
```swift
// Search for users by display name
func searchUsers(query: String) async throws -> [UserProfile]

// Get specific user profile
func getUserProfile(userId: UUID) async throws -> UserProfile
```

---

## Data Models

### FavorRequest
```swift
struct FavorRequest: Decodable, Identifiable, Sendable {
    let id: UUID
    let from_user_id: UUID
    let to_user_id: UUID
    let description: String
    let status: String // 'pending', 'accepted', 'completed', 'declined'
    let created_at: String
    let updated_at: String?
    let from_user_name: String?
    let to_user_name: String?
    
    // Computed properties
    var isPending: Bool
    var isAccepted: Bool
    var isCompleted: Bool
    var isDeclined: Bool
}
```

### UserProfile
```swift
struct UserProfile: Decodable, Identifiable, Sendable {
    let id: UUID
    let display_name: String?
    let created_at: String?
    
    var displayName: String // with fallback
}
```

---

## Database Requirements

### Tables Needed

#### `favor_requests`
```sql
- id: UUID (primary key)
- from_user_id: UUID (foreign key to profiles)
- to_user_id: UUID (foreign key to profiles)
- description: TEXT
- status: TEXT (pending, accepted, completed, declined)
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
```

#### `profiles`
```sql
- id: UUID (primary key, matches auth.users)
- display_name: TEXT
- created_at: TIMESTAMP
```

### RPC Function Needed

#### `complete_favor_and_mint`
```sql
-- Parameters:
-- p_request_id: UUID
-- p_coin_name: TEXT
-- 
-- Returns: { coin_id: UUID }
--
-- This function should:
-- 1. Update favor_requests.status = 'completed'
-- 2. Create a new coin record
-- 3. Set owner_id to from_user_id (the helper gets the coin)
-- 4. Return the new coin_id
```

---

## UI/UX Features

### Visual Design
- **Gradient themes** throughout (purple/pink for favors)
- **Status-based color coding:**
  - 🟠 Orange = Pending
  - 🟢 Green = Accepted
  - 🟣 Purple = Completed
  - 🔴 Red = Declined
- **Smooth animations** and transitions
- **Auto-dismiss** on success (reduces friction)

### User Feedback
- Loading states with spinners
- Error messages with retry options
- Empty states with helpful guidance
- Success celebrations with icons and animations

### Accessibility
- Clear labels with SF Symbols
- Semantic colors
- Readable fonts
- Touch-friendly hit areas

---

## Navigation Flow

```
MainView (Coins List)
    ├─ Toolbar: Favor Requests Icon
    │   └─ FavorRequestsView
    │       ├─ Toolbar: + Button → OfferFavorView (sheet)
    │       ├─ Incoming Tab
    │       │   └─ Tap "Mark as Done" → CompleteFavorView (sheet)
    │       └─ Outgoing Tab
    └─ Tap any coin → CoinDetailView
        └─ See journey timeline
```

---

## Next Steps / Future Enhancements

1. **Push Notifications**
   - Notify when someone offers you a favor
   - Notify when someone accepts your offer
   - Notify when you receive a new Favor coin

2. **Connections System**
   - Friend/connection management
   - Quick access to frequent collaborators

3. **Favor History**
   - "Favors I've Carried" section
   - Visual timeline of your participation in favor journeys

4. **Enhanced Coin Generation**
   - More sophisticated visual representation
   - Use actual DNA/traits data
   - 3D gem rendering

5. **Social Features**
   - Share favor journeys
   - Leaderboards (most helpful, most connected)
   - Badges/achievements

---

## Testing Checklist

- [ ] Offer a favor to another user
- [ ] Search finds correct users
- [ ] Can't send with empty description
- [ ] Accept a pending request
- [ ] Decline a pending request
- [ ] Complete an accepted request
- [ ] Coin is minted and appears in helper's vault
- [ ] Journey timeline shows all events
- [ ] Pull-to-refresh updates requests
- [ ] Empty states display correctly
- [ ] Error handling works properly

---

## Files Created

1. ✅ `OfferFavorView.swift` - Offer a favor workflow
2. ✅ `FavorRequestsView.swift` - View and manage requests
3. ✅ `CompleteFavorView.swift` - Complete favor and mint coin
4. ✅ Extended `SupabaseService.swift` - Service methods

## Files Modified

1. ✅ `MainView.swift` - Added navigation to favor requests
2. ✅ `SupabaseService.swift` - Added favor request methods

---

Created: October 5, 2026
Last Updated: October 5, 2026
