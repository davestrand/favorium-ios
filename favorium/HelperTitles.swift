//
//  HelperTitles.swift
//  favorium
//
//  Helper titles: earned by helping *different* people (each one who confirmed a
//  favor you did for them counts once). No title until 3 people; titles never go down.
//  The level is computed server-side (`profiles.helper_level`, thresholds and copy
//  in the `helper_titles` table); this file mirrors the names and meanings and
//  draws the avatar frames that show a title publicly.
//
//  Frames are drawn around the avatar, never over the face, so people can line
//  their photo up with them. Below `compactSize` each frame shrinks to a
//  simplified mark that still reads at list-row sizes.
//

import SwiftUI

// MARK: - Title model

enum HelperTitle: Int, CaseIterable, Identifiable, Sendable {
    case samaritan = 1, saint, angel, seraph, bodhisattva

    var id: Int { rawValue }

    /// Different people you must have helped to hold this title.
    var minPeopleHelped: Int {
        switch self {
        case .samaritan:   3
        case .saint:       6
        case .angel:       10
        case .seraph:      15
        case .bodhisattva: 25
        }
    }

    var displayName: String {
        switch self {
        case .samaritan:   "Samaritan"
        case .saint:       "Saint"
        case .angel:       "Angel"
        case .seraph:      "Seraph"
        case .bodhisattva: "Bodhisattva"
        }
    }

    /// One line shown on the Profile and in the moment the title is earned.
    var meaning: String {
        switch self {
        case .samaritan:   "One who stops to help a stranger on the road."
        case .saint:       "A life made holy by the good it does."
        case .angel:       "A messenger of kindness who arrives when most needed."
        case .seraph:      "The highest of the angels, burning with love."
        case .bodhisattva: "One who reached enlightenment and chose to stay and help others."
        }
    }

    /// The highest title earned, or nil below the first threshold.
    static func from(peopleHelped: Int) -> HelperTitle? {
        allCases.last { peopleHelped >= $0.minPeopleHelped }
    }
}

// MARK: - Frame

/// Draws a title's frame behind and around any circular portrait of `size`.
struct HelperTitleFrame<Portrait: View>: View {
    let title: HelperTitle?
    let size: CGFloat
    @ViewBuilder let portrait: () -> Portrait

    /// Below this, wings, lotus and nimbus detail would turn to noise or spill out of list rows.
    static var compactSize: CGFloat { 60 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    private var compact: Bool { size < Self.compactSize }
    private var s: CGFloat { size }

    var body: some View {
        portrait()
            .frame(width: s, height: s)
            // Initials avatars are translucent; keep wings and auras from showing through the face
            .background { if title != nil { Circle().fill(FavoriumTheme.background) } }
            .background { if let title { behind(title) } }
            .overlay { if let title { inFront(title) } }
            .onAppear {
                guard !reduceMotion, !compact, title == .bodhisattva || title == .seraph else { return }
                withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) { turning = true }
            }
    }

    // MARK: Layers

    @ViewBuilder
    private func behind(_ title: HelperTitle) -> some View {
        switch title {
        case .samaritan:
            EmptyView()
        case .saint:
            Nimbus(detailed: !compact)
                .frame(width: s * (compact ? 1.3 : 1.5), height: s * (compact ? 1.3 : 1.5))
                .offset(y: -s * (compact ? 0.08 : 0.12))
        case .angel:
            if !compact { wingPair(spreads: [12], length: 0.66) }
        case .seraph:
            if !compact { wingPair(spreads: [42, 14, -16], length: 0.6) }
        case .bodhisattva:
            FlameAura(tips: compact ? 12 : 18)
                .fill(RadialGradient(colors: [Self.paleGold, Self.flameGold, Self.flameAmber, Self.flameRose],
                                     center: .center, startRadius: s * 0.45, endRadius: s * 0.8))
                .overlay(FlameAura(tips: compact ? 12 : 18).stroke(Self.flameGold, lineWidth: max(0.5, s * 0.01)))
                .rotationEffect(.degrees(turning ? 360 : 0))
                .frame(width: s * (compact ? 1.4 : 1.6), height: s * (compact ? 1.4 : 1.6))
                .offset(y: -s * 0.04)
                .shadow(color: Self.flameAmber.opacity(0.5), radius: s * 0.06)
        }
    }

