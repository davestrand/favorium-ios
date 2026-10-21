//
//  FavorsView.swift
//  favorium
//
//  "Favors" tab — pending (incoming + outgoing) above completed history.
//  Uses SupabaseService exclusively; no new statuses or lifecycle invented.
//
//  Favor lifecycle (enforced server-side):
//    helper:  propose_favor            → proposed
//    helped:  respond_to_favor         → accepted / declined
//    helped:  complete_favor           → completed
//    helped:  transfer_coin (gives gem)→ transferred
//  Only the *helped* person can act after the proposal; the helper just waits.
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
    /// Last failed action, shown as a banner instead of failing silently
    var actionError: String?

    // MARK: - Derived

    /// Someone offered to help me — I need to accept or decline
    var offersToMe: [SupabaseService.Favor] {
        incoming.filter { $0.isProposed }
    }

    /// Someone is helping me — I confirm when it's done
    var helpingMe: [SupabaseService.Favor] {
        incoming.filter { $0.isAccepted }
    }

    /// Done and confirmed — I still owe the helper a gem
    var awaitingMyGem: [SupabaseService.Favor] {
        incoming.filter { $0.isCompleted && $0.coin_id == nil }
    }

    /// Favors I'm doing for others — nothing for me to do but wait
    var myOffersInFlight: [SupabaseService.Favor] {
        outgoing.filter { $0.isProposed || $0.isAccepted || ($0.isCompleted && $0.coin_id == nil) }
    }

    var pendingCount: Int {
        offersToMe.count + helpingMe.count + awaitingMyGem.count + myOffersInFlight.count
    }

    var hasPending: Bool { pendingCount > 0 }

    /// Identity of everything in Pending, so the list animates when favors arrive or resolve
    var pendingIDs: [UUID] {
        (offersToMe + awaitingMyGem + helpingMe + myOffersInFlight).map(\.id)
    }

    /// Finished favors (gem given, declined or cancelled) filtered per picker
    var historyItems: [SupabaseService.Favor] {
        let completed = (incoming + outgoing)
            .filter { $0.isTransferred || $0.isDeclined || $0.isCancelled }

        switch historyFilter {
        case .all:
            // Deduplicate (a favor appears in both incoming + outgoing for the same user pair)
            var seen = Set<UUID>()
            return completed
                .sorted { $0.created_at > $1.created_at }
                .filter { seen.insert($0.id).inserted }

        case .given:
            // Favors the user performed and was thanked for
            return outgoing
                .filter { $0.isTransferred }
                .sorted { $0.created_at > $1.created_at }

        case .received:
            // Favors the user received and gave a gem for
            return incoming
                .filter { $0.isTransferred }
                .sorted { $0.created_at > $1.created_at }
        }
    }

    // MARK: - Load

    @MainActor
    func load(userId: UUID) async {
        // Only show placeholders on the first load. Swapping loaded cards for
        // placeholders during pull-to-refresh shrinks the scroll content, which
        // makes SwiftUI cancel the refresh task mid-request.
        if loadState != .loaded {
            loadState = .loading
        }
        do {
            async let inTask  = SupabaseService.shared.myIncomingFavors(userId: userId)
            async let outTask = SupabaseService.shared.myOutgoingFavors(userId: userId)
            let (i, o) = try await (inTask, outTask)
            // Assign data directly — the view drives animations via .animation() on the content
            incoming = i
            outgoing = o
            loadState = .loaded
        } catch where Self.isCancellation(error) {
            // A cancelled refresh isn't a failure. Keep whatever is on screen,
            // and let the next .task / refresh retry a first load that was interrupted.
            if loadState == .loading { loadState = .idle }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Task cancellation can surface as Swift's CancellationError or, from the
    /// networking layer underneath Supabase, as URLError(.cancelled).
    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // MARK: - Actions

    @MainActor
    func accept(_ favor: SupabaseService.Favor, userId: UUID) async {
        await perform(on: favor, userId: userId) {
            try await SupabaseService.shared.acceptFavor(favorId: favor.id)
        }
    }

    @MainActor
    func decline(_ favor: SupabaseService.Favor, userId: UUID) async {
        await perform(on: favor, userId: userId) {
            try await SupabaseService.shared.declineFavor(favorId: favor.id)
        }
    }

    /// Helped person confirms the favor is done (complete_favor)
    @MainActor
    func complete(_ favor: SupabaseService.Favor, userId: UUID) async {
        await perform(on: favor, userId: userId) {
            try await SupabaseService.shared.completeFavor(favorId: favor.id)
        }
    }

    /// Either person cancels a favor that's still proposed or accepted (cancel_favor)
    @MainActor
    func cancel(_ favor: SupabaseService.Favor, userId: UUID) async {
        await perform(on: favor, userId: userId) {
            try await SupabaseService.shared.cancelFavor(favorId: favor.id)
        }
    }

    /// Runs a favor action, tracks the in-flight state, refreshes, and surfaces errors.
    @MainActor
    private func perform(on favor: SupabaseService.Favor, userId: UUID,
                         _ action: () async throws -> Void) async {
        actingOn.insert(favor.id)
        defer { actingOn.remove(favor.id) }
        actionError = nil
        do {
            try await action()
            await load(userId: userId)
        } catch {
            actionError = error.localizedDescription
        }
    }
}

// MARK: - Main View

struct FavorsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(FavorNotificationCenter.self) private var notifications
    @State private var vm = FavorsViewModel()
    @State private var showOfferHelp = false
    @State private var push = PushManager.shared
    @AppStorage("pushPromptDismissed") private var pushPromptDismissed = false
    /// Off until the first load lands, so initial content replaces the placeholders
    /// in place instead of every card sliding in at once. Live changes after that animate.
    @State private var animatesChanges = false
    /// Favor the user is giving a gem for (opens the give-a-gem sheet)
    @State private var givingGemFor: SupabaseService.Favor?
    /// Favor awaiting cancel confirmation
    @State private var cancelling: SupabaseService.Favor?
    @State private var showConnect = false

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ─────────────────────────────────────
                        StarfieldHeader(title: "Favors", subtitle: "Kindness in motion.")
                            .padding(.top, 28)
                            .padding(.bottom, 8)

                        // ── Start a favor / pair with someone ──────────
                        HStack(spacing: 12) {
                            Button { showOfferHelp = true } label: {
                                Label("Offer a favor", systemImage: "hand.raised")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .metallicGoldCapsule()
                            }

                            Button { showConnect = true } label: {
                                Label("Connect", systemImage: "person.2")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .foregroundColor(FavoriumTheme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(FavoriumTheme.surface.opacity(0.85))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(FavoriumTheme.goldGradient, lineWidth: 1.5))
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                        // Explain notifications before the one-time system prompt
                        if push.canAskPermission && !pushPromptDismissed {
                            PushPermissionCard {
                                Task { await push.requestAuthorization() }
                            } onDismiss: {
                                pushPromptDismissed = true
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }

                        if let error = vm.actionError {
                            errorBanner(error)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }

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
                // Content fades in over the fixed backdrop on the tab's first visit
                .fadeInOnFirstAppear()
                .refreshable {
                    if let uid = appVM.userId {
                        await vm.load(userId: uid)
                        await notifications.refreshActionCount()
                    }
                }
                .animation(animatesChanges ? .easeInOut(duration: 0.35) : nil, value: vm.hasPending)
                // New or resolved favors slide in/out instead of popping
                .animation(animatesChanges ? .spring(response: 0.45, dampingFraction: 0.85) : nil, value: vm.pendingIDs)
                // The prompt card collapses smoothly once permission is granted or dismissed
                .animation(.easeInOut(duration: 0.3), value: push.canAskPermission && !pushPromptDismissed)
            }
            .onChange(of: vm.loadState) { _, state in
                // Runs after the first loaded render, so only later changes animate
                if state == .loaded { animatesChanges = true }
            }
            .navigationBarHidden(true)
            .task {
                if let uid = appVM.userId, case .idle = vm.loadState {
                    await vm.load(userId: uid)
                }
            }
            // Live updates: reload whenever a favor changes elsewhere
            .onChange(of: notifications.changeToken) { _, _ in reload() }
            .sheet(isPresented: $showConnect) {
                ConnectView(userId: appVM.userId)
            }
            .sheet(isPresented: $showOfferHelp) {
                OfferHelpView(userId: appVM.userId) { reload() }
            }
            .sheet(item: $givingGemFor) { favor in
                SendGemView(initialFavor: favor, userId: appVM.userId) { reload() }
            }
            .confirmationDialog(
                cancelling.map { cancelTitle(for: $0) } ?? "",
                isPresented: Binding(
                    get: { cancelling != nil },
                    set: { if !$0 { cancelling = nil } }
                ),
                titleVisibility: .visible,
                presenting: cancelling
            ) { favor in
                Button(cancelLabel(for: favor), role: .destructive) {
                    // Don't notify the user about their own cancellation
                    notifications.noteLocalAction(favor.id)
                    act { await vm.cancel(favor, userId: $0) }
                }
                Button("Keep it", role: .cancel) { }
            } message: { favor in
                Text(cancelMessage(for: favor))
            }
        }
    }

    private func reload() {
        if let uid = appVM.userId {
            Task {
                await vm.load(userId: uid)
                // Keep the tab + app icon badge in step with what's on screen
                await notifications.refreshActionCount()
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
                    SectionHeader(title: "Pending", count: vm.pendingCount)

                    // Someone offered to help me — needs my reply (highest priority)
                    ForEach(vm.offersToMe) { favor in
                        IncomingPendingCard(
                            favor: favor,
                            isActing: vm.actingOn.contains(favor.id),
                            onAccept: { act { await vm.accept(favor, userId: $0) } },
                            onDecline: { act { await vm.decline(favor, userId: $0) } }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Done and confirmed — time to thank the helper with a gem
                    ForEach(vm.awaitingMyGem) { favor in
                        FavorStatusCard(
                            personId: favor.helper_id,
                            personName: favor.helper_name,
                            personPhoto: favor.helper_avatar_url,
                            title: "\(favor.helper_name ?? "Someone") helped you",
                            description: favor.description,
                            badge: ("Give a gem", FavoriumTheme.gold),
                            action: .init(label: "Give a gem", icon: "gift", isPrimary: true) {
                                givingGemFor = favor
                            },
                            cancel: nil,
                            isActing: vm.actingOn.contains(favor.id)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Someone is helping me — confirm when it's done
                    ForEach(vm.helpingMe) { favor in
                        FavorStatusCard(
                            personId: favor.helper_id,
                            personName: favor.helper_name,
                            personPhoto: favor.helper_avatar_url,
                            title: "\(favor.helper_name ?? "Someone") is helping you",
                            description: favor.description,
                            badge: ("In progress", FavoriumTheme.accent),
                            action: .init(label: "Mark complete", icon: "checkmark.circle", isPrimary: false) {
                                act { await vm.complete(favor, userId: $0) }
                            },
                            cancel: .init(label: cancelLabel(for: favor)) { cancelling = favor },
                            isActing: vm.actingOn.contains(favor.id)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Favors I'm doing for others — only the other person can move these forward
                    ForEach(vm.myOffersInFlight) { favor in
                        FavorStatusCard(
                            personId: favor.helped_id,
                            personName: favor.helped_name,
                            personPhoto: favor.helped_avatar_url,
                            title: "You're helping \(favor.helped_name ?? "someone")",
                            description: favor.description,
                            badge: helperWaitingBadge(favor),
                            action: nil,
                            // Cancellable until the helped person confirms it's done
                            cancel: favor.isCompleted ? nil
                                : .init(label: cancelLabel(for: favor)) { cancelling = favor },
                            isActing: vm.actingOn.contains(favor.id)
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
    }

    /// What the helper is waiting on, at each stage
    private func helperWaitingBadge(_ favor: SupabaseService.Favor) -> (String, Color) {
        let name = favor.helped_name ?? "them"
        if favor.isProposed { return ("Waiting for \(name) to accept", FavoriumTheme.ivoryDim) }
        if favor.isAccepted { return ("Waiting for \(name) to confirm", FavoriumTheme.accent) }
        return ("\(name) confirmed · gem on its way", FavoriumTheme.gold)
    }

    // MARK: - Cancel copy

    private func isMyOffer(_ favor: SupabaseService.Favor) -> Bool {
        favor.helper_id == appVM.userId
    }

    /// "Withdraw offer" before it's accepted (helper only), "Cancel favor" after
    private func cancelLabel(for favor: SupabaseService.Favor) -> String {
        favor.isProposed && isMyOffer(favor) ? "Withdraw offer" : "Cancel favor"
    }

    private func cancelTitle(for favor: SupabaseService.Favor) -> String {
        favor.isProposed && isMyOffer(favor) ? "Withdraw your offer?" : "Cancel this favor?"
    }

    private func cancelMessage(for favor: SupabaseService.Favor) -> String {
        let other = isMyOffer(favor) ? (favor.helped_name ?? "They") : (favor.helper_name ?? "They")
        return "\(other) will see it as cancelled. This can't be undone."
    }

    /// Runs a favor action with the signed-in user's id.
    private func act(_ action: @escaping (UUID) async -> Void) {
        guard let uid = appVM.userId else { return }
        Task {
            await action(uid)
            // Accept / decline / complete / cancel can change the badge count
            await notifications.refreshActionCount()
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
                            HistoryFavorRow(favor: favor, currentUserId: appVM.userId)
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
                        .foregroundColor(vm.historyFilter == filter ? FavoriumTheme.onGold : FavoriumTheme.ivory)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(vm.historyFilter == filter ? AnyShapeStyle(FavoriumTheme.goldGradient) : AnyShapeStyle(Color.clear))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(FavoriumTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(FavoriumTheme.accentMuted.opacity(0.25), lineWidth: 1))
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
                .foregroundColor(FavoriumTheme.accentMuted)
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
                // Who offered
                PersonAvatar(userId: favor.helper_id, name: favor.helper_name,
                             photo: favor.helper_avatar_url, size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(favor.helper_name ?? "Someone") offered to help")
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .metallicGoldCapsule()
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
            .overlay(isActing ? ProgressView().tint(FavoriumTheme.accent) : nil)
        }
        .padding(16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accentMuted.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Favor Status Card

/// A pending favor with a status badge and, when it's this user's turn, one action.
private struct FavorStatusCard: View {
    struct Action {
        let label: String
        let icon: String
        let isPrimary: Bool
        let perform: () -> Void
    }

    /// The other person in the favor (shown as their avatar)
    let personId: UUID
    let personName: String?
    let personPhoto: String?
    let title: String
    let description: String
    struct Cancel {
        let label: String
        let perform: () -> Void
    }

    let badge: (String, Color)
    let action: Action?
    let cancel: Cancel?
    let isActing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PersonAvatar(userId: personId, name: personName, photo: personPhoto, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Text(description)
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivory.opacity(0.85))
                        .lineLimit(2)
                    FavorStatusBadge(label: badge.0, color: badge.1)
                        .padding(.top, 2)
                }
            }

            if let action {
                Button(action: action.perform) {
                    HStack(spacing: 8) {
                        if isActing {
                            ProgressView().tint(action.isPrimary ? FavoriumTheme.onGold : FavoriumTheme.accent)
                        } else {
                            Image(systemName: action.icon)
                                .font(.system(size: 15))
                        }
                        Text(action.label)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .modifier(FavorActionStyle(isPrimary: action.isPrimary))
                }
                .disabled(isActing)
            }

            if let cancel {
                Button(cancel.label, role: .destructive, action: cancel.perform)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .frame(maxWidth: .infinity)
                    .disabled(isActing)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accentMuted.opacity(0.25), lineWidth: 1)
        )
    }
}

/// Gold capsule for the primary action, outlined capsule for secondary ones.
private struct FavorActionStyle: ViewModifier {
    let isPrimary: Bool

    func body(content: Content) -> some View {
        if isPrimary {
            content.metallicGoldCapsule()
        } else {
            content
                .foregroundColor(FavoriumTheme.accent)
                .overlay(Capsule().stroke(FavoriumTheme.accent.opacity(0.6), lineWidth: 1.5))
                .contentShape(Capsule())
        }
    }
}

// MARK: - History Row

private struct HistoryFavorRow: View {
    let favor: SupabaseService.Favor
    let currentUserId: UUID?

    private var iAmHelper: Bool { favor.helper_id == currentUserId }
    /// The other person in the favor
    private var otherId: UUID { iAmHelper ? favor.helped_id : favor.helper_id }
    private var otherName: String? { iAmHelper ? favor.helped_name : favor.helper_name }
    private var otherPhoto: String? { iAmHelper ? favor.helped_avatar_url : favor.helper_avatar_url }

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(userId: otherId, name: otherName, photo: otherPhoto, size: 48)

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
                    Image(systemName: statusLabel.icon)
                        .font(.system(size: 11))
                    Text(statusLabel.text)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(favor.isTransferred ? FavoriumTheme.accent : FavoriumTheme.ivoryDim)
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
                .stroke(FavoriumTheme.accentMuted.opacity(0.18), lineWidth: 1)
        )
    }

    /// Written from the signed-in user's side: "You helped Sam" / "Sam helped you"
    private var rowHeadline: String {
        let other = otherName ?? (iAmHelper ? "someone" : "Someone")
        if favor.isCompleted || favor.isTransferred {
            return iAmHelper ? "You helped \(other)" : "\(other) helped you"
        }
        if favor.isDeclined {
            return iAmHelper ? "\(other) declined your offer" : "You declined \(other)\u{2019}s offer"
        }
        if favor.isCancelled { return iAmHelper ? "Favor with \(other) cancelled" : "\(other)\u{2019}s favor cancelled" }
        return "Past favor"
    }

    private var statusLabel: (text: String, icon: String) {
        if favor.isTransferred { return ("Gem given", "gift") }
        if favor.isDeclined    { return ("Declined", "xmark.circle") }
        if favor.isCancelled   { return ("Cancelled", "minus.circle") }
        return ("Completed", "checkmark.circle")
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
        .environment(FavorNotificationCenter())
}
