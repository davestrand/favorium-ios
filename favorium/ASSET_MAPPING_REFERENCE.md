# 🗺️ Asset File Mapping Reference

## Complete Asset Structure

```
FavoriumFantasyProduction/
│
├── Gemstones (12 files total)
│   ├── Legacy System (8 files, grayscale 512×512)
│   │   ├── gem_brilliant.png        → GemShape.brilliant (all tiers)
│   │   ├── gem_heart.png            → GemShape.heart (all tiers)
│   │   ├── gem_star.png             → GemShape.star (all tiers)
│   │   ├── gem_hexagon.png          → GemShape.hexagon (all tiers)
│   │   ├── gem_octagon.png          → GemShape.octagon (all tiers)
│   │   ├── gem_pear.png             → GemShape.pear (all tiers)
│   │   ├── gem_marquise.png         → GemShape.marquise (all tiers)
│   │   └── gem_cushion.png          → GemShape.cushion (all tiers)
│   │
│   └── Progressive System (4 files, grayscale 512×512)
│       ├── gem_seed_lightning.png      → GemShape.lightning (Seed tier)
│       ├── gem_bloom_lightning.png     → GemShape.lightning (Bloom tier)
│       ├── gem_legacy_lightning.png    → GemShape.lightning (Legacy tier)
│       └── gem_radiance_lightning.png  → GemShape.lightning (Radiance tier)
│
└── Frames (36 files, grayscale 512×512 with transparent openings)
    │
    ├── Seed Tier (0-4 transfers)
    │   ├── frame_seed_brilliant.png
    │   ├── frame_seed_heart.png
    │   ├── frame_seed_star.png
    │   ├── frame_seed_hexagon.png
    │   ├── frame_seed_octagon.png
    │   ├── frame_seed_pear.png
    │   ├── frame_seed_marquise.png
    │   ├── frame_seed_cushion.png
    │   └── frame_seed_lightning.png
    │
    ├── Bloom Tier (5-14 transfers)
    │   ├── frame_bloom_brilliant.png
    │   ├── frame_bloom_heart.png
    │   ├── frame_bloom_star.png
    │   ├── frame_bloom_hexagon.png
    │   ├── frame_bloom_octagon.png
    │   ├── frame_bloom_pear.png
    │   ├── frame_bloom_marquise.png
    │   ├── frame_bloom_cushion.png
    │   └── frame_bloom_lightning.png
    │
    ├── Legacy Tier (15-29 transfers)
    │   ├── frame_legacy_brilliant.png
    │   ├── frame_legacy_heart.png
    │   ├── frame_legacy_star.png
    │   ├── frame_legacy_hexagon.png
    │   ├── frame_legacy_octagon.png
    │   ├── frame_legacy_pear.png
    │   ├── frame_legacy_marquise.png
    │   ├── frame_legacy_cushion.png
    │   └── frame_legacy_lightning.png
    │
    └── Radiance Tier (30+ transfers)
        ├── frame_radiance_brilliant.png
        ├── frame_radiance_heart.png
        ├── frame_radiance_star.png
        ├── frame_radiance_hexagon.png
        ├── frame_radiance_octagon.png
        ├── frame_radiance_pear.png
        ├── frame_radiance_marquise.png
        ├── frame_radiance_cushion.png
        └── frame_radiance_lightning.png
```

---

## Code-to-Asset Mapping

### Shape Enum → Gemstone Assets

```swift
enum GemShape: String {
    case brilliant    // → "gem_brilliant" (all tiers)
    case heart        // → "gem_heart" (all tiers)
    case star         // → "gem_star" (all tiers)
    case hexagon      // → "gem_hexagon" (all tiers)
    case octagon      // → "gem_octagon" (all tiers)
    case pear         // → "gem_pear" (all tiers)
    case marquise     // → "gem_marquise" (all tiers)
    case cushion      // → "gem_cushion" (all tiers)
    case lightning    // → "gem_{tier}_lightning" (tier-specific!)
}
```

**Asset name construction:**

