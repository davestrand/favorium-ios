//
//  MagicalCrystalView.swift
//  favorium
//
//  Created by Assistant on 10/9/26.
//
//  Experimental magical crystal with particle effects and fluid dynamics

import SwiftUI
import SpriteKit

/// Experimental magical crystal view with particles, swirls, and fluid effects
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
            // Base magical glow (reduced)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(0.4),
                            secondaryColor.opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .blur(radius: size * 0.12)
            
            // Particle system using SpriteKit (more subtle)
            MagicalParticleScene(model: model, size: size)
                .opacity(0.7)  // Reduce particle visibility
            
            // Swirling fluid layer (more subtle)
            FluidSwirls(model: model, size: size)
                .opacity(0.5)  // Reduce swirl visibility
            
            // Central gem core - THE STAR OF THE SHOW
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
    
    // Surface effects unlock at 5+ transfers
    private var hasSurfaceEffect: Bool {
        model.transferCount >= 5
    }
    
    // Surface effect - deterministic based on model, or forced
    // Tiered system:
    // - 5-29 transfers: Common effects
    // - 30-49 transfers: Rare effects  
    // - 50+ transfers: LEGENDARY effects
    private var surfaceEffect: SurfaceEffect? {
        // Always show if forced (for preview/testing)
        if let forced = forcedSurfaceEffect {
            return forced
        }
        
        // Only show surface effects at 5+ transfers
        guard hasSurfaceEffect else {
            return nil
        }
        
        // Use the model's seed to deterministically pick an effect
        let hash = abs(model.seed.hashValue)
        
        // Legendary effects for 50+ transfers
        if model.transferCount >= 50 {
            let legendaryEffects: [SurfaceEffect] = [.constellation, .aurora, .nebula, .vortex]
            return legendaryEffects[hash % legendaryEffects.count]
        }
        
        // Rare effects for 30-49 transfers
        if model.transferCount >= 30 {
            let rareEffects: [SurfaceEffect] = [.plasma, .prism, .celestial]
            return rareEffects[hash % rareEffects.count]
        }
        
        // Common effects for 5-29 transfers
        let commonEffects: [SurfaceEffect] = [.lightning, .oilSheen, .opalescence, .shimmerWave, .dripping, .ripples, .metallic]
        return commonEffects[hash % commonEffects.count]
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
            // Common effects
            case .lightning:
                LightningEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .oilSheen:
                OilSheenEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .opalescence:
                OpalescenceEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .shimmerWave:
                ShimmerWaveEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .dripping:
                DrippingEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .ripples:
                RipplesEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .metallic:
                MetallicEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
                
            // Rare effects
            case .plasma:
                PlasmaEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .prism:
                PrismEffect(gemShape: gemShape, size: size * 0.7, rotation: rotation)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .celestial:
                CelestialEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
                
            // Legendary effects
            case .constellation:
                ConstellationEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .aurora:
                AuroraEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .nebula:
                NebulaEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            case .vortex:
                VortexEffect(gemShape: gemShape, size: size * 0.7, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    .frame(width: size * 0.7, height: size * 0.7)
            }
        }
    }
}

// MARK: - Surface Effect Types

enum SurfaceEffect: String, CaseIterable {
    // Common effects (5-29 transfers)
    case lightning = "Lightning"
    case oilSheen = "Oil Sheen"
    case opalescence = "Opalescence"
    case shimmerWave = "Shimmer Wave"
    case dripping = "Dripping"
    case ripples = "Ripples"
    case metallic = "Metallic"
    
    // Rare effects (30-49 transfers)
    case plasma = "Plasma"
    case prism = "Prism"
    case celestial = "Celestial"
    
    // Legendary effects (50+ transfers)
    case constellation = "Constellation"
    case aurora = "Aurora"
    case nebula = "Nebula"
    case vortex = "Vortex"
    
    // TODO: Future surface effects to implement
    // - flames = "Flames" - Flickering flames dancing across the surface
    // - web = "Web" - Animated geometric patterns or crystalline webs
}

// MARK: - Surface Effect Views

