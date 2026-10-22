//
//  GemInteriorView.swift
//  favorium
//
//  "Entering" a gem: long-press a gem and it swells until you are inside it,
//  looking through a living kaleidoscope. The scene being mirrored is built
//  from the gem itself — its own gem and frame art, its DNA colours and their
//  complements — and the number of mirrors comes from the family's geometry.
//  Every gem's interior is therefore unique and always the same for that gem.
//
//  Touch: drag to turn the kaleidoscope, pinch to look closer, tap to scatter
//  light (mirrored into every wedge). Tilt: rolling the phone left or right
//  sets the spin's speed and direction; tipping it toward or away from you
//  speeds up or reverses the drift of the shapes inside.
//

import SwiftUI
import UIKit
import CoreMotion

// MARK: - What a gem's interior is made of

struct GemInterior {
    let name: String
    let family: GemFamily
    let tier: Tier
    let gemHue: Double          // 0–360
    let saturation: Double
    let frameHue: Double        // 0–360
    let seed: String
    /// Only shown from Bloom onward, the same rule as the gem itself
    let trait: GemTrait?

    init(name: String, dna: SupabaseService.GemDNA?, transferCount: Int) {
        let tier = Tier.from(transferCount: transferCount)
        self.name = name
        self.family = GemFamily.from(dna?.resolvedFamily)
        self.tier = tier
        self.gemHue = dna?.resolvedHue ?? 45
        self.saturation = min(max(dna?.resolvedSaturation ?? 0.7, 0.35), 1)
        // No frame hue on the DNA → let the frame echo the gem's complement
        self.frameHue = dna?.identity?.frameHue ?? (self.gemHue + 180).truncatingRemainder(dividingBy: 360)
        self.seed = dna?.seed.isEmpty == false ? dna!.seed : name
        self.trait = tier == .seed ? nil : GemTrait.from(dna?.trait)
    }

    /// Mirror count echoes each family's cut.
    var segments: Int {
        switch family {
        case .lightning: 6    // hexagonal, sharp facets
        case .celestial: 8    // an eight-pointed star
        case .victorian: 12   // a rose window of filigree
        case .gothic:    10   // the tracery of a pointed arch
        }
    }

    var gemAsset: String { family.assetName(tier: tier) }
    var frameAsset: String { FrameFamily.matching(family).assetName(tier: tier) }

    // The palette: the gem and frame colours plus their complements
    var gemColor: Color { Self.color(gemHue, saturation, 0.95) }
    var gemComplement: Color { Self.color(gemHue + 180, saturation * 0.85, 0.9) }
    var frameColor: Color { Self.color(frameHue, 0.7, 0.9) }
    var frameComplement: Color { Self.color(frameHue + 180, 0.6, 0.85) }
    var depth: Color { Self.color(gemHue, min(1, saturation + 0.2), 0.22) }
    var palette: [Color] { [gemColor, gemComplement, frameColor, frameComplement] }

    private static func color(_ hue: Double, _ sat: Double, _ bri: Double) -> Color {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return Color(hue: h / 360, saturation: sat, brightness: bri)
    }
}

// MARK: - The interior

struct GemInteriorView: View {
    let interior: GemInterior
    /// The gem as shown on the screen you came from, so the dive starts from it
    let gemDNA: SupabaseService.GemDNA?
    let transferCount: Int
    /// Where the gem sat on the screen you came from (global coordinates), so the dive starts from it
    var startFrame: CGRect = .zero

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lifted = false     // the gem has risen to the centre
    @State private var entered = false    // you've passed through its face
    @State private var flash = 0.0
    /// The diving gem as a flat picture: scaling a bitmap is cheap, whereas the live gem
    /// would re-render its glow and shadow at 9× size right as the shader starts.
    @State private var divingGem: Image?
    @State private var scene: InteriorScene?
    // Touch state
    @State private var twist: Double = 0            // radians, accumulated from drags
    @State private var dragStartAngle: Double?
    @State private var focusOffset: CGSize = .zero  // drift of the mirrored point, in points
    @State private var zoom: Double = 0.55
    @State private var pinchStartZoom: Double?
    @State private var bursts: [LightBurst] = []
    @State private var showHint = true
    @State private var motion = InteriorMotion()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Darkens over the screen you came from as you pass into the stone
                Color.black.opacity(entered ? 1 : (lifted ? 0.65 : 0))