Legacy System (8 shapes):
```swift
private var gemAssetName: String {
    "gem_\(shape.rawValue)"  // Single gem for all tiers
}
```

Progressive System (Lightning):
```swift
private var gemAssetName: String {
    if shape == .lightning {
        return "gem_\(frameTier.rawValue)_lightning"  // Tier-specific gem!
    }
    return "gem_\(shape.rawValue)"
}
```

### Tier Enum → Frame Assets

```swift
enum FrameTier: String {
    case seed       // 0-4 transfers   → "frame_seed_*"
    case bloom      // 5-14 transfers  → "frame_bloom_*"
    case legacy     // 15-29 transfers → "frame_legacy_*"
    case radiance   // 30+ transfers   → "frame_radiance_*"
}
```

**Asset name construction:**
```swift
private var frameAssetName: String {
    "frame_\(frameTier.rawValue)_\(shape.rawValue)"
}
```

---

## CrystalModel Base Forms → GemShape

Automatic mapping in `GemShape.from(baseForm:)`:

```swift
// Existing baseForm strings → GemShape
"brilliant"    → .brilliant
"diamond"      → .brilliant  ✅ Alias
"circle"       → .brilliant  ✅ Alias
"round"        → .brilliant  ✅ Alias

"heart"        → .heart

"star"         → .star

"hexagon"      → .hexagon
"hex"          → .hexagon    ✅ Alias

"octagon"      → .octagon
"oct"          → .octagon    ✅ Alias

"pear"         → .pear
"teardrop"     → .pear       ✅ Alias

"marquise"     → .marquise

"cushion"      → .cushion

"lightning"    → .lightning
"bolt"         → .lightning  ✅ Alias

// Unknown      → .brilliant  ✅ Fallback
```

---

## Transfer Count → Frame Tier

Automatic mapping in `FrameTier.from(transferCount:)`:

```swift
transferCount in 0..<5      → .seed
transferCount in 5..<15     → .bloom
transferCount in 15..<30    → .legacy
transferCount >= 30         → .radiance
```

Matches the tier system with four distinct levels.

---

## Asset Loading Flow

### 1. From CrystalModel

```swift
let model: CrystalModel = ...

// Automatic mapping
let shape = GemShape.from(baseForm: model.baseForm)
let tier = FrameTier.from(transferCount: model.transferCount)

// Asset names
let gemAsset = "gem_\(shape.rawValue)"            // e.g., "gem_heart"
let frameAsset = "frame_\(tier.rawValue)_\(shape.rawValue)"  // e.g., "frame_gold_heart"
```

### 2. Loading in SwiftUI

```swift
// Gem
Image("gem_heart")
    .resizable()
    .renderingMode(.template)     // ← Critical for tinting
    .colorMultiply(gemColor)       // Apply color
    .frame(width: size, height: size)

// Frame (same bounds!)
Image("frame_gold_heart")
    .resizable()
    .renderingMode(.template)     // ← Critical for tinting
    .colorMultiply(frameColor)     // Apply color
    .frame(width: size, height: size)
```

### 3. Layering (ZStack)

```swift
ZStack {
    // Layer 1: Glow (optional)
    Circle()
        .fill(RadialGradient(...))
        .blur(radius: size * 0.15)
    
    // Layer 2: Gemstone
    Image(gemAssetName)
        .renderingMode(.template)
        .colorMultiply(gemColor)
    
    // Layer 3: Frame
    Image(frameAssetName)
        .renderingMode(.template)
        .colorMultiply(frameColor)
    
    // Layer 4: Shimmer (optional)
    Rectangle()
        .fill(LinearGradient(...))
        .mask(Image(gemAssetName))
}
```

---

## Complete Example Trace

