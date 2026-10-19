//
//  MagicalCrystalView.swift
//  favorium
//
//  Created by Assistant on 10/9/26.
//
//  Experimental magical crystal with particle effects and fluid dynamics

import SwiftUI
import SpriteKit

/// Premium collectible crystal with decorative frames and subtle animations
struct MagicalCrystalView: View {
    let model: CrystalModel
    let size: CGFloat
    var forcedSurfaceEffect: SurfaceEffect? = nil
    
    init(dna: CrystalDNA, transferCount: Int, size: CGFloat = 200, forcedSurfaceEffect: SurfaceEffect? = nil) {
        self.model = CrystalEngine.derive(dna: dna, transferCount: transferCount)
        self.size = size
        self.forcedSurfaceEffect = forcedSurfaceEffect
    }
    
    init(model: CrystalModel, size: CGFloat = 200, forcedSurfaceEffect: SurfaceEffect? = nil) {
        self.model = model
        self.size = size
        self.forcedSurfaceEffect = forcedSurfaceEffect
    }
    
    var body: some View {
        ZStack {
            // Subtle background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .blur(radius: size * 0.15)
            
            // Decorative frame (based on rarity tier)
            DecorativeFrame(model: model, size: size)
            
            // The precious gem - THE STAR OF THE SHOW
            MagicalGemCore(model: model, size: size, forcedSurfaceEffect: forcedSurfaceEffect)
            
            // Subtle shimmer overlay (gentle, not chaotic)
            GentleShimmer(model: model, size: size)
        }
        .frame(width: size, height: size)
    }
    
    private var primaryColor: Color {
        Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
    }
    
    private var secondaryColor: Color {
        Color(
            hue: model.secondaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.85
        )
    }
}

// MARK: - Magical Gem Core

/// The central crystalline core with animated energy
struct MagicalGemCore: View {
    let model: CrystalModel
    let size: CGFloat
    var forcedSurfaceEffect: SurfaceEffect? = nil  // Optional override
    
    @State private var pulse: Double = 1.0
    @State private var rotation: Double = 0
    @State private var innerRotation: Double = 0
    @State private var shimmer: Double = 0
    @State private var dispersePhase: Double = 0
    @State private var rotation3D: Double = 0
    
    // Surface effect - deterministic based on tier, or forced
    // Mirrors the canonical Tier system from FavorGemView:
    // - Seed     (0–4):   no surface effect
    // - Bloom    (5–14):  common effects (subtle)
    // - Legacy   (15–29): rare effects (noticeable)
    // - Radiance (30+):   legendary effects (special)
    private var surfaceEffect: SurfaceEffect? {
        // Always show if forced (for preview/testing)
        if let forced = forcedSurfaceEffect {
            return forced
        }

        let hash = abs(model.seed.hashValue)

        switch Tier.from(transferCount: model.transferCount) {
        case .seed:
            return nil
        case .bloom:
            let effects: [SurfaceEffect] = [.shimmer, .glow, .sparkle]
            return effects[hash % effects.count]
        case .legacy:
            let effects: [SurfaceEffect] = [.holographic, .rainbow, .pulse]
            return effects[hash % effects.count]
        case .radiance:
            let effects: [SurfaceEffect] = [.constellation, .aurora, .prismatic]
            return effects[hash % effects.count]
        }
    }
    
