//
//  FavorGemExamples.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Quick reference examples for FavorGemView usage

import SwiftUI

// MARK: - Common Usage Patterns

extension FavorGemView {

    /// Basic gem with default settings
    static var basicExample: some View {
        FavorGemView(
            gemFamily: .lightning,
            tier: .legacy,
            gemColor: .cyan,
            size: 200
        )
    }

    /// Minimal gem without decorative effects
    static var minimalExample: some View {
        FavorGemView(
            gemFamily: .lightning,
            tier: .seed,
            gemColor: .blue,
            size: 100,
            showGlow: false,
            showShimmer: false
        )
    }

    /// Gem with custom frame color override
    static var customColorExample: some View {
        FavorGemView(
            gemFamily: .lightning,
            tier: .bloom,
            gemColor: .yellow,
            frameColor: .purple,
            size: 200
        )
    }
}

// MARK: - Integration Examples

struct GemIntegrationExamples {

    // MARK: List/Grid Usage

    /// Efficient list item with small gem thumbnail
    struct ListItemExample: View {
        let gemFamily: GemFamily
        let tier: Tier
        let gemColor: Color
        let title: String

        var body: some View {
            HStack(spacing: 12) {
                FavorGemView(
                    gemFamily: gemFamily,
                    tier: tier,
                    gemColor: gemColor,
                    size: 50,
                    showGlow: false,
                    showShimmer: false
                )

                Text(title)
                    .font(.headline)

                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
        }
    }

    /// Grid of gems with different colors across tiers
    struct GemGridExample: View {
        let items: [(Tier, Color)] = [
            (.seed,     .red),
            (.bloom,    .yellow),
            (.legacy,   .blue),
            (.radiance, .purple)
        ]

