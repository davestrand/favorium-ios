//
//  FavorGemView.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Asset-based gemstone and frame rendering system

import SwiftUI

// MARK: - Enums

/// The four universal progression tiers shared by all gem and frame families.
///
/// Tier is determined by how many times a Favor has been transferred:
/// - **Seed**:     0–4 transfers
/// - **Bloom**:    5–14 transfers
/// - **Legacy**:   15–29 transfers
/// - **Radiance**: 30+ transfers
enum Tier: String, CaseIterable, Identifiable {
    case seed
    case bloom
    case legacy
    case radiance

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Derive tier from a Favor's transfer count.
    static func from(transferCount: Int) -> Tier {
        switch transferCount {
        case 0..<5:   return .seed
        case 5..<15:  return .bloom
        case 15..<30: return .legacy
        default:      return .radiance
        }
    }

    /// Transfers needed to reach this tier — keep in sync with `from(transferCount:)`.
    var minTransfers: Int {
        switch self {
        case .seed:     return 0
        case .bloom:    return 5
        case .legacy:   return 15
        case .radiance: return 30
        }
    }

    /// The tier after this one, or nil at Radiance.
    var next: Tier? {
        let all = Tier.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// Short user-facing explanation shown in the gem guide.
    var description: String {
        switch self {
        case .seed:     return "Every gem begins here, freshly minted and full of promise."
        case .bloom:    return "Passed along enough times to open up and reveal its hidden trait."
        case .legacy:   return "A well-travelled gem carrying the story of many favors."
        case .radiance: return "The rarest gems, shining with a long history of kindness."
        }
    }

    /// Suggested tint color that reflects each tier's visual theme.
    var defaultColor: Color {
        switch self {
        case .seed:
            return Color(hue: 0.28, saturation: 0.5, brightness: 0.6)   // earthy green
        case .bloom:
            return Color(hue: 0.55, saturation: 0.7, brightness: 0.85)  // vibrant blue
        case .legacy:
            return Color(hue: 0.12, saturation: 0.8, brightness: 0.9)   // warm gold
        case .radiance:
            return Color(hue: 0.15, saturation: 0.15, brightness: 1.0)  // near-white platinum
        }
    }
}

/// A family of gem art assets — each family has one image per `Tier`.
///
/// Asset naming convention: `gem_{family}_{tier}.png`
/// e.g. `gem_lightning_seed.png`, `gem_lightning_radiance.png`
///
/// Add a new case here when a new gem family's art is ready.
enum GemFamily: String, CaseIterable, Identifiable {
    case lightning
    case celestial
    case victorian
    case gothic

    var id: String { rawValue }

    /// User-facing name. Asset names keep the raw value (e.g. `gothic`).
    var displayName: String {
        self == .gothic ? "Darkheart" : rawValue.capitalized
    }

    /// Short user-facing description shown in the gem guide.
    var description: String {
        switch self {
        case .lightning: return "Bold and electric, cut with sharp facets that catch every spark."
        case .celestial: return "Drawn from the night sky, with the calm glow of distant stars."
        case .victorian: return "Ornate and elegant, set in the fine filigree of a treasured heirloom."
        case .gothic:    return "Dark and dramatic, with a deep heart that glows from within."
        }
    }

    /// The asset name for this family at a given tier.
    func assetName(tier: Tier) -> String {
        "gem_\(rawValue)_\(tier.rawValue)"
    }

    /// Map a DNA `gemFamily` / `identity.base_form` string to a `GemFamily`.
    /// Falls back to `.lightning` for nil or unrecognised values.
    static func from(_ string: String?) -> GemFamily {
        normalized(string) ?? .lightning
    }

