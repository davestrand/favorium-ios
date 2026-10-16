//
//  FavorGemView.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Asset-based gemstone and frame rendering system

import SwiftUI

// MARK: - Enums

/// Nine gemstone shapes matching the asset files
/// 
/// Asset System:
/// - **Lightning**: Uses tier-specific gems (gem_seed_lightning, gem_bloom_lightning, etc.)
/// - **Other shapes**: Use single gem asset per shape (gem_heart, gem_brilliant, etc.)
enum GemShape: String, CaseIterable, Identifiable {
    case brilliant
    case heart
    case star
    case hexagon
    case octagon
    case pear
    case marquise
    case cushion
    case lightning  // New progressive gem shape with tier-specific assets
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Map from CrystalModel baseForm to GemShape
    static func from(baseForm: String) -> GemShape {
        let normalized = baseForm.lowercased().trimmingCharacters(in: .whitespaces)
        switch normalized {
        case "brilliant", "diamond", "circle", "round":
            return .brilliant
        case "heart":
            return .heart
        case "star":
            return .star
        case "hexagon", "hex":
            return .hexagon
        case "octagon", "oct":
            return .octagon
        case "pear", "teardrop":
            return .pear
        case "marquise":
            return .marquise
        case "cushion":
            return .cushion
        case "lightning", "bolt":
            return .lightning
        default:
            return .brilliant // fallback
        }
    }
}

/// Frame tiers matching asset complexity levels
enum FrameTier: String, CaseIterable, Identifiable {
    case seed       // Starting tier (0-4 transfers)
    case bloom      // Growing tier (5-14 transfers)
    case legacy     // Established tier (15-29 transfers)
    case radiance   // Maximum tier (30+ transfers)
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Map from transfer count to frame tier
    static func from(transferCount: Int) -> FrameTier {
        switch transferCount {
        case 0..<5:
            return .seed
        case 5..<15:
            return .bloom
        case 15..<30:
            return .legacy
        default:
            return .radiance
        }
    }
    
    /// Suggested frame color based on tier theme
    var defaultColor: Color {
        switch self {
        case .seed:
            // Fresh green/brown earth tones
            return Color(hue: 0.28, saturation: 0.5, brightness: 0.6)
        case .bloom:
            // Vibrant flowering colors
            return Color(hue: 0.55, saturation: 0.7, brightness: 0.85)
        case .legacy:
            // Rich gold/amber tones
            return Color(hue: 0.12, saturation: 0.8, brightness: 0.9)
        case .radiance:
            // Brilliant white/platinum
            return Color(hue: 0.15, saturation: 0.15, brightness: 1.0)
        }
    }
    
    /// Asset name mapping
    var assetName: String {
        // All tiers now use their proper names
        return rawValue
    }
}

// MARK: - FavorGemView

/// Reusable asset-based gemstone view with decorative frame
struct FavorGemView: View {
    let shape: GemShape
    let gemColor: Color
    let frameTier: FrameTier
    let frameColor: Color?
    let size: CGFloat
    let showGlow: Bool
    let showShimmer: Bool
    
    /// Primary initializer with all options
    init(
        shape: GemShape,
        gemColor: Color,
        frameTier: FrameTier,
        frameColor: Color? = nil,
        size: CGFloat = 200,
        showGlow: Bool = false,
        showShimmer: Bool = false
    ) {
        self.shape = shape
        self.gemColor = gemColor
        self.frameTier = frameTier
        self.frameColor = frameColor
        self.size = size
        self.showGlow = showGlow
        self.showShimmer = showShimmer
    }
    
    /// Convenience initializer from CrystalModel
    init(
        model: CrystalModel,
        size: CGFloat = 200,
        customFrameColor: Color? = nil,
        showGlow: Bool = false,
        showShimmer: Bool = false
    ) {
        self.shape = GemShape.from(baseForm: model.baseForm)
        self.gemColor = Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
        self.frameTier = FrameTier.from(transferCount: model.transferCount)
        self.frameColor = customFrameColor
        self.size = size
        self.showGlow = showGlow
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
    
    private var gemAssetName: String {
        // Lightning uses tier-specific gems (new system)
        if shape == .lightning {
            return "gem_\(frameTier.rawValue)_lightning"
        }
        // Other shapes use single gem asset (legacy system)
        return "gem_\(shape.rawValue)"
    }
    
    private var frameAssetName: String {
        "frame_\(frameTier.assetName)_\(shape.rawValue)"
    }
    
    private var resolvedFrameColor: Color {
        frameColor ?? frameTier.defaultColor
    }
}

// MARK: - Enhanced Version with Animated Effects

/// Enhanced gem view with pulse and rotation animations
struct AnimatedFavorGemView: View {
    let shape: GemShape
    let gemColor: Color
    let frameTier: FrameTier
    let frameColor: Color?
    let size: CGFloat
    