    var body: some View {
        ZStack {
            // Deep subsurface glow (light penetrating the crystal)
            subsurfaceGlow
            
            // REALISTIC GEM LAYERING
            gemLayers
            
            // SPECULAR HIGHLIGHTS (bright reflections)
            sparkles
            
            // Outer atmospheric glow
            atmosphericGlow
            
            // Surface effect overlay
            surfaceEffectView
        }
        .shadow(
            color: primaryColor.opacity(0.3),
            radius: 15,
            x: sin(rotation3D * .pi / 180) * 8,
            y: cos(rotation3D * .pi / 180) * 8
        )
        .shadow(
            color: Color.black.opacity(0.4),
            radius: 20,
            x: -sin(rotation3D * .pi / 180) * 5,
            y: -cos(rotation3D * .pi / 180) * 5
        )
        .rotation3DEffect(
            .degrees(rotation3D),
            axis: (x: 0.3, y: 1.0, z: 0.2),
            anchor: .center,
            perspective: 0.6
        )
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Body Components
    
    private var subsurfaceGlow: some View {
        gemShape
            .fill(
                RadialGradient(
                    colors: [
                        primaryColor.opacity(0.3),
                        secondaryColor.opacity(0.2),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.4, y: 0.4),
                    startRadius: 0,
                    endRadius: size * 0.65
                )
            )
            .scaleEffect(pulse * 1.08)
            .blur(radius: 18)
    }
    
    private var gemLayers: some View {
        ZStack {
            // PAVILION (bottom/back of gem) - darker, creates depth
            pavilionLayer
            
            // MAIN GEM BODY (Crown - top part)
            mainGemBody
            
            // Internal shimmer layer
            shimmerLayer
            
            // Chromatic dispersion ("fire" - rainbow flashes)
            chromaticDispersion
            
            // TABLE (top flat facet) - slight overlay
            tableLayer
            
            // GIRDLE (edge/rim) - sharp definition
            girdleLayer
        }
    }
    
    private var pavilionLayer: some View {
        gemShape
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [
                        secondaryColor.opacity(0.75),
                        primaryColor.opacity(0.6),
                        secondaryColor.opacity(0.8),
                        primaryColor.opacity(0.65),
                        secondaryColor.opacity(0.75)
                    ]),
                    center: .center,
                    angle: .degrees(rotation * 0.3)
                )
            )
            .frame(width: size * 0.68, height: size * 0.68)
            .offset(x: size * 0.015, y: size * 0.02)  // Offset creates 3D depth
            .blur(radius: 0.5)
    }
    
    private var mainGemBody: some View {
        gemShape
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.15), location: 0.0),
                        .init(color: primaryColor.opacity(0.4), location: 0.25),
                        .init(color: primaryColor.opacity(0.55), location: 0.5),
                        .init(color: secondaryColor.opacity(0.5), location: 0.75),
                        .init(color: secondaryColor.opacity(0.6), location: 1.0)
                    ]),
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size * 0.7, height: size * 0.7)
    }
    
    private var shimmerLayer: some View {
        gemShape
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.3),
                        Color.clear,
                        primaryColor.opacity(0.2),
                        Color.clear,
                        Color.white.opacity(0.25),
                        Color.clear,
                        secondaryColor.opacity(0.2),
                        Color.clear
                    ]),
                    center: .center,
                    angle: .degrees(rotation * 0.5)
                )
            )
            .frame(width: size * 0.7, height: size * 0.7)
            .blendMode(.overlay)
    }
    
    private var chromaticDispersion: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0 + dispersePhase
                let hue = Double(i) * 30.0 / 360.0
                
                gemShape
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.clear,
                                Color(hue: hue, saturation: 0.8, brightness: 1.0).opacity(0.15),
                                Color.clear
                            ],
                            center: UnitPoint(
                                x: 0.5 + cos(angle * .pi / 180) * 0.3,
                                y: 0.5 + sin(angle * .pi / 180) * 0.3
                            ),
                            startRadius: 0,
                            endRadius: size * 0.2
                        )
                    )
                    .frame(width: size * 0.7, height: size * 0.7)
            }
        }
        .blendMode(.screen)
        .opacity(0.4)
    }
    
    private var tableLayer: some View {
        gemShape
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        primaryColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.35, height: size * 0.35)
            .blendMode(.overlay)
    }
    
    private var girdleLayer: some View {
        gemShape
            .stroke(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.white.opacity(0.9), location: 0.0),
                        .init(color: primaryColor.opacity(0.95), location: 0.25),
                        .init(color: Color.white.opacity(0.7), location: 0.4),
                        .init(color: secondaryColor.opacity(0.8), location: 0.6),
                        .init(color: primaryColor.opacity(0.85), location: 0.85),
                        .init(color: Color.white.opacity(0.75), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2.5
            )
            .frame(width: size * 0.7, height: size * 0.7)
            .shadow(color: Color.white.opacity(0.4), radius: 1, x: -0.5, y: -0.5)
            .shadow(color: primaryColor.opacity(0.3), radius: 3, x: 1, y: 1)
    }
    
    private var sparkles: some View {
        ForEach(0..<sparkleCount) { i in
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 1.5
                    )
                )
                .frame(width: 3, height: 3)
                .offset(sparkleOffset(for: i))
                .opacity(sparkleOpacity(for: i))
                .blur(radius: 0.3)
        }
    }
    
    private var atmosphericGlow: some View {
        gemShape
            .stroke(primaryColor.opacity(0.25), lineWidth: 1)
            .frame(width: size * 0.76, height: size * 0.76)
            .blur(radius: 10)
    }
    
    private func startAnimations() {
        // Gentle pulse
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulse = 1.08
        }
        
        // Slow facet rotation
        withAnimation(.linear(duration: 30.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Inner energy rotation
        withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            innerRotation = -360
        }
        
        // Light refraction shimmer
        withAnimation(.linear(duration: 15.0).repeatForever(autoreverses: false)) {
            shimmer = 360
        }
        
        // Dispersion animation (slower for realism)
        withAnimation(.linear(duration: 25.0).repeatForever(autoreverses: false)) {
            dispersePhase = 360
        }
        
        // 3D rotation - gentle back and forth (never shows the flat edge)
        withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
            rotation3D = 25  // Only rotate 25 degrees each way
        }
    }
    
    // MARK: - Shape Variants
    
    private var gemShape: AnyShape {
        switch model.baseForm.lowercased() {
        case "heart":
            AnyShape(HeartShape())
        case "star":
            AnyShape(StarShape())
        case "hexagon":
            AnyShape(HexagonShape())
        case "octagon":
            AnyShape(OctagonShape())
        case "diamond":
            AnyShape(DiamondCutShape())
        case "pear", "teardrop":
            AnyShape(PearShape())
        case "marquise":
            AnyShape(MarquiseShape())
        case "cushion":
            AnyShape(CushionShape())
        default:
            AnyShape(Circle())
        }
    }
    
    // MARK: - Shape-specific properties
    
    private var facetCountForShape: Int {
        switch model.baseForm.lowercased() {
        case "heart": return 6
        case "star": return 10
        case "hexagon": return 6
        case "octagon": return 8
        case "diamond": return 8
        case "pear", "teardrop": return 7
        case "marquise": return 6
        case "cushion": return 8
        default: return 8
        }
    }
    
    private var innerCoreLines: Int {
        switch model.baseForm.lowercased() {
        case "star": return 5
        case "hexagon": return 6
        case "octagon": return 8
        case "heart": return 4
        default: return 6
        }
    }
    
    private var sparkleCount: Int {
        switch model.baseForm.lowercased() {
        case "star": return 10
        case "hexagon": return 6
        case "octagon": return 8
        default: return 8
        }
    }
    
    private var pulseDuration: Double {
        switch model.baseForm.lowercased() {
        case "star": return 1.5  // Faster pulse for stars
        case "heart": return 2.5  // Slower romantic pulse
        default: return 2.0
        }
    }
    
    private var primaryColor: Color {
        Color(hue: model.primaryHue / 360.0, saturation: model.saturation, brightness: 0.95)
    }
    
    private var secondaryColor: Color {
        Color(hue: model.secondaryHue / 360.0, saturation: model.saturation, brightness: 0.9)
    }
    
    private func facetIntensity(for index: Int) -> Double {
        let phase = Double(index) / 8.0
        return 0.4 + 0.5 * sin(phase * .pi * 2)
    }
    
    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = Double(index) * 360 / Double(sparkleCount) * .pi / 180
        let radius = size * 0.35
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
    
    private func sparkleOpacity(for index: Int) -> Double {
        let phase = (Double(index) / Double(sparkleCount) + pulse - 1.0) * 3
        return max(0, min(1, 0.5 + 0.5 * sin(phase * .pi * 2)))
    }
    
    // MARK: - Surface Effect View
    
    @ViewBuilder
    private var surfaceEffectView: some View {
        if let effect = surfaceEffect {
            switch effect {
            // Common effects - Subtle
            case .shimmer:
                SubtleShimmerEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .glow:
                SubtleGlowEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, pulse: pulse)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .sparkle:
                SubtleSparkleEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
                
            // Rare effects - More noticeable
            case .holographic:
                HolographicEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .rainbow:
                RainbowEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .pulse:
                PulseEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
                
            // Legendary effects - Special but classy
            case .constellation:
                ConstellationEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .aurora:
                CleanAuroraEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .prismatic:
                PrismaticEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            }
        }
    }
}

// MARK: - Surface Effect Types (Now Subtle)

enum SurfaceEffect: String, CaseIterable {
    // Bloom effects (5–14 transfers) - Subtle enhancements
    case shimmer = "Shimmer"
    case glow = "Glow"
    case sparkle = "Sparkle"

    // Legacy effects (15–29 transfers) - More noticeable but still classy
    case holographic = "Holographic"
    case rainbow = "Rainbow"
    case pulse = "Pulse"

    // Radiance effects (30+ transfers) - Special but not overwhelming
    case aurora = "Aurora"
    case constellation = "Constellation"
    case prismatic = "Prismatic"
}

// MARK: - Decorative Frames (Rarity Tiers)

/// Decorative frame around the gem - gets more ornate with higher transfer counts
struct DecorativeFrame: View {
    let model: CrystalModel
    let size: CGFloat

    @State private var rotation: Double = 0

    private var tier: Tier {
        Tier.from(transferCount: model.transferCount)
    }

    private var frameColor: Color {
        let hue = model.frameHue / 360.0
        switch tier {
        case .seed:     return Color.clear
        case .bloom:    return Color(hue: hue, saturation: 0.55, brightness: 0.75)
        case .legacy:   return Color(hue: hue, saturation: 0.45, brightness: 0.90)
        case .radiance: return Color(hue: hue, saturation: 0.80, brightness: 1.00)
        }
    }

    var body: some View {
        ZStack {
            switch tier {
            case .seed:
                EmptyView()
            case .bloom:
                // Simple elegant border
                commonFrame
            case .legacy:
                // Ornate frame with details
                rareFrame
            case .radiance:
                // Elaborate decorations
                legendaryFrame
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
    
    private var commonFrame: some View {
        ZStack {
            // Simple thin border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            frameColor.opacity(0.6),
                            frameColor.opacity(0.3),
                            frameColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size * 0.8, height: size * 0.8)
            
            // Subtle glow
            Circle()
                .stroke(frameColor.opacity(0.2), lineWidth: 1)
                .frame(width: size * 0.8, height: size * 0.8)
                .blur(radius: 3)
        }
    }
    
    private var rareFrame: some View {
        ZStack {
            // Ornate border with pattern
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            frameColor,
                            frameColor.opacity(0.7),
                            frameColor,
                            frameColor.opacity(0.7),
                            frameColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: size * 0.82, height: size * 0.82)
            
            // Inner decorative ring
            Circle()
                .stroke(frameColor.opacity(0.4), lineWidth: 1)
                .frame(width: size * 0.77, height: size * 0.77)
            
            // Decorative dots around the circle
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0 * .pi / 180
                let radius = size * 0.42
                
                Circle()
                    .fill(frameColor)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
                    .shadow(color: frameColor.opacity(0.5), radius: 2)
            }
            
            // Glow
            Circle()
                .stroke(frameColor.opacity(0.3), lineWidth: 4)
                .frame(width: size * 0.82, height: size * 0.82)
                .blur(radius: 4)
        }
    }
    
