//
//  GemGuideView.swift
//  favorium
//
//  Explains gem families and levels (tiers), opened by tapping the
//  family or level on the gem detail page. Previews use the viewer's own gem;
//  families the user hasn't collected and levels this gem hasn't reached stay hidden.
//

import SwiftUI

struct GemGuideView: View {
    /// Which section the sheet scrolls to when it opens
    enum Topic: String, Identifiable {
        case families, levels
        var id: String { rawValue }
    }

    let initialTopic: Topic
    let dna: SupabaseService.GemDNA?
    let transferCount: Int
    /// The signed-in user, used to look up which families they've collected
    let userId: UUID?

    /// Families from gems the user holds or created. Empty until loaded.
    @State private var collectedFamilies: Set<GemFamily> = []
    @Environment(\.dismiss) private var dismiss

    private var currentTier: Tier { Tier.from(transferCount: transferCount) }
    private var currentFamily: GemFamily { GemFamily.from(dna?.resolvedFamily) }

    /// The family shown on the detail page is never a secret
    private func isCollected(_ family: GemFamily) -> Bool {
        family == currentFamily || collectedFamilies.contains(family)
    }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            familiesSection.id(Topic.families)
                            levelsSection.id(Topic.levels)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                    .onAppear { proxy.scrollTo(initialTopic, anchor: .top) }
                }
            }
        }
        .task { await loadCollectedFamilies() }
    }

    /// Optional: if this fails, every family except this gem's simply stays hidden
    private func loadCollectedFamilies() async {
        guard let userId else { return }
        async let held = try? SupabaseService.shared.myFavors(userId: userId)
        async let originals = try? SupabaseService.shared.myOriginals(userId: userId)
        let coins = (await held ?? []) + (await originals ?? [])
        collectedFamilies = Set(coins.compactMap { GemFamily.normalized($0.gemDNA?.resolvedFamily) })
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                    .frame(width: 40, height: 40)
                    .background(FavoriumTheme.surface)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
            Text("Gem guide")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Families

    private var familiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let collectedCount = GemFamily.allCases.filter(isCollected).count
            sectionTitle("Families",
                         intro: "Every gem belongs to a family that sets its shape and frame, and it never changes as the gem travels. New families will appear over time — collect gems from each to reveal them.")

            Text("You've collected \(collectedCount) of \(GemFamily.allCases.count) families so far.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FavoriumTheme.accent)

            ForEach(GemFamily.allCases) { family in
                guideRow(
                    title: family.displayName,
                    subtitle: nil,
                    description: family.description,
                    isCurrent: family == currentFamily,
                    currentLabel: "This gem's family",
                    accent: FavoriumTheme.accent
                ) {
                    preview(family: family, tier: currentTier, locked: !isCollected(family))
                }
            }
        }
    }

    // MARK: - Levels

    private var levelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Levels",
                         intro: "Gems grow each time they're given in thanks for a favor. The more hands a gem passes through, the higher its level.")

            progressCard

            ForEach(Tier.allCases) { tier in
                guideRow(
                    title: tier.displayName,
                    subtitle: transferRangeText(tier),
                    description: tier.description,
                    isCurrent: tier == currentTier,
                    currentLabel: "This gem's level",
                    accent: tier.defaultColor
                ) {
                    preview(family: currentFamily, tier: tier,
                            locked: tier.minTransfers > currentTier.minTransfers)
                }
            }
        }
    }

    /// How far this gem is from its next level
    private var progressCard: some View {
        let text: String
        if let next = currentTier.next {
            let remaining = max(next.minTransfers - transferCount, 0)
            text = "This gem has been given \(timesText(transferCount)). \(timesText(remaining).capitalizedFirst) more and it reaches \(next.displayName)."
        } else {
            text = "This gem has been given \(timesText(transferCount)) and has reached the highest level."
        }
        return Text(text)
            .font(FavoriumTheme.captionFont)
            .foregroundColor(FavoriumTheme.ivory)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(currentTier.defaultColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                    .stroke(currentTier.defaultColor.opacity(0.4), lineWidth: 1)
            )
    }

    // MARK: - Building blocks

    private func sectionTitle(_ title: String, intro: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
            Text(intro)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guideRow<Preview: View>(
        title: String,
        subtitle: String?,
        description: String,
        isCurrent: Bool,
        currentLabel: String,
        accent: Color,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            preview()
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    }
                }
                Text(description)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
                if isCurrent {
                    Text(currentLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.15))
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(isCurrent ? accent.opacity(0.08) : FavoriumTheme.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                .stroke(isCurrent ? accent.opacity(0.5) : .clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// This gem's colors rendered in another family or at another level.
    /// Uncollected families and unreached levels are `locked`: blurred beyond
    /// recognition behind a question mark so the guide doesn't spoil them.
    private func preview(family: GemFamily, tier: Tier, locked: Bool = false) -> some View {
        ZStack {
            FavorGemView(
                gemFamily: family,
                tier: tier,
                gemColor: dna?.gemColor ?? tier.defaultColor,
                frameColor: dna?.frameColor,
                size: 60,
                suppressTilt: true
            )
            .blur(radius: locked ? 14 : 0)
            .opacity(locked ? 0.6 : 1)

            if locked {
                Image(systemName: "questionmark")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
            }
        }
        // Each gem stacks several blurred layers plus a shadow; flattening them into
        // one rendered layer keeps scrolling smooth. The padding leaves room for the
        // shadow so it isn't clipped by the flattened bounds.
        .padding(20)
        .drawingGroup()
        .padding(-20)
        .accessibilityHidden(true)
    }

    private func transferRangeText(_ tier: Tier) -> String {
        if let next = tier.next {
            return "\(tier.minTransfers)–\(next.minTransfers - 1) gifts"
        }
        return "\(tier.minTransfers)+ gifts"
    }

    private func timesText(_ count: Int) -> String {
        count == 1 ? "once" : "\(count) times"
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

#Preview {
    GemGuideView(initialTopic: .levels, dna: nil, transferCount: 7, userId: nil)
}
