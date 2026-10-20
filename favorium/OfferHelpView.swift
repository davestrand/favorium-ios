//
//  OfferHelpView.swift
//  favorium
//
//  "Offer help" sheet — step 1 of the favor flow. The signed-in user becomes
//  the helper on a new favor (propose_favor). The other person then accepts,
//  confirms it's done, and thanks the helper with a gem.
//

import SwiftUI

// MARK: - View Model

@Observable
final class OfferHelpViewModel {
    enum Step { case compose, sending, done, failed(String) }

    var recipient: SupabaseService.UserProfile?
    var message: String = ""

    /// People you've had favors with, most recent first
    var recentPeople: [SupabaseService.UserProfile] = []
    /// Everyone else you're connected with, alphabetical
    var otherConnections: [SupabaseService.UserProfile] = []
    var isLoadingPeople = false

    var searchQuery: String = ""
    var searchResults: [SupabaseService.UserProfile] = []
    var isSearching: Bool = false

    var step: Step = .compose

    var canSend: Bool {
        recipient != nil && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True once we have people to pick from without typing
    var hasKnownPeople: Bool { !recentPeople.isEmpty || !otherConnections.isEmpty }

    /// Known people filtered by the search box (case-insensitive name match)
    func filtered(_ people: [SupabaseService.UserProfile]) -> [SupabaseService.UserProfile] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return people }
        return people.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    /// Loads connections plus favor history so people can be picked without searching.
    @MainActor
    func loadPeople(userId: UUID?) async {
        guard let userId else { return }
        isLoadingPeople = true
        defer { isLoadingPeople = false }

        // Each source is optional — show whatever loads
        async let connectionsTask = try? SupabaseService.shared.myConnections(userId: userId)
        async let incomingTask    = try? SupabaseService.shared.myIncomingFavors(userId: userId)
        async let outgoingTask    = try? SupabaseService.shared.myOutgoingFavors(userId: userId)
        let connections = await connectionsTask ?? []
        let favors = ((await incomingTask) ?? []) + ((await outgoingTask) ?? [])

        // The other person on each favor, newest favor first, de-duplicated
        var seen = Set<UUID>()
        recentPeople = favors
            .sorted { $0.created_at > $1.created_at }
            .compactMap { favor -> SupabaseService.UserProfile? in
                let iAmHelper = favor.helper_id == userId
                let otherId   = iAmHelper ? favor.helped_id : favor.helper_id
                guard otherId != userId, seen.insert(otherId).inserted else { return nil }
                // Prefer the profile row from connections; fall back to the joined name
                return connections.first { $0.id == otherId }
                    ?? SupabaseService.UserProfile(
                        id: otherId,
                        display_name: iAmHelper ? favor.helped_name : favor.helper_name,
                        created_at: nil,
                        avatar_url: iAmHelper ? favor.helped_avatar_url : favor.helper_avatar_url
                    )
            }

        otherConnections = connections
            .filter { !seen.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Fallback search across all profiles, used only when no known people loaded.
    @MainActor
    func searchUsers() async {
        guard searchQuery.count >= 2 else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await SupabaseService.shared.searchUsers(query: searchQuery)) ?? []
    }

    @MainActor
    func send() async {
        guard let recipientId = recipient?.id else { return }
        step = .sending
        do {
            _ = try await SupabaseService.shared.proposeFavor(
                helpedUserId: recipientId,
                description: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            step = .done
        } catch {
            step = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Main View

struct OfferHelpView: View {
    let userId: UUID?
    let onComplete: () -> Void

    @State private var vm = OfferHelpViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            switch vm.step {
            case .compose:
                composeView
            case .sending:
                VStack(spacing: 20) {
                    ProgressView().tint(FavoriumTheme.accent).scaleEffect(1.6)
                    Text("Sending your offer…")
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
            case .done:
                doneView
                    // A natural moment to ask: they'll want to hear back
                    .task {
                        if PushManager.shared.canAskPermission {
                            await PushManager.shared.requestAuthorization()
                        }
                    }
            case .failed(let msg):
                failureView(msg)
            }
        }
        .task { await vm.loadPeople(userId: userId) }
    }

    // MARK: - Compose

    private var composeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                            .frame(width: 40, height: 40)
                            .background(FavoriumTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Offer help")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.top, 16)

                Text("Offer to do something kind for someone you're connected with. Once they accept and confirm it's done, they can thank you with a gem.")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)

                recipientField
                messageField

                Button {
                    Task { await vm.send() }
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Offer help")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
                    .opacity(vm.canSend ? 1.0 : 0.4)
                }
                .disabled(!vm.canSend)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Recipient field

    @ViewBuilder
    private var recipientField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who would you like to help?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)

            if let chosen = vm.recipient {
                HStack {
                    PersonAvatar(userId: chosen.id, name: chosen.displayName, photo: chosen.avatar_url, size: 28)
                    Text(chosen.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    Button { vm.recipient = nil; vm.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    }
                    .accessibilityLabel("Clear recipient")
                }
                .padding(12)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(FavoriumTheme.accent.opacity(0.4), lineWidth: 1))
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(FavoriumTheme.ivoryDim)
                    TextField(vm.hasKnownPeople ? "Filter by name" : "Search by name", text: $vm.searchQuery)
                        .foregroundColor(FavoriumTheme.ivory)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: vm.searchQuery) { _, _ in
                    // Known people filter locally; only hit the server when there's no list
                    if !vm.hasKnownPeople {
                        Task { await vm.searchUsers() }
                    }
                }

                if vm.isLoadingPeople {
                    ProgressView().tint(FavoriumTheme.accent).frame(maxWidth: .infinity).padding(.top, 4)
                } else if vm.hasKnownPeople {
                    knownPeopleList
                } else if vm.isSearching {
                    ProgressView().tint(FavoriumTheme.accent).padding(.top, 4)
                } else if !vm.searchResults.isEmpty {
                    peopleList(vm.searchResults)
                }
            }
        }
    }