```swift
// Starting point
let dna = CrystalDNA(
    identity: CrystalIdentity(
        baseForm: "heart",  // ← Input
        // ...
    ),
    // ...
)
let model = CrystalEngine.derive(dna: dna, transferCount: 35)

// Step 1: Shape mapping
model.baseForm == "heart"
→ GemShape.from(baseForm: "heart")
→ GemShape.heart

// Step 2: Tier mapping
model.transferCount == 35
→ FrameTier.from(transferCount: 35)
→ FrameTier.radiance  // (30+ transfers)

// Step 3: Asset names
gemAssetName = "gem_heart"
frameAssetName = "frame_radiance_heart"

// Step 4: Load from Assets.xcassets
Image("gem_heart")              // ← Must exist in Assets.xcassets
Image("frame_radiance_heart")   // ← Must exist in Assets.xcassets

// Step 5: Tint with colors
gemColor = Color(hue: model.primaryHue / 360.0, ...)
frameColor = FrameTier.radiance.defaultColor  // Radiance color

// Step 6: Render
FavorGemView displays the tinted, layered gem!
```

---

## Asset Requirements Checklist

For the **48 total assets** (12 gems + 36 frames):

### Legacy System (32 assets)
- 8 gem files (one per shape, used for all tiers)
- 24 frame files (8 shapes × 3 legacy tiers: seed, bloom, legacy)

### Progressive System - Lightning (16 assets)
- 4 tier-specific gem files (gem_seed_lightning, gem_bloom_lightning, etc.)
- 4 frame files (frame_seed_lightning, frame_bloom_lightning, etc.)
- 8 radiance frames for legacy shapes (frame_radiance_brilliant, etc.)

✅ **File Format**: PNG
✅ **Dimensions**: 512 × 512 pixels (square)
✅ **Color**: Grayscale (no baked-in colors)
✅ **Alpha**: Transparent background
✅ **Gemstones**: Full gemstone shape, no frame
✅ **Frames**: Transparent opening shaped for specific gem
✅ **Xcode Setting**: "Render As: Template Image"

### Critical: Template Image Mode

Without template mode:
❌ Color won't tint
❌ Grayscale will show as gray
❌ Dynamic coloring won't work

With template mode:
✅ Grayscale becomes a "stencil"
✅ `.colorMultiply()` works correctly
✅ Any color can be applied dynamically

---

## Naming Convention Rules

### Pattern

```
{type}_{tier?}_{shape}.png
```

### Examples

```
gem_brilliant.png              ← Gemstone (no tier)
gem_lightning.png              ← Lightning gemstone
frame_seed_brilliant.png       ← Frame (includes tier)
frame_radiance_lightning.png   ← Lightning with Radiance frame
```

### Why This Matters

The code constructs asset names programmatically:

```swift
// ✅ Correct
"gem_\(shape.rawValue)"                    // gem_heart OR gem_lightning
"frame_\(tier.rawValue)_\(shape.rawValue)" // frame_radiance_heart OR frame_bloom_lightning

// ❌ Wrong (won't load)
"gem-\(shape)"              // gem-heart (hyphen)
"frame_\(shape)_\(tier)"    // frame_heart_radiance (wrong order)
"\(tier)_\(shape)_frame"    // radiance_heart_frame (wrong order)
```

---

## Visual Layer Stack

```
┌─────────────────────────────┐
│   4. Shimmer (optional)     │  ← Animated sweep, masked to gem shape
├─────────────────────────────┤
│   3. Frame                  │  ← Transparent center, colored frame
├─────────────────────────────┤
│   2. Gemstone               │  ← Solid gem, colored
├─────────────────────────────┤
│   1. Glow (optional)        │  ← Radial gradient, blurred
└─────────────────────────────┘
```

**Key**: Layers 2 and 3 use **identical frame size** so frame opening aligns perfectly with gem.

---

## Transfer Count Evolution Visual

```
┌─────────────┬──────────┬─────────────────────┐
│ Transfers   │ Tier     │ Frame Style         │
├─────────────┼──────────┼─────────────────────┤
│ 0 - 4       │ Seed     │ Simple border       │
│ 5 - 14      │ Bloom    │ + Decorative dots   │
│ 15 - 29     │ Legacy   │ + Enhanced detail   │
│ 30+         │ Radiance │ + Wings/rays        │
└─────────────┴──────────┴─────────────────────┘
```

