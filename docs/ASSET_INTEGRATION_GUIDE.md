# Favorium Gemstone & Frame Asset Integration

## Overview

This document explains how to integrate the new asset-based gemstone and frame system into Favorium.

## Files Created

- **`FavorGemView.swift`** - Complete asset-based gem rendering system

## Asset Setup Instructions

### 1. Add Assets to Xcode

1. Open your Xcode project
2. Navigate to `Assets.xcassets` in the project navigator
3. Drag and drop all 32 PNG files from `FavoriumFantasyProduction` folder
4. Ensure each image is set to:
   - **Render As**: Template Image (for dynamic tinting)
   - **Devices**: Universal
   - **Scales**: 1x, 2x, 3x (Xcode will handle this automatically)

### 2. Verify Asset Names

The code expects these exact asset names:

#### Gemstone Assets (8 files):
```
gem_brilliant.png
gem_heart.png
gem_star.png
gem_hexagon.png
gem_octagon.png
gem_pear.png
gem_marquise.png
gem_cushion.png
```

#### Frame Assets (24 files):
```
frame_bronze_brilliant.png
frame_bronze_heart.png
frame_bronze_star.png
frame_bronze_hexagon.png
frame_bronze_octagon.png
frame_bronze_pear.png
frame_bronze_marquise.png
frame_bronze_cushion.png

frame_silver_brilliant.png
frame_silver_heart.png
frame_silver_star.png
frame_silver_hexagon.png
frame_silver_octagon.png
frame_silver_pear.png
frame_silver_marquise.png
frame_silver_cushion.png

frame_gold_brilliant.png
frame_gold_heart.png
frame_gold_star.png
frame_gold_hexagon.png
frame_gold_octagon.png
frame_gold_pear.png
frame_gold_marquise.png
frame_gold_cushion.png
```

## Usage Examples

### Basic Static Gem

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        FavorGemView(
            shape: .heart,
            gemColor: .pink,
            frameTier: .gold,
            size: 200
        )
    }
}
```

### Animated Gem with Pulse and Rotation

```swift
AnimatedFavorGemView(
    shape: .star,
    gemColor: .cyan,
    frameTier: .silver,
    size: 280
)
```

### From Existing CrystalModel

```swift
// Convert your existing CrystalModel to asset-based view
let model: CrystalModel = // ... your model
FavorGemView(model: model, size: 200)

