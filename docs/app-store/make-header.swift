import AppKit

let args = CommandLine.arguments
let dir = args[1], out = args[2]
let W: CGFloat = 1920, H: CGFloat = 1080
// Optional output pixel size; the 1920×1080 layout is scaled to fit it
let outW = args.count > 3 ? Int(args[3])! : 1920, outH = args.count > 4 ? Int(args[4])! : 1080
let s = CGFloat(outW) / W

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
let ivory = c(0.957, 0.933, 0.882), sky = c(0.851, 0.894, 0.961)
let gold = c(0.541, 0.384, 0.071), brass = c(0.690, 0.541, 0.243), navy = c(0.06, 0.09, 0.20)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: outW, pixelsHigh: outH, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: s, y: s)

// Background: pale sapphire sky fading to ivory marble
NSGradient(colors: [sky, ivory, ivory], atLocations: [0, 0.6, 1], colorSpace: .sRGB)!.draw(in: NSRect(x: 0, y: 0, width: W, height: H + 2), angle: -90)

// Sunburst rays from above the phones
let sun = CGPoint(x: 1380, y: H + 120)
ctx.saveGState()
for i in 0..<72 {
    let a = CGFloat(i) / 72 * .pi * 2
    let p = NSBezierPath(); p.move(to: sun)
    p.line(to: CGPoint(x: sun.x + cos(a) * 2600, y: sun.y + sin(a) * 2600))
    p.lineWidth = 2; c(1, 1, 1, 0.55).setStroke(); p.stroke()
}
ctx.restoreGState()
// Soften the rays toward the bottom
NSGradient(colors: [ivory.withAlphaComponent(0), ivory.withAlphaComponent(0.9)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H * 0.55), angle: -90)

// Gold arc behind the phones
let arc = NSBezierPath(); arc.appendArc(withCenter: CGPoint(x: 1380, y: 1180), radius: 760, startAngle: 180, endAngle: 360)
arc.lineWidth = 3; brass.withAlphaComponent(0.8).setStroke(); arc.stroke()
let arc2 = NSBezierPath(); arc2.appendArc(withCenter: CGPoint(x: 1380, y: 1180), radius: 742, startAngle: 180, endAngle: 360)
arc2.lineWidth = 1; brass.withAlphaComponent(0.5).setStroke(); arc2.stroke()

// Phones
func phone(_ name: String, center: CGPoint, height h: CGFloat) {
    guard let img = NSImage(contentsOfFile: "\(dir)/\(name)") else { fatalError("missing \(name)") }
    let w = h * 1320 / 2868, bez: CGFloat = h * 0.018
    let outer = NSRect(x: center.x - w / 2 - bez, y: center.y - h / 2 - bez, width: w + bez * 2, height: h + bez * 2)
    let r = w * 0.15
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = c(0.05, 0.08, 0.2, 0.35); sh.shadowBlurRadius = 50 * s; sh.shadowOffset = NSSize(width: 0, height: -24 * s); sh.set()
    navy.setFill(); NSBezierPath(roundedRect: outer, xRadius: r + bez, yRadius: r + bez).fill()
    NSGraphicsContext.restoreGraphicsState()
    let inner = NSRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: inner, xRadius: r, yRadius: r).addClip()
    img.draw(in: inner)
    NSGraphicsContext.restoreGraphicsState()
}
phone("02-collection.png", center: CGPoint(x: 1115, y: 500), height: 820)
phone("03-gem-details.png", center: CGPoint(x: 1645, y: 500), height: 820)
phone("01-hall.png", center: CGPoint(x: 1380, y: 535), height: 930)

// Text block
func draw(_ s: String, font: NSFont, color: NSColor, kern: CGFloat = 0, x: CGFloat, y: CGFloat) -> NSSize {
    let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern])
    a.draw(at: CGPoint(x: x, y: y)); return a.size()
}
let left: CGFloat = 130
let wordFont = NSFont(name: "Futura-Medium", size: 92) ?? .systemFont(ofSize: 92, weight: .medium)
let ws = draw("FAVORIUM", font: wordFont, color: navy, kern: 18, x: left, y: 610)

// Divider with a gold diamond
let midY: CGFloat = 585, midX = left + (ws.width - 18) / 2
let line = NSBezierPath(); line.lineWidth = 2
line.move(to: CGPoint(x: left + 40, y: midY)); line.line(to: CGPoint(x: midX - 22, y: midY))
line.move(to: CGPoint(x: midX + 22, y: midY)); line.line(to: CGPoint(x: left + ws.width - 58, y: midY))
brass.setStroke(); line.stroke()
let d = NSBezierPath(); d.move(to: CGPoint(x: midX, y: midY + 11)); d.line(to: CGPoint(x: midX + 11, y: midY)); d.line(to: CGPoint(x: midX, y: midY - 11)); d.line(to: CGPoint(x: midX - 11, y: midY)); d.close()
c(0.86, 0.64, 0.20).setFill(); d.fill()

let serif = NSFont(name: "Georgia", size: 50)!
let serifItalic = NSFontManager.shared.convert(serif, toHaveTrait: .italicFontMask)
_ = draw("Kindness you can hold", font: serifItalic, color: navy, x: left, y: 480)

let small = NSFont(name: "Georgia", size: 30)!
_ = draw("Do a favor, receive a gem.", font: small, color: navy.withAlphaComponent(0.8), x: left, y: 395)
_ = draw("Every gem carries its journey.", font: small, color: navy.withAlphaComponent(0.8), x: left, y: 352)

// "New in 1.1" pill
let pillFont = NSFont(name: "Futura-Medium", size: 22) ?? .systemFont(ofSize: 22, weight: .semibold)
let pillText = NSAttributedString(string: "NEW IN 1.1  ·  STEP INTO THE HALL", attributes: [.font: pillFont, .foregroundColor: gold, .kern: 3])
let ps = pillText.size()
let pill = NSRect(x: left, y: 250, width: ps.width + 48, height: ps.height + 24)
c(0.98, 0.94, 0.84).setFill(); NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
let pb = NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2); pb.lineWidth = 2; brass.setStroke(); pb.stroke()
pillText.draw(at: CGPoint(x: pill.minX + 24, y: pill.minY + 12))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