    /// Case- and whitespace-insensitive match, or nil if the string isn't a known family.
    static func normalized(_ string: String?) -> GemFamily? {
        guard let string else { return nil }
        return GemFamily(rawValue: string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// A family of frame art assets — each family has one image per `Tier`.
///
/// Asset naming convention: `frame_{family}_{tier}.png`
/// e.g. `frame_lightning_seed.png`, `frame_gothic_radiance.png`
///
/// A frame family is independent of the gem family — any combination is valid.
/// Add a new case here when a new frame family's art is ready.
enum FrameFamily: String, CaseIterable, Identifiable {
    case lightning
    case celestial
    case victorian
    case gothic

    var id: String { rawValue }

    /// User-facing name. Asset names keep the raw value (e.g. `gothic`).
    var displayName: String {
        self == .gothic ? "Darkheart" : rawValue.capitalized
    }

    /// The asset name for this family at a given tier.
    func assetName(tier: Tier) -> String {
        "frame_\(rawValue)_\(tier.rawValue)"
    }

    /// Map from a `CrystalDNA` frameFamily string to a `FrameFamily`.
    /// Falls back to `.lightning` until additional families are added.
    static func from(_ string: String?) -> FrameFamily {
        guard let string else { return .lightning }
        return FrameFamily(rawValue: string.lowercased()) ?? .lightning
    }

    /// Returns the frame family that matches a given gem family.
    /// Frame and gem families must always be paired together — use this
    /// whenever a frame family needs to be derived from a gem selection.
    static func matching(_ gemFamily: GemFamily) -> FrameFamily {
        FrameFamily(rawValue: gemFamily.rawValue) ?? .lightning
    }
}

/// A randomly assigned visual personality carried by an individual gem.
/// Bloom-tier and above gems each get one trait at generation time that never changes.
enum GemTrait: String, CaseIterable {
    case starlight    // Tiny pinpoint sparkles scattered across the surface, twinkling independently
    case rainbow      // Sweeping rainbow wash across the surface
    case iridescent   // Butterfly-wing shimmer — color shifts with the tilt
    case charged      // Crackling white-blue electric arcs travelling across the surface in bursts
    case ember        // Deep inner heat glow, like a coal

    // TODO: oiled      — dark rainbow slick like oil on water / dark opal, shifts with tilt
    // TODO: fogged     — cloudy internal haze that clears toward the center, smoke-filled look
    // TODO: frosted    — matte icy bloom around the edges (deferred — needs rethink)
    // TODO: pulsed     — slow deep heartbeat bloom from the center outward every 2–3 seconds
    // TODO: hollow     — glass sphere look: dark interior, bright rim, empty inside
    // TODO: smoked     — like frosted but warm/dark brownish, gem held in flame
    // TODO: veined     — faint branching gold/silver veins through the gem body, marble-like
    // TODO: rusted     — warm orange-brown patina over the frame metalwork only, aged look
    // TODO: cracked    — dark fissure network with energy leaking through (needs revisit)
    // TODO: gilded     — animated gold sheen sweeping across the frame with the tilt (needs revisit)
    // TODO: wet        — glossy liquid sheen (deferred — may need a dedicated overlay asset)

    /// Human-readable label shown in the UI.
    var displayName: String {
        switch self {
        case .starlight:  return "Starlight"
        case .rainbow:    return "Rainbow"
        case .iridescent: return "Iridescent"
        case .charged:    return "Charged"
        case .ember:      return "Ember"
        }
    }

    /// Short user-facing description shown on the gem detail page once the trait is revealed.
    var description: String {
        switch self {
        case .starlight:  return "Hidden stars glint across its facets as it turns in the light."
        case .rainbow:    return "A full spectrum of color drifts through its heart."
        case .iridescent: return "Its setting shimmers like a butterfly's wing, shifting with every tilt."
        case .charged:    return "Crackling arcs of energy dance across its surface."
        case .ember:      return "A slow inner fire glows deep within, warm as a coal."
        }
    }

    /// Map a DNA `trait` string to a `GemTrait`. Returns nil for nil/unknown values.
    static func from(_ string: String?) -> GemTrait? {
        guard let string else { return nil }
        return GemTrait(rawValue: string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// Reusable asset-based gemstone view with decorative frame.
///
/// Renders a `GemFamily` gem inside its matching `FrameFamily` frame, both at the same `Tier`.
/// The frame family is always derived from the gem family — they are never set independently.
///
/// Asset names are constructed as:
/// - Gem:   `gem_{gemFamily}_{tier}`   e.g. `gem_lightning_bloom`
/// - Frame: `frame_{frameFamily}_{tier}` e.g. `frame_lightning_bloom`
struct FavorGemView: View {
    let gemFamily: GemFamily
    /// Always derived from `gemFamily` via `FrameFamily.matching(_:)` — never set independently.
    let frameFamily: FrameFamily
    let tier: Tier
    let gemColor: Color
    let frameColor: Color?
    let size: CGFloat
    let showGlow: Bool
    let showShimmer: Bool
    /// When true, suppresses the built-in pendulum tilt so a parent view
    /// (e.g. AnimatedFavorGemView) can own all rotation without compounding.
    let suppressTilt: Bool
    /// Optional persistent trait — assigned once at gem generation, nil for Seed.
    let trait: GemTrait?

    /// Primary initializer. Frame family is always derived from gem family automatically.
    init(
        gemFamily: GemFamily,
        tier: Tier,
        gemColor: Color,
        frameColor: Color? = nil,
        size: CGFloat = 200,
        showGlow: Bool = false,
        showShimmer: Bool = false,
        suppressTilt: Bool = false,
        trait: GemTrait? = nil
    ) {
        self.gemFamily    = gemFamily
        self.frameFamily  = FrameFamily.matching(gemFamily)
        self.tier         = tier
        self.gemColor     = gemColor
        self.frameColor   = frameColor
        self.size         = size
        self.showGlow     = showGlow
        self.showShimmer  = showShimmer
        self.suppressTilt = suppressTilt
        // Traits stay hidden until the gem reaches Bloom, even if the DNA already carries one
        self.trait        = tier == .seed ? nil : trait
    }
    
    var body: some View {
        ZStack {
            // 1. Optional background glow
            if showGlow {
                backgroundGlow
            }
            
            // 2. Gemstone image (tinted)
            gemstoneImage
            
            // 3. Decorative frame (tinted)
            frameImage
            
            // 4. Optional shimmer effect
            if showShimmer {
                shimmerOverlay
            }

            // 5. Persistent gem trait effect (bloom+)
            if let trait {
                traitOverlay(trait)
            }
        }
        .frame(width: size, height: size)
        // Pendulum tilt — skipped when a parent view owns rotation (suppressTilt: true)
        .rotation3DEffect(
            .degrees(suppressTilt ? 0 : tilt),
            axis: (x: 0.15, y: 1.0, z: 0.0),
            anchor: .center,
            perspective: 0.5
        )
        // Shadow drifts with the tilt to ground the 3D illusion
        .shadow(
            color: .black.opacity(0.35),
            radius: 14,
            x: suppressTilt ? 0 : sin(tilt * .pi / 180) * 10,
            y: 6
        )
        .onAppear {
            if trait == .charged {
                startChargedAnimation()
            }
            guard !suppressTilt else { return }
            // Pendulum tilt — rocks symmetrically from -20° to +20° and back
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                tilt = 20
            }
        }
        .onChange(of: trait) { _, newTrait in
            if newTrait == .charged {
                chargedPhase = 0.0
                startChargedAnimation()
            }
        }
    }
    
    // MARK: - Asset Name Helpers

    /// Asset name for the gem image: `gem_{family}_{tier}` e.g. `gem_lightning_legacy`
    private var gemAssetName: String {
        gemFamily.assetName(tier: tier)
    }

    /// Asset name for the frame image: `frame_{family}_{tier}` e.g. `frame_lightning_legacy`
    private var frameAssetName: String {
        frameFamily.assetName(tier: tier)
    }

    /// The frame tint color to use: the caller-supplied override, or the tier's default color.
    private var resolvedFrameColor: Color {
        frameColor ?? tier.defaultColor
    }

    // MARK: - Components
    
    private var backgroundGlow: some View {
        ZStack {
            // Outer frame color glow (metallic aura)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            resolvedFrameColor.opacity(0.12),
                            resolvedFrameColor.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: size * 0.25)
            
            // Middle transition glow (blend of both)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gemColor.opacity(0.12),
                            Color(
                                red: (gemColor.components.red + resolvedFrameColor.components.red) / 2,
                                green: (gemColor.components.green + resolvedFrameColor.components.green) / 2,
                                blue: (gemColor.components.blue + resolvedFrameColor.components.blue) / 2
                            ).opacity(0.07),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: size * 0.15)
            
            // Inner gem color glow (core radiance)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gemColor.opacity(0.2),
                            gemColor.opacity(0.1),
                            gemColor.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.8, height: size * 0.8)
                .blur(radius: size * 0.08)
        }
    }
    
    private var gemstoneImage: some View {
        ZStack {
            // Base shadow layer for depth
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(.black)
                .opacity(0.4)
                .blur(radius: 3)
                .offset(y: size * 0.02)
            
            // Main gem with darker base for depth
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(gemColor)
                .brightness(-0.15) // Darker base
                .saturation(1.2)
            
            // Mid-tone layer for dimension
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(gemColor)
                .brightness(0.1)
                .saturation(1.1)
                .blendMode(.lighten)
                .opacity(0.8)
            
            // Bright facet highlights
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(.white)
                .blendMode(.screen)
                .opacity(0.5)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Intense sparkle points
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(.white)
                .blendMode(.screen)
                .opacity(0.7)
                .mask(
                    RadialGradient(
                        colors: [.white, .clear],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
            
            // Subtle color dispersion (prismatic effect)
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(Color(hue: (gemColor.hueValue + 0.1).truncatingRemainder(dividingBy: 1.0), saturation: 0.8, brightness: 1.0))
                .blendMode(.screen)
                .opacity(0.2)
                .offset(x: -2, y: -2)
            
            // Inner rim glow where gem meets frame
            Image(gemAssetName)
                .resizable()
                .frame(width: size * 0.98, height: size * 0.98)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(gemColor.opacity(0))
                .overlay(
                    Image(gemAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorMultiply(gemColor)
                        .blur(radius: 4)
                        .blendMode(.screen)
                )
                .opacity(0.6)
        }
    }
    
    private var frameImage: some View {
        ZStack {
            // Subtle glow from frame picking up gem color
            Image(frameAssetName)
                .resizable()
                .frame(width: size * 1.05, height: size * 1.05)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(gemColor)
                .blur(radius: 6)
                .opacity(0.4)
            
            // Base frame with shadow for depth
            Image(frameAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(.black)
                .opacity(0.3)
                .blur(radius: 2)
                .offset(y: size * 0.015)
            
            // Main frame colored layer (preserving detail)
            Image(frameAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(resolvedFrameColor)
                .brightness(-0.1) // Slightly darker base
                .saturation(1.1)
            
            // Mid-tone highlights for dimension
            Image(frameAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(resolvedFrameColor)
                .brightness(0.15)
                .blendMode(.lighten)
                .opacity(0.7)
            
            // Metallic specular highlights
            Image(frameAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(.white)
                .blendMode(.screen)
                .opacity(0.5)
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.4), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Sharp highlight points (for ornate details)
            Image(frameAssetName)
                .resizable()
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .colorMultiply(.white)
                .blendMode(.screen)
                .opacity(0.6)
                .mask(
                    RadialGradient(
                        colors: [.white, .clear],
                        center: UnitPoint(x: 0.3, y: 0.2),
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
        }
    }
    
    // MARK: - Gem Trait Effects

    @State private var rainbowPhase: Double = 0      // Rainbow: slow background drift
    @State private var rainbowSpin: Double = -15     // Rainbow: tilt-driven rotation
    @State private var iridescentHueShift: Double = 0.0 // Iridescent: slow hue drift between swings
    // Starlight: no independent animation state needed —
    // brightness is derived from tilt angle passing through each star's trigger window.
    @State private var emberGlow: Double = 0.4       // Ember: heat pulse
    @State private var chargedPhase: Double = 0.0    // Charged: arc travel position (0→1 looping)

    @ViewBuilder
    private func traitOverlay(_ trait: GemTrait) -> some View {
        switch trait {
        case .starlight:  starlightTraitView
        case .rainbow:    rainbowTraitView
        case .iridescent: iridescentTraitView
        case .charged:    chargedTraitView
        case .ember:      emberTraitView
        }
    }

    /// Starlight — pinpoint glints that flash only when the pendulum tilt passes
    /// through each star's unique trigger angle. Completely silent at all other angles.
    ///
    /// Each star has a `triggerAngle` (in the -15…+20 range) and a narrow `window`
    /// width. `starBrightness(trigger:window:)` returns a smooth 0→1→0 pulse using
    /// a squared cosine so the peak is sharp and the shoulders fall off quickly.
    /// At most 1–2 stars are near their peak at any given tilt position.
    private var starlightTraitView: some View {
        ZStack {
            // Upper tip
            starPoint(x:  0.00, y: -0.28, scale: 0.6, brightness: starBrightness(trigger: -10.0, window: 3.5))
            starPoint(x: -0.05, y: -0.18, scale: 0.8, brightness: starBrightness(trigger:  16.0, window: 3.0))
            // Main gem body
            starPoint(x:  0.09, y: -0.10, scale: 1.0, brightness: starBrightness(trigger:   5.0, window: 2.5))
            starPoint(x: -0.12, y:  0.02, scale: 1.4, brightness: starBrightness(trigger: -14.0, window: 3.0))
            starPoint(x:  0.10, y:  0.06, scale: 1.1, brightness: starBrightness(trigger:  12.0, window: 2.5))
            starPoint(x:  0.00, y:  0.12, scale: 1.8, brightness: starBrightness(trigger:   0.0, window: 4.0)) // hero — fires near center
            // Lower main gem
            starPoint(x: -0.08, y:  0.22, scale: 1.2, brightness: starBrightness(trigger:  19.0, window: 2.5))
            starPoint(x:  0.11, y:  0.18, scale: 1.0, brightness: starBrightness(trigger:  -5.0, window: 3.0))
            // Pendant crystal zone
            starPoint(x: -0.22, y:  0.38, scale: 0.9, brightness: starBrightness(trigger:   9.0, window: 2.5))
            starPoint(x:  0.20, y:  0.44, scale: 0.7, brightness: starBrightness(trigger: -13.0, window: 3.0))
        }
        .blendMode(.screen)
        .mask(
            ZStack {
                Image(gemAssetName)
                    .resizable()
                    .frame(width: size, height: size)
                Image(frameAssetName)
                    .resizable()
                    .frame(width: size, height: size)
            }
        )
    }

    /// Returns 0…1 brightness based on how close `tilt` is to `triggerAngle`.
    /// `window` is the half-width in degrees — stars only glow within ±window of their trigger.
    /// Uses a squared cosine for a sharp peak that falls off quickly on both sides.
    private func starBrightness(trigger: Double, window: Double) -> Double {
        let delta = abs(tilt - trigger)
        guard delta < window else { return 0 }
        let t = delta / window              // 0 at trigger, 1 at edge
        let cosVal = cos(t * .pi / 2)       // 1 at center, 0 at edge
        return cosVal * cosVal              // squared = sharper peak
    }

    /// A single star — hard pinpoint core, soft halo, and needle-thin cross arms
    /// that stretch far enough to read across a coloured gem surface.
    private func starPoint(x: Double, y: Double, scale: Double, brightness: Double) -> some View {
        let baseSize = size * 0.07 * scale
        // Arms are intentionally very long and hair-thin — like a lens flare needle
        let armLength = baseSize * 7.0
        let armThick  = max(baseSize * 0.08, 1.0)   // never thinner than 1pt on screen
        return ZStack {
            // Soft glow halo — gives the star presence without bulk
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.85), .white.opacity(0.0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: baseSize * 0.8
                    )
                )
                .frame(width: baseSize * 1.8, height: baseSize * 1.8)
                .blur(radius: baseSize * 0.35)

            // Hard bright pinpoint — tiny solid white dot at the core
            Circle()
                .fill(Color.white)
                .frame(width: max(baseSize * 0.3, 2.0), height: max(baseSize * 0.3, 2.0))

            // Horizontal needle arm
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.95), .white, .white.opacity(0.95), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: armLength, height: armThick)
                .blur(radius: 0.4)

            // Vertical needle arm
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.95), .white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: armThick, height: armLength)
                .blur(radius: 0.4)
        }
        .offset(x: size * x, y: size * y)
        .opacity(brightness)
    }

    /// Rainbow — a full-spectrum colour wheel that physically spins in sync
    /// with the pendulum tilt. `rainbowSpin` is animated with the same
    /// easeInOut curve and duration as `tilt`, so the wheel rocks in lockstep
    /// with the gem. A slow `rainbowPhase` drift offsets the hue stops
    /// continuously so it never looks static.
    private var rainbowTraitView: some View {
        let stops: [Gradient.Stop] = (0..<12).map { i in
            let hue = (rainbowPhase + Double(i) / 12.0)
                .truncatingRemainder(dividingBy: 1.0)
            return .init(
                color: Color(hue: hue, saturation: 1.0, brightness: 1.0),
                location: Double(i) / 12.0
            )
        }
        return AngularGradient(stops: stops, center: .center)
            .frame(width: size, height: size)
            // rainbowSpin tracks the pendulum — same animation, 3× the angle
            .rotationEffect(.degrees(rainbowSpin))
            .opacity(0.50)
            .blendMode(.color)
            .mask(
                Image(gemAssetName)
                    .resizable()
                    .frame(width: size, height: size)
            )
            .onAppear {
                // Mirror the pendulum: same easing + duration as tilt, 1× range
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    rainbowSpin = 20    // swings -15…+20, i.e. 35° total — same arc as the gem tilt
                }
                // Slow hue drift — one full revolution every 8 s
                withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                    rainbowPhase = 1.0
                }
            }
    }

    /// Iridescent — a narrow butterfly-wing shimmer that rides the pendulum tilt
    /// perfectly by deriving its position directly from `tilt` rather than running
    /// a separate animation.
    ///
    /// Design notes:
    /// - `tilt` ranges -15…+20 (35° arc). We normalise that to 0…1 and convert
    ///   to a pixel offset so the band travels with the gem turn, not merely
    ///   alongside it.
    /// - The **frame** uses `.hue` blend mode — shifts colour while preserving
    ///   luminance completely, so engraved detail, shadows and highlights all
    ///   show through as if the metalwork is genuinely changing colour in the light.
    /// - The **gem** uses a light `.overlay` pass so the facet structure stays
    ///   readable underneath the shimmer.
    /// - A sharp `.screen` specular streak sits on top of both — the thin bright
    ///   line you see on a real butterfly wing scale.
    /// - Palette drifts slowly via `iridescentHueShift` so each swing looks
    ///   subtly different without cycling the whole rainbow.
    private var iridescentTraitView: some View {
        // Normalise tilt (-15…+20) → 0…1, then map to a pixel sweep across the frame.
        let tiltNorm    = (tilt - (-15.0)) / 35.0
        let pixelOffset = (tiltNorm - 0.5) * size

        // Butterfly-wing palette — a ~0.25 hue arc that drifts slowly.
        // Fades to transparent at the edges so the band has a soft boundary
        // rather than a hard clip.
        let base = iridescentHueShift
        let h1 = base
        let h2 = (base + 0.10).truncatingRemainder(dividingBy: 1.0)
        let h3 = (base + 0.22).truncatingRemainder(dividingBy: 1.0)

        // Band is narrower — only occupies the middle 60% of the sweep width,
        // fading out quickly at both edges so it reads as a glint not a wash.
        let bandStops: [Gradient.Stop] = [
            .init(color: Color(hue: h1, saturation: 1.0, brightness: 1.0).opacity(0.0), location: 0.00),
            .init(color: Color(hue: h1, saturation: 1.0, brightness: 1.0).opacity(0.6), location: 0.30),
            .init(color: Color(hue: h2, saturation: 1.0, brightness: 1.0).opacity(0.8), location: 0.50),
            .init(color: Color(hue: h3, saturation: 0.95, brightness: 1.0).opacity(0.6), location: 0.70),
            .init(color: Color(hue: h3, saturation: 1.0, brightness: 1.0).opacity(0.0), location: 1.00),
        ]

        let band = LinearGradient(stops: bandStops, startPoint: .leading, endPoint: .trailing)
            .frame(width: size * 1.5, height: size)   // narrower sheet than before
            .offset(x: pixelOffset)

        // Very thin specular line — just a subtle glint, not a bright sweep
        let specular = LinearGradient(
            stops: [
                .init(color: .white.opacity(0.00), location: 0.44),
                .init(color: .white.opacity(0.35), location: 0.50),
                .init(color: .white.opacity(0.00), location: 0.56),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: size * 1.5, height: size)
        .offset(x: pixelOffset)

        return ZStack {

            // ── Frame only: .hue at low opacity — tints metalwork hue without
            // touching luminance, so engraving detail is completely preserved.
            ZStack {
                band.blendMode(.hue).opacity(0.5)
                specular.blendMode(.screen).opacity(0.4)
            }
            .frame(width: size, height: size)
            .clipped()
            .mask(
                Image(frameAssetName)
                    .resizable()
                    .frame(width: size, height: size)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: true)) {
                iridescentHueShift = 0.22
            }
        }
    }

    private func startChargedAnimation() {
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            chargedPhase = 1.0
        }
    }

    /// Charged — crackling white-blue electric arcs that travel across the gem
    /// surface in short bursts. Three arcs run at staggered phases so there is
    /// always at least one visible at a time.
    private var chargedTraitView: some View {
        ZStack {
            // Ambient blue-white tint
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .colorMultiply(Color(hue: 0.6, saturation: 0.6, brightness: 1.0))
                .opacity(0.18)
                .blendMode(.color)

            // Arc 0 — diagonal ~20°, offset up
            ChargedArcView(phase: chargedPhase, phaseOffset: 0.0,
                           angle: 20,  yOffset: -size * 0.08, arcWidth: size * 0.9, arcHeight: max(size * 0.014, 2))
            // Arc 1 — steeper ~85°, centered
            ChargedArcView(phase: chargedPhase, phaseOffset: 1.0 / 3.0,
                           angle: 85,  yOffset:  0,            arcWidth: size * 0.9, arcHeight: max(size * 0.014, 2))
            // Arc 2 — shallow ~150°, offset down
            ChargedArcView(phase: chargedPhase, phaseOffset: 2.0 / 3.0,
                           angle: 150, yOffset:  size * 0.08,  arcWidth: size * 0.9, arcHeight: max(size * 0.014, 2))
        }
        .mask(
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
        )
    }

    /// Ember — a deep red-orange inner fire that pulses outward, tinting the
    /// whole gem warm and making it visibly glow.
    private var emberTraitView: some View {
        ZStack {
            // Warm colour tint over the whole gem
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
                .colorMultiply(Color(hue: 0.06, saturation: 1.0, brightness: 1.0))
                .opacity(0.5)
                .blendMode(.color)

            // Pulsing core fireball
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 1.0, brightness: 1.0).opacity(emberGlow * 0.9),
                            Color(hue: 0.04, saturation: 1.0, brightness: 0.9).opacity(emberGlow * 0.5),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.38
                    )
                )
                .frame(width: size * 0.76, height: size * 0.76)
                .blur(radius: size * 0.06)
                .blendMode(.plusLighter)