// Or animated version
AnimatedFavorGemView(model: model, size: 280)
```

### Custom Frame Color

```swift
FavorGemView(
    shape: .hexagon,
    gemColor: .blue,
    frameTier: .bronze,
    frameColor: .purple,  // Override default bronze color
    size: 200
)
```

### Without Glow or Shimmer

```swift
FavorGemView(
    shape: .diamond,
    gemColor: .red,
    frameTier: .gold,
    size: 200,
    showGlow: false,      // Disable background glow
    showShimmer: false    // Disable shimmer effect
)
```

## API Reference

### GemShape Enum

Maps to gemstone asset files:

```swift
enum GemShape: String, CaseIterable {
    case brilliant  // Round/diamond cut
    case heart
    case star
    case hexagon
    case octagon
    case pear       // Teardrop shape
    case marquise   // Football/navette shape
    case cushion    // Rounded square
}
```

**Automatic Mapping from CrystalModel:**
- "diamond", "circle", "round" → `.brilliant`
- "teardrop" → `.pear`
- Other shapes map directly by name

### FrameTier Enum

Three complexity levels:

```swift
enum FrameTier: String, CaseIterable {
    case bronze  // Simple elegant border (0-4 transfers)
    case silver  // Ornate with details (5-29 transfers)
    case gold    // Elaborate decorations (30+ transfers)
}
```

**Default Colors:**
- Bronze: Warm copper tone (hue 0.08)
- Silver: Cool gray metallic (hue 0.0, no saturation)
- Gold: Rich yellow gold (hue 0.15)

### FavorGemView

Main reusable component:

```swift
FavorGemView(
    shape: GemShape,
    gemColor: Color,
    frameTier: FrameTier,
    frameColor: Color? = nil,        // Optional override
    size: CGFloat = 200,
    showGlow: Bool = true,           // Background radial glow
    showShimmer: Bool = false        // Animated shine sweep
)
```

**From CrystalModel:**
```swift
FavorGemView(
    model: CrystalModel,
    size: CGFloat = 200,
    customFrameColor: Color? = nil,
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

**Animations:**
- Gentle pulsing glow (2.5s cycle)
- Very slow rotation (60s full rotation)
- Shimmer sweep effect

## Integration with Existing MagicalCrystalView

You can use both systems side by side:

### Option 1: Replace in Specific Views

```swift
// Old procedural version
MagicalCrystalView(model: model, size: 200)

// New asset-based version
FavorGemView(model: model, size: 200)
```

### Option 2: Toggle Between Styles

```swift
struct CrystalDisplayView: View {
    let model: CrystalModel
    @State private var useAssets = true
    
    var body: some View {
        VStack {
            if useAssets {
                FavorGemView(model: model, size: 280)
            } else {
                MagicalCrystalView(model: model, size: 280)
            }
            
            Toggle("Use Asset Graphics", isOn: $useAssets)
        }
    }
}
```

### Option 3: Hybrid Approach

Use asset-based gems for UI elements (lists, grids) and procedural gems for feature presentations:

```swift
// In list/grid views - fast, consistent
List {
    ForEach(crystals) { crystal in
        HStack {
            FavorGemView(model: crystal.model, size: 60)
            Text(crystal.name)
        }
    }
}

// In detail view - rich, animated
VStack {
    MagicalCrystalView(model: selectedCrystal.model, size: 300)
    // ... details
}
```

## Testing Gallery

The built-in `FavorGemGallery` view provides:

1. **Interactive Demo** - Change shapes, tiers, and colors in real-time
2. **Complete Matrix** - See all 24 combinations at once
3. **Color Controls** - Test any gem/frame color combination

To use:

```swift
#Preview("Gem Gallery") {
    FavorGemGallery()
}
```

Or add to your app for testing:

```swift
struct ContentView: View {
    var body: some View {
        TabView {
            // Your existing views
            // ...
            
            FavorGemGallery()
                .tabItem {
                    Label("Gallery", systemImage: "sparkles")
                }
        }
    }
}
```

## Performance Considerations

### Asset-Based Advantages

✅ **Fast** - No complex Canvas/TimelineView rendering
✅ **Consistent** - Same appearance across all devices
✅ **Memory efficient** - Images cached by system
✅ **Battery friendly** - No continuous animation updates (unless using AnimatedFavorGemView)

### When to Use Each System

**Use FavorGemView (asset-based) for:**
- List/grid items
- Small thumbnails
- Static displays
- Battery-conscious scenarios
- Consistent appearance needs

**Use MagicalCrystalView (procedural) for:**
- Hero presentations
- Special effects showcases
- Unique surface effects (constellation, aurora, etc.)
- When you need the elaborate particle systems

## Transfer Count Mapping

The system automatically maps transfer counts to appropriate frame tiers:

| Transfer Count | Frame Tier | Visual Style |
|---------------|------------|--------------|
| 0-4           | Bronze     | Simple elegant border |
| 5-29          | Silver     | Ornate with decorative dots |
| 30-49         | Gold       | Elaborate with wings/rays |
| 50+           | Gold       | Same as 30-49 |

This matches the tier system in `MagicalCrystalView`'s `DecorativeFrame` component.

## Customization Tips

### Custom Gem Colors

```swift
// From HSB values
Color(hue: 0.6, saturation: 0.8, brightness: 0.9)

// From hex (with extension)
Color(hex: 0x4A90E2)

// Gradient effects (future enhancement)
// Can be added by modifying gemstoneImage to use LinearGradient
```

### Custom Frame Colors

```swift
// Metallic colors work best
let copper = Color(hue: 0.08, saturation: 0.6, brightness: 0.7)
let platinum = Color(hue: 0.0, saturation: 0.0, brightness: 0.9)
let rose_gold = Color(hue: 0.03, saturation: 0.5, brightness: 0.9)

FavorGemView(
    shape: .heart,
    gemColor: .pink,
    frameTier: .gold,
    frameColor: rose_gold
)
```

### Size Guidelines

- **Thumbnail**: 40-60 pts
- **List Item**: 60-100 pts
- **Card Display**: 120-200 pts
- **Featured/Hero**: 240-320 pts

All sizes maintain aspect ratio automatically.

## Troubleshooting

### Assets Not Appearing

1. ✅ Check that images are in `Assets.xcassets`
2. ✅ Verify asset names match exactly (case-sensitive)
3. ✅ Ensure "Render As" is set to "Template Image"
4. ✅ Clean build folder (Cmd+Shift+K)
5. ✅ Restart Xcode if needed

### Colors Not Tinting

- Make sure images are grayscale PNGs with alpha
- Verify "Render As: Template Image" in asset settings
- Check that `.renderingMode(.template)` is applied (already in code)

### Frame Not Aligned with Gem

- Both images must be 512×512 px
- Frame opening must be centered
- No scaling/padding should be added to individual layers
- Both use `.frame(width: size, height: size)` - DO NOT modify

### Performance Issues

If you experience lag with many gems:

```swift
// Use static FavorGemView instead of AnimatedFavorGemView
// Disable shimmer for list items
FavorGemView(
    shape: shape,
    gemColor: color,
    frameTier: tier,
    size: 60,
    showGlow: false,      // Disable for lists
    showShimmer: false    // Disable for lists
)
```

## Future Enhancements

Possible additions to consider:

1. **Shadow Variations** - Different shadow styles per tier
2. **Particle Effects** - Lightweight sparkles for legendary gems
3. **Gradient Gems** - Two-color gemstone rendering
4. **Rotation Presets** - Different rotation speeds per shape
5. **Hit Detection** - Precise tap areas matching gem shape
6. **Export Functions** - Save gem as image for sharing

## Questions?

This system is designed to be simple and performant while maintaining the magical feel of Favorium's procedurally-generated gems. Use whichever system (asset-based or procedural) best fits each use case in your app.
