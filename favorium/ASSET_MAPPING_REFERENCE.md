# 🗺️ Asset File Mapping Reference

## Complete Asset Structure

```
FavoriumFantasyProduction/
│
├── Gemstones (8 files, grayscale 512×512)
│   ├── gem_brilliant.png        → GemShape.brilliant
│   ├── gem_heart.png            → GemShape.heart
│   ├── gem_star.png             → GemShape.star
│   ├── gem_hexagon.png          → GemShape.hexagon
│   ├── gem_octagon.png          → GemShape.octagon
│   ├── gem_pear.png             → GemShape.pear
│   ├── gem_marquise.png         → GemShape.marquise
│   └── gem_cushion.png          → GemShape.cushion
│
└── Frames (24 files, grayscale 512×512 with transparent openings)
    │
    ├── Bronze Tier (0-4 transfers)
    │   ├── frame_bronze_brilliant.png
    │   ├── frame_bronze_heart.png
    │   ├── frame_bronze_star.png
    │   ├── frame_bronze_hexagon.png
    │   ├── frame_bronze_octagon.png
    │   ├── frame_bronze_pear.png
    │   ├── frame_bronze_marquise.png
    │   └── frame_bronze_cushion.png
    │
    ├── Silver Tier (5-29 transfers)
    │   ├── frame_silver_brilliant.png
    │   ├── frame_silver_heart.png
    │   ├── frame_silver_star.png
    │   ├── frame_silver_hexagon.png
    │   ├── frame_silver_octagon.png
    │   ├── frame_silver_pear.png
    │   ├── frame_silver_marquise.png
    │   └── frame_silver_cushion.png
    │
    └── Gold Tier (30+ transfers)
        ├── frame_gold_brilliant.png
        ├── frame_gold_heart.png
        ├── frame_gold_star.png
        ├── frame_gold_hexagon.png
        ├── frame_gold_octagon.png
        ├── frame_gold_pear.png
        ├── frame_gold_marquise.png
        └── frame_gold_cushion.png
```

---

## Code-to-Asset Mapping

### Shape Enum → Gemstone Assets

```swift
enum GemShape: String {
    case brilliant    // → "gem_brilliant"
    case heart        // → "gem_heart"
    case star         // → "gem_star"
    case hexagon      // → "gem_hexagon"
    case octagon      // → "gem_octagon"
    case pear         // → "gem_pear"
    case marquise     // → "gem_marquise"
    case cushion      // → "gem_cushion"
}
```

**Asset name construction:**
```swift
private var gemAssetName: String {
    "gem_\(shape.rawValue)"
}
```

### Tier Enum → Frame Assets

```swift
enum FrameTier: String {
    case bronze    // 0-4 transfers   → "frame_bronze_*"
    case silver    // 5-29 transfers  → "frame_silver_*"
    case gold      // 30+ transfers   → "frame_gold_*"
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

// Unknown      → .brilliant  ✅ Fallback
```

---

## Transfer Count → Frame Tier

Automatic mapping in `FrameTier.from(transferCount:)`:

```swift
transferCount in 0..<5      → .bronze
transferCount in 5..<30     → .silver
transferCount in 30..<50    → .gold
transferCount >= 50         → .gold
```

Matches the existing tier system in `DecorativeFrame` from `MagicalCrystalView.swift`.

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
→ FrameTier.gold  // (30+ transfers)

// Step 3: Asset names
gemAssetName = "gem_heart"
frameAssetName = "frame_gold_heart"

// Step 4: Load from Assets.xcassets
Image("gem_heart")        // ← Must exist in Assets.xcassets
Image("frame_gold_heart") // ← Must exist in Assets.xcassets

// Step 5: Tint with colors
gemColor = Color(hue: model.primaryHue / 360.0, ...)
frameColor = FrameTier.gold.defaultColor  // Gold: hue 0.15

// Step 6: Render
FavorGemView displays the tinted, layered gem!
```

---

## Asset Requirements Checklist

For **each** of the 32 assets:

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
gem_brilliant.png           ← Gemstone (no tier)
frame_bronze_brilliant.png  ← Frame (includes tier)
```

### Why This Matters

The code constructs asset names programmatically:

```swift
// ✅ Correct
"gem_\(shape.rawValue)"                    // gem_heart
"frame_\(tier.rawValue)_\(shape.rawValue)" // frame_gold_heart

// ❌ Wrong (won't load)
"gem-\(shape)"              // gem-heart (hyphen)
"frame_\(shape)_\(tier)"    // frame_heart_gold (wrong order)
"\(tier)_\(shape)_frame"    // gold_heart_frame (wrong order)
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
│ 0 - 4       │ Bronze   │ Simple border       │
│ 5 - 29      │ Silver   │ + Decorative dots   │
│ 30 - 49     │ Gold     │ + Wings/rays        │
│ 50+         │ Gold     │ Same as 30-49       │
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
├── frame_bronze_brilliant
│   └── frame_bronze_brilliant.png (→ Template Image)
├── frame_bronze_heart
│   └── frame_bronze_heart.png (→ Template Image)
│
... (all 32 assets)
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
✅ All 32 files visible in Assets.xcassets
✅ Each asset name matches exactly (case-sensitive)
✅ "Render As: Template Image" set for ALL assets
✅ No compile errors when building
✅ FavorGemGallery preview shows colored gems (not gray)
✅ Frames align perfectly with gems (no offset/scaling issues)
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
