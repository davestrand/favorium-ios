//
//  SendGemView.swift
//  favorium
//
//  Send-a-gem sheet: recipient selection, purpose (thank / ask), message,
//  and review step. Maps to transfer_coin RPC on the existing backend.
//  Does NOT invent new statuses — uses propose_favor + transfer_coin as on web.
//

import SwiftUI

// MARK: - View Model

@Observable
final class SendGemViewModel {
    enum Purpose { case thank, ask }
    enum Step    { case compose, review, sending, done, failed(String) }

    // Form state
    var recipient: SupabaseService.UserProfile?
    var purpose: Purpose = .thank
    var message: String = ""

    // Search
    var searchQuery: String = ""
    var searchResults: [SupabaseService.UserProfile] = []
    var isSearching: Bool = false

    // Flow
    var step: Step = .compose

    @MainActor
    func searchUsers() async {
        guard searchQuery.count >= 2 else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        searchResults = (try? await SupabaseService.shared.searchUsers(query: searchQuery)) ?? []
    }

    @MainActor
    func send(coinId: UUID, fromUserId: UUID?) async {
        guard let recipientId = recipient?.id,
              fromUserId != nil else {
            step = .failed("Missing required information.")
            return
        }

        step = .sending

        do {
            // 1. Propose the favor (creates the favor record)
            let favorId = try await SupabaseService.shared.proposeFavor(
                helpedUserId: recipientId,
                description: message.isEmpty ? purposeDefaultMessage : message
            )

            // 2. Transfer the gem (links gem to the favor + transfers ownership)
            try await SupabaseService.shared.transferCoin(favorId: favorId, coinId: coinId)

            step = .done
        } catch {
            step = .failed(error.localizedDescription)
        }
    }

    var canProceedToReview: Bool {
        recipient != nil && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var purposeDefaultMessage: String {
        switch purpose {
        case .thank: return "Thank you"
        case .ask:   return "I'd love your help with something"
        }
    }
}

// MARK: - Main View

struct SendGemView: View {
    let coinId: UUID
    let coinName: String
    let transferCount: Int
    let userId: UUID?
    let onComplete: () -> Void

    @State private var vm = SendGemViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FavoriumTheme.background.ignoresSafeArea()

                switch vm.step {
                case .compose:
                    composeView
                case .review:
                    reviewView
                case .sending:
                    sendingView
                case .done:
                    doneView
                case .failed(let msg):
                    failureView(msg)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Compose step

    private var composeView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                            .frame(width: 40, height: 40)
                            .background(FavoriumTheme.surface)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Send a gem")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    // Balance
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 16)

                // Gem preview
                gemPreview
                    .padding(.bottom, 24)

                // Form fields
                VStack(spacing: 20) {
                    recipientField
                    purposeField
                    messageField
                }
                .padding(.horizontal, 20)