    private var legendaryFrame: some View {
        ZStack {
            // Wings/Rays extending outward
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45.0
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                frameColor,
                                frameColor.opacity(0.7),
                                frameColor.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.25, height: 4)
                    .offset(x: size * 0.3)
                    .rotationEffect(.degrees(angle + rotation * 0.1))
                    .shadow(color: frameColor.opacity(0.5), radius: 4)
            }
            
            // Elaborate border - double ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            frameColor,
                            frameColor.opacity(0.6),
                            frameColor,
                            frameColor.opacity(0.6),
                            frameColor
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: size * 0.85, height: size * 0.85)
            
            Circle()
                .stroke(frameColor.opacity(0.5), lineWidth: 2)
                .frame(width: size * 0.78, height: size * 0.78)
            
            // Decorative gems/jewels on the frame
            ForEach(0..<16, id: \.self) { i in
                let angle = Double(i) * 22.5 * .pi / 180
                let radius = size * 0.44
                let isLarge = i % 4 == 0
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white,
                                frameColor,
                                frameColor.opacity(0.7)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: isLarge ? 4 : 2
                        )
                    )
                    .frame(width: isLarge ? 6 : 3, height: isLarge ? 6 : 3)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
                    .shadow(color: frameColor.opacity(0.8), radius: 3)
            }
            
            // Powerful glow
            Circle()
                .stroke(frameColor.opacity(0.4), lineWidth: 6)
                .frame(width: size * 0.85, height: size * 0.85)
                .blur(radius: 8)
        }
    }
}

// MARK: - Gentle Shimmer Overlay

/// Subtle shimmer that sweeps across the gem periodically
struct GentleShimmer: View {
    let model: CrystalModel
    let size: CGFloat
    
    @State private var shimmerPhase: Double = 0
    
    var body: some View {
        ZStack {
            // Gentle diagonal shine that sweeps across
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0),
                            .init(color: Color.white.opacity(0.15), location: 0.45),
                            .init(color: Color.white.opacity(0.3), location: 0.5),
                            .init(color: Color.white.opacity(0.15), location: 0.55),
                            .init(color: Color.clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 2, height: size)
                .rotationEffect(.degrees(-30))
                .offset(x: (shimmerPhase - 0.5) * size * 3)
                .mask(Circle().frame(width: size * 0.75, height: size * 0.75))
                .blendMode(.overlay)
        }
        .onAppear {
            // Slow periodic shimmer
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.0
            }
        }
    }
}

// MARK: - COMMON SURFACE EFFECTS (Subtle)

struct SubtleShimmerEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    var body: some View {
        gemShape
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.3),
                        Color.clear,
                        Color.white.opacity(0.2),
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    center: .center,
                    angle: .degrees(rotation * 0.5)
                )
            )
            .frame(width: size, height: size)
            .blendMode(.overlay)
            .opacity(0.6)
    }
}

struct SubtleGlowEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let pulse: Double
    
    var body: some View {
        gemShape
            .fill(
                RadialGradient(
                    colors: [
                        primaryColor.opacity(0.3 * pulse),
                        primaryColor.opacity(0.1 * pulse),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 8)
            .blendMode(.screen)
    }
}

struct SubtleSparkleEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    
    @State private var sparklePhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Just a few gentle sparkles
                for i in 0..<6 {
                    let seed = Double(i) * 123.456
                    let twinkle = abs(sin(time * 1.5 + seed))
                    
                    if twinkle > 0.7 {
                        let angle = seed * 2
                        let distance = sin(seed) * canvasSize.width * 0.3
                        let x = canvasSize.width / 2 + cos(angle) * distance
                        let y = canvasSize.height / 2 + sin(angle) * distance
                        
                        // Small cross sparkle
                        let length: CGFloat = 6
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y - length))
                        path.addLine(to: CGPoint(x: x, y: y + length))
                        path.move(to: CGPoint(x: x - length, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y))
                        
                        context.stroke(
                            path,
                            with: .color(Color.white.opacity(twinkle)),
                            lineWidth: 1.5
                        )
                    }
                }
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

// MARK: - RARE SURFACE EFFECTS (More Noticeable)

struct HolographicEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    var body: some View {
        gemShape
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hue: 0.0, saturation: 0.8, brightness: 1.0).opacity(0.3),
                        Color(hue: 0.15, saturation: 0.8, brightness: 1.0).opacity(0.3),
                        Color(hue: 0.3, saturation: 0.8, brightness: 1.0).opacity(0.3),
                        Color(hue: 0.5, saturation: 0.8, brightness: 1.0).opacity(0.3),
                        Color(hue: 0.65, saturation: 0.8, brightness: 1.0).opacity(0.3),
                        Color(hue: 0.8, saturation: 0.8, brightness: 1.0).opacity(0.3),
                        Color(hue: 1.0, saturation: 0.8, brightness: 1.0).opacity(0.3)
                    ]),
                    center: .center,
                    angle: .degrees(rotation * 2)
                )
            )
            .frame(width: size, height: size)
            .blendMode(.screen)
            .opacity(0.7)
    }
}

struct RainbowEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let hue = Double(i) / 7.0
                let offset = Double(i) * size * 0.05
                
                gemShape
                    .stroke(
                        Color(hue: hue, saturation: 0.8, brightness: 1.0).opacity(0.4),
                        lineWidth: 2
                    )
                    .frame(width: size - offset, height: size - offset)
            }
        }
        .rotationEffect(.degrees(rotation * 0.3))
        .blendMode(.screen)
        .opacity(0.6)
    }
}

struct PulseEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var pulsePhase: Double = 0
    
    var body: some View {
        ZStack {
            gemShape
                .fill(primaryColor.opacity(0.2 * pulsePhase))
                .frame(width: size, height: size)
                .blur(radius: 4)
            
            gemShape
                .fill(secondaryColor.opacity(0.2 * (1 - pulsePhase)))
                .frame(width: size, height: size)
                .blur(radius: 4)
        }
        .blendMode(.screen)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
        }
    }
}

// MARK: - LEGENDARY SURFACE EFFECTS (Special but Classy)

struct CleanAuroraEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Just 2-3 gentle flowing waves
                for wave in 0..<3 {
                    let waveOffset = Double(wave) * 0.33
                    let waveTime = time * 0.4 + waveOffset
                    
                    var path = Path()
                    let segments = 20
                    
                    for i in 0...segments {
                        let t = Double(i) / Double(segments)
                        let x = canvasSize.width * t
                        let y = canvasSize.height * 0.5 + 
                                sin(t * .pi * 2 + waveTime) * canvasSize.height * 0.15
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    let waveColor = wave % 2 == 0 ? primaryColor : secondaryColor
                    
                    context.stroke(
                        path,
                        with: .color(waveColor.opacity(0.4)),
                        lineWidth: 8
                    )
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(0.3)),
                        lineWidth: 2
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
        .blur(radius: 2)
    }
}

struct PrismaticEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Clean rainbow rays from center
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45.0
                let hue = Double(i) / 8.0
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: hue, saturation: 0.8, brightness: 1.0).opacity(0.5),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.6, height: 2)
                    .offset(x: size * 0.2)
                    .rotationEffect(.degrees(angle + rotation * 0.5))
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
        .opacity(0.6)
    }
}