    @State private var pulse: Double = 1.0
    @State private var rotation: Double = 0
    @State private var shimmerPhase: Double = 0
    
    init(
        shape: GemShape,
        gemColor: Color,
        frameTier: FrameTier,
        frameColor: Color? = nil,
        size: CGFloat = 200
    ) {
        self.shape = shape
        self.gemColor = gemColor
        self.frameTier = frameTier
        self.frameColor = frameColor
        self.size = size
    }
    
    init(model: CrystalModel, size: CGFloat = 200, customFrameColor: Color? = nil) {
        self.shape = GemShape.from(baseForm: model.baseForm)
        self.gemColor = Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
        self.frameTier = FrameTier.from(transferCount: model.transferCount)
        self.frameColor = customFrameColor
        self.size = size
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
                shape: shape,
                gemColor: gemColor,
                frameTier: frameTier,
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

/// Preview gallery showing all gem shapes and frame tiers
struct FavorGemGallery: View {
    @State private var selectedShape: GemShape = .brilliant
    @State private var selectedTier: FrameTier = .legacy
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
            // Dark background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Title
                    Text("Favor Gem Gallery")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 40)
                    
                    // Featured gem (large, animated)
                    VStack(spacing: 16) {
                        AnimatedFavorGemView(
                            shape: selectedShape,
                            gemColor: gemColor,
                            frameTier: selectedTier,
                            frameColor: useCustomFrameColor ? frameColor : nil,
                            size: 280
                        )
                        
                        VStack(spacing: 8) {
                            Text(selectedShape.displayName)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            
                            Text("\(selectedTier.displayName) Frame")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // Controls
                    VStack(spacing: 24) {
                        // Shape selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gemstone Shape")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(GemShape.allCases) { shape in
                                    ShapeButton(
                                        shape: shape,
                                        isSelected: selectedShape == shape,
                                        action: { selectedShape = shape }
                                    )
                                }
                            }
                        }
                        
                        // Frame tier selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frame Tier")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                ForEach(FrameTier.allCases) { tier in
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
                    
                    // Complete matrix view
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Complete Collection")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                        
                        ForEach(FrameTier.allCases) { tier in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(tier.displayName) Tier")
                                    .font(.headline)
                                    .foregroundColor(tier.defaultColor)
                                    .padding(.horizontal, 24)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(GemShape.allCases) { shape in
                                            VStack(spacing: 8) {
                                                FavorGemView(
                                                    shape: shape,
                                                    gemColor: gemColor,
                                                    frameTier: tier,
                                                    frameColor: useCustomFrameColor ? frameColor : nil,
                                                    size: 100,
                                                    showGlow: true,
                                                    showShimmer: false
                                                )
                                                
                                                Text(shape.displayName)
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ShapeButton: View {
    let shape: GemShape
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image("gem_\(shape.rawValue)")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.5))
                    .frame(width: 50, height: 50)
                
                Text(shape.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .cyan : .white.opacity(0.5))
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct TierButton: View {
    let tier: FrameTier
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
        shape: GemShape,
        color: Color,
        tier: FrameTier,
        size: CGFloat = 40,
        alignment: Alignment = .topTrailing,
        offset: CGSize = .zero
    ) -> some View {
        self.overlay(alignment: alignment) {
            FavorGemView(
                shape: shape,
                gemColor: color,
                frameTier: tier,
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
        // This is a simplified extraction - for the dispersion effect
        // In production, you might want a more accurate UIColor/NSColor conversion
        return 0.5 // Fallback for now, but will work with the truncatingRemainder
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
            return (0.5, 0.5, 0.5) // Fallback
        }
        return (Double(rgbColor.redComponent), Double(rgbColor.greenComponent), Double(rgbColor.blueComponent))
        #else
        return (0.5, 0.5, 0.5) // Fallback
        #endif
    }
}

// MARK: - Shape Path Helpers

extension GemShape {
    /// Get an approximate SwiftUI shape for hit testing or masking
    /// Note: These are simplified versions, actual assets have more detail
    @ViewBuilder
    var approximateShape: some View {
        switch self {
        case .brilliant:
            Circle()
        case .heart:
            HeartShape()
        case .star:
            StarShape()
        case .hexagon:
            HexagonShape()
        case .octagon:
            OctagonShape()
        case .pear:
            PearShape()
        case .marquise:
            MarquiseShape()
        case .cushion:
            CushionShape()
        case .lightning:
            LightningBoltShape()
        }
    }
}

// MARK: - Lightning Shape Definition
// Note: Other shapes are defined in MagicalCrystalView.swift

struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Lightning bolt zigzag pattern
        path.move(to: CGPoint(x: w * 0.6, y: 0))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.4))
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.4))
        path.addLine(to: CGPoint(x: w * 0.25, y: h))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.55))
        path.closeSubpath()
        return path
    }
}