                kaleidoscope(size: size)
                    .scaleEffect(entered ? 1 : 0.2)
                    .opacity(entered ? 1 : 0)

                // The same gem lifts from where it sat, then swells past the screen as you pass through it
                let start = startFrame.isEmpty
                    ? CGRect(x: size.width / 2 - 110, y: size.height / 2 - 110, width: 220, height: 220)
                    : startFrame
                Group {
                    if let divingGem {
                        divingGem.resizable()
                    } else {
                        FavorGemView(dna: gemDNA, transferCount: transferCount, size: 220)
                    }
                }
                    .frame(width: 220, height: 220)
                    .scaleEffect(entered ? 9 : (lifted ? 1.25 : start.width / 220))
                    .position(lifted ? CGPoint(x: size.width / 2, y: size.height / 2)
                                     : CGPoint(x: start.midX, y: start.midY))
                    .opacity(entered ? 0 : 1)
                    .allowsHitTesting(false)

                // A burst of the gem's own light at the moment you pass through
                RadialGradient(colors: [.white, interior.gemColor.opacity(0.85), interior.gemColor.opacity(0)],
                               center: .center, startRadius: 0,
                               endRadius: max(size.width, size.height) * 0.7)
                    .opacity(flash)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)

                // Vignette — the curved walls of the stone closing in at the edges
                RadialGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.8)],
                               center: .center,
                               startRadius: min(size.width, size.height) * 0.28,
                               endRadius: max(size.width, size.height) * 0.62)
                    .allowsHitTesting(false)

                chrome
            }
            .contentShape(Rectangle())
            .gesture(twistGesture(size: size).simultaneously(with: pinchGesture))
            .onTapGesture(coordinateSpace: .local) { location in
                scatterLight(at: location, size: size)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .sensoryFeedback(.impact(weight: .light), trigger: bursts.count)
        // Runs for as long as you're inside; cancelled (and the sensors stopped) on leaving
        .task { await motion.run(animated: !reduceMotion) }
        // Tilt steers the kaleidoscope, so the screen itself must not rotate
        .onAppear { OrientationLock.set(.portrait) }
        .onDisappear { OrientationLock.set(.all) }
        .task {
            if scene == nil { scene = InteriorScene(interior: interior) }
            await diveIn()
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.8)) { showHint = false }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inside \(interior.name)")
        .accessibilityAction(named: "Leave the gem") { leave() }
    }

    // MARK: Kaleidoscope

    private func kaleidoscope(size: CGSize) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            // Scene time and spin are integrated by InteriorMotion, so tilt can speed them up or reverse them
            let t = motion.sceneTime
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let focus = CGPoint(x: center.x + focusOffset.width, y: center.y + focusOffset.height)
            Canvas { context, canvasSize in
                scene?.draw(in: &context, size: canvasSize, time: t, bursts: bursts, now: timeline.date)
            }
            .layerEffect(
                ShaderLibrary.gemKaleidoscope(
                    .float2(size),
                    .float(Float(interior.segments)),
                    .float(Float(tubeAngle)),
                    .float(Float(zoom)),
                    .float2(focus),
                    .float(1)
                ),
                maxSampleOffset: size,
                // Never run the shader before the view has a real size
                isEnabled: size.width > 1 && size.height > 1
            )
        }
    }

    // MARK: Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button(action: leave) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Leave the gem")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            Spacer()

            VStack(spacing: 6) {
                Text(interior.name)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                if showHint {
                    Text("Drag to turn · Pinch to look closer · Tap to scatter light")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(0.6), radius: 6)
            .opacity(entered ? 1 : 0)
            .padding(.bottom, 50)
        }
    }

    // MARK: Gestures

    /// Turning the tube: the angle of your finger around the centre twists the mirrors,
    /// while the drag also drifts the point they reflect, so new shapes slide into view.
    private func twistGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                if let start = dragStartAngle {
                    var delta = angle - start
                    if delta > .pi { delta -= 2 * .pi }
                    if delta < -.pi { delta += 2 * .pi }
                    twist -= delta
                }
                dragStartAngle = angle
                focusOffset.width = clamp(focusOffset.width - value.velocity.width * 0.002, size.width * 0.4)
                focusOffset.height = clamp(focusOffset.height - value.velocity.height * 0.002, size.height * 0.4)
            }
            .onEnded { _ in dragStartAngle = nil }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStartZoom ?? zoom
                pinchStartZoom = start
                // Spreading your fingers looks closer, so the wedge spans less of the scene
                zoom = min(1.4, max(0.18, start / value.magnification))
            }
            .onEnded { _ in pinchStartZoom = nil }
    }

    private func clamp(_ value: CGFloat, _ limit: CGFloat) -> CGFloat {
        min(limit, max(-limit, value))
    }

    /// A tap lights up the matching spot in the source, so it blooms in every wedge at once.
    private func scatterLight(at location: CGPoint, size: CGSize) {
        guard entered else { return }
        let source = KaleidoscopeMath.sourcePoint(
            for: location, size: size, segments: Double(interior.segments),
            rotation: tubeAngle, zoom: zoom,
            focus: CGPoint(x: size.width / 2 + focusOffset.width, y: size.height / 2 + focusOffset.height))
        bursts.append(LightBurst(point: source, start: .now, hue: [interior.gemHue, interior.frameHue].randomElement() ?? 0))
        bursts.removeAll { Date.now.timeIntervalSince($0.start) > LightBurst.lifetime }
    }

    /// Your twist plus the tilt-driven spin, wrapped to one turn: the GPU works in
    /// 32-bit floats, which can't fold angles of millions of radians.
    private var tubeAngle: Double {
        (twist + motion.spinAngle).truncatingRemainder(dividingBy: 2 * .pi)
    }

    /// Lift → pass through (buzz + flash) → inside.
    private func diveIn() async {
        let renderer = ImageRenderer(content: FavorGemView(dna: gemDNA, transferCount: transferCount, size: 220))
        renderer.scale = 3
        if let picture = renderer.uiImage { divingGem = Image(uiImage: picture) }
        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.3)) { lifted = true; entered = true }
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { lifted = true }
        try? await Task.sleep(for: .seconds(0.4))
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1)
        withAnimation(.easeIn(duration: 0.35)) { entered = true }
        withAnimation(.easeIn(duration: 0.22)) { flash = 1 }
        try? await Task.sleep(for: .seconds(0.28))
        withAnimation(.easeOut(duration: 0.8)) { flash = 0 }
    }

    private func leave() {
        // The gem shrinks back to where it came from before the cover goes away
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { entered = false; lifted = false }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { dismiss() }
        }
    }
}