// MARK: - RARE EFFECTS (30-49 transfers)

struct PlasmaEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                
                // Liquid plasma blobs that morph and flow
                let blobCount = 15
                
                for blob in 0..<blobCount {
                    let seed = Double(blob) * 12.789
                    let blobTime = time * 0.6 + seed
                    
                    // Blob follows complex orbital path
                    let orbitRadius = canvasSize.width * 0.25
                    let orbitAngle = blobTime * (0.5 + sin(seed) * 0.3) + seed * 2
                    let orbitX = cos(orbitAngle) * orbitRadius
                    let orbitY = sin(orbitAngle) * orbitRadius
                    
                    // Add secondary oscillation for figure-8 patterns
                    let secondaryAngle = blobTime * 1.2 + seed
                    let secondaryRadius = canvasSize.width * 0.15
                    let x = centerX + orbitX + cos(secondaryAngle) * secondaryRadius
                    let y = centerY + orbitY + sin(secondaryAngle) * secondaryRadius
                    
                    // Blob morphs in size
                    let baseSize = canvasSize.width * 0.15
                    let sizePulse = sin(blobTime * 2 + seed) * 0.4 + 1.0
                    let blobWidth = baseSize * sizePulse
                    let blobHeight = baseSize * (sizePulse * 1.2) // Slightly elliptical
                    
                    // Rotation for organic feel
                    let rotation = blobTime * 0.8 + seed
                    
                    // Color shifting between primary and secondary with extra hue shift
                    let colorMix = (sin(blobTime * 0.8 + seed) + 1.0) / 2.0
                    let hueShift = (time * 20 + Double(blob) * 30).truncatingRemainder(dividingBy: 360)
                    let blobColor = Color(hue: hueShift / 360.0, saturation: 0.9, brightness: 1.0)
                    
                    // Create blob with multiple layers for depth
                    for layer in 0..<4 {
                        let layerScale = 1.0 - Double(layer) * 0.2
                        let layerWidth = blobWidth * layerScale
                        let layerHeight = blobHeight * layerScale
                        
                        let blobRect = CGRect(
                            x: x - layerWidth / 2,
                            y: y - layerHeight / 2,
                            width: layerWidth,
                            height: layerHeight
                        )
                        
                        var blobPath = Path(ellipseIn: blobRect)
                        
                        // Apply rotation transform
                        var transform = CGAffineTransform(translationX: x, y: y)
                        transform = transform.rotated(by: rotation)
                        transform = transform.translatedBy(x: -x, y: -y)
                        blobPath = blobPath.applying(transform)
                        
                        let layerOpacity = (0.25 - Double(layer) * 0.05) * sizePulse
                        context.fill(
                            blobPath,
                            with: .color(blobColor.opacity(layerOpacity))
                        )
                    }
                    
                    // Bright hotspot
                    let hotspotSize = blobWidth * 0.3
                    let hotspotRect = CGRect(
                        x: x - hotspotSize / 2,
                        y: y - hotspotSize / 2,
                        width: hotspotSize,
                        height: hotspotSize
                    )
                    let hotspotPath = Path(ellipseIn: hotspotRect)
                    context.fill(
                        hotspotPath,
                        with: .color(Color.white.opacity(0.5 * sizePulse))
                    )
                }
                
                // Energy tendrils connecting nearby blobs
                var blobPositions: [(CGPoint, Double)] = []
                for blob in 0..<blobCount {
                    let seed = Double(blob) * 12.789
                    let blobTime = time * 0.6 + seed
                    
                    let orbitRadius = canvasSize.width * 0.25
                    let orbitAngle = blobTime * (0.5 + sin(seed) * 0.3) + seed * 2
                    let orbitX = cos(orbitAngle) * orbitRadius
                    let orbitY = sin(orbitAngle) * orbitRadius
                    
                    let secondaryAngle = blobTime * 1.2 + seed
                    let secondaryRadius = canvasSize.width * 0.15
                    let x = centerX + orbitX + cos(secondaryAngle) * secondaryRadius
                    let y = centerY + orbitY + sin(secondaryAngle) * secondaryRadius
                    
                    blobPositions.append((CGPoint(x: x, y: y), seed))
                }
                
                // Draw connections between close blobs
                for i in 0..<blobPositions.count {
                    for j in (i+1)..<blobPositions.count {
                        let pos1 = blobPositions[i].0
                        let pos2 = blobPositions[j].0
                        
                        let dx = pos2.x - pos1.x
                        let dy = pos2.y - pos1.y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        if distance < canvasSize.width * 0.35 {
                            var path = Path()
                            path.move(to: pos1)
                            
                            // Wavy connection
                            let midX = (pos1.x + pos2.x) / 2
                            let midY = (pos1.y + pos2.y) / 2
                            let perpX = -dy / distance
                            let perpY = dx / distance
                            let waveOffset = sin(time * 2 + Double(i + j)) * 15
                            
                            path.addQuadCurve(
                                to: pos2,
                                control: CGPoint(
                                    x: midX + perpX * waveOffset,
                                    y: midY + perpY * waveOffset
                                )
                            )
                            
                            let connectionStrength = 1.0 - (distance / (canvasSize.width * 0.35))
                            let hue = (time * 30 + Double(i + j) * 40).truncatingRemainder(dividingBy: 360)
                            let connectionColor = Color(hue: hue / 360.0, saturation: 0.8, brightness: 1.0)
                            
                            context.stroke(
                                path,
                                with: .color(connectionColor.opacity(connectionStrength * 0.3)),
                                lineWidth: 2.0
                            )
                            
                            context.stroke(
                                path,
                                with: .color(Color.white.opacity(connectionStrength * 0.2)),
                                lineWidth: 1.0
                            )
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
        .blur(radius: size * 0.02) // Slight blur for plasma glow
    }
}

struct PrismEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    @State private var trippyPhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                
                // Draw holographic interference patterns
                drawInterferencePatterns(
                    context: context,
                    canvasSize: canvasSize,
                    centerY: centerY,
                    time: time
                )
                
                // Draw shifting color zones
                drawColorZones(
                    context: context,
                    canvasSize: canvasSize,
                    centerX: centerX,
                    centerY: centerY,
                    time: time
                )
                
                // Draw kaleidoscope geometry
                drawKaleidoscope(
                    context: context,
                    canvasSize: canvasSize,
                    centerX: centerX,
                    centerY: centerY,
                    time: time
                )
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
        .onAppear {
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                trippyPhase = .pi * 2
            }
        }
    }
    
    private func drawInterferencePatterns(context: GraphicsContext, canvasSize: CGSize, centerY: CGFloat, time: Double) {
        for band in 0..<6 {
            let bandOffset = Double(band) * .pi / 3
            let bandFrequency = 8.0 + Double(band) * 4.0
            
            for strip in 0..<30 {
                let stripProgress = Double(strip) / 30.0
                
                // Wave displacement
                let waveX = stripProgress * canvasSize.width
                let waveCalc1 = stripProgress * bandFrequency + time * 2 + bandOffset
                let waveCalc2 = (stripProgress + 0.033) * bandFrequency + time * 2 + bandOffset
                let waveY1 = centerY + sin(waveCalc1) * canvasSize.height * 0.25
                let waveY2 = centerY + sin(waveCalc2) * canvasSize.height * 0.25
                
                // Rainbow color
                let hueCalc = stripProgress + time * 0.2 + Double(band) * 0.16
                let hue = hueCalc.truncatingRemainder(dividingBy: 1.0)
                let stripColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)
                
                var path = Path()
                path.move(to: CGPoint(x: waveX, y: waveY1))
                path.addLine(to: CGPoint(x: waveX + 2, y: waveY2))
                
                // Vary opacity with interference pattern
                let interferenceCalc = stripProgress * 20 + time * 3
                let interference = sin(interferenceCalc) * 0.3 + 0.5
                let finalOpacity = interference * 0.6
                
                context.stroke(
                    path,
                    with: .color(stripColor.opacity(finalOpacity)),
                    lineWidth: 3.0
                )
            }
        }
    }
    
    private func drawColorZones(context: GraphicsContext, canvasSize: CGSize, centerX: CGFloat, centerY: CGFloat, time: Double) {
        for zone in 0..<12 {
            let zoneDouble = Double(zone)
            let zoneAngle = zoneDouble * .pi / 6 + time * 0.5
            let hue = zoneDouble / 12.0
            let zoneColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)
            
            // Calculate positions
            let cosZone = cos(zoneAngle)
            let sinZone = sin(zoneAngle)
            let endX = centerX + cosZone * canvasSize.width * 0.5
            let endY = centerY + sinZone * canvasSize.height * 0.5
            
            var path = Path()
            path.move(to: CGPoint(x: centerX, y: centerY))
            path.addLine(to: CGPoint(x: endX, y: endY))
            
            // Pulsing width
            let timeFactor = time * 2 + zoneDouble
            let pulseAmount = sin(timeFactor) * 10
            let pulseWidth: CGFloat = 20 + pulseAmount
            
            context.stroke(
                path,
                with: .color(zoneColor.opacity(0.35)),
                lineWidth: pulseWidth
            )
        }
    }
    
    private func drawKaleidoscope(context: GraphicsContext, canvasSize: CGSize, centerX: CGFloat, centerY: CGFloat, time: Double) {
        let segmentCount = 8
        for segment in 0..<segmentCount {
            let segmentAngle = Double(segment) * (.pi * 2 / Double(segmentCount))
            
            for layer in 0..<5 {
                let layerRadius = canvasSize.width * 0.15 * (1.0 + Double(layer) * 0.2)
                let angle1 = segmentAngle + time * 0.4
                let angle2 = segmentAngle + (.pi * 2 / Double(segmentCount)) + time * 0.4
                
                var path = Path()
                path.move(to: CGPoint(x: centerX, y: centerY))
                path.addLine(to: CGPoint(
                    x: centerX + cos(angle1) * layerRadius,
                    y: centerY + sin(angle1) * layerRadius
                ))
                path.addLine(to: CGPoint(
                    x: centerX + cos(angle2) * layerRadius,
                    y: centerY + sin(angle2) * layerRadius
                ))
                path.closeSubpath()
                
                // Rainbow gradient per segment
                let hueCalc = Double(segment) / Double(segmentCount) + time * 0.15
                let hue = hueCalc.truncatingRemainder(dividingBy: 1.0)
                let segmentColor = Color(hue: hue, saturation: 0.9, brightness: 1.0)
                
                context.fill(
                    path,
                    with: .color(segmentColor.opacity(0.15))
                )
                
                context.stroke(
                    path,
                    with: .color(segmentColor.opacity(0.4)),
                    lineWidth: 1.5
                )
            }
        }
    }
}

