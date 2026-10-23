# Lightning Frame Integration Guide

## Overview
The experimental **Lightning** frame tier has been added to the gem system. This tier uses 700x700 pixel assets for both frames and gems.

## What Was Changed

### 1. Added Lightning Tier to `FrameTier` Enum
**File: `FavorGemView.swift`**

```swift
enum FrameTier: String, CaseIterable, Identifiable {
    case seed       // Starting tier (0-4 transfers)
    case bloom      // Growing tier (5-14 transfers)
    case legacy     // Established tier (15-29 transfers)
    case radiance   // Maximum tier (30+ transfers)
    case lightning  // Experimental high-resolution tier (700x700)
    
    // ... rest of enum
}
```

- **Default Color**: Electric blue/cyan (Hue: 0.55, Saturation: 0.9, Brightness: 1.0)
- **Transfer Count Representative**: 50 (for display purposes)

### 2. Updated Randomizer Interface
**File: `GemRandomizerView.swift`**

- Slider now goes from 0-4 (previously 0-3)
- Labels changed from "Seed → Radiance" to "Seed → Lightning"
- Added quick-access lightning button (⚡ icon) in navigation bar

### 3. Added Preview for Testing
A new preview called "Lightning Frame Test" displays the lightning frame with different gem shapes and colors.

## Required Asset Names

The system expects these assets for the lightning tier:

### Frame Assets (700x700 pixels)
- `frame_lightning_brilliant`
- `frame_lightning_heart`
- `frame_lightning_star`
- `frame_lightning_hexagon`
- `frame_lightning_octagon`
- `frame_lightning_pear`
- `frame_lightning_marquise`
- `frame_lightning_cushion`

### Gem Assets (uses existing gems)
The system will use the standard gem assets:
- `gem_brilliant`
- `gem_heart`
- `gem_star`
- etc.

> **Note**: If you mentioned `gem_lightning` as a specific asset, you would need to modify the `gemAssetName` property in `FavorGemView.swift` to use it specifically for the lightning tier.

## How to Test

### Method 1: Use the Main Randomizer
1. Launch the app and go to the "Generator" tab
2. Tap the ⚡ (lightning bolt) button in the top-left navigation bar
3. This instantly jumps the slider to the Lightning tier
4. Generate gems to see different shapes with the lightning frame

### Method 2: Manual Slider Control
1. Launch the app and go to the "Generator" tab
2. Move the "Frame Level" slider all the way to the right
3. Generate gems to test different shapes

### Method 3: Use the Preview
1. In Xcode, select the "Lightning Frame Test" preview
2. This shows two gems side-by-side with the lightning frame
3. Useful for comparing against expected results

### Method 4: Shape Explorer
1. Go to the "Shapes" tab
2. Select any gem shape
3. Tap "Generate 12" to create variations
4. The lightning tier will appear in the batch if selected

## Next Steps

### If Lightning Works Well:
1. Create remaining frame assets at 700x700 for other tiers:
   - `frame_seed_[shape]` (8 shapes)
   - `frame_bloom_[shape]` (8 shapes)
   - `frame_legacy_[shape]` (8 shapes)
   - `frame_radiance_[shape]` (8 shapes)

2. Optionally update gem assets to 700x700:
   - `gem_brilliant`
   - `gem_heart`
   - `gem_star`
   - `gem_hexagon`
   - `gem_octagon`
   - `gem_pear`
   - `gem_marquise`
   - `gem_cushion`

### If Adjustments Needed:
Let me know if:
- The asset naming convention needs to change
- Lightning should use a universal gem (`gem_lightning` instead of shape-specific gems)
- The rendering needs adjustments for the higher resolution
- The default color needs tweaking

## Technical Details

### Asset Loading
The system constructs asset names as:
```swift
Frame: "frame_\(tier)_\(shape)"
Gem: "gem_\(shape)"
```

For lightning + brilliant:
- Frame: `frame_lightning_brilliant`
- Gem: `gem_brilliant`

### Rendering Pipeline
1. Background glow (if enabled - currently disabled)
2. Gemstone layers (shadow, base, midtone, highlights, sparkles)
3. Frame layers (shadow, base, midtone, highlights, sharp points)
4. Shimmer overlay (if enabled - currently disabled)

### Size Scaling
The `FavorGemView` has a `size` parameter that scales the entire composition. Even though your source assets are 700x700, they'll be scaled to whatever size is requested:
- Main generator: 220 points
- Favorites: 140 points
- Detail view: 320 points
- Batch generator: 100 points

SwiftUI's image rendering handles the downscaling automatically while preserving quality.

## Troubleshooting

### If Assets Don't Appear:
1. Check asset names match exactly (case-sensitive)
2. Verify assets are added to the asset catalog
3. Ensure assets are included in the target membership
4. Check console for "Image not found" warnings

### If Quality Issues:
- Ensure assets are set to "Preserve Vector Data" if using PDFs
- Or use @3x PNG assets for best quality on all devices
- Check that asset catalog settings match for all lightning assets

### If Colors Look Wrong:
- Lightning's default color can be adjusted in `FrameTier.defaultColor`
- Individual gems can override with custom frame colors
- The color multiply blend mode may need adjustment for this tier

## Example Code

Here's how to manually create a lightning frame gem in your code:

```swift
FavorGemView(
    shape: .brilliant,
    gemColor: .cyan,
    frameTier: .lightning,
    frameColor: nil,  // Uses default lightning color
    size: 280,
    showGlow: false,
    showShimmer: false
)
```

---

**Created**: October 15, 2026  
**Status**: Experimental  
**Resolution**: 700x700 pixels  