**Note**: Frame *visual complexity* matches tier. Color is applied separately via `.colorMultiply()`.

---

## Xcode Assets.xcassets Structure

After adding assets, your project should look like:

```
Assets.xcassets/
├── AppIcon
├── gem_brilliant
│   └── gem_brilliant.png (→ Template Image)
├── gem_heart
│   └── gem_heart.png (→ Template Image)
├── gem_star
│   └── gem_star.png (→ Template Image)
├── gem_hexagon
│   └── gem_hexagon.png (→ Template Image)
├── gem_octagon
│   └── gem_octagon.png (→ Template Image)
├── gem_pear
│   └── gem_pear.png (→ Template Image)
├── gem_marquise
│   └── gem_marquise.png (→ Template Image)
├── gem_cushion
│   └── gem_cushion.png (→ Template Image)
├── gem_lightning
│   └── gem_lightning.png (→ Template Image)
├── frame_seed_brilliant
│   └── frame_seed_brilliant.png (→ Template Image)
├── frame_seed_heart
│   └── frame_seed_heart.png (→ Template Image)
│
... (all 45 assets: 9 gems × 1 + 9 shapes × 4 tiers)
```

Each asset should show:
- **Devices**: Universal
- **Render As**: Template Image ← CRITICAL
- **Resizing**: Preserve Vector Data (optional, for SVG)

---

## Common Mistakes to Avoid

| ❌ Don't | ✅ Do |
|---------|-------|
| Name: `Gem_Heart.png` | Name: `gem_heart.png` (lowercase) |
| Render As: Original Image | Render As: Template Image |
| Gems: 1024×1024 | Gems: 512×512 |
| Frames: 800×800 | Frames: 512×512 (same as gems!) |
| Gems: Pre-colored pink | Gems: Grayscale (tinting does coloring) |
| Frames: Baked bronze color | Frames: Grayscale (tinting does coloring) |
| Add to project root | Add to Assets.xcassets |
| Scale frames differently | Use identical `.frame()` size for gems and frames |

---

## Verification Checklist

After adding assets to Xcode:

```
✅ All 48 files visible in Assets.xcassets
   - 8 legacy gem files (gem_brilliant, gem_heart, etc.)
   - 4 progressive Lightning gem files (gem_seed_lightning, etc.)
   - 36 frame files (all shapes × all tiers)
✅ Each asset name matches exactly (case-sensitive)
✅ "Render As: Template Image" set for ALL assets
✅ No compile errors when building
✅ FavorGemGallery preview shows colored gems (not gray)
✅ Frames align perfectly with gems (no offset/scaling issues)
✅ Lightning gems evolve visually through tiers
✅ Legacy gems display correctly with all tier frames
```

---

## Quick Debug Steps

### Problem: Assets show as gray

**Cause**: Not set to "Template Image"

**Fix**:
1. Select asset in Assets.xcassets
2. Open Attributes Inspector (right sidebar)
3. Set "Render As" → "Template Image"
4. Clean build (Cmd+Shift+K)
5. Rebuild

### Problem: Asset not found

**Cause**: Name mismatch or not in Assets.xcassets

**Fix**:
1. Verify exact filename matches code
2. Check case sensitivity
3. Ensure asset is in Assets.xcassets (not project root)
4. Clean build

### Problem: Frame doesn't align with gem

**Cause**: Different image dimensions or code scaling

**Fix**:
1. Verify both gem and frame are 512×512
2. Check that both use `.frame(width: size, height: size)`
3. Don't add padding/offset to individual layers
4. Frame opening must be centered in asset

---

## That's Everything! 🎉

This reference covers:
✅ Complete asset structure
✅ Code-to-asset mapping
✅ CrystalModel integration
✅ Asset loading flow
✅ Layer stacking
✅ Naming conventions
✅ Common pitfalls
✅ Debug procedures

**Next**: Add those assets and watch the magic happen! ✨💎