struct CelestialEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    
    @State private var pulsePhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                
                // Draw mandala petals
                drawMandala(
                    context: context,
                    canvasSize: canvasSize,
                    centerX: centerX,
                    centerY: centerY,
                    time: time
                )
                
                // Draw central sacred geometry
                drawSacredGeometry(
                    context: context,
                    canvasSize: canvasSize,
                    centerX: centerX,
                    centerY: centerY,
                    time: time
                )
            }
        }
        .frame(width: size, height: size)
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
    
    private func drawMandala(context: GraphicsContext, canvasSize: CGSize, centerX: CGFloat, centerY: CGFloat, time: Double) {
        let ringCount = 8
        let petalCount = 12
        
        for ring in 0..<ringCount {
            let ringDouble = Double(ring)
            let ringProgress = ringDouble / Double(ringCount)
            let radius = canvasSize.width * 0.45 * ringProgress
            
            // Each ring breathes at different rates
            let breatheCalc = time * (1.5 + ringDouble * 0.3)
            let breathe = sin(breatheCalc) * 0.2 + 1.0
            let animatedRadius = radius * breathe
            
            for petal in 0..<petalCount {
                let petalDouble = Double(petal)
                
                // Calculate angles
                let baseAngle = petalDouble * (.pi * 2 / Double(petalCount))
                let angleOffset = time * 0.5 + ringDouble * 0.2
                let angle = baseAngle + angleOffset
                
                // Petal position with spiral distortion
                let spiralCalc = time * 0.8 + petalDouble * 0.5
                let spiralFactor = sin(spiralCalc) * 0.3
                let cosAngle = cos(angle + spiralFactor)
                let sinAngle = sin(angle + spiralFactor)
                let x = centerX + cosAngle * animatedRadius
                let y = centerY + sinAngle * animatedRadius
                
                // Petal dimensions
                let petalLength = canvasSize.width * 0.12 * (1.0 - ringProgress * 0.5)
                let petalWidth = petalLength * 0.4
                
                // Petal color
                let hueCalc = time * 30 + petalDouble * 30 + ringDouble * 15
                let hueShift = hueCalc.truncatingRemainder(dividingBy: 360)
                let petalHue = hueShift / 360.0
                let petalColor = Color(hue: petalHue, saturation: 0.9, brightness: 1.0)
                
                // Petal path
                let petalRect = CGRect(
                    x: x - petalWidth / 2,
                    y: y - petalLength / 2,
                    width: petalWidth,
                    height: petalLength
                )
                let petalPath = Path(ellipseIn: petalRect)
                
                // Pulsing opacity
                let pulseCalc = time * 2 + petalDouble * 0.5 + ringDouble * 0.3
                let pulseValue = sin(pulseCalc) * 0.3 + 0.7
                let opacity = 0.4 * pulseValue * (1.0 - ringProgress * 0.3)
                
                // Transform for rotation
                let wobbleCalc = time * 3 + petalDouble
                let wobble = sin(wobbleCalc) * 0.2
                var transform = CGAffineTransform(translationX: x, y: y)
                transform = transform.rotated(by: angle + .pi / 2 + wobble)
                transform = transform.translatedBy(x: -x, y: -y)
                
                var rotatedPath = Path(petalPath.cgPath)
                rotatedPath = rotatedPath.applying(transform)
                
                // Draw outer glow
                let outerOpacity = opacity * 0.4
                context.fill(
                    rotatedPath,
                    with: .color(petalColor.opacity(outerOpacity))
                )
                
                // Draw bright core
                let coreRect = CGRect(
                    x: x - petalWidth / 4,
                    y: y - petalLength / 4,
                    width: petalWidth / 2,
                    height: petalLength / 2
                )
                var corePath = Path(ellipseIn: coreRect)
                corePath = corePath.applying(transform)
                let coreOpacity = opacity * 0.6
                context.fill(
                    corePath,
                    with: .color(Color.white.opacity(coreOpacity))
                )
            }
        }
    }
    
    private func drawSacredGeometry(context: GraphicsContext, canvasSize: CGSize, centerX: CGFloat, centerY: CGFloat, time: Double) {
        let geometryRotation = time * 0.8
        
        for layer in 0..<6 {
            let layerDouble = Double(layer)
            let layerRadius = canvasSize.width * 0.15 * (1.0 + layerDouble * 0.25)
            let sides = 6
            
            var path = Path()
            for i in 0...sides {
                let iDouble = Double(i)
                let angleCalc = iDouble * (.pi * 2 / Double(sides)) + geometryRotation + layerDouble * 0.5
                let x = centerX + cos(angleCalc) * layerRadius
                let y = centerY + sin(angleCalc) * layerRadius
                
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            let hueCalc = time * 40 + layerDouble * 60
            let hueShift = hueCalc.truncatingRemainder(dividingBy: 360)
            let lineColor = Color(hue: hueShift / 360.0, saturation: 1.0, brightness: 1.0)
            
            context.stroke(
                path,
                with: .color(lineColor.opacity(0.5)),
                lineWidth: 2.0
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.3)),
                lineWidth: 1.0
            )
        }
    }
}