struct LightningEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    
    @State private var boltPhase: Double = 0
    @State private var intensity: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Draw occasional bolts that crawl across the surface
                for i in 0..<3 {
                    let seed = Double(i) * 1.234
                    let offset = Double(i) * 2.5  // Stagger the bolts more
                    let boltTime = time * 0.5 + offset  // Slower movement
                    
                    // Each bolt appears and fades periodically
                    let cycleTime = (boltTime).truncatingRemainder(dividingBy: 4.0)
                    
                    // Only visible for part of the cycle
                    let isVisible = cycleTime < 1.5  // Visible for 1.5s out of every 4s
                    
                    if isVisible {
                        let path = createLightningBolt(size: canvasSize, seed: seed, phase: boltTime)
                        
                        // Fade in and out smoothly
                        let fadeProgress = min(cycleTime / 0.3, (1.5 - cycleTime) / 0.3)
                        let baseOpacity = min(1.0, fadeProgress)
                        
                        // Subtle flickering
                        let flicker = 0.7 + abs(sin(boltTime * 12.0 + seed)) * 0.3
                        let opacity = baseOpacity * flicker
                        
                        // Bright white core
                        context.stroke(
                            path,
                            with: .color(Color.white.opacity(opacity * 0.9)),
                            lineWidth: 2.0
                        )
                        
                        // Colored glow
                        context.stroke(
                            path,
                            with: .color(primaryColor.opacity(opacity * 0.6)),
                            lineWidth: 4.5
                        )
                    }
                }
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
    
    private func createLightningBolt(size: CGSize, seed: Double, phase: Double) -> Path {
        var path = Path()
        
        // Random start and end points
        let startX = size.width * (0.2 + sin(seed) * 0.3)
        let startY = size.height * (0.1 + cos(seed * 1.3) * 0.2)
        let endX = size.width * (0.5 + sin(seed * 2.1 + phase) * 0.4)
        let endY = size.height * (0.6 + cos(seed * 1.7 + phase) * 0.3)
        
        // Generate main bolt with jagged segments
        var segments: [(CGPoint, CGPoint)] = []
        let mainBolt = generateBoltSegments(
            from: CGPoint(x: startX, y: startY),
            to: CGPoint(x: endX, y: endY),
            displacement: size.width * 0.15,
            seed: seed + phase
        )
        
        // Draw main bolt
        if let first = mainBolt.first {
            path.move(to: first)
        }
        for point in mainBolt.dropFirst() {
            path.addLine(to: point)
        }
        
        // Add branches (forked lightning)
        if mainBolt.count > 3 {
            // Branch from a middle point
            let branchIndex = Int(mainBolt.count / 2)
            let branchStart = mainBolt[branchIndex]
            
            // Branch direction (perpendicular-ish to main bolt)
            let branchEndX = branchStart.x + cos(seed * 3 + phase) * size.width * 0.3
            let branchEndY = branchStart.y + sin(seed * 2 + phase) * size.height * 0.2
            
            let branch = generateBoltSegments(
                from: branchStart,
                to: CGPoint(x: branchEndX, y: branchEndY),
                displacement: size.width * 0.08,
                seed: seed + phase + 100
            )
            
            path.move(to: branchStart)
            for point in branch.dropFirst() {
                path.addLine(to: point)
            }
        }
        
        return path
    }
    
    // Recursive function to create jagged lightning segments
    private func generateBoltSegments(from start: CGPoint, to end: CGPoint, displacement: CGFloat, seed: Double) -> [CGPoint] {
        // Base case: if displacement is too small, just draw a line
        if displacement < 2 {
            return [start, end]
        }
        
        // Find midpoint
        let midX = (start.x + end.x) / 2
        let midY = (start.y + end.y) / 2
        
        // Perpendicular offset for jaggedness
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        
        // Perpendicular vector
        let perpX = -dy / length
        let perpY = dx / length
        
        // Random offset using seed for consistency
        let randomOffset = (sin(seed + midX + midY) * 2 - 1) * displacement
        
        let offsetMid = CGPoint(
            x: midX + perpX * randomOffset,
            y: midY + perpY * randomOffset
        )
        
        // Recursively generate left and right segments
        let leftSegments = generateBoltSegments(
            from: start,
            to: offsetMid,
            displacement: displacement * 0.6,
            seed: seed * 1.3
        )
        
        let rightSegments = generateBoltSegments(
            from: offsetMid,
            to: end,
            displacement: displacement * 0.6,
            seed: seed * 1.7
        )
        
        // Combine segments (skip first point of right to avoid duplication)
        return leftSegments + rightSegments.dropFirst()
    }
}

struct OilSheenEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Fast-rotating rainbow
            gemShape
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hue: 0.0, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.1, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.2, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.3, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.4, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.5, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.6, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.7, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.8, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.9, saturation: 1.0, brightness: 1.0),
                            Color(hue: 1.0, saturation: 1.0, brightness: 1.0),
                            Color(hue: 0.0, saturation: 1.0, brightness: 1.0)
                        ]),
                        center: .center,
                        angle: .degrees(rotation * 3)  // Faster rotation (was * 2)
                    )
                )
                .frame(width: size, height: size)
            
            // Counter-rotating layer for more shimmer
            gemShape
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.8),
                            Color.clear,
                            Color.white.opacity(0.8),
                            Color.clear,
                            Color.white.opacity(0.8),
                            Color.clear
                        ]),
                        center: .center,
                        angle: .degrees(-rotation * 2)
                    )
                )
                .frame(width: size, height: size)
                .blendMode(.overlay)
        }
        .opacity(0.5)
        .blendMode(.screen)
    }
}

struct OpalescenceEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let rotation: Double
    
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let hue = Double(i) / 6.0
                let angle = (rotation + Double(i) * 60) * .pi / 180
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: hue, saturation: 0.9, brightness: 1.0).opacity(0.7),
                                Color(hue: hue, saturation: 0.8, brightness: 1.0).opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.35
                        )
                    )
                    .frame(width: size * 0.7, height: size * 0.7)
                    .offset(
                        x: cos(angle) * size * 0.2,
                        y: sin(angle) * size * 0.2
                    )
            }
        }
        .frame(width: size, height: size)
        .mask(
            gemShape
                .frame(width: size, height: size)
        )
        .blendMode(.screen)
        .opacity(0.7)
    }
}