            // Outer ember rim — orange halo around the edge
            Circle()
                .strokeBorder(
                    Color(hue: 0.06, saturation: 1.0, brightness: 1.0).opacity(emberGlow * 0.7),
                    lineWidth: size * 0.06
                )
                .frame(width: size * 0.72, height: size * 0.72)
                .blur(radius: size * 0.04)
                .blendMode(.plusLighter)
        }
        .mask(
            Image(gemAssetName)
                .resizable()
                .frame(width: size, height: size)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                emberGlow = 1.0
            }
        }
    }

    // MARK: - Shimmer & Tilt

    @State private var glowPulse: Double = 0.5
    @State private var tilt: Double = -15

    private var shimmerOverlay: some View {
        ZStack {
            // Shine sweep — intensity driven by how close tilt is to center (0°)
            shimmerSweep

            // Breathing inner highlight along the top-left facet edge
            facetBreath
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = 1.0
            }
        }
    }

    private var shineIntensity: Double {
        let radians = tilt * .pi / 180
        let raw = cos(radians)
        return pow(max(raw, 0), 4)
    }

    private var shimmerSweep: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear,                                location: 0.0),
                        .init(color: .white.opacity(0.15 * shineIntensity), location: 0.42),
                        .init(color: .white.opacity(0.70 * shineIntensity), location: 0.50),
                        .init(color: .white.opacity(0.15 * shineIntensity), location: 0.58),
                        .init(color: .clear,                                location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size * 2.5, height: size * 2)
            .rotationEffect(.degrees(-35))
            .offset(x: (tilt / 15.0) * size * 0.3)
            .mask(
                ZStack {
                    Image(gemAssetName).resizable().frame(width: size, height: size)
                    Image(frameAssetName).resizable().frame(width: size, height: size)
                }
            )
            .blendMode(.overlay)
    }

    private var facetBreath: some View {
        Image(gemAssetName)
            .resizable()
            .frame(width: size, height: size)
            .colorMultiply(.white)
            .blendMode(.screen)
            .opacity(glowPulse * 0.22)
            .mask(
                LinearGradient(
                    colors: [.white, .white.opacity(0.5), .clear],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.6, y: 0.6)
                )
            )
    }
}

