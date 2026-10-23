# Favorium Gemstone Asset System

## Quick Start

### 1. Add the PNG assets to your Xcode project

Place all 32 images from `FavoriumFantasyProduction` into `Assets.xcassets`:
- 8 gem images: `gem_brilliant.png`, `gem_heart.png`, etc.
- 24 frame images: `frame_bronze_brilliant.png`, `frame_silver_heart.png`, etc.

**Important**: Set each image's "Render As" property to **Template Image** in the Attributes Inspector.

### 2. Use the views in your code

```swift
import SwiftUI

// Simple static gem
FavorGemView(
    shape: .heart,
    gemColor: .pink,
    frameTier: .gold,
    size: 200
)

// Animated gem with pulse and rotation
AnimatedFavorGemView(
    shape: .star,
    gemColor: .cyan,
    frameTier: .silver,
    size: 280
)

// From existing CrystalModel
let model: CrystalModel = // ...
FavorGemView(model: model, size: 200)
```

## Files Included

| File | Purpose |
|------|---------|
| `FavorGemView.swift` | Main implementation - enums, views, gallery |
| `FavorGemExamples.swift` | Usage examples and code patterns |
| `ASSET_INTEGRATION_GUIDE.md` | Comprehensive documentation |
| `README_ASSETS.md` | This file |

## Key Components

### GemShape Enum
Eight shapes matching your assets:
```swift
.brilliant, .heart, .star, .hexagon, .octagon, .pear, .marquise, .cushion
```

### FrameTier Enum
Three complexity levels:
```swift
.bronze  // 0-4 transfers
.silver  // 5-29 transfers
.gold    // 30+ transfers
```

### FavorGemView
Main component for static gems:
```swift
FavorGemView(
    shape: GemShape,
    gemColor: Color,
    frameTier: FrameTier,
    frameColor: Color? = nil,
    size: CGFloat = 200,
    showGlow: Bool = true,
    showShimmer: Bool = false
)
```

### AnimatedFavorGemView
Enhanced version with automatic animations:
```swift
AnimatedFavorGemView(
    shape: GemShape,
    gemColor: Color,
    frameTier: FrameTier,
    frameColor: Color? = nil,
    size: CGFloat = 200
)
```

### FavorGemGallery
Interactive demo for testing all combinations:
```swift
#Preview("Gallery") {
    FavorGemGallery()
}
```

## Common Patterns

### List Item
```swift
HStack {
    FavorGemView(
        shape: .heart,
        gemColor: .pink,
        frameTier: .bronze,
        size: 50,
        showGlow: false,
        showShimmer: false
    )
    Text("Heart Crystal")
}
```

### Grid Display
```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
    ForEach(gems) { gem in
        FavorGemView(model: gem.model, size: 120)
    }
}
```

### Hero View
```swift
VStack {
    AnimatedFavorGemView(model: crystal.model, size: 320)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    
    Text(crystal.name)
        .font(.title.bold())
}
```

### Badge Overlay
```swift
CardView()
    .gemBadge(
        shape: .star,
        color: .yellow,
        tier: .gold,
        size: 40,
        alignment: .topTrailing
    )
```

## Integration Strategy

You now have **two rendering systems**:

1. **`FavorGemView`** (asset-based) - Fast, consistent, battery-friendly
2. **`MagicalCrystalView`** (procedural) - Rich effects, unique variations

### Recommended Usage

| Scenario | Use |
|----------|-----|
| List/grid items | `FavorGemView` |
| Small thumbnails | `FavorGemView` |
| Static displays | `FavorGemView` |
| Detail hero view | `AnimatedFavorGemView` or `MagicalCrystalView` |
| Special effects | `MagicalCrystalView` with surface effects |

Both systems work with the same `CrystalModel`, so you can mix and match based on needs.

## Pre-Defined Colors

Use `GemColorPalettes` for classic gemstone colors:

```swift
import FavorGemExamples

FavorGemView(
    shape: .brilliant,
    gemColor: GemColorPalettes.ruby,
    frameTier: .gold,
    frameColor: GemColorPalettes.gold
)
```

Available palettes:
- `ruby`, `sapphire`, `emerald`, `amethyst`, `topaz`, `aquamarine`
- `celestial`, `void`, `ethereal`, `inferno`, `frost`
- Frame colors: `bronze`, `silver`, `gold`, `platinum`, `roseGold`, `blackGold`

## Testing

Run the built-in previews:

```swift
#Preview("Gallery") { FavorGemGallery() }
#Preview("Evolution") { TransferEvolutionExample() }
#Preview("Color Palettes") { ColorPaletteGallery() }
```

Or add the gallery to your app for interactive testing.

## Performance

Asset-based gems are **much faster** than procedural rendering:
- No `Canvas` or `TimelineView` overhead
- Images cached by system
- Battery-friendly static display
- Only `AnimatedFavorGemView` has continuous animations

For lists with many items, use static `FavorGemView` with `showGlow: false` and `showShimmer: false`.

## Troubleshooting

**Assets not showing?**
1. Verify images are in `Assets.xcassets`
2. Check "Render As: Template Image" is set
3. Clean build folder (Cmd+Shift+K)
4. Ensure filenames match exactly (case-sensitive)

**Colors not tinting?**
- Images must be grayscale PNG with alpha channel
- `.renderingMode(.template)` must be applied (already in code)

**Frame not aligned?**
- Both gem and frame must be 512×512 px
- Frame opening must be centered in the image
- Do not modify the frame/gem sizing in code

## Next Steps

1. ✅ Add all 32 PNG files to `Assets.xcassets`
2. ✅ Set each to "Template Image" rendering mode
3. ✅ Run the `FavorGemGallery` preview to verify
4. ✅ Replace existing crystal views where appropriate
5. ✅ Customize colors and effects to match your design

## Questions?

See `ASSET_INTEGRATION_GUIDE.md` for comprehensive documentation, or check `FavorGemExamples.swift` for code patterns.

---

Created by Assistant • October 14, 2026