    @ViewBuilder
    private func inFront(_ title: HelperTitle) -> some View {
        switch title {
        case .samaritan:
            Circle()
                .strokeBorder(Self.goldRing, lineWidth: max(1.5, s * 0.05))
                .frame(width: s * 1.12, height: s * 1.12)
                .shadow(color: Self.warmGold.opacity(0.45), radius: s * 0.05)
        case .saint:
            Circle()
                .strokeBorder(Self.goldRing, lineWidth: max(1, s * 0.025))
                .frame(width: s * 1.04, height: s * 1.04)
        case .angel:
            halo(colors: [Self.paleGold, Self.warmGold, Self.paleGold], glow: Self.paleGold)
        case .seraph:
            halo(colors: [Self.flameGold, Self.flameRose, Self.flameAmber, Self.flameGold], glow: Self.flameAmber)
                .scaleEffect(turning ? 1.06 : 1)
        case .bodhisattva:
            if !compact {
                Lotus()
                    .frame(width: s * 0.75, height: s * 0.3)
                    .offset(y: s * 0.52)
            }
        }
    }

    private func halo(colors: [Color], glow: Color) -> some View {
        Ellipse()
            .strokeBorder(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                          lineWidth: max(1.5, s * 0.045))
            .frame(width: s * 0.62, height: s * 0.17)
            .shadow(color: glow.opacity(0.9), radius: s * 0.04)
            .offset(y: -s * (compact ? 0.6 : 0.64))
    }

    /// Mirrored wings rooted behind the shoulders. Each spread angle adds one wing per side.
    private func wingPair(spreads: [Double], length: CGFloat) -> some View {
        let wingSize = s * length
        return ZStack {
            ForEach(spreads, id: \.self) { spread in
                wing(size: wingSize, spread: spread)
                    .offset(x: -s * 0.18 - wingSize / 2, y: s * 0.12 - wingSize * 0.35)
                wing(size: wingSize, spread: spread)
                    .scaleEffect(x: -1)
                    .offset(x: s * 0.18 + wingSize / 2, y: s * 0.12 - wingSize * 0.35)
            }
        }
    }

    private func wing(size: CGFloat, spread: Double) -> some View {
        FeatherWing()
            .fill(LinearGradient(colors: [Self.paleGold, Self.warmGold, Color(red: 0.80, green: 0.56, blue: 0.18)],
                                 startPoint: .topTrailing, endPoint: .bottomLeading))
            .overlay(FeatherWing().stroke(Color(red: 0.62, green: 0.42, blue: 0.10).opacity(0.7),
                                          lineWidth: max(0.5, s * 0.008)))
            .frame(width: size, height: size)
            // Rotate around the root (bottom-trailing) so wings fan up or down from the shoulder
            .rotationEffect(.degrees(spread), anchor: UnitPoint(x: 1, y: 0.85))
            .shadow(color: Self.paleGold.opacity(0.5), radius: s * 0.03)
    }

    // MARK: Palette (fixed, so frames look the same in light and dark mode)