// MARK: - LEGENDARY EFFECTS (50+ transfers)

struct ConstellationEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    
    @State private var connectionPhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Create better distributed star positions
                let starCount = 20
                var starPositions: [(CGPoint, Double)] = []
                
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                let maxRadius = min(canvasSize.width, canvasSize.height) * 0.4
                
                // Use Fibonacci/golden ratio for better distribution
                for i in 0..<starCount {
                    let iDouble = Double(i)
                    
                    // Golden angle for spiral distribution
                    let goldenAngle = .pi * 2.0 * 0.618034  // Golden ratio
                    let angle = iDouble * goldenAngle
                    
                    // Vary distance for better coverage
                    let normalizedI = iDouble / Double(starCount)
                    let distance = sqrt(normalizedI) * maxRadius  // Square root for even distribution
                    
                    let x = centerX + cos(angle) * distance
                    let y = centerY + sin(angle) * distance
                    
                    // Varied twinkling
                    let twinkle = 0.4 + abs(sin(time * (1.5 + normalizedI) + iDouble)) * 0.6
                    starPositions.append((CGPoint(x: x, y: y), twinkle))
                }
                
                // Draw constellation lines connecting nearby stars
                for i in 0..<starPositions.count {
                    for j in (i+1)..<starPositions.count {
                        let pos1 = starPositions[i].0
                        let pos2 = starPositions[j].0
                        
                        let dx = pos2.x - pos1.x
                        let dy = pos2.y - pos1.y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        // Connect stars that are close but not too close
                        let connectionThreshold = maxRadius * 0.4
                        if distance < connectionThreshold && distance > maxRadius * 0.1 {
                            var path = Path()
                            path.move(to: pos1)
                            path.addLine(to: pos2)
                            
                            // Animated connection strength
                            let phaseOffset = Double(i + j) * 0.3
                            let connectionStrength = (sin(time * 0.5 + phaseOffset) + 1.0) / 2.0
                            let baseOpacity = 1.0 - (distance / connectionThreshold) * 0.5
                            let opacity = baseOpacity * connectionStrength * 0.4
                            
                            context.stroke(
                                path,
                                with: .color(primaryColor.opacity(opacity)),
                                lineWidth: 1.0
                            )
                            
                            // Brighter core for closer connections
                            if distance < connectionThreshold * 0.6 {
                                context.stroke(
                                    path,
                                    with: .color(Color.white.opacity(opacity * 0.3)),
                                    lineWidth: 0.5
                                )
                            }
                        }
                    }
                }
                
                // Draw stars with varied sizes
                for (index, (position, twinkle)) in starPositions.enumerated() {
                    // Vary star sizes - make some "major" stars bigger
                    let isMajorStar = index % 4 == 0
                    let baseSize = isMajorStar ? 5.0 : 3.5
                    let starSize = baseSize + twinkle * 2.5
                    
                    // Star glow
                    let glowSize = starSize * 2.5
                    let glowPath = Path(ellipseIn: CGRect(
                        x: position.x - glowSize,
                        y: position.y - glowSize,
                        width: glowSize * 2,
                        height: glowSize * 2
                    ))
                    context.fill(glowPath, with: .color(primaryColor.opacity(twinkle * 0.3)))
                    
                    // Star core
                    let corePath = Path(ellipseIn: CGRect(
                        x: position.x - starSize / 2,
                        y: position.y - starSize / 2,
                        width: starSize,
                        height: starSize
                    ))
                    context.fill(corePath, with: .color(Color.white.opacity(twinkle * 0.9)))
                    
                    // Cross sparkle
                    var sparkle = Path()
                    let sparkleLength = starSize * 1.2
                    sparkle.move(to: CGPoint(x: position.x, y: position.y - sparkleLength))
                    sparkle.addLine(to: CGPoint(x: position.x, y: position.y + sparkleLength))
                    sparkle.move(to: CGPoint(x: position.x - sparkleLength, y: position.y))
                    sparkle.addLine(to: CGPoint(x: position.x + sparkleLength, y: position.y))
                    
                    context.stroke(sparkle, with: .color(Color.white.opacity(twinkle * 0.6)), lineWidth: 0.8)
                    
                    // Add diagonal sparkles for major stars
                    if isMajorStar {
                        var diagonalSparkle = Path()
                        let diagLength = sparkleLength * 0.7
                        diagonalSparkle.move(to: CGPoint(x: position.x - diagLength, y: position.y - diagLength))
                        diagonalSparkle.addLine(to: CGPoint(x: position.x + diagLength, y: position.y + diagLength))
                        diagonalSparkle.move(to: CGPoint(x: position.x + diagLength, y: position.y - diagLength))
                        diagonalSparkle.addLine(to: CGPoint(x: position.x - diagLength, y: position.y + diagLength))
                        
                        context.stroke(diagonalSparkle, with: .color(Color.white.opacity(twinkle * 0.5)), lineWidth: 0.6)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

struct AuroraEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var wavePhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                let centerY = canvasSize.height / 2
                let amplitude = canvasSize.height * 0.15  // Wave height
                
                // Multiple flowing aurora waves
                for wave in 0..<5 {
                    let waveOffset = Double(wave) * 0.2
                    let waveTime = time * 0.3 + waveOffset
                    
                    // Vertical offset for this wave (centered around middle)
                    let waveDouble = Double(wave)
                    let verticalSpacing = canvasSize.height * 0.12
                    let baseY = centerY + (waveDouble - 2.0) * verticalSpacing
                    
                    // Create flowing wave path
                    var path = Path()
                    let segments = 30
                    
                    for i in 0...segments {
                        let t = Double(i) / Double(segments)
                        let x = canvasSize.width * t
                        
                        // Multiple sine waves for complex aurora shape
                        let wave1 = sin(t * .pi * 3 + waveTime + waveDouble) * amplitude
                        let wave2 = sin(t * .pi * 7 + waveTime * 1.3) * amplitude * 0.3
                        let y = baseY + wave1 + wave2
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    // Color gradient between primary and secondary
                    let sinValue = sin(time * 0.5 + waveDouble * 0.5)
                    let colorMix = (sinValue + 1.0) / 2.0
                    
                    // Create interpolated color by mixing hues
                    // Use a simpler approach that doesn't rely on CGColor components
                    let baseHue = 0.5 + waveDouble * 0.08  // Vary hue per wave
                    let waveColor = Color(hue: baseHue, saturation: 0.8, brightness: 0.9)
                    
                    // Draw wave with glow
                    let thicknesses: [CGFloat] = [15.0, 12.0, 9.0, 6.0, 3.0]
                    for thickness in thicknesses {
                        let thicknessRatio = thickness / 15.0
                        let baseOpacity = 0.15
                        let opacityReduction = thicknessRatio * 0.5
                        let opacity = baseOpacity * (1.0 - opacityReduction)
                        
                        context.stroke(
                            path,
                            with: .color(waveColor.opacity(opacity)),
                            lineWidth: thickness
                        )
                    }
                    
                    // Bright core
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(0.4)),
                        lineWidth: 1.0
                    )
                }
            }
        }
        .frame(width: size, height: size)  // Set explicit frame
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