struct ShimmerWaveEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color
    
    @State private var wavePhase: Double = 0
    
    var body: some View {
        ZStack {
            // Multiple waves sweeping across at different speeds
            ForEach(0..<4, id: \.self) { i in
                let offset = Double(i) * 0.25
                let currentPhase = (wavePhase + offset).truncatingRemainder(dividingBy: 1.0)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0),
                                .init(color: primaryColor.opacity(0.3), location: 0.3),
                                .init(color: Color.white.opacity(0.9), location: 0.5),
                                .init(color: secondaryColor.opacity(0.3), location: 0.7),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 1.5, height: size)
                    .rotationEffect(.degrees(Double(i) * 20 - 30))  // Varied angles
                    .offset(x: (currentPhase - 0.5) * size * 3)
            }
        }
        .frame(width: size, height: size)
        .mask(
            gemShape
                .frame(width: size, height: size)
        )
        .blendMode(.screen)
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                wavePhase = 1.0
            }
        }
    }
}

struct DrippingEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    
    @State private var dripPhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for i in 0..<5 {
                    let seed = Double(i) * 0.789
                    let x = canvasSize.width * (0.2 + Double(i) * 0.15)
                    
                    // Each drip has its own cycle
                    let dripTime = (time * 0.4 + seed * 2.0).truncatingRemainder(dividingBy: 3.0)
                    
                    // Drip grows from top, then falls and disappears
                    let growPhase = min(dripTime / 0.8, 1.0)  // Grows for 0.8s
                    let fallPhase = max(0, (dripTime - 0.8) / 2.2)  // Falls for remaining 2.2s
                    
                    if dripTime < 3.0 {
                        let maxLength = canvasSize.height * 0.6
                        let currentLength = maxLength * growPhase
                        let fallDistance = canvasSize.height * 0.4 * fallPhase
                        
                        // Start position moves down as it falls
                        let startY = fallDistance
                        let endY = startY + currentLength
                        
                        // Drip trail
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: startY))
                        
                        let controlX = x + sin(time * 2 + seed) * 4
                        path.addQuadCurve(
                            to: CGPoint(x: x, y: endY),
                            control: CGPoint(x: controlX, y: (startY + endY) * 0.5)
                        )
                        
                        // Drip bulb at the end
                        let bulbSize = 5 + sin(time * 3 + seed) * 2
                        let bulbPath = Path(ellipseIn: CGRect(
                            x: x - bulbSize / 2,
                            y: endY - bulbSize / 2,
                            width: bulbSize,
                            height: bulbSize * 1.4
                        ))
                        
                        // Fade out as it falls off screen
                        let fadeOut = endY > canvasSize.height * 0.9 ? 
                            max(0, 1.0 - (endY - canvasSize.height * 0.9) / (canvasSize.height * 0.1)) : 1.0
                        
                        // Draw trail
                        context.stroke(
                            path, 
                            with: .color(primaryColor.opacity(0.5 * fadeOut)), 
                            lineWidth: 2.5
                        )
                        
                        // Draw bulb
                        context.fill(
                            bulbPath, 
                            with: .color(primaryColor.opacity(0.7 * fadeOut))
                        )
                        
                        // Highlight on bulb
                        let highlightPath = Path(ellipseIn: CGRect(
                            x: x - bulbSize / 4,
                            y: endY - bulbSize / 3,
                            width: bulbSize / 2,
                            height: bulbSize / 2
                        ))
                        context.fill(
                            highlightPath, 
                            with: .color(Color.white.opacity(0.5 * fadeOut))
                        )
                    }
                }
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

