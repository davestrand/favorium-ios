//
//  FavorDetailView.swift
//  favorium
//
//  A past favor in full: who it was with, the whole description, each step it
//  went through, and — once a gem changed hands — a way to open that gem.
//

import SwiftUI

// MARK: - Shared wording (History rows and this page say the same thing)

extension SupabaseService.Favor {
    func iAmHelper(_ userId: UUID?) -> Bool { helper_id == userId }

    /// The other person in the favor, from the signed-in user's side
    func other(_ userId: UUID?) -> (id: UUID, name: String?, photo: String?, level: Int?) {
        iAmHelper(userId)
            ? (helped_id, helped_name, helped_avatar_url, helped_level)
            : (helper_id, helper_name, helper_avatar_url, helper_level)
    }

    /// "You helped Sam" / "Sam helped you"
    func headline(for userId: UUID?) -> String {
        let mine = iAmHelper(userId)
        let other = other(userId).name ?? (mine ? "someone" : "Someone")
        if isCompleted || isTransferred {
            return mine ? "You helped \(other)" : "\(other) helped you"
        }
        if isDeclined {
            return mine ? "\(other) declined your offer" : "You declined \(other)\u{2019}s offer"
        }
        if isCancelled { return mine ? "Favor with \(other) cancelled" : "\(other)\u{2019}s favor cancelled" }
        return "Past favor"
    }

    var statusLabel: (text: String, icon: String) {
        if isTransferred { return ("Gem given", "gift") }
        if isDeclined    { return ("Declined", "xmark.circle") }
        if isCancelled   { return ("Cancelled", "minus.circle") }
        return ("Completed", "checkmark.circle")
    }
}

// MARK: - Detail

struct FavorDetailView: View {
    let favor: SupabaseService.Favor
    let userId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var gemName: String?
    @State private var showGem = false

    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let date: String?
        let isEnding: Bool   // declined / cancelled — drawn muted
    }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar
                    header
                    descriptionCard
                    stepsCard
                    if favor.coin_id != nil { gemButton }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .task {
            if let coinId = favor.coin_id {
                gemName = try? await SupabaseService.shared.coinName(coinId: coinId)
            }
        }
        .sheet(isPresented: $showGem) {
            if let coinId = favor.coin_id {
                GemDetailView(coinId: coinId, coinName: gemName ?? "Gem", userId: userId)
            }
        }
    }

    private var topBar: some View {
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
            Text("Favor")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 16)
    }

    private var header: some View {
        let person = favor.other(userId)
        let status = favor.statusLabel
        return VStack(spacing: 10) {
            PersonAvatar(userId: person.id, name: person.name, photo: person.photo, level: person.level, size: 72)
            Text(favor.headline(for: userId))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Label(status.text, systemImage: status.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(favor.isTransferred ? FavoriumTheme.accent : FavoriumTheme.ivoryDim)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background((favor.isTransferred ? FavoriumTheme.accent : FavoriumTheme.ivoryDim).opacity(0.14))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private var descriptionCard: some View {
        card {
            Text("The favor")
                .font(.system(size: 11, weight: .semibold).width(.expanded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(FavoriumTheme.accent)
            Text(favor.description)
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivory)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var stepsCard: some View {
        let list = steps
        return card {
            Text("How it went")
                .font(.system(size: 11, weight: .semibold).width(.expanded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(FavoriumTheme.accent)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        // Same spine as the gem journey: dot plus a line to the next step
                        VStack(spacing: 0) {
                            Circle()
                                .fill(step.isEnding ? FavoriumTheme.ivoryDim : FavoriumTheme.accent)
                                .frame(width: 10, height: 10)
                                .padding(.top, 4)
                            if index < list.count - 1 {
                                Rectangle()
                                    .fill(FavoriumTheme.accentMuted.opacity(0.35))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 10)

                        HStack(alignment: .firstTextBaseline) {
                            Text(step.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(step.isEnding ? FavoriumTheme.ivoryDim : FavoriumTheme.ivory)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            if let date = step.date {
                                Text(date)
                                    .font(.system(size: 12))
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                                    .fixedSize()
                            }
                        }
                        .padding(.bottom, index < list.count - 1 ? 18 : 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var gemButton: some View {
        Button { showGem = true } label: {
            HStack {
                Image(systemName: "diamond")
                Text(gemName.map { "See \($0)" } ?? "See the gem")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .metallicGoldCapsule()
        }
        .buttonStyle(.plain)
    }

    /// The favor's lifecycle, written from the signed-in user's side. Steps without a
    /// recorded time (declines, cancellations) appear without a date.
    private var steps: [Step] {
        let mine = favor.iAmHelper(userId)
        let other = favor.other(userId).name ?? "them"
        var result = [Step(title: mine ? "You offered to help \(other)" : "\(other) offered to help",
                           date: format(favor.created_at), isEnding: false)]
        if let accepted = favor.accepted_at {
            result.append(Step(title: mine ? "\(other) accepted" : "You accepted", date: format(accepted), isEnding: false))
        }
        if let completed = favor.completed_at {
            result.append(Step(title: "Marked done", date: format(completed), isEnding: false))
        }
        if favor.isTransferred {
            result.append(Step(title: mine ? "\(other) gave you a gem" : "You gave \(other) a gem",
                               date: favor.transferred_at.flatMap(format), isEnding: false))
        }
        if favor.isDeclined {
            result.append(Step(title: mine ? "\(other) declined" : "You declined", date: nil, isEnding: true))
        }
        if favor.isCancelled {
            result.append(Step(title: "Cancelled", date: nil, isEnding: true))
        }
        return result
    }

    private func format(_ raw: String) -> String? {
        SupabaseService.PairingCode.parseTimestamp(raw)?
            .formatted(.dateTime.month(.abbreviated).day().hour().minute())   // "Oct 18, 12:10 AM"
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .stroke(FavoriumTheme.accentMuted.opacity(0.25), lineWidth: 1)
            )
    }
}

#Preview("Gem given") {
    let me = UUID()
    FavorDetailView(
        favor: .init(
            id: UUID(), helper_id: me, helped_id: UUID(),
            description: "Drove me to the airport at 4am and waited until the flight actually left.",
            status: "transferred",
            created_at: "2026-10-18T07:10:00+00:00",
            accepted_at: "2026-10-18T07:40:00+00:00",
            completed_at: "2026-10-19T04:55:00+00:00",
            transferred_at: "2026-10-19T09:12:00+00:00",
            coin_id: UUID(),
            helper_name: "You", helped_name: "Bilbo"
        ),
        userId: me
    )
}
