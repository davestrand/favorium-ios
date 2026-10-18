//
//  FavorsView.swift
//  favorium
//
//  "Favors" tab — pending (incoming + outgoing) above completed history.
//  Uses SupabaseService exclusively; no new statuses or lifecycle invented.
//

import SwiftUI

// MARK: - View Model

@Observable
final class FavorsViewModel {
    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }
    enum HistoryFilter: String, CaseIterable { case all, given, received }

    var incoming: [SupabaseService.Favor] = []    // helped_id == me
    var outgoing: [SupabaseService.Favor] = []    // helper_id == me
    var loadState: LoadState = .idle
    var historyFilter: HistoryFilter = .all

    // Action-in-flight tracking (favorId → true while network call is pending)
    var actingOn: Set<UUID> = []

    // MARK: - Derived

    /// Pending: proposed incoming (needs my reply) + accepted outgoing (in progress)
    var pendingIncoming: [SupabaseService.Favor] {
        incoming.filter { $0.isProposed }
    }

    var pendingOutgoing: [SupabaseService.Favor] {
        outgoing.filter { $0.isAccepted }
    }

    var hasPending: Bool { !pendingIncoming.isEmpty || !pendingOutgoing.isEmpty }

    /// Completed history filtered per picker
    var historyItems: [SupabaseService.Favor] {
        let completed = (incoming + outgoing)
            .filter { $0.isCompleted || $0.isTransferred || $0.isDeclined || $0.isCancelled }

        switch historyFilter {
        case .all:
            // Deduplicate (a favor appears in both incoming + outgoing for the same user pair)
            var seen = Set<UUID>()
            return completed
                .sorted { $0.created_at > $1.created_at }
                .filter { seen.insert($0.id).inserted }

        case .given:
            // Favors the user performed — outgoing that completed
            return outgoing
                .filter { $0.isCompleted || $0.isTransferred }
                .sorted { $0.created_at > $1.created_at }

        case .received:
            // Favors the user received — incoming that completed
            return incoming
                .filter { $0.isCompleted || $0.isTransferred }
                .sorted { $0.created_at > $1.created_at }
        }
    }

    // MARK: - Load

    @MainActor
    func load(userId: UUID) async {
        loadState = .loading
        do {
            async let inTask  = SupabaseService.shared.myIncomingFavors(userId: userId)
            async let outTask = SupabaseService.shared.myOutgoingFavors(userId: userId)
            let (i, o) = try await (inTask, outTask)
            // Assign data directly — the view drives animations via .animation() on the content
            incoming = i
            outgoing = o
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Actions

    @MainActor
    func accept(_ favor: SupabaseService.Favor, userId: UUID) async {
        actingOn.insert(favor.id)
        defer { actingOn.remove(favor.id) }
        do {
            try await SupabaseService.shared.acceptFavor(favorId: favor.id)
            await load(userId: userId)
        } catch { /* surface error if needed */ }
    }

    @MainActor
    func decline(_ favor: SupabaseService.Favor, userId: UUID) async {
        actingOn.insert(favor.id)
        defer { actingOn.remove(favor.id) }
        do {
            try await SupabaseService.shared.declineFavor(favorId: favor.id)
            await load(userId: userId)
        } catch { }
    }

    @MainActor
    func complete(_ favor: SupabaseService.Favor, userId: UUID) async {
        actingOn.insert(favor.id)
        defer { actingOn.remove(favor.id) }
        do {
            try await SupabaseService.shared.completeFavor(favorId: favor.id)
            await load(userId: userId)
        } catch { }
    }
}

// MARK: - Main View

struct FavorsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var vm = FavorsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                FavoriumTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ─────────────────────────────────────
                        StarfieldHeader(title: "Favors", subtitle: "Kindness in motion.")
                            .padding(.top, 44)
                            .padding(.bottom, 8)

                        // ── Pending ────────────────────────────────────
                        pendingSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, vm.hasPending ? 28 : 0)

                        // ── History ────────────────────────────────────
                        historySection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                    }
                }
                .refreshable {
                    if let uid = appVM.userId {
                        await vm.load(userId: uid)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: vm.hasPending)
                .animation(.easeInOut(duration: 0.4), value: vm.loadState)
            }
            .navigationBarHidden(true)
            .task {
                if let uid = appVM.userId, case .idle = vm.loadState {
                    await vm.load(userId: uid)
                }
            }
        }
    }

    // MARK: - Pending section

    @ViewBuilder
    private var pendingSection: some View {
        switch vm.loadState {
        case .idle, .loading:
            pendingLoadingPlaceholders
        case .failed(let msg):
            errorBanner(msg)
        case .loaded:
            if vm.hasPending {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(
                        title: "Pending",
                        count: vm.pendingIncoming.count + vm.pendingOutgoing.count
                    )

                    // Incoming (awaiting my reply) — highest priority
                    ForEach(vm.pendingIncoming) { favor in
                        IncomingPendingCard(
                            favor: favor,
                            isActing: vm.actingOn.contains(favor.id),
                            onAccept: {
                                if let uid = appVM.userId {
                                    Task { await vm.accept(favor, userId: uid) }
                                }
                            },
                            onDecline: {
                                if let uid = appVM.userId {
                                    Task { await vm.decline(favor, userId: uid) }
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Outgoing accepted (in progress)
                    ForEach(vm.pendingOutgoing) { favor in
                        OutgoingInProgressCard(
                            favor: favor,
                            isActing: vm.actingOn.contains(favor.id),
                            onComplete: {
                                if let uid = appVM.userId {
                                    Task { await vm.complete(favor, userId: uid) }
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var pendingLoadingPlaceholders: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Pending")
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .fill(FavoriumTheme.surface)
                    .frame(height: 120)
                    .shimmer()
            }
        }
    }

    // MARK: - History section

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "History")

            // Filter picker
            filterPicker
                .padding(.bottom, 4)

            switch vm.loadState {
            case .idle, .loading:
                historyLoadingPlaceholders
            case .failed(let msg):
                errorBanner(msg)
            case .loaded:
                if vm.historyItems.isEmpty {
                    emptyHistory
                } else {
                    VStack(spacing: 8) {
                        ForEach(vm.historyItems) { favor in
                            HistoryFavorRow(favor: favor)
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
    }

    private var filterPicker: some View {
        HStack(spacing: 0) {
            ForEach(FavorsViewModel.HistoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.historyFilter = filter
                    }
                } label: {
                    Text(filter.rawValue.capitalized)
                        .font(.system(size: 14, weight: vm.historyFilter == filter ? .semibold : .regular))
                        .foregroundColor(vm.historyFilter == filter ? .black : FavoriumTheme.ivory)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(vm.historyFilter == filter ? FavoriumTheme.teal : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(FavoriumTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(FavoriumTheme.tealMuted.opacity(0.25), lineWidth: 1))
    }

    private var historyLoadingPlaceholders: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                    .fill(FavoriumTheme.surface)
                    .frame(height: 84)
                    .shimmer()
            }
        }
    }

    private var emptyHistory: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(FavoriumTheme.tealMuted)
            Text("No completed favors yet")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(FavoriumTheme.amber)
            Text(message)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivory)
        }
        .padding()
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
    }
}

// MARK: - Incoming Pending Card (awaiting my reply)

private struct IncomingPendingCard: View {
    let favor: SupabaseService.Favor
    let isActing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Gem thumbnail (placeholder tier)
                FavorGemView(
                    gemFamily: .lightning,
                    tier: .bloom,
                    gemColor: FavoriumTheme.teal,
                    size: 66,
                    showGlow: false
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(favor.helper_name ?? "Someone") asked you")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FavoriumTheme.ivory)
                        Spacer()
                        FavorStatusBadge(label: "Awaiting your reply", color: FavoriumTheme.gold)
                    }
                    Text(favor.description)
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivory.opacity(0.85))
                        .lineLimit(2)
                }
            }

            // Action buttons
            HStack(spacing: 10) {
                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Accept")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(FavoriumTheme.teal)
                    .clipShape(Capsule())
                }
                .disabled(isActing)

                Button(action: onDecline) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Decline")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(FavoriumTheme.ivory)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(FavoriumTheme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(FavoriumTheme.ivoryDim.opacity(0.3), lineWidth: 1))
                }
                .disabled(isActing)
            }
            .overlay(isActing ? ProgressView().tint(FavoriumTheme.teal) : nil)
        }
        .padding(16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.tealMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Outgoing In-Progress Card

private struct OutgoingInProgressCard: View {
    let favor: SupabaseService.Favor
    let isActing: Bool
    let onComplete: () -> Void

    private var acceptedSubtitle: String {
        guard let raw = favor.accepted_at else { return "\(favor.helped_name ?? "They") accepted" }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            return "\(favor.helped_name ?? "They") accepted · \(rel.localizedString(for: date, relativeTo: .now))"
        }
        return "\(favor.helped_name ?? "They") accepted"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                FavorGemView(
                    gemFamily: .lightning,
                    tier: .bloom,
                    gemColor: Color(hue: 0.10, saturation: 0.85, brightness: 0.95),
                    size: 66,
                    showGlow: false
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("You asked \(favor.helped_name ?? "someone")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(FavoriumTheme.ivory)
                        Spacer()
                        FavorStatusBadge(label: "In progress", color: FavoriumTheme.teal)
                    }
                    Text(favor.description)
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivory.opacity(0.85))
                        .lineLimit(2)
                    Text(acceptedSubtitle)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
            }

            Button(action: onComplete) {
                HStack(spacing: 8) {
                    Image(systemName: isActing ? "hourglass" : "checkmark.circle")
                        .font(.system(size: 15))
                    Text(isActing ? "Marking completed…" : "Mark completed")
                        .fontWeight(.semibold)
                }
                .foregroundColor(FavoriumTheme.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .overlay(
                    Capsule().stroke(FavoriumTheme.teal.opacity(0.6), lineWidth: 1.5)
                )
            }
            .clipShape(Capsule())
            .disabled(isActing)
        }
        .padding(16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.tealMuted.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - History Row

private struct HistoryFavorRow: View {
    let favor: SupabaseService.Favor

    var body: some View {
        HStack(spacing: 12) {
            FavorGemView(
                gemFamily: .lightning,
                tier: .legacy,
                gemColor: rowGemColor,
                size: 56,
                showGlow: false
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(rowHeadline)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    Text(rowDate)
                        .font(.system(size: 12))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
                Text(favor.description)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                        .foregroundColor(FavoriumTheme.teal)
                    Text("Completed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FavoriumTheme.teal)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                .stroke(FavoriumTheme.tealMuted.opacity(0.18), lineWidth: 1)
        )
    }

    private var rowHeadline: String {
        // The Favor struct carries helper_name / helped_name from the joined profiles.
        // We use the status to decide direction label; the caller already filters by
        // historyFilter so context is known.
        if favor.isCompleted || favor.isTransferred {
            let helper = favor.helper_name ?? "Someone"
            let helped = favor.helped_name ?? "someone"
            // If the helper and helped are the same person this shouldn't happen,
            // but we present the most natural description either way.
            return "\(helper) helped \(helped)"
        }
        if favor.isDeclined { return "Favor declined" }
        if favor.isCancelled { return "Favor cancelled" }
        return "Past favor"
    }

    private var rowGemColor: Color {
        // Derive a deterministic hue from the favor UUID so the same
        // favor always shows the same gem tint — no randomness at render time.
        let hue = Double(favor.id.hashValue & 0xFFFF) / Double(0xFFFF)
        return Color(hue: hue, saturation: 0.65, brightness: 0.88)
    }

    private var rowDate: String {
        let raw = favor.completed_at ?? favor.created_at
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "MMM d"
        return out.string(from: date)
    }
}

// MARK: - Shared helpers

private struct FavorStatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }
}

#Preview("Favors") {
    @Previewable @State var appVM = AppViewModel()
    FavorsView()
        .environment(appVM)
}