// MARK: - Orientation lock

enum OrientationLock {
    @MainActor
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            // Tell every controller in the chain, including the full-screen cover itself
            var controller = scene.keyWindow?.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        }
    }
}

// MARK: - Tilt

/// Integrates the interior's motion each frame. Without tilt the tube turns slowly
/// and the shapes drift forward; tilt changes both speeds, and can reverse them.
/// The attitude when you entered counts as level, so it works lying down too.
@MainActor
@Observable
final class InteriorMotion {
    private(set) var spinAngle: Double = 0      // radians, wrapped
    private(set) var sceneTime: Double = 0      // seconds of scene drift, may run backwards

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var reference: CMAttitude?
    @ObservationIgnored private var roll: Double = 0     // smoothed, radians
    @ObservationIgnored private var pitch: Double = 0

    static let baseSpin = 0.05          // radians per second at rest
    static let tiltSpin = 2.6           // extra radians per second per radian of roll
    static let tiltFlow = 6.0           // extra scene speed per radian of pitch

    func run(animated: Bool) async {
        // Reduce Motion: no automatic movement, tilt included
        guard animated else { return }
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1.0 / 60
            manager.startDeviceMotionUpdates()
        }
        defer { manager.stopDeviceMotionUpdates() }

        var last = Date.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date.now
            let dt = min(now.timeIntervalSince(last), 0.1)
            last = now
            readTilt()
            spinAngle = (spinAngle + (Self.baseSpin + roll * Self.tiltSpin) * dt)
                .truncatingRemainder(dividingBy: 2 * .pi)
            sceneTime += (1 + pitch * Self.tiltFlow) * dt
        }
    }

    private func readTilt() {
        guard let attitude = manager.deviceMotion?.attitude.copy() as? CMAttitude else { return }
        guard let reference else { self.reference = attitude; return }
        attitude.multiply(byInverseOf: reference)
        // A small dead zone keeps a steady hand from drifting; then ease toward the new tilt
        func shaped(_ v: Double) -> Double {
            let clamped = max(-0.8, min(0.8, v))
            return abs(clamped) < 0.03 ? 0 : clamped
        }
        roll += (shaped(attitude.roll) - roll) * 0.35
        pitch += (shaped(attitude.pitch) - pitch) * 0.35
    }
}