struct RipplesEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    
    @State private var ripplePhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Create multiple ripple sources that trigger at different times
                let rippleSources = 5
                
                for source in 0..<rippleSources {
                    let seed = Double(source) * 123.456
                    
                    // Each source triggers ripples periodically
                    let cycleTime = (time * 0.3 + seed * 2.0).truncatingRemainder(dividingBy: 4.0)
                    
                    // Random position for this ripple source
                    let sourceX = canvasSize.width * (0.3 + sin(seed) * 0.4)
                    let sourceY = canvasSize.height * (0.3 + cos(seed * 1.3) * 0.4)
                    
                    // Create expanding ripples from this source
                    if cycleTime < 3.0 {
                        // Draw 3-4 concentric ripples expanding outward
                        for ripple in 0..<4 {
                            let rippleDelay = Double(ripple) * 0.4
                            let rippleTime = cycleTime - rippleDelay
                            
                            if rippleTime > 0 {
                                // Ripple radius grows over time
                                let maxRadius = min(canvasSize.width, canvasSize.height) * 0.6
                                let radius = rippleTime / 3.0 * maxRadius
                                
                                // Fade out as ripple expands
                                let fadeOut = max(0, 1.0 - rippleTime / 3.0)
                                
                                // Ripple ring
                                let ripplePath = Path(ellipseIn: CGRect(
                                    x: sourceX - radius,
                                    y: sourceY - radius,
                                    width: radius * 2,
                                    height: radius * 2
                                ))
                                
                                // Draw ripple with glow
                                context.stroke(
                                    ripplePath,
                                    with: .color(Color.white.opacity(0.6 * fadeOut)),
                                    lineWidth: 2.0
                                )
                                context.stroke(
                                    ripplePath,
                                    with: .color(primaryColor.opacity(0.4 * fadeOut)),
                                    lineWidth: 4.0
                                )
                                
                                // Inner highlight
                                if ripple == 0 {
                                    context.stroke(
                                        ripplePath,
                                        with: .color(primaryColor.opacity(0.2 * fadeOut)),
                                        lineWidth: 8.0
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

struct FrostEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    
    @State private var growthPhase: Double = 0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Cycle: 3s freeze, 2s frozen, 3s thaw, 2s clear
                let cycleTime = time.truncatingRemainder(dividingBy: 10.0)
                
                // Calculate frost coverage (0 = clear, 1 = fully frozen)
                let frostCoverage: Double
                if cycleTime < 3.0 {
                    // Freezing phase - frost grows
                    frostCoverage = min(1.0, cycleTime / 3.0)
                } else if cycleTime < 5.0 {
                    // Fully frozen phase
                    frostCoverage = 1.0
                } else if cycleTime < 8.0 {
                    // Thawing phase - frost melts
                    frostCoverage = max(0.0, 1.0 - (cycleTime - 5.0) / 3.0)
                } else {
                    // Clear phase
                    frostCoverage = 0.0
                }
                
                if frostCoverage > 0 {
                    // Ice overlay - gets more opaque as frost grows
                    let icePath = Path(ellipseIn: CGRect(
                        origin: .zero,
                        size: canvasSize
                    ))
                    
                    // Frost base layer
                    context.fill(
                        icePath,
                        with: .color(Color.white.opacity(0.15 * frostCoverage))
                    )
                    context.fill(
                        icePath,
                        with: .color(Color.cyan.opacity(0.08 * frostCoverage))
                    )
                    
                    // Frost crystals growing from edges toward center
                    let crystalCount = 60
                    for i in 0..<crystalCount {
                        let seed = Double(i) * 123.456
                        let angleSeed = seed * 2.0
                        
                        // Crystals grow from edge inward
                        let edgeAngle = angleSeed
                        let edgeX = canvasSize.width * 0.5 + cos(edgeAngle) * canvasSize.width * 0.5
                        let edgeY = canvasSize.height * 0.5 + sin(edgeAngle) * canvasSize.height * 0.5
                        
                        // Growth varies per crystal based on overall frost coverage
                        let crystalGrowth = min(1.0, max(0, (frostCoverage - Double(i) / Double(crystalCount) * 0.3) * 1.5))
                        
                        if crystalGrowth > 0 {
                            let baseLength = 15.0 + sin(seed) * 8.0
                            let length = baseLength * crystalGrowth * (1 + sin(time * 2 + seed) * 0.15)
                            
                            // Crystal grows toward center
                            let growthAngle = edgeAngle + .pi + sin(seed * 3) * 0.3
                            
                            let x = edgeX
                            let y = edgeY
                            
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: y))
                            
                            // Main crystal branch
                            let endX = x + cos(growthAngle) * length
                            let endY = y + sin(growthAngle) * length
                            path.addLine(to: CGPoint(x: endX, y: endY))
                            
                            // Side branches
                            for branch in 0..<2 {
                                let branchAngle = growthAngle + (Double(branch) - 0.5) * 0.6
                                let branchLength = length * 0.5
                                let branchProgress = 0.6
                                let branchX = x + cos(growthAngle) * length * branchProgress
                                let branchY = y + sin(growthAngle) * length * branchProgress
                                
                                path.move(to: CGPoint(x: branchX, y: branchY))
                                path.addLine(to: CGPoint(
                                    x: branchX + cos(branchAngle) * branchLength,
                                    y: branchY + sin(branchAngle) * branchLength
                                ))
                            }
                            
                            // Draw crystal with glow
                            let opacity = 0.5 * crystalGrowth + sin(time * 3 + seed) * 0.2 * crystalGrowth
                            context.stroke(
                                path,
                                with: .color(Color.white.opacity(opacity)),
                                lineWidth: 1.2
                            )
                            context.stroke(
                                path,
                                with: .color(Color.cyan.opacity(opacity * 0.6)),
                                lineWidth: 2.5
                            )
                        }
                    }
                    
                    // Frost texture overlay
                    for i in 0..<40 {
                        let seed = Double(i) * 234.567
                        let x = sin(seed) * canvasSize.width * 0.4 + canvasSize.width * 0.5
                        let y = cos(seed * 1.3) * canvasSize.height * 0.4 + canvasSize.height * 0.5
                        
                        // Only visible if frost has covered this area
                        let distanceFromCenter = sqrt(pow(x - canvasSize.width * 0.5, 2) + pow(y - canvasSize.height * 0.5, 2))
                        let maxDistance = min(canvasSize.width, canvasSize.height) * 0.5
                        let normalizedDistance = distanceFromCenter / maxDistance
                        
                        // Frost grows from edge (1.0) to center (0.0)
                        let isVisible = normalizedDistance > (1.0 - frostCoverage * 1.2)
                        
                        if isVisible {
                            let baseLength = 6.0 + sin(seed * 2) * 3.0
                            let length = baseLength * (1 + sin(time * 2.5 + seed) * 0.2)
                            let angle = seed * 3 + time * 0.15
                            
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: y))
                            
                            let endX = x + cos(angle) * length
                            let endY = y + sin(angle) * length
                            path.addLine(to: CGPoint(x: endX, y: endY))
                            
                            let opacity = 0.35 + sin(time * 2.5 + seed) * 0.2
                            context.stroke(
                                path,
                                with: .color(Color.white.opacity(opacity * frostCoverage)),
                                lineWidth: 0.8
                            )
                        }
                    }
                }
            }
        }
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
    }
}

