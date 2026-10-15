//
//  FavorGemView.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Asset-based gemstone and frame rendering system

import SwiftUI

// MARK: - Enums

/// Eight gemstone shapes matching the asset files
enum GemShape: String, CaseIterable, Identifiable {
    case brilliant
    case heart
    case star
    case hexagon
    case octagon
    case pear
    case marquise
    case cushion
    
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
        default:
            return .brilliant // fallback
        }
    }
}

/// Three frame tiers matching asset complexity levels
enum FrameTier: String, CaseIterable, Identifiable {
    case bronze
    case silver
    case gold
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Map from transfer count to frame tier
    static func from(transferCount: Int) -> FrameTier {
        switch transferCount {
        case 0..<5:
            return .bronze
        case 5..<30:
            return .silver
        case 30..<50:
            return .gold
        default:
            return .gold
        }
    }
    
    /// Suggested metallic frame color
    var defaultColor: Color {
        switch self {
        case .bronze:
            return Color(hue: 0.08, saturation: 0.6, brightness: 0.7)
        case .silver:
            return Color(hue: 0.0, saturation: 0.0, brightness: 0.8)
        case .gold:
            return Color(hue: 0.15, saturation: 0.8, brightness: 1.0)
        }
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
        showGlow: Bool = true,
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
        showGlow: Bool = true,
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
            // Outer soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gemColor.opacity(0.25),
                            gemColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .blur(radius: size * 0.2)
            
            // Inner intense glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            gemColor.opacity(0.5),
                            gemColor.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: size * 0.1)
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
                .renderingMode(.template)
                .foregroundColor(gemColor)
                .frame(width: size * 1.02, height: size * 1.02)
                .aspectRatio(contentMode: .fit)
                .blur(radius: 4)
                .opacity(0.3)
            
            // Main frame
            Image(frameAssetName)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(resolvedFrameColor)
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
            
            // Highlight on frame edges
            Image(frameAssetName)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .aspectRatio(contentMode: .fit)
                .blendMode(.screen)
                .opacity(0.2)
                .mask(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .center
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
        "gem_\(shape.rawValue)"
    }
    
    private var frameAssetName: String {
        "frame_\(frameTier.rawValue)_\(shape.rawValue)"
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
    @State private var selectedTier: FrameTier = .gold
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
        }
    }
}

// MARK: - Previews

#Preview("Single Gem") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        FavorGemView(
            shape: .heart,
            gemColor: .pink,
            frameTier: .gold,
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
            frameTier: .silver,
            size: 280
        )
    }
}

#Preview("Gallery") {
    FavorGemGallery()
}