struct NebulaEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                let maxRadius = min(canvasSize.width, canvasSize.height) * 0.4
                
                // Swirling nebula clouds - MORE VISIBLE
                for cloud in 0..<30 {  // More clouds
                    let seed = Double(cloud) * 12.456
                    let cloudTime = time * 0.3 + seed  // Faster movement
                    
                    // Cloud position (slowly drifting in circle around center)
                    let angle = cloudTime * 0.4 + seed * 2
                    let radius = maxRadius * (0.3 + sin(cloudTime * 0.5 + seed) * 0.6)
                    let x = centerX + cos(angle) * radius
                    let y = centerY + sin(angle) * radius
                    
                    // Larger cloud sizes
                    let baseSize = maxRadius * 0.35
                    let cloudSize = baseSize * (0.7 + sin(cloudTime * 0.7 + seed) * 0.3)
                    
                    // More vibrant colors
                    let cloudColor: Color
                    let cloudMod = cloud % 4
                    if cloudMod == 0 {
                        cloudColor = primaryColor
                    } else if cloudMod == 1 {
                        cloudColor = secondaryColor
                    } else if cloudMod == 2 {
                        // Blend color
                        cloudColor = Color(hue: 0.6, saturation: 0.8, brightness: 0.9)
                    } else {
                        // White wispy clouds
                        cloudColor = Color.white
                    }
                    
                    // Nebula cloud with multiple layers for depth
                    let cloudPath = Path(ellipseIn: CGRect(
                        x: x - cloudSize,
                        y: y - cloudSize,
                        width: cloudSize * 2,
                        height: cloudSize * 2
                    ))
                    
                    // Outer glow - more visible
                    context.fill(cloudPath, with: .color(cloudColor.opacity(0.15)))
                    
                    // Inner brighter core
                    let coreSize = cloudSize * 0.6
                    let corePath = Path(ellipseIn: CGRect(
                        x: x - coreSize,
                        y: y - coreSize,
                        width: coreSize * 2,
                        height: coreSize * 2
                    ))
                    context.fill(corePath, with: .color(cloudColor.opacity(0.25)))
                    
                    // Very bright center
                    let centerSize = cloudSize * 0.3
                    let centerPath = Path(ellipseIn: CGRect(
                        x: x - centerSize,
                        y: y - centerSize,
                        width: centerSize * 2,
                        height: centerSize * 2
                    ))
                    context.fill(centerPath, with: .color(cloudColor.opacity(0.4)))
                }
                
                // Add MORE star particles scattered throughout
                for star in 0..<50 {
                    let seed = Double(star) * 45.123
                    let angle = seed * 3.0
                    let distance = sin(seed * 2.0) * maxRadius * 1.2
                    
                    let x = centerX + cos(angle) * distance
                    let y = centerY + sin(angle) * distance
                    
                    // Twinkling stars
                    let twinkle = 0.3 + abs(sin(time * 2.0 + seed)) * 0.7
                    let starSize: CGFloat = (star % 3 == 0) ? 3.0 : 2.0  // Varied sizes
                    
                    let starPath = Path(ellipseIn: CGRect(
                        x: x - starSize,
                        y: y - starSize,
                        width: starSize * 2,
                        height: starSize * 2
                    ))
                    context.fill(starPath, with: .color(Color.white.opacity(twinkle)))
                    
                    // Glow around brighter stars
                    if star % 3 == 0 {
                        let glowSize = starSize * 2
                        let glowPath = Path(ellipseIn: CGRect(
                            x: x - glowSize,
                            y: y - glowSize,
                            width: glowSize * 2,
                            height: glowSize * 2
                        ))
                        context.fill(glowPath, with: .color(Color.white.opacity(twinkle * 0.3)))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
        .blur(radius: size * 0.04)  // Less blur to make it more visible
    }
}

struct VortexEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                let maxRadius = min(canvasSize.width, canvasSize.height) * 0.45
                
                // Spiral arms pulling toward/pushing from center
                let armCount = 6
                
                for arm in 0..<armCount {
                    let baseAngle = Double(arm) * .pi * 2 / Double(armCount)
                    
                    // Create spiral path
                    var path = Path()
                    let segments = 40
                    
                    for i in 0...segments {
                        let t = Double(i) / Double(segments)
                        let distance = maxRadius * t
                        
                        // Spiral formula
                        let angle = baseAngle + t * .pi * 3 + time * 0.5
                        
                        let x = centerX + cos(angle) * distance
                        let y = centerY + sin(angle) * distance
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    // Alternate colors
                    let armColor = arm % 2 == 0 ? primaryColor : secondaryColor
                    
                    // Draw spiral with gradient thickness
                    context.stroke(
                        path,
                        with: .color(armColor.opacity(0.4)),
                        lineWidth: 3.0
                    )
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(0.5)),
                        lineWidth: 1.0
                    )
                }
                
                // Energy particles being pulled in/pushed out
                for particle in 0..<30 {
                    let seed = Double(particle) * 45.678
                    let particleTime = (time * 2 + seed).truncatingRemainder(dividingBy: 3.0)
                    let progress = particleTime / 3.0
                    
                    // Particle follows spiral
                    let armIndex = Int(seed * 10) % armCount
                    let baseAngle = Double(armIndex) * .pi * 2 / Double(armCount)
                    
                    let distance = maxRadius * (1 - progress) // Moving inward
                    let angle = baseAngle + (1 - progress) * .pi * 3 + time * 0.5
                    
                    let x = centerX + cos(angle) * distance
                    let y = centerY + sin(angle) * distance
                    
                    // Particle size and brightness
                    let particleSize: CGFloat = 3 * (1 - progress) + 1
                    let brightness = 1.0 - progress * 0.5
                    
                    let particlePath = Path(ellipseIn: CGRect(
                        x: x - particleSize,
                        y: y - particleSize,
                        width: particleSize * 2,
                        height: particleSize * 2
                    ))
                    
                    context.fill(particlePath, with: .color(Color.white.opacity(brightness * 0.9)))
                }
            }
        }
        .frame(width: size, height: size)  // Set explicit frame
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

// MARK: - Shape Definitions

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addCurve(to: CGPoint(x: w, y: h * 0.35), control1: CGPoint(x: w * 0.75, y: h * 0.75), control2: CGPoint(x: w, y: h * 0.55))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.15), control1: CGPoint(x: w, y: h * 0.15), control2: CGPoint(x: w * 0.7, y: 0))
        path.addCurve(to: CGPoint(x: 0, y: h * 0.35), control1: CGPoint(x: w * 0.3, y: 0), control2: CGPoint(x: 0, y: h * 0.15))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: 0, y: h * 0.55), control2: CGPoint(x: w * 0.25, y: h * 0.75))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5
        
        for i in 0..<(points * 2) {
            let angle = (.pi / Double(points)) * Double(i) - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.93, y: h * 0.25))
        path.addLine(to: CGPoint(x: w * 0.93, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: w * 0.07, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.07, y: h * 0.25))
        path.closeSubpath()
        return path
    }
}

struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let offset = 0.3
        
        path.move(to: CGPoint(x: w * offset, y: 0))
        path.addLine(to: CGPoint(x: w * (1 - offset), y: 0))
        path.addLine(to: CGPoint(x: w, y: h * offset))
        path.addLine(to: CGPoint(x: w, y: h * (1 - offset)))
        path.addLine(to: CGPoint(x: w * (1 - offset), y: h))
        path.addLine(to: CGPoint(x: w * offset, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * (1 - offset)))
        path.addLine(to: CGPoint(x: 0, y: h * offset))
        path.closeSubpath()
        return path
    }
}

