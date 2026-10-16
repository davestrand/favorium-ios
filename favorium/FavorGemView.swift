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

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// The asset name for this family at a given tier.
    func assetName(tier: Tier) -> String {
        "gem_\(rawValue)_\(tier.rawValue)"
    }

    /// Map from a `CrystalDNA` gemFamily string to a `GemFamily`.
    /// Falls back to `.lightning` until additional families are added.
    static func from(_ string: String?) -> GemFamily {
        guard let string else { return .lightning }
        return GemFamily(rawValue: string.lowercased()) ?? .lightning
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

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

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
}

// MARK: - FavorGemView

/// Reusable asset-based gemstone view with decorative frame.
///
/// Renders a `GemFamily` gem inside a `FrameFamily` frame, both at the same `Tier`.
/// Any gem family can be paired with any frame family — they are fully independent.
///
/// Asset names are constructed as:
/// - Gem:   `gem_{gemFamily}_{tier}`   e.g. `gem_lightning_bloom`
/// - Frame: `frame_{frameFamily}_{tier}` e.g. `frame_gothic_bloom`
struct FavorGemView: View {
    let gemFamily: GemFamily
    let frameFamily: FrameFamily
    let tier: Tier
    let gemColor: Color
    let frameColor: Color?
    let size: CGFloat
    let showGlow: Bool
    let showShimmer: Bool

    /// Primary initializer — explicitly specify both families and tier.
    init(
        gemFamily: GemFamily,
        frameFamily: FrameFamily,
        tier: Tier,
        gemColor: Color,
        frameColor: Color? = nil,
        size: CGFloat = 200,
        showGlow: Bool = false,
        showShimmer: Bool = false
    ) {
        self.gemFamily   = gemFamily
        self.frameFamily = frameFamily
        self.tier        = tier
        self.gemColor    = gemColor
        self.frameColor  = frameColor
        self.size        = size
        self.showGlow    = showGlow
        self.showShimmer = showShimmer
    }