// MARK: - Rendering a real coin from its DNA

extension SupabaseService.GemDNA {
    /// Gem tint from the DNA's primary hue and saturation.
    var gemColor: Color {
        Color(hue: resolvedHue / 360.0, saturation: resolvedSaturation, brightness: 0.9)
    }

    /// The gem's own frame color from `identity.frame_hue` (0–360), using the same
    /// saturation/brightness as the Gem Generator. Nil when the DNA has no frame hue,
    /// in which case the frame falls back to the tier's default color.
    var frameColor: Color? {
        identity?.frameHue.map { Color(hue: $0 / 360.0, saturation: 0.7, brightness: 0.85) }
    }
}

extension FavorGemView {
    /// Renders a real coin exactly as its DNA describes it — family, gem color,
    /// frame color and trait — at the tier its transfer count has reached.
    /// Use this for every coin-backed gem so no screen forgets a DNA field.
    init(
        dna: SupabaseService.GemDNA?,
        transferCount: Int,
        size: CGFloat = 200,
        showGlow: Bool = false,
        showShimmer: Bool = false
    ) {
        let tier = Tier.from(transferCount: transferCount)
        self.init(
            gemFamily: GemFamily.from(dna?.resolvedFamily),
            tier: tier,
            gemColor: dna?.gemColor ?? tier.defaultColor,
            frameColor: dna?.frameColor,
            size: size,
            showGlow: showGlow,
            showShimmer: showShimmer,
            trait: GemTrait.from(dna?.trait)
        )
    }
}

