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
    
    // MARK: Simple Examples
    
    /// Basic gem with default settings
    static var basicExample: some View {
        FavorGemView(
            shape: .heart,
            gemColor: .pink,
            frameTier: .gold,
            size: 200
        )
    }
    
    /// Minimal gem without decorative effects
    static var minimalExample: some View {
        FavorGemView(
            shape: .brilliant,
            gemColor: .blue,
            frameTier: .bronze,
            size: 100,
            showGlow: false,
            showShimmer: false
        )
    }
    
    /// Gem with custom frame color
    static var customColorExample: some View {
        FavorGemView(
            shape: .star,
            gemColor: .yellow,
            frameTier: .silver,
            frameColor: .purple,  // Custom frame color
            size: 200
        )
    }
}

// MARK: - Integration Examples

struct GemIntegrationExamples {
    
    // MARK: List/Grid Usage
    
    /// Efficient list item with small gem thumbnail
    struct ListItemExample: View {
        let gemShape: GemShape
        let gemColor: Color
        let title: String
        
        var body: some View {
            HStack(spacing: 12) {
                FavorGemView(
                    shape: gemShape,
                    gemColor: gemColor,
                    frameTier: .bronze,
                    size: 50,
                    showGlow: false,      // Disable for performance
                    showShimmer: false    // Disable for performance
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
    
    /// Grid of gems with different colors
    struct GemGridExample: View {
        let gems = [
            (GemShape.heart, Color.red),
            (GemShape.star, Color.yellow),
            (GemShape.hexagon, Color.blue),
            (GemShape.brilliant, Color.purple)
        ]
        
        var body: some View {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(Array(gems.enumerated()), id: \.0) { index, gem in
                    VStack {
                        FavorGemView(
                            shape: gem.0,
                            gemColor: gem.1,
                            frameTier: .silver,
                            size: 120
                        )
                        
                        Text(gem.0.displayName)
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
                // Large animated gem
                AnimatedFavorGemView(
                    model: model,
                    size: 320
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                
                // Details
                VStack(spacing: 8) {
                    Text(GemShape.from(baseForm: model.baseForm).displayName)
                        .font(.title.bold())
                    
                    Text("\(model.transferCount) transfers")
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
                        FavorGemView(
                            model: model,
                            size: 200,
                            showShimmer: true
                        )
                        
                        Text("Asset-Based")
                            .font(.caption.bold())
                    }
                    
                    VStack(spacing: 12) {
                        MagicalCrystalView(
                            model: model,
                            size: 200
                        )
                        
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
    
    /// Custom animation timing
    struct CustomAnimationExample: View {
        @State private var scale: CGFloat = 1.0
        @State private var rotation: Double = 0
        
        var body: some View {
            FavorGemView(
                shape: .star,
                gemColor: .yellow,
                frameTier: .gold,
                size: 200
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // Bounce animation
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.2
                }
                
                // Spin animation
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
                shape: .heart,
                gemColor: .pink,
                frameTier: .gold,
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

/// Show how gems evolve through transfer counts
struct TransferEvolutionExample: View {
    let shape: GemShape = .brilliant
    let gemColor: Color = .cyan
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Transfer Count Evolution")
                    .font(.title.bold())
                    .padding(.top)
                
                // Newborn (0 transfers)
                evolutionStage(
                    tier: .bronze,
                    transferCount: 0,
                    phase: "Newborn",
                    description: "Fresh and simple"
                )
                
                // Awakened (5 transfers)
                evolutionStage(
                    tier: .silver,
                    transferCount: 5,
                    phase: "Awakened",
                    description: "First kindness glows within"
                )
                
                // Radiant (15 transfers)
                evolutionStage(
                    tier: .silver,
                    transferCount: 15,
                    phase: "Radiant",
                    description: "Steadier inner light"
                )
                
                // Storied (30 transfers)
                evolutionStage(
                    tier: .gold,
                    transferCount: 30,
                    phase: "Storied",
                    description: "Many journeys layered within"
                )
                
                // Legendary (50+ transfers)
                evolutionStage(
                    tier: .gold,
                    transferCount: 50,
                    phase: "Legendary",
                    description: "Lit from somewhere else"
                )
            }
            .padding()
        }
        .background(Color.black)
        .foregroundColor(.white)
    }
    
    private func evolutionStage(tier: FrameTier, transferCount: Int, phase: String, description: String) -> some View {
        VStack(spacing: 12) {
            FavorGemView(
                shape: shape,
                gemColor: gemColor,
                frameTier: tier,
                size: 180,
                showGlow: true,
                showShimmer: transferCount >= 5
            )
            
            VStack(spacing: 4) {
                Text(phase)
                    .font(.headline)
                
                Text("\(transferCount) transfers")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(tier.displayName + " Frame")
                    .font(.caption)
                    .foregroundColor(tier.defaultColor)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
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
    static let ruby = Color(hue: 0.0, saturation: 0.9, brightness: 0.9)
    static let sapphire = Color(hue: 0.6, saturation: 0.9, brightness: 0.8)
    static let emerald = Color(hue: 0.33, saturation: 0.9, brightness: 0.7)
    static let amethyst = Color(hue: 0.75, saturation: 0.7, brightness: 0.8)
    static let topaz = Color(hue: 0.15, saturation: 0.9, brightness: 0.9)
    static let aquamarine = Color(hue: 0.5, saturation: 0.6, brightness: 0.9)
    
    // Fantasy colors
    static let celestial = Color(hue: 0.6, saturation: 0.5, brightness: 1.0)
    static let void = Color(hue: 0.8, saturation: 0.9, brightness: 0.5)
    static let ethereal = Color(hue: 0.7, saturation: 0.3, brightness: 0.95)
    static let inferno = Color(hue: 0.05, saturation: 1.0, brightness: 1.0)
    static let frost = Color(hue: 0.55, saturation: 0.5, brightness: 1.0)
    
    // Metallic frame colors
    static let copper = Color(hue: 0.08, saturation: 0.6, brightness: 0.7)
    static let bronze = Color(hue: 0.08, saturation: 0.6, brightness: 0.7)
    static let silver = Color(hue: 0.0, saturation: 0.0, brightness: 0.8)
    static let gold = Color(hue: 0.15, saturation: 0.8, brightness: 1.0)
    static let platinum = Color(hue: 0.0, saturation: 0.0, brightness: 0.9)
    static let roseGold = Color(hue: 0.03, saturation: 0.5, brightness: 0.9)
    static let blackGold = Color(hue: 0.12, saturation: 0.4, brightness: 0.3)
}

/// Gallery showing color palette examples
struct ColorPaletteGallery: View {
    let palettes: [(String, Color, Color)] = [
        ("Ruby", GemColorPalettes.ruby, GemColorPalettes.gold),
        ("Sapphire", GemColorPalettes.sapphire, GemColorPalettes.silver),
        ("Emerald", GemColorPalettes.emerald, GemColorPalettes.gold),
        ("Amethyst", GemColorPalettes.amethyst, GemColorPalettes.platinum),
        ("Topaz", GemColorPalettes.topaz, GemColorPalettes.bronze),
        ("Aquamarine", GemColorPalettes.aquamarine, GemColorPalettes.silver),
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(Array(palettes.enumerated()), id: \.0) { index, palette in
                    VStack(spacing: 8) {
                        FavorGemView(
                            shape: .brilliant,
                            gemColor: palette.1,
                            frameTier: .gold,
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
                gemShape: .heart,
                gemColor: .pink,
                title: "Heart Crystal"
            )
            
            GemIntegrationExamples.ListItemExample(
                gemShape: .star,
                gemColor: .yellow,
                title: "Star Crystal"
            )
            
            GemIntegrationExamples.ListItemExample(
                gemShape: .hexagon,
                gemColor: .blue,
                title: "Hexagon Crystal"
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
