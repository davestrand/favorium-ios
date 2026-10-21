//
//  DecoStyle.swift
//  favorium
//
//  Art-deco sci-fi ornaments for the "Sovereign" look: a sapphire sunburst
//  behind a gold arch, and stepped gold dividers.
//

import SwiftUI

// MARK: - Sunburst backdrop

/// Full-screen background: midnight navy with a fan of sapphire-and-silver light
/// rays radiating from a gold-ringed point above the top edge. The rays fade out
/// toward the bottom so lower content always sits on calm, dark navy.
struct DecoBackdrop: View {
    /// Number of light rays across the fan.
    var rayCount: Int = 26

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // Burst origin sits just above the visible area, centered.
            let origin = CGPoint(x: size.width / 2, y: -size.height * 0.06)
            let radius = hypot(size.width, size.height) * 1.1
            let archRadius = size.width * 0.62

            ZStack {
                LinearGradient(
                    colors: [FavoriumTheme.backgroundTop, FavoriumTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Canvas { context, _ in
                    let rays = rayWedges(origin: origin, radius: radius)

                    // Soft sapphire bloom underneath the rays
                    context.drawLayer { glow in
                        glow.addFilter(.blur(radius: 10))
                        glow.fill(rays.wide, with: .color(FavoriumTheme.sapphire.opacity(0.55)))
                    }
                    // Crisp pale-silver light strips on top
                    context.fill(rays.thin, with: .color(FavoriumTheme.sapphireGlow.opacity(0.55)))
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white.opacity(0.6), location: 0.25),
                            .init(color: .clear, location: 0.62)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Gold arch framing the burst, like the throne-room ring
                Circle()
                    .strokeBorder(FavoriumTheme.goldGradient, lineWidth: 3)
                    .frame(width: archRadius * 2, height: archRadius * 2)
                    .position(origin)
                    .shadow(color: FavoriumTheme.accent.opacity(0.6), radius: 6)
                    .opacity(0.9)
                Circle()
                    .strokeBorder(FavoriumTheme.accentMuted.opacity(0.6), lineWidth: 1)
                    .frame(width: archRadius * 2 - 14, height: archRadius * 2 - 14)
                    .position(origin)

                // Warm gold glow at the heart of the burst
                RadialGradient(
                    colors: [FavoriumTheme.accent.opacity(0.4), .clear],
                    center: .init(x: 0.5, y: 0),
                    startRadius: 0,
                    endRadius: size.width * 0.45
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Builds two paths of wedges fanning downward from `origin`: wide wedges for
    /// the glow layer and narrow ones for the sharp highlight strips.
    private func rayWedges(origin: CGPoint, radius: CGFloat) -> (wide: Path, thin: Path) {
        var wide = Path()
        var thin = Path()
        // Fan spans the lower half-circle (0° = right, 180° = left, y grows down).
        let start = Angle.degrees(8).radians
        let end = Angle.degrees(172).radians
        let step = (end - start) / Double(max(rayCount - 1, 1))

        for i in 0..<rayCount {
            let center = start + step * Double(i)
            wide.addPath(wedge(origin: origin, radius: radius, center: center, halfWidth: step * 0.28))
            thin.addPath(wedge(origin: origin, radius: radius, center: center, halfWidth: step * 0.06))
        }
        return (wide, thin)
    }

    private func wedge(origin: CGPoint, radius: CGFloat, center: Double, halfWidth: Double) -> Path {
        Path { p in
            p.move(to: origin)
            p.addLine(to: point(origin, radius, center - halfWidth))
            p.addLine(to: point(origin, radius, center + halfWidth))
            p.closeSubpath()
        }
    }

    private func point(_ origin: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: origin.x + radius * cos(angle), y: origin.y + radius * sin(angle))
    }
}

// MARK: - Stepped gold divider

/// Art-deco rule: a center diamond flanked by stepped gold lines that fade out.
struct DecoDivider: View {
    var width: CGFloat = 180

    var body: some View {
        HStack(spacing: 6) {
            side(leading: true)
            Rectangle()
                .fill(FavoriumTheme.goldGradient)
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
            side(leading: false)
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }

    /// Two stacked lines — a long one and a shorter one — fading toward the outer edge.
    private func side(leading: Bool) -> some View {
        let fade = LinearGradient(
            colors: [FavoriumTheme.accentMuted.opacity(0), FavoriumTheme.accent],
            startPoint: leading ? .leading : .trailing,
            endPoint: leading ? .trailing : .leading
        )
        return VStack(alignment: leading ? .trailing : .leading, spacing: 3) {
            Rectangle().fill(fade).frame(height: 1)
            Rectangle().fill(fade).frame(height: 1)
                .padding(leading ? .leading : .trailing, 24)
        }
    }
}

/// Fades content in the first time it appears, such as a tab's first visit.
/// State lives with the view, so returning to an already-visited tab doesn't replay it.
private struct FadeInOnFirstAppear: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            // Scoped so only the opacity animates, never the content's layout
            .animation(.easeInOut(duration: 0.9)) { $0.opacity(visible ? 1 : 0) }
            .task {
                // Let the transparent first frame render; flipping `visible` in
                // onAppear lands in that same frame and skips the fade entirely.
                try? await Task.sleep(for: .milliseconds(60))
                visible = true
            }
    }
}

extension View {
    /// Fades this view in on its first appearance.
    func fadeInOnFirstAppear() -> some View {
        modifier(FadeInOnFirstAppear())
    }

    /// Wide-tracked uppercase treatment for deco headings.
    func decoTitle() -> some View {
        self
            .textCase(.uppercase)
            .tracking(6)
    }
}

#Preview {
    ZStack {
        DecoBackdrop()
        VStack(spacing: 10) {
            Text("Favorium")
                .font(FavoriumTheme.titleFont)
                .foregroundStyle(FavoriumTheme.ivory)
                .decoTitle()
            DecoDivider()
            Text("Kindness in motion.")
                .font(FavoriumTheme.captionFont)
                .foregroundStyle(FavoriumTheme.silver)
        }
    }
}