// MARK: - Charged Arc Helper

/// A single electric arc for the charged trait. Implemented as its own View so
/// that `phase` is observed as a proper input, guaranteeing SwiftUI redraws on
/// every animation tick rather than computing visibility once at build time.
private struct ChargedArcView: View {
    let phase: Double        // shared 0→1 looping value from the parent's @State
    let phaseOffset: Double  // staggers this arc within the cycle (0, 1/3, 2/3)
    let angle: Double        // rotation angle in degrees
    let yOffset: CGFloat     // perpendicular displacement from center
    let arcWidth: CGFloat
    let arcHeight: CGFloat

    /// Local phase for this arc — 0→1 looping, shifted by offset.
    private var local: Double {
        (phase + phaseOffset).truncatingRemainder(dividingBy: 1.0)
    }

    /// Smooth 0→1→0 over the first 35% of the cycle, silent the rest.
    private var visibility: Double {
        local < 0.35 ? sin(local / 0.35 * .pi) : 0.0
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear,                                                   location: 0.00),
                        .init(color: Color(hue: 0.58, saturation: 0.35, brightness: 1.0),     location: 0.25),
                        .init(color: .white,                                                   location: 0.50),
                        .init(color: Color(hue: 0.58, saturation: 0.35, brightness: 1.0),     location: 0.75),
                        .init(color: .clear,                                                   location: 1.00),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: arcWidth, height: arcHeight)
            .blur(radius: arcHeight * 0.8)
            .offset(y: yOffset)
            .rotationEffect(.degrees(angle))
            .opacity(visibility)
            .blendMode(.plusLighter)
    }
}