    // MARK: - Known people

    @ViewBuilder
    private var knownPeopleList: some View {
        let recent = vm.filtered(vm.recentPeople)
        let others = vm.filtered(vm.otherConnections)

        if recent.isEmpty && others.isEmpty {
            Text("No one matches \u{201C}\(vm.searchQuery)\u{201D}.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .padding(.top, 4)
        }

        if !recent.isEmpty {
            Text("Recent")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FavoriumTheme.accentMuted)
                .padding(.top, 6)
            // Quick-pick avatars for people you've had favors with
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(recent) { person in
                        Button { choose(person) } label: {
                            VStack(spacing: 6) {
                                PersonAvatar(userId: person.id, name: person.displayName, photo: person.avatar_url, size: 52)
                                Text(person.displayName)
                                    .font(.system(size: 12))
                                    .foregroundColor(FavoriumTheme.ivory)
                                    .lineLimit(1)
                                    .frame(width: 64)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Offer help to \(person.displayName)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }

        if !others.isEmpty {
            Text(recent.isEmpty ? "Your connections" : "Other connections")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(FavoriumTheme.accentMuted)
                .padding(.top, 6)
            peopleList(others)
        }
    }

    private func peopleList(_ people: [SupabaseService.UserProfile]) -> some View {
        VStack(spacing: 0) {
            ForEach(people) { user in
                Button { choose(user) } label: {
                    HStack {
                        PersonAvatar(userId: user.id, name: user.displayName, photo: user.avatar_url, size: 28)
                        Text(user.displayName)
                            .font(.system(size: 15))
                            .foregroundColor(FavoriumTheme.ivory)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if user.id != people.last?.id {
                    Divider().background(FavoriumTheme.accentMuted.opacity(0.2))
                }
            }
        }
        .background(FavoriumTheme.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func choose(_ person: SupabaseService.UserProfile) {
        withAnimation(.easeInOut(duration: 0.2)) {
            vm.recipient = person
            vm.searchQuery = ""
            vm.searchResults = []
        }
    }

    // MARK: - Message field

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What will you do for them?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)

            ZStack(alignment: .topLeading) {
                if vm.message.isEmpty {
                    Text("I'd be happy to help with…")
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $vm.message)
                    .font(FavoriumTheme.bodyFont)
                    .foregroundColor(FavoriumTheme.ivory)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .frame(minHeight: 100)
            }
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Done / Failure

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(FavoriumTheme.accent)
            Text("Offer sent!")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
            Text("\(vm.recipient?.displayName ?? "They") will see your offer in their Favors tab.")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                onComplete()
                dismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundColor(FavoriumTheme.amber)
            Text("Couldn't send your offer")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(FavoriumTheme.ivory)
            Text(message)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation { vm.step = .compose }
            } label: {
                Text("Back")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

#Preview("Offer help") {
    OfferHelpView(userId: nil, onComplete: {})
}