        var body: some View {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(Array(items.enumerated()), id: \.0) { _, item in
                    VStack {
                        FavorGemView(
                            gemFamily: .lightning,
                            tier: item.0,
                            gemColor: item.1,
                            size: 120
                        )

                        Text(item.0.displayName)
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: Detail View Usage

    /// Hero gem display for detail screens
    struct HeroGemExample: View {
        let model: CrystalModel

        var body: some View {
            VStack(spacing: 24) {
                AnimatedFavorGemView(model: model, size: 320)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                VStack(spacing: 8) {
                    Text(model.assetGemFamily.displayName)
                        .font(.title.bold())

                    Text("\(model.transferCount) transfers · \(model.assetTier.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(model.phase.whisper)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }

    // MARK: Comparison View

    /// Side-by-side comparison of asset vs procedural rendering
    struct ComparisonExample: View {
        let model: CrystalModel

        var body: some View {
            VStack(spacing: 30) {
                Text("Rendering Comparison")
                    .font(.title.bold())

                HStack(spacing: 30) {
                    VStack(spacing: 12) {
                        FavorGemView(model: model, size: 200, showShimmer: true)
                        Text("Asset-Based")
                            .font(.caption.bold())
                    }

                    VStack(spacing: 12) {
                        MagicalCrystalView(model: model, size: 200)
                        Text("Procedural")
                            .font(.caption.bold())
                    }
                }
            }
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
        }
    }

    // MARK: Animation Examples

    /// Custom scale + rotation animation
    struct CustomAnimationExample: View {
        @State private var scale: CGFloat = 1.0
        @State private var rotation: Double = 0

        var body: some View {
            FavorGemView(
                gemFamily: .lightning,
                tier: .legacy,
                gemColor: .yellow,
                size: 200
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.2
                }
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
    }

    /// Tap animation with spring effect
    struct TapAnimationExample: View {
        @State private var tapped = false

        var body: some View {
            FavorGemView(
                gemFamily: .lightning,
                tier: .legacy,
                gemColor: .cyan,
                size: 200,
                showShimmer: true
            )
            .scaleEffect(tapped ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: tapped)
            .onTapGesture {
                tapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    tapped = false
                }
            }
        }
    }
}

// MARK: - Transfer Evolution Example

/// Shows how a gem evolves visually through the four tiers
struct TransferEvolutionExample: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Transfer Count Evolution")
                    .font(.title.bold())
                    .padding(.top)

                evolutionStage(tier: .seed,     transferCount: 2,  description: "Fresh and simple")
                evolutionStage(tier: .bloom,    transferCount: 8,  description: "First kindness glows within")
                evolutionStage(tier: .legacy,   transferCount: 20, description: "Steadier inner light")
                evolutionStage(tier: .radiance, transferCount: 35, description: "Many journeys layered within")
            }
            .padding()
        }
        .background(Color.black)
        .foregroundColor(.white)
    }

    private func evolutionStage(tier: Tier, transferCount: Int, description: String) -> some View {
        VStack(spacing: 12) {
            FavorGemView(
                gemFamily: .lightning,
                tier: tier,
                gemColor: .cyan,
                size: 180,
                showGlow: true,
                showShimmer: transferCount >= 5
            )

            VStack(spacing: 4) {
                Text(tier.displayName)
                    .font(.headline)

                Text("\(transferCount) transfers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider().background(Color.white.opacity(0.3))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Color Palette Examples

/// Pre-defined color palettes for gems
struct GemColorPalettes {

    // Classic gemstone colors
    static let ruby        = Color(hue: 0.0,  saturation: 0.9, brightness: 0.9)
    static let sapphire    = Color(hue: 0.6,  saturation: 0.9, brightness: 0.8)
    static let emerald     = Color(hue: 0.33, saturation: 0.9, brightness: 0.7)
    static let amethyst    = Color(hue: 0.75, saturation: 0.7, brightness: 0.8)
    static let topaz       = Color(hue: 0.15, saturation: 0.9, brightness: 0.9)
    static let aquamarine  = Color(hue: 0.5,  saturation: 0.6, brightness: 0.9)

    // Fantasy colors
    static let celestial   = Color(hue: 0.6,  saturation: 0.5, brightness: 1.0)
    static let void        = Color(hue: 0.8,  saturation: 0.9, brightness: 0.5)
    static let ethereal    = Color(hue: 0.7,  saturation: 0.3, brightness: 0.95)
    static let inferno     = Color(hue: 0.05, saturation: 1.0, brightness: 1.0)
    static let frost       = Color(hue: 0.55, saturation: 0.5, brightness: 1.0)

    // Frame tint colors
    static let copper      = Color(hue: 0.08, saturation: 0.6, brightness: 0.7)
    static let bronze      = Color(hue: 0.08, saturation: 0.6, brightness: 0.7)
    static let silver      = Color(hue: 0.0,  saturation: 0.0, brightness: 0.8)
    static let gold        = Color(hue: 0.15, saturation: 0.8, brightness: 1.0)
    static let platinum    = Color(hue: 0.0,  saturation: 0.0, brightness: 0.9)
    static let roseGold    = Color(hue: 0.03, saturation: 0.5, brightness: 0.9)
    static let blackGold   = Color(hue: 0.12, saturation: 0.4, brightness: 0.3)
}

/// Gallery showing how gem color interacts with the lightning family
struct ColorPaletteGallery: View {
    let palettes: [(String, Color, Color)] = [
        ("Ruby",       GemColorPalettes.ruby,       GemColorPalettes.gold),
        ("Sapphire",   GemColorPalettes.sapphire,   GemColorPalettes.silver),
        ("Emerald",    GemColorPalettes.emerald,     GemColorPalettes.gold),
        ("Amethyst",   GemColorPalettes.amethyst,    GemColorPalettes.platinum),
        ("Topaz",      GemColorPalettes.topaz,       GemColorPalettes.bronze),
        ("Aquamarine", GemColorPalettes.aquamarine,  GemColorPalettes.silver),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(Array(palettes.enumerated()), id: \.0) { _, palette in
                    VStack(spacing: 8) {
                        FavorGemView(
                            gemFamily: .lightning,
                            tier: .legacy,
                            gemColor: palette.1,
                            frameColor: palette.2,
                            size: 140,
                            showGlow: true,
                            showShimmer: false
                        )

                        Text(palette.0)
                            .font(.caption.bold())
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .foregroundColor(.white)
    }
}

// MARK: - Previews

#Preview("List Item") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 16) {
            GemIntegrationExamples.ListItemExample(
                gemFamily: .lightning,
                tier: .seed,
                gemColor: .cyan,
                title: "Lightning Seed"
            )
            GemIntegrationExamples.ListItemExample(
                gemFamily: .lightning,
                tier: .bloom,
                gemColor: .yellow,
                title: "Lightning Bloom"
            )
            GemIntegrationExamples.ListItemExample(
                gemFamily: .lightning,
                tier: .legacy,
                gemColor: .purple,
                title: "Lightning Legacy"
            )
        }
        .padding()
    }
}

#Preview("Grid") {
    ZStack {
        Color.black.ignoresSafeArea()
        GemIntegrationExamples.GemGridExample()
    }
}

#Preview("Transfer Evolution") {
    TransferEvolutionExample()
}

#Preview("Color Palettes") {
    ColorPaletteGallery()
}

#Preview("Custom Animation") {
    ZStack {
        Color.black.ignoresSafeArea()
        GemIntegrationExamples.CustomAnimationExample()
    }
}

#Preview("Tap Animation") {
    ZStack {
        Color.black.ignoresSafeArea()
        GemIntegrationExamples.TapAnimationExample()
    }
}