// MARK: - Source scene

/// A tap of light, drawn in source space so the kaleidoscope multiplies it.
struct LightBurst: Identifiable {
    static let lifetime: TimeInterval = 1.4
    let id = UUID()
    let point: CGPoint
    let start: Date
    let hue: Double
}

/// The living picture the mirrors reflect. Generated once from the gem's seed,
/// so a gem's interior never changes, then animated over time.
@MainActor
final class InteriorScene {
    private struct Shard {
        var x, y: Double          // home position, 0–1
        var size: Double          // fraction of the short side
        var spin: Double          // radians per second
        var orbit: Double         // drift radius, fraction of the short side
        var phase: Double
        var colorIndex: Int
        var kind: Kind
    }
    private enum Kind { case gem, frame, facet }

    private let interior: GemInterior
    private let shards: [Shard]
    private let sparkles: [(x: Double, y: Double, phase: Double)]

    init(interior: GemInterior) {
        self.interior = interior
        var rng = CrystalRng(seed: interior.seed, salt: "interior")
        // Higher tiers have richer interiors
        let extra = [Tier.seed: 0, .bloom: 4, .legacy: 8, .radiance: 12][interior.tier] ?? 0
        var shards: [Shard] = []
        // The mirrors mostly reflect the middle of the scene, so crowd it there
        func add(_ kind: Kind, count: Int, size: ClosedRange<Double>, spread: Double) {
            for _ in 0..<count {
                shards.append(Shard(
                    x: 0.5 + rng.range(-spread, spread), y: 0.5 + rng.range(-spread, spread) * 0.6,
                    size: rng.range(size.lowerBound, size.upperBound),
                    spin: rng.range(-0.25, 0.25), orbit: rng.range(0.02, 0.12),
                    phase: rng.range(0, 2 * .pi), colorIndex: rng.int(4), kind: kind))
            }
        }
        add(.facet, count: 22 + extra, size: 0.14...0.4, spread: 0.42)
        add(.frame, count: 4, size: 0.5...0.85, spread: 0.3)
        add(.gem, count: 8 + extra / 4, size: 0.2...0.45, spread: 0.32)
        self.shards = shards
        let sparkleCount = interior.trait == .starlight ? 60 : 18
        self.sparkles = (0..<sparkleCount).map { _ in (rng.next(), rng.next(), rng.range(0, 2 * .pi)) }
    }

