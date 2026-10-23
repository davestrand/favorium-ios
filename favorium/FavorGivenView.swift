//
//  FavorGivenView.swift
//  favorium
//
//  The moment a gem changes hands, from both sides:
//   • given    — the end of Give a gem
//   • received — a gem arrived for help you gave (live update, push, or next launch)
//

import SwiftUI

/// A gem that changed hands, and with whom
struct FavorGiven: Identifiable {
    enum Kind { case given, received }

    let id = UUID()
    var kind: Kind = .given
    let gem: GiftableGem?
    /// The other person: the helper for `given`, the person helped for `received`
    let helperName: String
    var favorDescription: String? = nil
    /// Other gems that arrived since the last celebration (received only)
    var alsoArrived = 0
}

struct FavorGivenView: View {
    let given: FavorGiven
    /// Runs before closing (e.g. so the screen underneath refreshes)
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var raysTurn = false

    private var gemName: String { given.gem?.name ?? (given.kind == .given ? "Your gem" : "A gem") }

    private var heading: String { given.kind == .given ? "Favor given" : "A gem arrived" }

    private var message: String {
        switch given.kind {
        case .given:
            return "\(gemName) is now with \(given.helperName). Thank you for passing on the kindness."
        case .received:
            return "\(given.helperName) gave you \(gemName). Your kindness is in your collection now."
        }
    }

    /// The favor it thanks, quoted on its own line (received only)
    private var reason: String? {
        guard given.kind == .received, let description = given.favorDescription else { return nil }
        return "For \u{201C}\(FavorNotificationCenter.clipped(description))\u{201D}"
    }

    private var others: String? {
        switch given.alsoArrived {
        case 0:  nil
        case 1:  "And 1 more gem arrived while you were away."
        default: "And \(given.alsoArrived) more gems arrived while you were away."
        }
    }
    private var glowColor: Color {
        given.gem?.dna?.gemColor ?? Tier.from(transferCount: given.gem?.transferCount ?? 0).defaultColor
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Slow gold rays behind the stone, like the header's sunburst
                RaysShape(count: 18)
                    .fill(FavoriumTheme.goldGradient)
                    .opacity(revealed ? 0.22 : 0)
                    .frame(width: 320, height: 320)
                    .rotationEffect(.degrees(raysTurn ? 360 : 0))
                    .mask(RadialGradient(colors: [.white, .clear], center: .center, startRadius: 40, endRadius: 160))

                RadialGradient(colors: [glowColor.opacity(0.45), .clear],
                               center: .center, startRadius: 10, endRadius: 140)
                    .frame(width: 280, height: 280)
                    .blur(radius: 20)
                    .opacity(revealed ? 1 : 0)

                FavorGemView(dna: given.gem?.dna, transferCount: given.gem?.transferCount ?? 0,
                             size: 180, showShimmer: true)
                    .scaleEffect(revealed ? 1 : 0.55)
                    .offset(y: revealed ? 0 : 40)
                    .opacity(revealed ? 1 : 0)
            }
            .frame(height: 300)
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text(heading)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                Text(message)
                    .font(FavoriumTheme.bodyFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let reason {
                    Text(reason)
                        .font(.system(size: 15, design: .serif).italic())
                        .foregroundColor(FavoriumTheme.ivory.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                if let others {
                    Text(others)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 36)
            .opacity(revealed ? 1 : 0)
            .accessibilityElement(children: .combine)

            Spacer()

            Button {
                onDone()
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FavoriumTheme.background.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: revealed)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                revealed = true
            }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                raysTurn = true
            }
        }
    }
}

/// Thin wedges radiating from the centre
private struct RaysShape: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height) / 2
        let step = 2 * Double.pi / Double(count)
        let half = step * 0.18
        var path = Path()
        for i in 0..<count {
            let a = Double(i) * step
            path.move(to: c)
            path.addLine(to: CGPoint(x: c.x + cos(a - half) * r, y: c.y + sin(a - half) * r))
            path.addLine(to: CGPoint(x: c.x + cos(a + half) * r, y: c.y + sin(a + half) * r))
            path.closeSubpath()
        }
        return path
    }
}

#Preview("Gem arrived") {
    FavorGivenView(given: FavorGiven(
        kind: .received,
        gem: GiftableGem(id: UUID(), name: "Hex Green", transferCount: 3, dna: nil),
        helperName: "Sam",
        favorDescription: "Can you please check on my kitten while I'm away?",
        alsoArrived: 1
    ))
}

#Preview("Favor given") {
    FavorGivenView(given: FavorGiven(
        gem: GiftableGem(id: UUID(), name: "Hex Green", transferCount: 3, dna: nil),
        helperName: "Dave"
    ))
}