// MARK: - Enhanced Version with Animated Effects

/// Enhanced gem view with pulse and rotation animations
struct AnimatedFavorGemView: View {
    let gemFamily: GemFamily
    /// Always derived from `gemFamily` via `FrameFamily.matching(_:)` — never set independently.
    let frameFamily: FrameFamily
    let tier: Tier
    let gemColor: Color
    let frameColor: Color?
    let size: CGFloat

    @State private var pulse: Double = 1.0
    @State private var tilt: Double = -8

    init(
        gemFamily: GemFamily,
        tier: Tier,
        gemColor: Color,
        frameColor: Color? = nil,
        size: CGFloat = 200
    ) {
        self.gemFamily   = gemFamily
        self.frameFamily = FrameFamily.matching(gemFamily)
        self.tier        = tier
        self.gemColor    = gemColor
        self.frameColor  = frameColor
        self.size        = size
    }

    var body: some View {
        ZStack {
            // Pulsing glow — scales slightly in sync with the tilt
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gemColor.opacity(0.3),
                            gemColor.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size * pulse, height: size * pulse)
                .blur(radius: size * 0.15)

            // Gem and frame — shimmer on, pendulum owned here via rotation3DEffect below
            FavorGemView(
                gemFamily: gemFamily,
                tier: tier,
                gemColor: gemColor,
                frameColor: frameColor,
                size: size,
                showGlow: false,
                showShimmer: true,
                suppressTilt: true
            )
        }
        .frame(width: size, height: size)
        // Pendulum tilt on the whole ZStack (glow + gem move together)
        .rotation3DEffect(
            .degrees(tilt),
            axis: (x: 0.15, y: 1.0, z: 0.0),
            anchor: .center,
            perspective: 0.5
        )
        .shadow(
            color: .black.opacity(0.35),
            radius: 14,
            x: sin(tilt * .pi / 180) * 10,
            y: 6
        )
        .onAppear {
            // Gentle pulse
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulse = 1.1
            }
            // Slow pendulum — rocks from -8° to +8° and back, slightly slower than thumbnails
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                tilt = 8
            }
        }
    }
}

