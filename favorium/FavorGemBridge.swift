//
//  FavorGemBridge.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Bridge helpers between asset system and existing CrystalEngine

import SwiftUI

// MARK: - CrystalModel Extensions

extension CrystalModel {

    /// The resolved gem family for asset rendering.
    var assetGemFamily: GemFamily {
        GemFamily.from(gemFamily)
    }

    /// The resolved frame family for asset rendering.
    var assetFrameFamily: FrameFamily {
        FrameFamily.from(frameFamily)
    }

    /// The progression tier derived from transfer count.
    var assetTier: Tier {
        Tier.from(transferCount: transferCount)
    }

    /// Primary color as SwiftUI Color.
    var primarySwiftUIColor: Color {
        Color(hue: primaryHue / 360.0, saturation: saturation, brightness: 0.9)
    }

    /// Secondary color as SwiftUI Color.
    var secondarySwiftUIColor: Color {
        Color(hue: secondaryHue / 360.0, saturation: saturation, brightness: 0.85)
    }

    /// Suggested frame tint color based on material family.
    /// Falls back to the tier's default color when no special treatment is needed.
    var suggestedFrameColor: Color {
        let tierColor = assetTier.defaultColor

        switch materialFamily {
        case .metallic:
            return tierColor

        case .cosmic, .spectral:
            return Color(hue: primaryHue / 360.0, saturation: 0.3, brightness: 0.7)

        case .opal, .moonstone:
            return Color(hue: 0.6, saturation: 0.1, brightness: 0.85)

        default:
            return tierColor
        }
    }
}

// MARK: - Quick Factory Methods

extension FavorGemView {

    /// Optimized for list rows — no effects for performance.
    static func listItem(model: CrystalModel, size: CGFloat = 50) -> some View {
        FavorGemView(model: model, size: size, showGlow: false, showShimmer: false)
    }

    /// Optimized for grid cells — glow on, shimmer off.
    static func gridItem(model: CrystalModel, size: CGFloat = 100) -> some View {
        FavorGemView(model: model, size: size, showGlow: true, showShimmer: false)
    }

    /// Optimized for card display — all effects on.
    static func card(model: CrystalModel, size: CGFloat = 160) -> some View {
        FavorGemView(model: model, size: size, showGlow: true, showShimmer: true)
    }

    /// Large animated hero gem.
    static func hero(model: CrystalModel, size: CGFloat = 320) -> some View {
        AnimatedFavorGemView(model: model, size: size)
    }
}

// MARK: - Rendering Mode Selection

enum GemRenderingMode {
    case asset       // Use FavorGemView
    case procedural  // Use MagicalCrystalView
    case auto        // Choose based on context
}

/// Smart wrapper that chooses between asset and procedural rendering.
struct AdaptiveGemView: View {
    let model: CrystalModel
    let size: CGFloat
    let mode: GemRenderingMode
    let forceAnimated: Bool

    init(
        model: CrystalModel,
        size: CGFloat = 200,
        mode: GemRenderingMode = .auto,
        animated: Bool = false
    ) {
        self.model = model
        self.size = size
        self.mode = mode
        self.forceAnimated = animated
    }

    var body: some View {
        Group {
            switch resolvedMode {
            case .asset:
                if forceAnimated {
                    AnimatedFavorGemView(model: model, size: size)
                } else {
                    FavorGemView(model: model, size: size)
                }
            case .procedural:
                MagicalCrystalView(model: model, size: size)
            case .auto:
                FavorGemView(model: model, size: size)
            }
        }
    }

    private var resolvedMode: GemRenderingMode {
        switch mode {
        case .asset, .procedural: return mode
        case .auto: return autoSelectMode
        }
    }

    private var autoSelectMode: GemRenderingMode {
        if size < 100       { return .asset }
        if model.transferCount >= 50 { return .procedural }
        if size < 250       { return .asset }
        return .procedural
    }
}

// MARK: - Batch Conversion Helpers

extension Array where Element == CrystalModel {

    /// Convert all models to asset gem views.
    func asGemViews(size: CGFloat = 100) -> [AnyView] {
        map { AnyView(FavorGemView(model: $0, size: size)) }
    }

    /// Group models by their resolved tier.
    func groupedByTier() -> [Tier: [CrystalModel]] {
        Dictionary(grouping: self) { $0.assetTier }
    }

    /// Group models by their gem family.
    func groupedByGemFamily() -> [GemFamily: [CrystalModel]] {
        Dictionary(grouping: self) { $0.assetGemFamily }
    }