                // Review button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.step = .review
                    }
                } label: {
                    HStack {
                        Text("Review gift")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(vm.canProceedToReview ? FavoriumTheme.teal : FavoriumTheme.tealMuted.opacity(0.4))
                    .clipShape(Capsule())
                }
                .disabled(!vm.canProceedToReview)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Gem preview

    private var gemPreview: some View {
        let tier = Tier.from(transferCount: transferCount)
        let gemColor = tier.defaultColor
        return VStack(spacing: 10) {
            ZStack {
                RadialGradient(
                    colors: [gemColor.opacity(0.18), .clear],
                    center: .center, startRadius: 20, endRadius: 130
                )
                .frame(width: 260, height: 260)
                .blur(radius: 20)

                AnimatedFavorGemView(
                    gemFamily: .lightning,
                    tier: tier,
                    gemColor: gemColor,
                    size: 180
                )
            }
            Text(coinName)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
            Text("Heart · \(tier.displayName)")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(tier.defaultColor)
            Text("A gem of kindness, gratitude and bright connections.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Recipient field

    @ViewBuilder
    private var recipientField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)

            if let chosen = vm.recipient {
                // Chosen — show chip with clear button
                HStack {
                    Circle()
                        .fill(FavoriumTheme.teal.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(chosen.displayName.prefix(1)).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(FavoriumTheme.teal)
                        )
                    Text(chosen.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                    Spacer()
                    Button { vm.recipient = nil; vm.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
                .padding(12)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(FavoriumTheme.teal.opacity(0.4), lineWidth: 1))

            } else {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(FavoriumTheme.ivoryDim)
                    TextField("Search by name", text: $vm.searchQuery)
                        .foregroundColor(FavoriumTheme.ivory)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: vm.searchQuery) { _, _ in
                    Task { await vm.searchUsers() }
                }

                if vm.isSearching {
                    ProgressView().tint(FavoriumTheme.teal).padding(.top, 4)
                } else if !vm.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.searchResults) { user in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.recipient = user
                                    vm.searchQuery = ""
                                    vm.searchResults = []
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(FavoriumTheme.tealMuted.opacity(0.3))
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Text(String(user.displayName.prefix(1)).uppercased())
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(FavoriumTheme.teal)
                                        )
                                    Text(user.displayName)
                                        .font(.system(size: 15))
                                        .foregroundColor(FavoriumTheme.ivory)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if user.id != vm.searchResults.last?.id {
                                Divider().background(FavoriumTheme.tealMuted.opacity(0.2))
                            }
                        }
                    }
                    .background(FavoriumTheme.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Purpose field

    private var purposeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purpose")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)

            HStack(spacing: 10) {
                PurposeButton(
                    label: "Thank someone",
                    icon: "heart",
                    isSelected: vm.purpose == .thank,
                    action: { withAnimation { vm.purpose = .thank } }
                )
                PurposeButton(
                    label: "Ask a favor",
                    icon: "sparkles",
                    isSelected: vm.purpose == .ask,
                    action: { withAnimation { vm.purpose = .ask } }
                )
            }
        }
    }

    // MARK: - Message field

    private var messageField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your message")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)

            ZStack(alignment: .topLeading) {
                if vm.message.isEmpty {
                    Text(vm.purpose == .thank
                         ? "Thank you for helping with…"
                         : "I'd love your help with…")
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
                    .frame(minHeight: 80)
            }
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Review step

    private var reviewView: some View {
        VStack(spacing: 0) {
            // Nav
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { vm.step = .compose }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                        .frame(width: 40, height: 40)
                        .background(FavoriumTheme.surface)
                        .clipShape(Circle())
                }
                Spacer()
                Text("Review gift")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 24)

            // Review card
            VStack(spacing: 16) {
                gemPreview
                    .padding(.bottom, 8)

                VStack(spacing: 12) {
                    reviewRow(label: "To",      value: vm.recipient?.displayName ?? "—")
                    reviewRow(label: "Purpose", value: vm.purpose == .thank ? "Thank someone" : "Ask a favor")
                    reviewRow(label: "Message", value: vm.message)
                }
                .padding(16)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
                .padding(.horizontal, 20)
            }

            Spacer()

            // Confirm send
            Button {
                Task { await vm.send(coinId: coinId, fromUserId: userId) }
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send gem")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FavoriumTheme.teal)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func reviewRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(FavoriumTheme.ivoryDim)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
        }
    }

    // MARK: - Sending / Done / Failure

    private var sendingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .tint(FavoriumTheme.teal)
                .scaleEffect(1.6)
            Text("Sending gem…")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
            Spacer()
        }
    }

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(FavoriumTheme.teal)
                .transition(.scale.combined(with: .opacity))

            Text("Gem sent!")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)

            Text("Your gem is on its way to \(vm.recipient?.displayName ?? "them").")
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
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FavoriumTheme.teal)
                    .clipShape(Capsule())
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
            Text("Something went wrong")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(FavoriumTheme.ivory)
            Text(message)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    withAnimation { vm.step = .compose }
                } label: {
                    Text("Edit")
                        .fontWeight(.semibold)
                        .foregroundColor(FavoriumTheme.ivory)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FavoriumTheme.surface)
                        .clipShape(Capsule())
                }
                Button {
                    Task { await vm.send(coinId: coinId, fromUserId: userId) }
                } label: {
                    Text("Try again")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FavoriumTheme.teal)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Purpose Button

private struct PurposeButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .black : FavoriumTheme.ivory)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? FavoriumTheme.teal : FavoriumTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : FavoriumTheme.tealMuted.opacity(0.4),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Send Gem") {
    SendGemView(
        coinId: UUID(),
        coinName: "Rainbow Heart",
        transferCount: 8,
        userId: nil,
        onComplete: {}
    )
}