    func draw(in context: inout GraphicsContext, size: CGSize, time t: Double, bursts: [LightBurst], now: Date) {
        let rect = CGRect(origin: .zero, size: size)
        let short = min(size.width, size.height)
        let palette = interior.palette

        // Rainbow gems slowly cycle the whole interior through the spectrum
        if interior.trait == .rainbow {
            context.addFilter(.hueRotation(.degrees(t * 20)))
        }

        // Backdrop: the gem's depths, lit by its complement at the heart and washed with the frame's colours
        let heart = CGPoint(x: rect.midX + cos(t * 0.11) * short * 0.08, y: rect.midY + sin(t * 0.09) * short * 0.08)
        context.fill(Path(rect), with: .color(interior.depth))
        context.fill(Path(rect), with: .radialGradient(
            Gradient(colors: [palette[1].opacity(0.9), palette[0].opacity(0.45), .clear]),
            center: heart, startRadius: 0, endRadius: short * 0.6))
        context.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [palette[2].opacity(0.35), .clear, palette[3].opacity(0.35)]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))

        if interior.trait == .ember {
            context.fill(Path(ellipseIn: rect.insetBy(dx: -short * 0.2, dy: -short * 0.2)),
                         with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.45, blue: 0.1).opacity(0.5), .clear]),
                                               center: CGPoint(x: rect.midX, y: rect.midY),
                                               startRadius: 0, endRadius: short * (0.6 + 0.08 * sin(t * 1.3))))
        }

        let gem = context.resolve(Image(interior.gemAsset))
        let frame = context.resolve(Image(interior.frameAsset))

        for shard in shards {
            let center = CGPoint(
                x: shard.x * size.width + cos(t * 0.3 + shard.phase) * shard.orbit * short,
                y: shard.y * size.height + sin(t * 0.23 + shard.phase) * shard.orbit * short)
            let side = shard.size * short
            var layer = context
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: .radians(shard.phase + t * shard.spin))
            let box = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
            switch shard.kind {
            case .gem:
                layer.addFilter(.colorMultiply(interior.gemColor))
                layer.draw(gem, in: box)
            case .frame:
                layer.opacity = 0.85
                layer.addFilter(.colorMultiply(interior.frameColor))
                layer.draw(frame, in: box)
            case .facet:
                // Jewel tones only (the gem and its complement), translucent so the art shows through
                layer.opacity = 0.5
                layer.blendMode = .screen
                let tone = shard.colorIndex.isMultiple(of: 2) ? interior.gemColor : interior.gemComplement
                layer.fill(facetPath(in: box), with: .linearGradient(
                    Gradient(colors: [tone, tone.opacity(0.1)]),
                    startPoint: box.origin, endPoint: CGPoint(x: box.maxX, y: box.maxY)))
            }
        }

        // Pinpoints of light that twinkle in and out
        for sparkle in sparkles {
            let glow = max(0, sin(t * 1.7 + sparkle.phase))
            guard glow > 0.05 else { continue }
            let r = short * 0.006 * (0.5 + glow)
            let p = CGPoint(x: sparkle.x * size.width, y: sparkle.y * size.height)
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(glow * 0.9)))
        }

        // Charged gems crackle with an occasional arc
        if interior.trait == .charged, sin(t * 2.1) > 0.92 {
            var arc = Path()
            var rng = CrystalRng(seed: interior.seed, salt: "arc-\(Int(t * 2))")
            arc.move(to: CGPoint(x: rng.next() * size.width, y: rng.next() * size.height))
            for _ in 0..<6 { arc.addLine(to: CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)) }
            context.stroke(arc, with: .color(Color(red: 0.75, green: 0.9, blue: 1)), lineWidth: 2)
        }

        // Taps of light, expanding and fading
        for burst in bursts {
            let age = now.timeIntervalSince(burst.start) / LightBurst.lifetime
            guard age < 1 else { continue }
            let radius = short * (0.03 + 0.25 * age)
            let color = Color(hue: burst.hue / 360, saturation: 0.5, brightness: 1)
            var layer = context
            layer.blendMode = .screen
            layer.fill(Path(ellipseIn: CGRect(x: burst.point.x - radius, y: burst.point.y - radius,
                                              width: radius * 2, height: radius * 2)),
                       with: .radialGradient(Gradient(colors: [.white.opacity(1 - age), color.opacity((1 - age) * 0.7), .clear]),
                                             center: burst.point, startRadius: 0, endRadius: radius))
        }
    }

    /// Facet shapes in the spirit of each family's cut.
    private func facetPath(in box: CGRect) -> Path {
        let c = CGPoint(x: box.midX, y: box.midY)
        let r = box.width / 2
        var path = Path()
        switch interior.family {
        case .lightning:
            // A sharp shard
            path.move(to: CGPoint(x: c.x, y: c.y - r))
            path.addLine(to: CGPoint(x: c.x + r * 0.35, y: c.y + r * 0.1))
            path.addLine(to: CGPoint(x: c.x - r * 0.1, y: c.y + r))
            path.closeSubpath()
        case .celestial:
            // A four-pointed star
            for k in 0..<8 {
                let a = Double(k) * .pi / 4 - .pi / 2
                let radius = k.isMultiple(of: 2) ? r : r * 0.28
                let p = CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
                if k == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        case .victorian:
            // A filigree petal
            path.move(to: CGPoint(x: c.x, y: c.y - r))
            path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + r, y: c.y))
            path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - r, y: c.y))
        case .gothic:
            // A pointed lancet arch
            path.move(to: CGPoint(x: c.x - r * 0.5, y: c.y + r))
            path.addLine(to: CGPoint(x: c.x - r * 0.5, y: c.y))
            path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - r * 0.5, y: c.y - r * 0.6))
            path.addQuadCurve(to: CGPoint(x: c.x + r * 0.5, y: c.y), control: CGPoint(x: c.x + r * 0.5, y: c.y - r * 0.6))
            path.addLine(to: CGPoint(x: c.x + r * 0.5, y: c.y + r))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Shared fold math