// MARK: - Gallery View for Testing

/// Preview gallery showing all gem/frame family combinations across tiers
struct FavorGemGallery: View {
    @State private var selectedGemFamily: GemFamily = .lightning
    @State private var selectedTier: Tier = .legacy
    @State private var primaryHue: Double = 200
    @State private var saturation: Double = 0.8
    @State private var frameHue: Double = 50
    @State private var useCustomFrameColor: Bool = false

    var gemColor: Color {
        Color(hue: primaryHue / 360.0, saturation: saturation, brightness: 0.9)
    }

    var frameColor: Color {
        Color(hue: frameHue / 360.0, saturation: 0.8, brightness: 0.85)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Text("Favor Gem Gallery")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    // Featured gem (large, animated)
                    VStack(spacing: 16) {
                        AnimatedFavorGemView(
                            gemFamily: selectedGemFamily,
                            tier: selectedTier,
                            gemColor: gemColor,
                            frameColor: useCustomFrameColor ? frameColor : nil,
                            size: 280
                        )

                        VStack(spacing: 8) {
                            Text("\(selectedGemFamily.displayName) gem")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text("\(selectedGemFamily.displayName) · \(selectedTier.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 20)

                    // Controls
                    VStack(spacing: 24) {
                        // Gem family selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gem Family")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                ForEach(GemFamily.allCases) { family in
                                    FamilyButton(
                                        title: family.displayName,
                                        isSelected: selectedGemFamily == family,
                                        color: .cyan,
                                        action: {
                                            selectedGemFamily = family
                                        }
                                    )
                                }
                            }
                        }

                        // Frame family selector (removed — frame always matches gem family)

                        // Tier selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tier")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                ForEach(Tier.allCases) { tier in
                                    TierButton(
                                        tier: tier,
                                        isSelected: selectedTier == tier,
                                        action: { selectedTier = tier }
                                    )
                                }
                            }
                        }

                        // Color controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gem Color")
                                .font(.headline)
                                .foregroundColor(.white)

                            VStack(spacing: 8) {
                                HStack {
                                    Text("Hue")
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("\(Int(primaryHue))°")
                                        .foregroundColor(.white)
                                }
                                Slider(value: $primaryHue, in: 0...360, step: 1)
                                    .tint(gemColor)

                                HStack {
                                    Text("Saturation")
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("\(Int(saturation * 100))%")
                                        .foregroundColor(.white)
                                }
                                Slider(value: $saturation, in: 0...1, step: 0.01)
                                    .tint(.cyan)
                            }
                        }

                        // Custom frame color
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $useCustomFrameColor) {
                                Text("Custom Frame Color")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .tint(.cyan)

                            if useCustomFrameColor {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("Frame Hue")
                                            .foregroundColor(.white.opacity(0.7))
                                        Spacer()
                                        Text("\(Int(frameHue))°")
                                            .foregroundColor(.white)
                                    }
                                    Slider(value: $frameHue, in: 0...360, step: 1)
                                        .tint(frameColor)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Tier progression for the current gem/frame pairing
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tier Progression")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(Tier.allCases) { tier in
                                    VStack(spacing: 8) {
                                        FavorGemView(
                                            gemFamily: selectedGemFamily,
                                            tier: tier,
                                            gemColor: gemColor,
                                            frameColor: useCustomFrameColor ? frameColor : nil,
                                            size: 120,
                                            showGlow: true
                                        )

                                        Text(tier.displayName)
                                            .font(.caption)
                                            .foregroundColor(tier.defaultColor)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)

                    Color.clear.frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FamilyButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? color : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: isSelected ? 0 : 1.5)
                )
        }
    }
}

struct TierButton: View {
    let tier: Tier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tier.displayName)
                .font(.headline)
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? tier.defaultColor : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tier.defaultColor, lineWidth: isSelected ? 0 : 2)
                )
        }
    }
}

// MARK: - Convenience View Modifiers

extension View {
    /// Wrap any view with a gem badge overlay
    func gemBadge(
        gemFamily: GemFamily = .lightning,
        tier: Tier,
        color: Color,
        size: CGFloat = 40,
        alignment: Alignment = .topTrailing,
        offset: CGSize = .zero
    ) -> some View {
        self.overlay(alignment: alignment) {
            FavorGemView(
                gemFamily: gemFamily,
                tier: tier,
                gemColor: color,
                size: size,
                showGlow: false,
                showShimmer: false
            )
            .offset(offset)
        }
    }
}

