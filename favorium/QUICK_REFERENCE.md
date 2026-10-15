# Favorium Gemstone Asset System — Quick Reference Card

## 🚀 Most Common Operations

### Show a Gem from CrystalModel
```swift
FavorGemView(model: yourModel, size: 200)
```

### Show an Animated Gem
```swift
AnimatedFavorGemView(model: yourModel, size: 280)
```

### Show a Custom Gem
```swift
FavorGemView(
    shape: .heart,
    gemColor: .pink,
    frameTier: .gold,
    size: 200
)
```

### Verify Assets Are Loaded
```swift
#Preview { AssetVerificationView() }
```

### Test Everything Interactively
```swift
#Preview { FavorGemGallery() }
```

---

## 📁 Essential Files

| What I Need | File to Open |
|-------------|--------------|
| Main implementation | `FavorGemView.swift` |
| Integration helpers | `FavorGemBridge.swift` |
| Usage examples | `FavorGemExamples.swift` |
| Asset verification | `AssetVerification.swift` |
| Quick start docs | `README_ASSETS.md` |

---

## 🎨 All Gem Shapes

```swift
.brilliant  .heart  .star  .hexagon
.octagon    .pear   .marquise  .cushion
```

## 🏆 All Frame Tiers

```swift
.bronze  // 0-4 transfers, simple border
.silver  // 5-29 transfers, ornate details
.gold    // 30+ transfers, elaborate wings
```

---

## 💡 Quick Recipes

### List Item (Small, Fast)
```swift
FavorGemView(
    model: model,
    size: 50,
    showGlow: false,
    showShimmer: false
)
```

### Grid Item (Medium)
```swift
FavorGemView(
    model: model,
    size: 120,
    showGlow: true,
    showShimmer: false
)
```

### Hero Display (Large, Animated)
```swift
AnimatedFavorGemView(model: model, size: 320)
```

### Custom Colors
```swift
FavorGemView(
    shape: .star,
    gemColor: GemColorPalettes.sapphire,
    frameTier: .gold,
    frameColor: GemColorPalettes.platinum,
    size: 200
)
```

### Smart Auto-Rendering
```swift
AdaptiveGemView(
    model: model,
    size: 200,
    mode: .auto  // Chooses best rendering
)
```

---

## 🎨 Pre-Defined Colors

### Gemstone Colors
```swift
GemColorPalettes.ruby
GemColorPalettes.sapphire
GemColorPalettes.emerald
GemColorPalettes.amethyst
GemColorPalettes.topaz
GemColorPalettes.aquamarine
```

### Fantasy Colors
```swift
GemColorPalettes.celestial
GemColorPalettes.void
GemColorPalettes.ethereal
GemColorPalettes.inferno
GemColorPalettes.frost
```

### Frame Colors
```swift
GemColorPalettes.bronze
GemColorPalettes.silver
GemColorPalettes.gold
GemColorPalettes.platinum
GemColorPalettes.roseGold
GemColorPalettes.blackGold
```

---

## ⚡️ Performance Tips

### For Lists (Many Items)
- Use `FavorGemView.listItem(model:)`
- Set `showGlow: false`
- Set `showShimmer: false`
- Keep size small (50-80pt)

### For Grids (Medium Count)
- Use `FavorGemView.gridItem(model:)`
- Keep `showGlow: true`
- Set `showShimmer: false`
- Size around 100-120pt

### For Hero Views (Single Item)
- Use `AnimatedFavorGemView`
- All effects enabled
- Size 280-320pt

---

## 🔍 Troubleshooting

### Assets show as gray
→ Set "Render As: Template Image" in Xcode

### Assets not found
→ Run `AssetVerificationView()` to check

### Frame doesn't align
→ Both gem and frame must be 512×512px
→ Don't modify `.frame()` size in code

### Performance issues
→ Disable effects for list items
→ Use static `FavorGemView` instead of animated

---

## 📦 Required Assets (32 total)

### Gemstones (8)
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

### Frames (24)
```
frame_bronze_{shape}.png  (8 frames)
frame_silver_{shape}.png  (8 frames)
frame_gold_{shape}.png    (8 frames)
```

**Critical**: All must be:
- 512×512 px
- Grayscale PNG
- Alpha transparent
- "Render As: Template Image"

---

## 🎓 Learning Path

1. ✅ Add 32 assets to Xcode
2. ✅ Set to "Template Image"
3. ✅ Run `AssetVerificationView()`
4. ✅ Run `FavorGemGallery()`
5. ✅ Try a simple `FavorGemView`
6. ✅ Integrate into your views

---

## 📞 Where to Look

| I Want To... | Look At... |
|--------------|------------|
| See all options | `FavorGemGallery()` |
| Verify assets | `AssetVerificationView()` |
| Copy examples | `FavorGemExamples.swift` |
| Learn API | `ASSET_INTEGRATION_GUIDE.md` |
| Debug issues | `ASSET_MAPPING_REFERENCE.md` |
| Quick start | `README_ASSETS.md` |
| Complete guide | `IMPLEMENTATION_SUMMARY.md` |

---

## 🔗 Integration with Existing Code

### CrystalModel Extensions
```swift
model.assetGemShape         // → GemShape
model.assetFrameTier        // → FrameTier
model.primarySwiftUIColor   // → Color
model.suggestedFrameColor   // → Color
```

### Factory Methods
```swift
FavorGemView.listItem(model: model)
FavorGemView.gridItem(model: model)
FavorGemView.card(model: model)
FavorGemView.hero(model: model)
```

---

## 💻 Console Debug

```swift
// Print asset report to console
AssetVerification.printReport()
```

---

## ⚙️ Default Values

```swift
// Sizes
size: 200           // Default
listItem: 50
gridItem: 100
card: 160
hero: 320

// Effects
showGlow: true      // Default
showShimmer: false  // Default

// Frame colors
bronze: (hue: 0.08, sat: 0.6, bright: 0.7)
silver: (hue: 0.0, sat: 0.0, bright: 0.8)
gold: (hue: 0.15, sat: 0.8, bright: 1.0)
```

---

## 🎯 Common Patterns

### List with Gems
```swift
List(crystals) { crystal in
    HStack {
        FavorGemView.listItem(model: crystal.model)
        Text(crystal.name)
    }
}
```

### Grid with Gems
```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
    ForEach(crystals) { crystal in
        FavorGemView.gridItem(model: crystal.model)
    }
}
```

### Detail with Animated Gem
```swift
VStack {
    AnimatedFavorGemView(model: crystal.model, size: 300)
    Text(crystal.name).font(.title)
}
```

### Badge Overlay
```swift
MyView()
    .gemBadge(
        shape: .star,
        color: .yellow,
        tier: .gold
    )
```

---

## ✅ Pre-Flight Checklist

- ✅ Assets in Assets.xcassets
- ✅ "Template Image" mode set
- ✅ `AssetVerificationView()` → 32/32
- ✅ `FavorGemGallery()` → colored gems
- ✅ Tested in list/grid
- ✅ Tested on device

---

**That's it! You're ready to go.** 🚀💎

For more details, see `INDEX.md` or `README_ASSETS.md`.

---

*Favorium Asset System v1.0 • October 14, 2026*