    static var paleGold: Color { Color(red: 1.0, green: 0.93, blue: 0.70) }
    static var warmGold: Color { Color(red: 0.93, green: 0.72, blue: 0.29) }
    static var flameGold: Color { Color(red: 1.0, green: 0.80, blue: 0.30) }
    static var flameAmber: Color { Color(red: 0.98, green: 0.52, blue: 0.16) }
    static var flameRose: Color { Color(red: 0.90, green: 0.30, blue: 0.30) }
    static var goldRing: LinearGradient {
        LinearGradient(colors: [paleGold, warmGold, Color(red: 0.62, green: 0.44, blue: 0.12), warmGold],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Earned moment

/// Shown once per level on each device when the server reports a new title.
struct TitleEarnedView: View {
    let title: HelperTitle
    let userId: UUID?
    let name: String
    let photo: String?
    let peopleHelped: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    /// "a Saint" / "an Angel", matching the server's push copy
    private var withArticle: String {
        let vowels: Set<Character> = ["A", "E", "I", "O", "U"]
        return (title.displayName.first.map(vowels.contains) == true ? "an " : "a ") + title.displayName
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            PersonAvatar(userId: userId, name: name, photo: photo, level: title.rawValue, size: 140)
                .scaleEffect(revealed ? 1 : 0.6)
                .opacity(revealed ? 1 : 0)
                .padding(.bottom, 20)
            VStack(spacing: 10) {
                Text("You've become \(withArticle)")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                    .multilineTextAlignment(.center)
                Text(title.meaning)
                    .font(FavoriumTheme.bodyFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(peopleHelped) different people have confirmed your help.")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.accent)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 36)
            Spacer()
            Button { dismiss() } label: {
                Text("Wear it proudly")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FavoriumTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.65).delay(0.15)) {
                revealed = true
            }
        }
    }
}

// MARK: - Shapes

/// A stylised wing rooted at the bottom-trailing corner (the shoulder). Its arm
/// sweeps up and out toward the top-leading corner, and feathers hang from it,
/// growing longer toward the wingtip like a real wing's primaries.
private struct FeatherWing: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let root = CGPoint(x: rect.maxX, y: rect.minY + h * 0.78)
        let bend = CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.02)
        let tip = CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.12)
        func arm(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * root.x + 2 * u * t * bend.x + t * t * tip.x,
                           y: u * u * root.y + 2 * u * t * bend.y + t * t * tip.y)
        }
        let reach = min(w, h)
        var path = Path()
        // The arm itself: a tapering band of covert feathers
        path.move(to: root)
        path.addQuadCurve(to: tip, control: bend)
        path.addQuadCurve(to: root, control: CGPoint(x: bend.x + w * 0.02, y: bend.y + h * 0.22))
        // Feathers hang from the arm, turning outward toward the tip
        let count = 12
        for i in 0..<count {
            let t = 0.08 + 0.92 * CGFloat(i) / CGFloat(count - 1)
            let base = arm(t)
            let degrees = 262 - 62 * Double(t)            // nearly straight down → out to the side
            let a = degrees * .pi / 180
            let dir = CGPoint(x: cos(a), y: -sin(a))
            let perp = CGPoint(x: -dir.y, y: dir.x)
            let length = reach * (0.24 + 0.40 * t)
            let width = length * 0.3
            let end = CGPoint(x: base.x + dir.x * length, y: base.y + dir.y * length)
            let mid = CGPoint(x: base.x + dir.x * length * 0.5, y: base.y + dir.y * length * 0.5)
            path.move(to: base)
            path.addQuadCurve(to: end, control: CGPoint(x: mid.x + perp.x * width, y: mid.y + perp.y * width))
            path.addQuadCurve(to: base, control: CGPoint(x: mid.x - perp.x * width, y: mid.y - perp.y * width))
        }
        return path
    }
}

/// A disc ringed with flame tongues, like the aureole behind a Buddha figure.
/// Tongues alternate tall and short and lean one way so the ring reads as fire.
private struct FlameAura: Shape {
    var tips: Int

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let base = outer * 0.74
        let step = 2 * Double.pi / Double(tips)
        func point(_ angle: Double, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
        }
        var path = Path()
        path.move(to: point(-Double.pi / 2, base))
        for k in 0..<tips {
            let a = -Double.pi / 2 + Double(k) * step
            let height = k.isMultiple(of: 2) ? outer : outer * 0.86
            // Concave sides give each tongue a sharp, licking point
            path.addQuadCurve(to: point(a + step * 0.75, height), control: point(a + step * 0.55, base * 1.04))
            path.addQuadCurve(to: point(a + step, base), control: point(a + step * 0.8, base * 1.08))
        }
        path.closeSubpath()
        return path
    }
}