struct DiamondCutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        
        path.move(to: CGPoint(x: cx, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: cy))
        path.addLine(to: CGPoint(x: cx, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: cy))
        path.closeSubpath()
        return path
    }
}

struct PearShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.5, y: h))
        path.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.35), control1: CGPoint(x: w * 0.75, y: h * 0.8), control2: CGPoint(x: w * 0.85, y: h * 0.55))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.15), control1: CGPoint(x: w * 0.85, y: h * 0.23), control2: CGPoint(x: w * 0.7, y: h * 0.15))
        path.addCurve(to: CGPoint(x: w * 0.15, y: h * 0.35), control1: CGPoint(x: w * 0.3, y: h * 0.15), control2: CGPoint(x: w * 0.15, y: h * 0.23))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: w * 0.15, y: h * 0.55), control2: CGPoint(x: w * 0.25, y: h * 0.8))
        path.closeSubpath()
        return path
    }
}

struct MarquiseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h), control1: CGPoint(x: w * 0.9, y: h * 0.25), control2: CGPoint(x: w * 0.9, y: h * 0.75))
        path.addCurve(to: CGPoint(x: w * 0.5, y: 0), control1: CGPoint(x: w * 0.1, y: h * 0.75), control2: CGPoint(x: w * 0.1, y: h * 0.25))
        path.closeSubpath()
        return path
    }
}

struct CushionShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.width * 0.15)
    }
}

// MARK: - Randomizer Playground

struct MagicalCrystalPlayground: View {
    @State private var currentDNA: CrystalDNA = Self.randomDNA()
    @State private var transferCount: Int = 15
    @State private var selectedEffect: SurfaceEffect? = nil  // nil means auto
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Crystal display
                MagicalCrystalView(
                    dna: currentDNA,
                    transferCount: transferCount,
                    size: 280,
                    forcedSurfaceEffect: selectedEffect
                )
                .id(currentDNA.seed) // Force re-render on DNA change
                
                // Info
                VStack(spacing: 8) {
                    Text(currentDNA.identity.baseForm.capitalized)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    Text("Hue: \(Int(currentDNA.identity.primaryHue))° • Sat: \(Int((currentDNA.identity.saturation ?? 1.0) * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Text("Transfers: \(transferCount)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))

                        if Tier.from(transferCount: transferCount) != .seed {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    if let effect = selectedEffect {
                        Text("Effect: \(effect.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    } else {
                        switch Tier.from(transferCount: transferCount) {
                        case .radiance:
                            Text("⭐️ Radiance Effect Active ⭐️")
                                .font(.caption2.bold())
                                .foregroundColor(.yellow)
                        case .legacy:
                            Text("💎 Legacy Effect Active")
                                .font(.caption2.bold())
                                .foregroundColor(.purple)
                        case .bloom:
                            Text("✨ Bloom Effect Active")
                                .font(.caption2)
                                .foregroundColor(.green)
                        case .seed:
                            Text("Surface Effect: Locked (5+ transfers)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                // Controls
                VStack(spacing: 16) {
                    // Surface Effect Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Surface Effect")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                        
                        Picker("Surface Effect", selection: $selectedEffect) {
                            Text("Auto").tag(nil as SurfaceEffect?)
                            ForEach(SurfaceEffect.allCases, id: \.self) { effect in
                                Text(effect.rawValue).tag(effect as SurfaceEffect?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.cyan)
                    }
                    .padding(.horizontal)
                    
                    // Transfer count slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Evolution Level")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                        
                        Slider(value: Binding(
                            get: { Double(transferCount) },
                            set: { transferCount = Int($0) }
                        ), in: 0...60, step: 1)
                        .tint(.cyan)
                    }
                    .padding(.horizontal)
                    
                    // Randomize button
                    Button(action: randomize) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Randomize Crystal")
                            Image(systemName: "sparkles")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func randomize() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDNA = Self.randomDNA()
        }
    }
    
    static func randomDNA() -> CrystalDNA {
        let primaryHue = Double.random(in: 0...360)
        let relationships = ["analogous", "complementary", "triadic", "refracted"]
        let relationship = relationships.randomElement()!
        
        let secondaryHue: Double
        switch relationship {
        case "complementary":
            secondaryHue = (primaryHue + 180).truncatingRemainder(dividingBy: 360)
        case "triadic":
            secondaryHue = (primaryHue + 120).truncatingRemainder(dividingBy: 360)
        case "analogous":
            secondaryHue = (primaryHue + Double.random(in: 20...60)).truncatingRemainder(dividingBy: 360)
        default:
            secondaryHue = Double.random(in: 0...360)
        }
        
        // Different shapes for variety!
        let shapes = ["diamond", "heart", "star", "hexagon", "octagon", "pear", "marquise", "cushion", "circle"]
        
        return CrystalDNA(
            identity: CrystalIdentity(
                primaryColor: primaryHue,
                secondaryColor: secondaryHue,
                accentColor: (secondaryHue + 30).truncatingRemainder(dividingBy: 360),
                materialFamily: ["spectral", "coloredGemstone", "opalescent"].randomElement()!,
                baseForm: shapes.randomElement()!,
                colorRelationship: relationship,
                secondaryInfluence: Double.random(in: 0.3...0.8),
                saturation: Double.random(in: 0.6...1.0),
                refraction: Double.random(in: 0.6...1.0),
                luster: nil,
                transparency: nil,
                innerLight: nil,
                inclusionType: nil,
                inclusionDensity: nil,
                facetCount: nil,
                facetPattern: nil,
                symmetry: nil,
                surfaceCharacter: nil,
                palette: nil, frameHue: 0.1
            ),
            personality: CrystalPersonality(
                complexityBias: Double.random(in: 0.5...1.0),
                orbitalAffinity: Double.random(in: 0.7...1.0),
                evolutionFamily: nil,
                secondaryFamily: nil,
                metallicAffinity: nil,
                fractalAffinity: nil,
                spectralAffinity: nil,
                organicAffinity: nil,
                celestialAffinity: nil,
                particleAffinity: nil,
                refraction: Double.random(in: 0.6...1.0)
            ),
            seed: UUID().uuidString
        )
    }
}

// MARK: - Lightweight Preview Version (for Xcode Previews)

/// Simplified version without expensive particle systems for faster previews
struct MagicalCrystalView_PreviewOptimized: View {
    let model: CrystalModel
    let size: CGFloat
    var forcedSurfaceEffect: SurfaceEffect? = nil
    
    init(dna: CrystalDNA, transferCount: Int, size: CGFloat = 200, forcedSurfaceEffect: SurfaceEffect? = nil) {
        self.model = CrystalEngine.derive(dna: dna, transferCount: transferCount)
        self.size = size
        self.forcedSurfaceEffect = forcedSurfaceEffect
    }
    
    var body: some View {
        ZStack {
            // Just the gem core, skip expensive particles and swirls
            MagicalGemCore(model: model, size: size, forcedSurfaceEffect: forcedSurfaceEffect)
        }
        .frame(width: size, height: size)
    }
    
    private var primaryColor: Color {
        Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
    }
    
    private var secondaryColor: Color {
        Color(
            hue: model.secondaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.85
        )
    }
}

// MARK: - Preview
// Note: If previews timeout, comment them out and run the app in simulator instead.
// The full MagicalCrystalView with particles is very expensive for Xcode Previews.

// Uncomment to test the randomizer (most expensive preview):
/*
#Preview("🎲 Magical Crystal Randomizer") {
    MagicalCrystalPlayground()
}
*/