/// Mirrors GemKaleidoscope.metal so a tap can be traced back to the source point it shows.
enum KaleidoscopeMath {
    static func sourcePoint(for position: CGPoint, size: CGSize, segments: Double,
                            rotation: Double, zoom: Double, focus: CGPoint) -> CGPoint {
        let p = CGPoint(x: position.x - size.width / 2, y: position.y - size.height / 2)
        let r = hypot(p.x, p.y)
        let wedge = 2 * Double.pi / max(segments, 2)
        var a = atan2(p.y, p.x) + rotation
        a -= wedge * floor(a / wedge)
        let folded = min(a, wedge - a)
        var s = CGPoint(x: focus.x + cos(folded) * r * zoom, y: focus.y + sin(folded) * r * zoom)
        s.x = mirror(s.x, size.width)
        s.y = mirror(s.y, size.height)
        return s
    }

    private static func mirror(_ v: Double, _ length: Double) -> Double {
        let period = length * 2
        let m = v - period * floor(v / period)
        return m > length ? period - m : m
    }
}

// MARK: - Entering from anywhere

extension View {
    /// Long-press to step inside this gem. Presents without the system slide so the
    /// interior's own dive-in is the only motion.
    func enterGemOnLongPress(isPresented: Binding<Bool>, interior: @escaping () -> GemInterior,
                             dna: SupabaseService.GemDNA?, transferCount: Int) -> some View {
        modifier(EnterGemModifier(isPresented: isPresented, interior: interior, dna: dna, transferCount: transferCount))
    }
}

private struct EnterGemModifier: ViewModifier {
    @Binding var isPresented: Bool
    let interior: () -> GemInterior
    let dna: SupabaseService.GemDNA?
    let transferCount: Int
    @State private var sourceFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            // Hidden while you're inside, so only the diving copy is ever on screen
            .opacity(isPresented ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sourceFrame = $0 }
            .onLongPressGesture(minimumDuration: 0.45) { present() }
            .accessibilityAction(named: "Step inside the gem") { present() }
            .fullScreenCover(isPresented: $isPresented) {
                GemInteriorView(interior: interior(), gemDNA: dna, transferCount: transferCount,
                                startFrame: sourceFrame)
                    .presentationBackground(.clear)
            }
    }

    private func present() {
        // Felt the instant the press is recognised
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { isPresented = true }
    }
}

// MARK: - Preview

#Preview("Inside a gem") {
    GemInteriorView(
        interior: GemInterior(name: "Rainbow Heart", dna: nil, transferCount: 8),
        gemDNA: nil, transferCount: 8)
}