// MARK: - Asset Verification

/// Quick check to see which frame and gem assets are loaded
struct FrameAssetVerificationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Frame Assets Verification")
                    .font(.title.bold())
                    .padding()
                
                ForEach(FrameTier.allCases) { tier in
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
                            ForEach(GemShape.allCases) { shape in
                                VStack(spacing: 4) {
                                    // Lightning uses tier-specific gems
                                    let gemAssetName = shape == .lightning 
                                        ? "gem_\(tier.rawValue)_lightning"
                                        : "gem_\(shape.rawValue)"
                                    let frameAssetName = "frame_\(tier.rawValue)_\(shape.rawValue)"
                                    
                                    // Try to load the gem and frame
                                    ZStack {
                                        Image(gemAssetName)
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(.cyan)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(frameAssetName)
                                            .resizable()
                                            .renderingMode(.template)
                                            .foregroundColor(tier.defaultColor.opacity(0.7))
                                            .frame(width: 60, height: 60)
                                    }
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    
                                    Text(shape.rawValue)
                                        .font(.caption2)
                                    
                                    // Check if both assets loaded
                                    HStack(spacing: 4) {
                                        if UIImage(named: gemAssetName) != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption2)
                                        } else {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.caption2)
                                        }
                                        
                                        if UIImage(named: frameAssetName) != nil {
                                            Image(systemName: "checkmark.square.fill")
                                                .foregroundColor(.green)
                                                .font(.caption2)
                                        } else {
                                            Image(systemName: "xmark.square.fill")
                                                .foregroundColor(.red)
                                                .font(.caption2)
                                        }
                                    }
                                    
                                    // Show asset names for Lightning (new system)
                                    if shape == .lightning {
                                        Text("G: \(gemAssetName)")
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
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("= Gem asset loaded")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundColor(.green)
                        Text("= Frame asset loaded")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("Lightning uses tier-specific gems (new system)")
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .padding(.top, 4)
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
            shape: .heart,
            gemColor: .pink,
            frameTier: .legacy,
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
            shape: .star,
            gemColor: .cyan,
            frameTier: .bloom,
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
            Text("Lightning Evolution System")
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("Each tier has its own unique Lightning gem")
                .font(.subheadline)
                .foregroundColor(.cyan)
            
            // Show all 4 tiers of Lightning
            HStack(spacing: 20) {
                ForEach(FrameTier.allCases) { tier in
                    VStack(spacing: 12) {
                        FavorGemView(
                            shape: .lightning,
                            gemColor: .cyan,
                            frameTier: tier,
                            size: 160,
                            showGlow: true,
                            showShimmer: false
                        )
                        
                        VStack(spacing: 4) {
                            Text(tier.displayName)
                                .font(.headline)
                                .foregroundColor(tier.defaultColor)
                            
                            Text("gem_\(tier.rawValue)_lightning")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .padding()
            
            Text("Assets Required:")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 4) {
                Group {
                    Text("• gem_seed_lightning.png")
                    Text("• gem_bloom_lightning.png")
                    Text("• gem_legacy_lightning.png")
                    Text("• gem_radiance_lightning.png")
                    Text("• frame_seed_lightning.png")
                    Text("• frame_bloom_lightning.png")
                    Text("• frame_legacy_lightning.png")
                    Text("• frame_radiance_lightning.png")
                }
                .font(.caption)
                .foregroundColor(.cyan.opacity(0.8))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .padding()
    }
}