/// Lotus petals opening upward beneath the portrait.
private struct Lotus: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                ForEach([-56.0, -28, 0, 28, 56], id: \.self) { angle in
                    Ellipse()
                        .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.82, blue: 0.86),
                                                      Color(red: 0.93, green: 0.55, blue: 0.62),
                                                      HelperTitleFrame<EmptyView>.warmGold],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(Ellipse().stroke(HelperTitleFrame<EmptyView>.warmGold.opacity(0.8), lineWidth: 0.75))
                        .frame(width: w * 0.24, height: h * 0.95)
                        .rotationEffect(.degrees(angle), anchor: .bottom)
                        .offset(y: -h * 0.05)
                }
            }
            .frame(width: w, height: h)
        }
    }
}

/// The gold disc behind a saint's head in icon painting, with tooled rays and a beaded rim.
private struct Nimbus: View {
    var detailed: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let r = min(size.width, size.height) / 2
            context.fill(Path(ellipseIn: rect),
                         with: .radialGradient(Gradient(colors: [HelperTitleFrame<EmptyView>.paleGold,
                                                                 HelperTitleFrame<EmptyView>.warmGold,
                                                                 Color(red: 0.70, green: 0.50, blue: 0.14)]),
                                               center: c, startRadius: r * 0.3, endRadius: r))
            guard detailed else { return }
            let ink = GraphicsContext.Shading.color(Color(red: 0.55, green: 0.38, blue: 0.08).opacity(0.55))
            // Tooled rays between the face and the rim
            for k in 0..<36 {
                let a = Double(k) / 36 * 2 * .pi
                var ray = Path()
                ray.move(to: CGPoint(x: c.x + cos(a) * r * 0.66, y: c.y + sin(a) * r * 0.66))
                ray.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.84, y: c.y + sin(a) * r * 0.84))
                context.stroke(ray, with: ink, lineWidth: max(0.5, r * 0.012))
            }
            // Beaded rim
            for k in 0..<48 {
                let a = Double(k) / 48 * 2 * .pi
                let p = CGPoint(x: c.x + cos(a) * r * 0.92, y: c.y + sin(a) * r * 0.92)
                let d = r * 0.035
                context.fill(Path(ellipseIn: CGRect(x: p.x - d, y: p.y - d, width: d * 2, height: d * 2)), with: ink)
            }
        }
    }
}

// MARK: - Previews

/// A stand-in photo: head and shoulders, centred the way a cropped selfie usually is.
private struct SamplePortrait: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.35, green: 0.45, blue: 0.62), Color(red: 0.16, green: 0.20, blue: 0.32)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                let w = geo.size.width
                Circle().fill(Color(red: 0.86, green: 0.70, blue: 0.58))
                    .frame(width: w * 0.42).position(x: w / 2, y: w * 0.40)
                Ellipse().fill(Color(red: 0.25, green: 0.30, blue: 0.45))
                    .frame(width: w * 0.9, height: w * 0.6).position(x: w / 2, y: w * 1.0)
            }
        }
        .clipShape(Circle())
    }
}

#Preview("Helper title frames") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 64) {
        ForEach(HelperTitle.allCases) { title in
            VStack(spacing: 30) {
                HelperTitleFrame(title: title, size: 96) { SamplePortrait() }
                Text("\(title.displayName) · \(title.minPeopleHelped)")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
            }
        }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FavoriumTheme.background)
}

#Preview("Title earned") {
    TitleEarnedView(title: .angel, userId: UUID(), name: "Sam", photo: nil, peopleHelped: 10)
}

#Preview("Small sizes") {
    let titles: [HelperTitle?] = [nil] + HelperTitle.allCases
    VStack(spacing: 40) {
        HStack(spacing: 22) {
            ForEach(titles, id: \.self) { title in
                PersonAvatar(userId: UUID(), name: "Sam", level: title?.rawValue, size: 24)
            }
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 40) {
            ForEach(titles, id: \.self) { title in
                PersonAvatar(userId: UUID(), name: "Sam", level: title?.rawValue, size: 44)
            }
        }
    }
    .padding(40)
    .background(FavoriumTheme.background)
}