struct MetallicEffect: View {
    let gemShape: AnyShape
    let size: CGFloat
    let primaryColor: Color
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Main metallic sweep
            gemShape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.9), location: 0.0),
                            .init(color: primaryColor.opacity(0.6), location: 0.25),
                            .init(color: Color.black.opacity(0.5), location: 0.5),
                            .init(color: primaryColor.opacity(0.7), location: 0.75),
                            .init(color: Color.white.opacity(0.85), location: 1.0)
                        ],
                        startPoint: UnitPoint(
                            x: 0.5 + cos(rotation * .pi / 180) * 0.5,
                            y: 0.5 + sin(rotation * .pi / 180) * 0.5
                        ),
                        endPoint: UnitPoint(
                            x: 0.5 - cos(rotation * .pi / 180) * 0.5,
                            y: 0.5 - sin(rotation * .pi / 180) * 0.5
                        )
                    )
                )
                .frame(width: size, height: size)
            
            // Sharp highlight bands (like polished metal)
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.8),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.15, height: size * 2)
                    .rotationEffect(.degrees(rotation + Double(i) * 45))
                    .offset(
                        x: cos((rotation + Double(i) * 120) * .pi / 180) * size * 0.3,
                        y: sin((rotation + Double(i) * 120) * .pi / 180) * size * 0.3
                    )
                    .mask(gemShape.frame(width: size, height: size))
                    .blendMode(.overlay)
            }
        }
        .blendMode(.overlay)
        .opacity(0.7)
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
        let maskedContent = TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                let centerX = canvasSize.width / 2
                let centerY = canvasSize.height / 2
                
                // Holographic interference patterns - multiple frequency bands
                for band in 0..<6 {
                    let bandOffset = Double(band) * .pi / 3
                    let bandFrequency = 8.0 + Double(band) * 4.0
                    
                    for strip in 0..<30 {
                        let stripProgress = Double(strip) / 30.0
                        let angle = time * 0.3 + bandOffset
                        
                        // Wave displacement
                        let waveX = stripProgress * canvasSize.width
                        let waveY1 = centerY + sin(stripProgress * bandFrequency + time * 2 + bandOffset) * canvasSize.height * 0.25
                        let waveY2 = centerY + sin((stripProgress + 0.033) * bandFrequency + time * 2 + bandOffset) * canvasSize.height * 0.25
                        
                        // Rainbow color based on position and time
                        let hue = (stripProgress + time * 0.2 + Double(band) * 0.16).truncatingRemainder(dividingBy: 1.0)
                        let stripColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)
                        
                        var path = Path()
                        path.move(to: CGPoint(x: waveX, y: waveY1))
                        path.addLine(to: CGPoint(x: waveX + 2, y: waveY2))
                        
                        // Vary opacity with interference pattern
                        let interference = sin(stripProgress * 20 + time * 3) * 0.3 + 0.5
                        
                        context.stroke(
                            path,
                            with: .color(stripColor.opacity(interference * 0.6)),
                            lineWidth: 3.0
                        )
                    }
                }
                
                // Create shifting color zones
                for zone in 0..<12 {
                    let zoneDouble = Double(zone)
                    let zoneAngle = zoneDouble * .pi / 6 + time * 0.5
                    let hue = zoneDouble / 12.0
                    let zoneColor = Color(hue: hue, saturation: 1.0, brightness: 1.0)
                    
                    // Radial gradient zone - break up calculations
                    let cosZone = cos(zoneAngle)
                    let sinZone = sin(zoneAngle)
                    
                    let startX = centerX + cosZone * canvasSize.width * 0.1
                    let startY = centerY + sinZone * canvasSize.height * 0.1
                    let endX = centerX + cosZone * canvasSize.width * 0.5
                    let endY = centerY + sinZone * canvasSize.height * 0.5
                    
                    var path = Path()
                    path.move(to: CGPoint(x: centerX, y: centerY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                    
                    // Pulsing width
                    let timeFactor = time * 2 + zoneDouble
                    let pulseAmount = sin(timeFactor) * 10
                    let pulseWidth: CGFloat = 20 + pulseAmount
                    
                    let opacity: Double = 0.35
                    
                    context.stroke(
                        path,
                        with: .color(zoneColor.opacity(opacity)),
                        lineWidth: pulseWidth
                    )
                }
                
                // Kaleidoscope geometry - fractal-like patterns
                let segmentCount = 8
                for segment in 0..<segmentCount {
                    let segmentAngle = Double(segment) * (.pi * 2 / Double(segmentCount))
                    
                    // Create triangular prism segments
                    for layer in 0..<5 {
                        let layerRadius = canvasSize.width * 0.15 * (1.0 + Double(layer) * 0.2)
                        let nextRadius = canvasSize.width * 0.15 * (1.0 + Double(layer + 1) * 0.2)
                        
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
                        let hue = (Double(segment) / Double(segmentCount) + time * 0.15).truncatingRemainder(dividingBy: 1.0)
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
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
        
        return maskedContent
            .onAppear {
                withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                    trippyPhase = .pi * 2
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
                
                // Psychedelic mandala pattern with breathing geometry
                let ringCount = 8
                let petalCount = 12
                
                for ring in 0..<ringCount {
                    let ringProgress = Double(ring) / Double(ringCount)
                    let radius = canvasSize.width * 0.45 * ringProgress
                    
                    // Each ring breathes at different rates
                    let breathe = sin(time * (1.5 + Double(ring) * 0.3)) * 0.2 + 1.0
                    let animatedRadius = radius * breathe
                    
                    for petal in 0..<petalCount {
                        let baseAngle = Double(petal) * (.pi * 2 / Double(petalCount))
                        let angleOffset = time * 0.5 + Double(ring) * 0.2
                        let angle = baseAngle + angleOffset
                        
                        // Petal position with spiral distortion
                        let spiralFactor = sin(time * 0.8 + Double(petal) * 0.5) * 0.3
                        let x = centerX + cos(angle + spiralFactor) * animatedRadius
                        let y = centerY + sin(angle + spiralFactor) * animatedRadius
                        
                        // Petal shape - elongated and organic
                        let petalLength = canvasSize.width * 0.12 * (1.0 - ringProgress * 0.5)
                        let petalWidth = petalLength * 0.4
                        
                        // Petal glow with color cycling
                        let hueShift = (time * 30 + Double(petal) * 30 + Double(ring) * 15).truncatingRemainder(dividingBy: 360)
                        let petalHue = (hueShift / 360.0)
                        let petalColor = Color(hue: petalHue, saturation: 0.9, brightness: 1.0)
                        
                        // Draw petal as ellipse
                        let petalRect = CGRect(
                            x: x - petalWidth / 2,
                            y: y - petalLength / 2,
                            width: petalWidth,
                            height: petalLength
                        )
                        let petalPath = Path(ellipseIn: petalRect)
                        
                        // Pulsing opacity
                        let pulseValue = sin(time * 2 + Double(petal) * 0.5 + Double(ring) * 0.3) * 0.3 + 0.7
                        let opacity = 0.4 * pulseValue * (1.0 - ringProgress * 0.3)
                        
                        // Rotate petal to face center with slight wobble
                        let wobble = sin(time * 3 + Double(petal)) * 0.2
                        var transform = CGAffineTransform(translationX: x, y: y)
                        transform = transform.rotated(by: angle + .pi / 2 + wobble)
                        transform = transform.translatedBy(x: -x, y: -y)
                        
                        var rotatedPath = Path(petalPath.cgPath)
                        rotatedPath = rotatedPath.applying(transform)
                        
                        // Draw outer glow
                        context.fill(
                            rotatedPath,
                            with: .color(petalColor.opacity(opacity * 0.4))
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
                        context.fill(
                            corePath,
                            with: .color(Color.white.opacity(opacity * 0.6))
                        )
                    }
                }
                
                // Central sacred geometry - rotating
                let geometryRotation = time * 0.8
                for layer in 0..<6 {
                    let layerRadius = canvasSize.width * 0.15 * (1.0 + Double(layer) * 0.25)
                    let sides = 6
                    
                    var path = Path()
                    for i in 0...sides {
                        let angle = Double(i) * (.pi * 2 / Double(sides)) + geometryRotation + Double(layer) * 0.5
                        let x = centerX + cos(angle) * layerRadius
                        let y = centerY + sin(angle) * layerRadius
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    let hueShift = (time * 40 + Double(layer) * 60).truncatingRemainder(dividingBy: 360)
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
        .frame(width: size, height: size)
        .mask(gemShape.frame(width: size, height: size))
        .blendMode(.screen)
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

// MARK: - Fluid Swirls

/// Animated fluid swirls using Canvas
struct FluidSwirls: View {
    let model: CrystalModel
    let size: CGFloat
    
    @State private var phase: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let animated = phase + time * 0.5
                
                // Draw multiple fluid swirl layers
                for layer in 0..<3 {
                    let layerPhase = animated + Double(layer) * 2.0
                    drawFluidLayer(
                        context: context,
                        size: canvasSize,
                        phase: layerPhase,
                        layer: layer
                    )
                }
            }
        }
        .blendMode(.plusLighter)
    }
    
    private func drawFluidLayer(context: GraphicsContext, size: CGSize, phase: Double, layer: Int) {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = min(size.width, size.height) * 0.3
        
        var path = Path()
        
        // Create swirling path
        for i in 0..<100 {
            let t = Double(i) / 100.0
            let angle = t * .pi * 4 + phase
            let spiralRadius = radius * (0.3 + 0.7 * t)
            
            // Add noise/perturbation for organic feel
            let noise = sin(angle * 3 + phase) * 10
            let x = centerX + cos(angle) * (spiralRadius + noise)
            let y = centerY + sin(angle) * (spiralRadius + noise)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Color based on layer
        let hue = (model.primaryHue + Double(layer) * 30) / 360.0
        let color = Color(hue: hue, saturation: model.saturation, brightness: 0.9)
        
        context.stroke(
            path,
            with: .color(color.opacity(0.4)),
            lineWidth: 2
        )
    }
}

// MARK: - Particle System

/// SpriteKit-based particle system for magical effects
struct MagicalParticleScene: UIViewRepresentable {
    let model: CrystalModel
    let size: CGFloat
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        
        let scene = ParticleScene(size: CGSize(width: size, height: size))
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFit
        scene.model = model
        
        view.presentScene(scene)
        view.isPaused = false  // Ensure animations run
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        // Update if needed
    }
}

class ParticleScene: SKScene {
    var model: CrystalModel?
    
    // Lazy-loaded particle textures
    private lazy var circleTexture: SKTexture = {
        createCircleTexture(size: 32)
    }()
    
    private lazy var glowTexture: SKTexture = {
        createGlowTexture(size: 64)
    }()
    
    private lazy var sparkTexture: SKTexture = {
        createSparkTexture(size: 24)
    }()
    
    override func didMove(to view: SKView) {
        guard let model = model else { return }
        
        // Create multiple particle emitters for layered effects
        createOrbitingParticles(model: model)
        createChaoticSparkBursts(model: model)
        createEnergyRays(model: model)
        createShimmeringDust(model: model)
    }
    
    // MARK: - Texture Generation
    
    private func createCircleTexture(size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let ctx = context.cgContext
            
            // Draw a soft circle with gradient
            let colors = [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0.5).cgColor,
                UIColor.clear.cgColor
            ]
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.6, 1.0]
            )!
            
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size / 2, y: size / 2),
                startRadius: 0,
                endCenter: CGPoint(x: size / 2, y: size / 2),
                endRadius: size / 2,
                options: []
            )
        }
        return SKTexture(image: image)
    }
    
    private func createGlowTexture(size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Soft glow with more diffuse edge
            let colors = [
                UIColor.white.cgColor,
                UIColor.white.withAlphaComponent(0.7).cgColor,
                UIColor.white.withAlphaComponent(0.3).cgColor,
                UIColor.clear.cgColor
            ]
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.3, 0.7, 1.0]
            )!
            
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: size / 2, y: size / 2),
                startRadius: 0,
                endCenter: CGPoint(x: size / 2, y: size / 2),
                endRadius: size / 2,
                options: []
            )
        }
        return SKTexture(image: image)
    }
    
    private func createSparkTexture(size: CGFloat) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            // Four-pointed star/spark
            ctx.setFillColor(UIColor.white.cgColor)
            
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            
            // Draw a star shape
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x, y: center.y - radius)) // Top
            path.addLine(to: CGPoint(x: center.x + radius * 0.2, y: center.y - radius * 0.2))
            path.addLine(to: CGPoint(x: center.x + radius, y: center.y)) // Right
            path.addLine(to: CGPoint(x: center.x + radius * 0.2, y: center.y + radius * 0.2))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius)) // Bottom
            path.addLine(to: CGPoint(x: center.x - radius * 0.2, y: center.y + radius * 0.2))
            path.addLine(to: CGPoint(x: center.x - radius, y: center.y)) // Left
            path.addLine(to: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.2))
            path.closeSubpath()
            
            ctx.addPath(path)
            ctx.fillPath()
            
            // Add glow
            ctx.setShadow(offset: .zero, blur: 4, color: UIColor.white.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }
        return SKTexture(image: image)
    }
    
    // MARK: - Particle Emitters
    
    private func createOrbitingParticles(model: CrystalModel) {
        // Fast-moving orbital particles that zip around
        let emitter = SKEmitterNode()
        
        emitter.particleTexture = circleTexture
        emitter.particleBirthRate = 20  // Reduced from 50
        emitter.particleLifetime = 2.5
        emitter.particleLifetimeRange = 1.0
        
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        emitter.particlePositionRange = CGVector(dx: size.width * 0.15, dy: size.height * 0.15)
        
        // Fast, tangential movement for orbital feel
        emitter.particleSpeed = 60  // Reduced
        emitter.particleSpeedRange = 30
        emitter.emissionAngleRange = CGFloat.pi * 2
        
        // Rotation for visual interest
        emitter.particleRotation = 0
        emitter.particleRotationRange = CGFloat.pi * 2
        emitter.particleRotationSpeed = CGFloat.pi * 2
        
        // Thin streaky particles
        emitter.particleAlpha = 0.6  // More subtle
        emitter.particleAlphaSpeed = -0.3
        
        emitter.particleScale = 0.12
        emitter.particleScaleRange = 0.08
        emitter.particleScaleSpeed = -0.04
        
        let primaryColor = UIColor(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 1.0,
            alpha: 1.0
        )
        emitter.particleColor = primaryColor
        emitter.particleColorBlendFactor = 1.0
        
        emitter.particleBlendMode = .add
        
        addChild(emitter)
    }
    
    private func createChaoticSparkBursts(model: CrystalModel) {
        // Random explosive bursts of sparkles
        let emitter = SKEmitterNode()
        
        emitter.particleTexture = sparkTexture
        emitter.particleBirthRate = 0  // We'll trigger bursts manually
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.4
        
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Explosive outward bursts
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 80
        emitter.emissionAngleRange = CGFloat.pi * 2
        
        // Rapid fade
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.5
        
        emitter.particleScale = 0.25
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -0.3
        
        // Wild rotation
        emitter.particleRotation = 0
        emitter.particleRotationRange = CGFloat.pi * 2
        emitter.particleRotationSpeed = CGFloat.pi * 8
        
        let secondaryColor = UIColor(
            hue: model.secondaryHue / 360.0,
            saturation: model.saturation * 0.8,
            brightness: 1.0,
            alpha: 1.0
        )
        emitter.particleColor = secondaryColor
        emitter.particleColorBlendFactor = 0.7
        
        emitter.particleBlendMode = .add
        
        addChild(emitter)
        
        // Create random bursts
        let burstAction = SKAction.sequence([
            SKAction.run { [weak emitter] in
                // Random burst size
                emitter?.particleBirthRate = CGFloat.random(in: 200...500)
            },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak emitter] in
                emitter?.particleBirthRate = 0
            },
            SKAction.wait(forDuration: Double.random(in: 0.3...1.2))
        ])
        
        emitter.run(.repeatForever(burstAction))
    }
    
    private func createEnergyRays(model: CrystalModel) {
        // Shooting rays that dart out from center
        let emitter = SKEmitterNode()
        
        emitter.particleTexture = glowTexture
        emitter.particleBirthRate = 12  // Reduced from 25
        emitter.particleLifetime = 1.8
        emitter.particleLifetimeRange = 0.6
        
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        emitter.particlePositionRange = CGVector(dx: 15, dy: 15)
        
        // Fast rays shooting outward
        emitter.particleSpeed = 80  // Reduced
        emitter.particleSpeedRange = 40
        emitter.emissionAngleRange = CGFloat.pi * 2
        
        // Stretch them into rays
        emitter.particleAlpha = 0.5  // More subtle
        emitter.particleAlphaSpeed = -0.6
        
        emitter.particleScale = 0.35
        emitter.particleScaleRange = 0.15
        emitter.particleScaleSpeed = -0.12
        
        // Point in direction of motion
        emitter.particleRotation = 0
        emitter.particleRotationRange = CGFloat.pi * 2
        
        let rayColor = UIColor(
            hue: (model.primaryHue + 30) / 360.0,
            saturation: model.saturation * 0.9,
            brightness: 0.95,
            alpha: 1.0
        )
        emitter.particleColor = rayColor
        emitter.particleColorBlendFactor = 0.9
        
        emitter.particleBlendMode = .add
        
        addChild(emitter)
    }
    
    private func createShimmeringDust(model: CrystalModel) {
        // Chaotic swirling dust that changes direction
        let emitter = SKEmitterNode()
        
        emitter.particleTexture = circleTexture
        emitter.particleBirthRate = 25  // Reduced from 40
        emitter.particleLifetime = 3.0
        emitter.particleLifetimeRange = 1.5
        
        emitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        emitter.particlePositionRange = CGVector(dx: size.width * 0.25, dy: size.height * 0.25)
        
        // Slow chaotic drift
        emitter.particleSpeed = 20  // Reduced
        emitter.particleSpeedRange = 15
        emitter.emissionAngleRange = CGFloat.pi * 2
        
        // Add turbulence with rotation
        emitter.particleRotation = 0
        emitter.particleRotationRange = CGFloat.pi * 2
        emitter.particleRotationSpeed = CGFloat.pi * 0.8
        
        // Shimmer effect with alpha variation
        emitter.particleAlpha = 0.3  // More subtle
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = 0  // Stay visible
        
        emitter.particleScale = 0.08
        emitter.particleScaleRange = 0.06
        
        // Random pulsing
        emitter.particleScaleSpeed = 0.03
        emitter.particleScaleSequence = nil
        
        // Color cycling through primary and secondary
        let dustColor = UIColor(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation * 0.5,
            brightness: 1.0,
            alpha: 1.0
        )
        emitter.particleColor = dustColor
        emitter.particleColorBlendFactor = 0.7
        
        // Color variation over lifetime
        let colorAction = SKAction.sequence([
            SKAction.customAction(withDuration: 1.5) { [weak emitter] node, elapsedTime in
                guard let emitter = emitter else { return }
                let progress = elapsedTime / 1.5
                let hue = (model.primaryHue + (model.secondaryHue - model.primaryHue) * progress) / 360.0
                emitter.particleColor = UIColor(
                    hue: hue,
                    saturation: model.saturation * 0.5,
                    brightness: 1.0,
                    alpha: 1.0
                )
            },
            SKAction.customAction(withDuration: 1.5) { [weak emitter] node, elapsedTime in
                guard let emitter = emitter else { return }
                let progress = 1.0 - (elapsedTime / 1.5)
                let hue = (model.primaryHue + (model.secondaryHue - model.primaryHue) * progress) / 360.0
                emitter.particleColor = UIColor(
                    hue: hue,
                    saturation: model.saturation * 0.5,
                    brightness: 1.0,
                    alpha: 1.0
                )
            }
        ])
        
        emitter.run(.repeatForever(colorAction))
        
        emitter.particleBlendMode = .add
        
        addChild(emitter)
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
                    
                    Text("Hue: \(Int(currentDNA.identity.primaryHue))° • Sat: \(Int(currentDNA.identity.saturation * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 4) {
                        Text("Transfers: \(transferCount)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        
                        if transferCount >= 5 {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    if let effect = selectedEffect {
                        Text("Effect: \(effect.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    } else if transferCount >= 50 {
                        Text("⭐️ LEGENDARY Effect Active ⭐️")
                            .font(.caption2.bold())
                            .foregroundColor(.yellow)
                    } else if transferCount >= 30 {
                        Text("💎 RARE Effect Active")
                            .font(.caption2.bold())
                            .foregroundColor(.purple)
                    } else if transferCount >= 5 {
                        Text("✨ Surface Effect: Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else {
                        Text("Surface Effect: Locked (5+ transfers)")
                            .font(.caption2)
                            .foregroundColor(.gray)
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
                primaryHue: primaryHue,
                secondaryHue: secondaryHue,
                saturation: Double.random(in: 0.6...1.0),
                materialFamily: ["spectral", "coloredGemstone", "opalescent"].randomElement()!,
                baseForm: shapes.randomElement()!,
                colorRelationship: relationship,
                secondaryInfluence: Double.random(in: 0.3...0.8)
            ),
            personality: CrystalPersonality(
                complexityBias: Double.random(in: 0.5...1.0),
                orbitalAffinity: Double.random(in: 0.7...1.0),
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