// MARK: - Color Helpers

extension Color {
    /// Approximate hue value from color (simplified)
    var hueValue: Double {
        return 0.5
    }

    /// RGB components for color blending
    var components: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return (0.5, 0.5, 0.5)
        }
        return (Double(rgbColor.redComponent), Double(rgbColor.greenComponent), Double(rgbColor.blueComponent))
        #else
        return (0.5, 0.5, 0.5)
        #endif
    }
}

// MARK: - Asset Verification

/// Visual check confirming that all expected gem and frame assets are present in the catalog.
struct FrameAssetVerificationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Asset Verification")
                    .font(.title.bold())
                    .padding()

                ForEach(Tier.allCases) { tier in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(tier.displayName) Tier")
                            .font(.headline)
                            .foregroundColor(tier.defaultColor)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(GemFamily.allCases) { gemFamily in
                                ForEach(FrameFamily.allCases) { frameFamily in
                                    let gemAsset   = gemFamily.assetName(tier: tier)
                                    let frameAsset = frameFamily.assetName(tier: tier)

                                    VStack(spacing: 4) {
                                        ZStack {
                                            Image(gemAsset)
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundColor(.cyan)
                                                .frame(width: 50, height: 50)

                                            Image(frameAsset)
                                                .resizable()
                                                .renderingMode(.template)
                                                .foregroundColor(tier.defaultColor.opacity(0.7))
                                                .frame(width: 60, height: 60)
                                        }
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)

                                        Text("\(gemFamily.rawValue)/\(frameFamily.rawValue)")
                                            .font(.caption2)

                                        HStack(spacing: 4) {
                                            Image(systemName: UIImage(named: gemAsset) != nil
                                                  ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(UIImage(named: gemAsset) != nil ? .green : .red)
                                                .font(.caption2)

                                            Image(systemName: UIImage(named: frameAsset) != nil
                                                  ? "checkmark.square.fill" : "xmark.square.fill")
                                                .foregroundColor(UIImage(named: frameAsset) != nil ? .green : .red)
                                                .font(.caption2)
                                        }

                                        Text(gemAsset)
                                            .font(.system(size: 8))
                                            .foregroundColor(.cyan.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Legend
                VStack(alignment: .leading, spacing: 8) {
                    Text("Legend")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("= Gem asset loaded").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                    HStack {
                        Image(systemName: "checkmark.square.fill").foregroundColor(.green)
                        Text("= Frame asset loaded").font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Previews

#Preview("Asset Verification") {
    FrameAssetVerificationView()
}

#Preview("Single Gem") {
    ZStack {
        Color.black.ignoresSafeArea()
        FavorGemView(
            gemFamily: .lightning,
            tier: .legacy,
            gemColor: .cyan,
            size: 280,
            showGlow: true,
            showShimmer: true
        )
    }
}

#Preview("Animated Gem") {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedFavorGemView(
            gemFamily: .lightning,
            tier: .bloom,
            gemColor: .cyan,
            size: 280
        )
    }
}

#Preview("Gallery") {
    FavorGemGallery()
}

#Preview("Lightning Progression") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            Text("Lightning Evolution")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("gem_lightning_{tier}  +  frame_lightning_{tier}")
                .font(.subheadline)
                .foregroundColor(.cyan)

            HStack(spacing: 20) {
                ForEach(Tier.allCases) { tier in
                    VStack(spacing: 12) {
                        FavorGemView(
                            gemFamily: .lightning,
                            tier: tier,
                            gemColor: .cyan,
                            size: 140,
                            showGlow: true
                        )

                        VStack(spacing: 4) {
                            Text(tier.displayName)
                                .font(.headline)
                                .foregroundColor(tier.defaultColor)

                            Text(GemFamily.lightning.assetName(tier: tier))
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))

                            Text(FrameFamily.lightning.assetName(tier: tier))
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}

#Preview("Trait: None") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FavorGemView(gemFamily: .lightning, tier: .bloom, gemColor: .cyan,
                         size: 260, showGlow: true, showShimmer: false, trait: nil)
            Text("None").font(.headline).foregroundColor(.white.opacity(0.4))
        }
    }
}

#Preview("Trait: Starlight") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FavorGemView(gemFamily: .lightning, tier: .bloom, gemColor: .cyan,
                         size: 260, showGlow: true, showShimmer: false, trait: .starlight)
            Text("Starlight").font(.headline).foregroundColor(.white)
        }
    }
}

#Preview("Trait: Rainbow") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FavorGemView(gemFamily: .lightning, tier: .bloom, gemColor: .cyan,
                         size: 260, showGlow: true, showShimmer: false, trait: .rainbow)
            Text("Rainbow").font(.headline).foregroundColor(.white)
        }
    }
}

#Preview("Trait: Iridescent") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FavorGemView(gemFamily: .lightning, tier: .bloom, gemColor: .cyan,
                         size: 260, showGlow: true, showShimmer: false, trait: .iridescent)
            Text("Iridescent").font(.headline).foregroundColor(.white)
        }
    }
}

#Preview("Trait: Charged") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FavorGemView(gemFamily: .lightning, tier: .bloom, gemColor: .cyan,
                         size: 260, showGlow: true, showShimmer: false, trait: .charged)
            Text("Charged").font(.headline).foregroundColor(.white)
        }
    }
}

#Preview("Trait: Ember") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FavorGemView(gemFamily: .lightning, tier: .bloom, gemColor: .cyan,
                         size: 260, showGlow: true, showShimmer: false, trait: .ember)
            Text("Ember").font(.headline).foregroundColor(.white)
        }
    }
}