    /// Convenience initializer from a `CrystalModel`.
    /// Reads `gemFamily` and `frameFamily` from the model's DNA when available,
    /// falling back to `.lightning` for both until additional families are in production.
    init(
        model: CrystalModel,
        size: CGFloat = 200,
        customFrameColor: Color? = nil,
        showGlow: Bool = false,
        showShimmer: Bool = false
    ) {
        self.gemFamily   = GemFamily.from(model.gemFamily)
        self.frameFamily = FrameFamily.from(model.frameFamily)
        self.tier        = Tier.from(transferCount: model.transferCount)
        self.gemColor    = Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
        self.frameColor  = customFrameColor
        self.size        = size
        self.showGlow    = showGlow
        self.showShimmer = showShimmer
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
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - Components
    
    private var backgroundGlow: some View {
        ZStack {
            // Outer frame color glow (metallic aura)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            resolvedFrameColor.opacity(0.3),
                            resolvedFrameColor.opacity(0.15),
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
                            gemColor.opacity(0.35),
                            Color(
                                red: (gemColor.components.red + resolvedFrameColor.components.red) / 2,
                                green: (gemColor.components.green + resolvedFrameColor.components.green) / 2,
                                blue: (gemColor.components.blue + resolvedFrameColor.components.blue) / 2
                            ).opacity(0.2),
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
                            gemColor.opacity(0.6),
                            gemColor.opacity(0.4),
                            gemColor.opacity(0.1)
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
    
    @State private var shimmerPhase: Double = 0
    
    private var shimmerOverlay: some View {
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
            .mask(
                Image(gemAssetName)
                    .resizable()
                    .frame(width: size, height: size)
            )
            .blendMode(.overlay)
            .onAppear {
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }
    }
    
    // MARK: - Asset Name Helpers

    /// e.g. `gem_lightning_bloom`
    private var gemAssetName: String {
        gemFamily.assetName(tier: tier)
    }

    /// e.g. `frame_lightning_bloom`
    private var frameAssetName: String {
        frameFamily.assetName(tier: tier)
    }

    private var resolvedFrameColor: Color {
        frameColor ?? tier.defaultColor
    }
}

// MARK: - Enhanced Version with Animated Effects

/// Enhanced gem view with pulse and rotation animations
struct AnimatedFavorGemView: View {
    let gemFamily: GemFamily
    let frameFamily: FrameFamily
    let tier: Tier
    let gemColor: Color
    let frameColor: Color?
    let size: CGFloat

    @State private var pulse: Double = 1.0
    @State private var rotation: Double = 0
    @State private var shimmerPhase: Double = 0

    init(
        gemFamily: GemFamily,
        frameFamily: FrameFamily,
        tier: Tier,
        gemColor: Color,
        frameColor: Color? = nil,
        size: CGFloat = 200
    ) {
        self.gemFamily   = gemFamily
        self.frameFamily = frameFamily
        self.tier        = tier
        self.gemColor    = gemColor
        self.frameColor  = frameColor
        self.size        = size
    }

    init(model: CrystalModel, size: CGFloat = 200, customFrameColor: Color? = nil) {
        self.gemFamily   = GemFamily.from(model.gemFamily)
        self.frameFamily = FrameFamily.from(model.frameFamily)
        self.tier        = Tier.from(transferCount: model.transferCount)
        self.gemColor    = Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
        self.frameColor  = customFrameColor
        self.size        = size
    }
    var body: some View {
        ZStack {
            // Pulsing glow
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

            // Gem and frame
            FavorGemView(
                gemFamily: gemFamily,
                frameFamily: frameFamily,
                tier: tier,
                gemColor: gemColor,
                frameColor: frameColor,
                size: size,
                showGlow: false,
                showShimmer: true
            )
            .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
        .onAppear {
            // Gentle pulse
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulse = 1.1
            }
            // Very slow rotation
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Gallery View for Testing

/// Preview gallery showing all gem/frame family combinations across tiers
struct FavorGemGallery: View {
    @State private var selectedGemFamily: GemFamily = .lightning
    @State private var selectedFrameFamily: FrameFamily = .lightning
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
                            frameFamily: selectedFrameFamily,
                            tier: selectedTier,
                            gemColor: gemColor,
                            frameColor: useCustomFrameColor ? frameColor : nil,
                            size: 280
                        )

                        VStack(spacing: 8) {
                            Text("\(selectedGemFamily.displayName) gem")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text("\(selectedFrameFamily.displayName) frame · \(selectedTier.displayName)")
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
                                        action: { selectedGemFamily = family }
                                    )
                                }
                            }
                        }

                        // Frame family selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frame Family")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 12) {
                                ForEach(FrameFamily.allCases) { family in
                                    FamilyButton(
                                        title: family.displayName,
                                        isSelected: selectedFrameFamily == family,
                                        color: .orange,
                                        action: { selectedFrameFamily = family }
                                    )
                                }
                            }
                        }

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
                                            frameFamily: selectedFrameFamily,
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

// MARK: - Bridge to Existing System

extension MagicalCrystalView {
    /// Create an asset-based version from the same model
    func asAssetBased(size: CGFloat = 200) -> some View {
        FavorGemView(model: model, size: size)
    }
}

// MARK: - Convenience View Modifiers

extension View {
    /// Wrap any view with a gem badge overlay
    func gemBadge(
        gemFamily: GemFamily = .lightning,
        frameFamily: FrameFamily = .lightning,
        tier: Tier,
        color: Color,
        size: CGFloat = 40,
        alignment: Alignment = .topTrailing,
        offset: CGSize = .zero
    ) -> some View {
        self.overlay(alignment: alignment) {
            FavorGemView(
                gemFamily: gemFamily,
                frameFamily: frameFamily,
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
            frameFamily: .lightning,
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
            frameFamily: .lightning,
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
                            frameFamily: .lightning,
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