    /// Group models by their frame family.
    func groupedByFrameFamily() -> [FrameFamily: [CrystalModel]] {
        Dictionary(grouping: self) { $0.assetFrameFamily }
    }
}

// MARK: - Preview Helpers

extension CrystalModel {

    /// Create a test model with specific characteristics.
    static func preview(
        gemFamily: GemFamily = .lightning,
        frameFamily: FrameFamily = .lightning,
        hue: Double = 200,
        transferCount: Int = 15
    ) -> CrystalModel {
        let dna = CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: hue,
                secondaryHue: (hue + 30).truncatingRemainder(dividingBy: 360),
                saturation: 0.8,
                materialFamily: "coloredGemstone",
                baseForm: gemFamily.rawValue,
                colorRelationship: "complementary",
                secondaryInfluence: 0.5,
                gemFamily: gemFamily.rawValue,
                frameFamily: frameFamily.rawValue
            ),
            personality: CrystalPersonality(
                complexityBias: 0.7,
                orbitalAffinity: 0.8,
                refraction: 0.7
            ),
            seed: UUID().uuidString
        )
        return CrystalEngine.derive(dna: dna, transferCount: transferCount)
    }

    /// A varied collection of preview models across all tiers.
    static var previewCollection: [CrystalModel] {
        [
            preview(hue: 0,   transferCount: 2),   // seed
            preview(hue: 40,  transferCount: 8),   // bloom
            preview(hue: 120, transferCount: 20),  // legacy
            preview(hue: 200, transferCount: 35),  // radiance
            preview(hue: 260, transferCount: 5),   // bloom
            preview(hue: 300, transferCount: 15),  // legacy
        ]
    }
}

// MARK: - Usage Examples

struct GemBridgeExamples {

    /// Simple list using bridge factory helpers.
    struct SimpleListExample: View {
        let crystals: [CrystalModel] = CrystalModel.previewCollection

        var body: some View {
            List(crystals, id: \.seed) { crystal in
                HStack {
                    FavorGemView.listItem(model: crystal)

                    VStack(alignment: .leading) {
                        Text("\(crystal.assetGemFamily.displayName) gem")
                            .font(.headline)
                        Text("\(crystal.transferCount) transfers · \(crystal.assetTier.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    /// Grid using adaptive rendering.
    struct AdaptiveGridExample: View {
        let crystals: [CrystalModel] = CrystalModel.previewCollection

        var body: some View {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(crystals, id: \.seed) { crystal in
                        VStack {
                            AdaptiveGemView(model: crystal, size: 120, mode: .auto)
                            Text(crystal.phase.whisper)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .padding()
            }
        }
    }

    /// Grouped display by tier.
    struct GroupedByTierExample: View {
        let crystals: [CrystalModel] = CrystalModel.previewCollection

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    let grouped = crystals.groupedByTier()

                    ForEach(Tier.allCases) { tier in
                        if let models = grouped[tier] {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(tier.displayName + " Tier")
                                    .font(.title2.bold())
                                    .foregroundColor(tier.defaultColor)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(models, id: \.seed) { model in
                                            FavorGemView(model: model, size: 120)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .foregroundColor(.white)
        }
    }

    /// Detail view with material-based smart frame color.
    struct SmartDetailExample: View {
        let model: CrystalModel

        var body: some View {
            VStack(spacing: 30) {
                AnimatedFavorGemView(
                    model: model,
                    size: 300,
                    customFrameColor: model.suggestedFrameColor
                )
                .shadow(color: model.primarySwiftUIColor.opacity(0.5), radius: 30)

                VStack(spacing: 12) {
                    Text(model.assetGemFamily.displayName)
                        .font(.largeTitle.bold())

                    HStack(spacing: 20) {
                        Label("\(model.transferCount)", systemImage: "arrow.triangle.swap")
                        Label(model.assetTier.displayName, systemImage: "crown")
                        Label(model.materialFamily.rawValue, systemImage: "sparkles")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                    Text(model.phase.whisper)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
        }
    }
}

// MARK: - Previews

#Preview("Simple List") {
    GemBridgeExamples.SimpleListExample()
}

#Preview("Adaptive Grid") {
    GemBridgeExamples.AdaptiveGridExample()
}

#Preview("Grouped by Tier") {
    GemBridgeExamples.GroupedByTierExample()
}

#Preview("Smart Detail") {
    let model = CrystalModel.preview(hue: 330, transferCount: 50)
    return GemBridgeExamples.SmartDetailExample(model: model)
}

