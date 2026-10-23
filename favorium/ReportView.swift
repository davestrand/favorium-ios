//
//  ReportView.swift
//  favorium
//
//  Reporting and blocking (IOS_CONTRACT §18, App Store guideline 1.2).
//  Reports are write-only; the server resolves who wrote an engraving, so the
//  app only ever sends the target's id.
//

import SwiftUI

// MARK: - Report

struct ReportView: View {
    let target: SupabaseService.ReportTarget
    let targetId: UUID
    /// "Alex", "this favor", "this message" — used in the heading
    let subject: String
    var onReported: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var reason: SupabaseService.ReportReason?
    @State private var details = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var sent = false

    private static let maxDetails = 500

    private var trimmedDetails: String { details.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var tooLong: Bool { trimmedDetails.unicodeScalars.count > Self.maxDetails }
    private var canSend: Bool { reason != nil && !tooLong && !isSaving }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()
            if sent { sentView } else { form }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FavoriumTheme.ivoryDim)
                    Spacer()
                }
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Report \(subject)")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)
                    Text(target == .engraving
                         ? "Reports are private. This message will also be hidden for you."
                         : "Reports are private. The other person isn\u{2019}t told who sent one.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    ForEach(SupabaseService.ReportReason.allCases) { option in
                        Button {
                            reason = option
                        } label: {
                            HStack {
                                Text(option.label)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(FavoriumTheme.ivory)
                                Spacer()
                                Image(systemName: reason == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(reason == option ? FavoriumTheme.accent : FavoriumTheme.ivoryDim.opacity(0.5))
                            }
                            .padding(14)
                            .background(FavoriumTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(reason == option ? .isSelected : [])
                    }
                }

                VStack(alignment: .trailing, spacing: 6) {
                    TextField("Anything else we should know? (optional)", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundColor(FavoriumTheme.ivory)
                        .padding(14)
                        .background(FavoriumTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                        .overlay(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                            .stroke(tooLong ? FavoriumTheme.amber : FavoriumTheme.accentMuted.opacity(0.4), lineWidth: 1))
                    Text("\(trimmedDetails.unicodeScalars.count)/\(Self.maxDetails)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundColor(tooLong ? FavoriumTheme.amber : FavoriumTheme.ivoryDim)
                }

                if let error {
                    Text(error)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.amber)
                }

                Button(action: send) {
                    HStack {
                        if isSaving { ProgressView().tint(FavoriumTheme.onGold) } else { Image(systemName: "flag.fill") }
                        Text("Send report").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
                    .opacity(canSend ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var sentView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 54))
                .foregroundColor(FavoriumTheme.accent)
            Text("Thank you")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
            Text(target == .user
                 ? "We\u{2019}ll look into it. If you don\u{2019}t want to hear from them again, you can also block them."
                 : "We\u{2019}ll look into it.")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            Button {
                onReported()
                dismiss()
            } label: {
                Text("Done").fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func send() {
        guard let reason, canSend else { return }
        isSaving = true
        error = nil
        Task {
            do {
                try await SupabaseService.shared.reportContent(
                    target: target, targetId: targetId, reason: reason,
                    details: trimmedDetails.isEmpty ? nil : trimmedDetails
                )
                withAnimation(.easeInOut(duration: 0.3)) { sent = true }
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
            isSaving = false
        }
    }
}

// MARK: - Block

/// Someone the user might report or block
struct SafetyPerson: Identifiable, Equatable {
    let id: UUID
    let name: String
}

/// The report sheet and block confirmation for a person. Blocking cancels open favors
/// between you, so it always asks first and then says how many were cancelled.
struct PersonSafetyActions: ViewModifier {
    @Binding var reporting: SafetyPerson?
    @Binding var blocking: SafetyPerson?
    var onBlocked: () -> Void = {}

    @State private var outcome: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: $reporting) { person in
                ReportView(target: .user, targetId: person.id, subject: person.name)
            }
            .confirmationDialog(
                blocking.map { "Block \($0.name)?" } ?? "",
                isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } }),
                titleVisibility: .visible,
                presenting: blocking
            ) { person in
                Button("Block", role: .destructive) { block(person) }
                Button("Not now", role: .cancel) { }
            } message: { _ in
                Text("You won\u{2019}t see each other in your circles or be able to offer favors to each other. Any open favors between you will be cancelled. Gems that already moved stay where they are.")
            }
            .alert("Blocked", isPresented: Binding(get: { outcome != nil }, set: { if !$0 { outcome = nil } })) {
                Button("OK") { onBlocked() }
            } message: {
                Text(outcome ?? "")
            }
    }

    private func block(_ person: SafetyPerson) {
        Task {
            do {
                let result = try await SupabaseService.shared.blockUser(person.id)
                let cancelled = result.cancelled_favors ?? 0
                outcome = switch cancelled {
                case 0:  "\(person.name) is blocked. You can unblock them from Connect."
                case 1:  "\(person.name) is blocked, and 1 open favor between you was cancelled."
                default: "\(person.name) is blocked, and \(cancelled) open favors between you were cancelled."
                }
            } catch {
                outcome = SupabaseService.errorMessage(error)
            }
        }
    }
}

extension View {
    func personSafetyActions(reporting: Binding<SafetyPerson?>, blocking: Binding<SafetyPerson?>,
                             onBlocked: @escaping () -> Void = {}) -> some View {
        modifier(PersonSafetyActions(reporting: reporting, blocking: blocking, onBlocked: onBlocked))
    }
}

// MARK: - Blocked people

struct BlockedPeopleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var people: [SupabaseService.BlockedPerson] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var unblocking: Set<UUID> = []

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button("Done") { dismiss() }
                            .foregroundColor(FavoriumTheme.accent)
                        Spacer()
                    }
                    .padding(.top, 16)

                    Text("Blocked people")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)

                    if isLoading {
                        ProgressView().tint(FavoriumTheme.accent).frame(maxWidth: .infinity)
                    } else if let error {
                        Text(error)
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.amber)
                    } else if people.isEmpty {
                        Text("You haven\u{2019}t blocked anyone.")
                            .font(FavoriumTheme.bodyFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    } else {
                        Text("Unblocking doesn\u{2019}t bring back favors that were cancelled.")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                        VStack(spacing: 0) {
                            ForEach(people) { person in
                                HStack(spacing: 12) {
                                    PersonAvatar(userId: person.user_id, name: person.display_name,
                                                 photo: person.avatar_url, size: 44)
                                    Text(person.display_name ?? "Someone")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(FavoriumTheme.ivory)
                                    Spacer()
                                    Button("Unblock") { unblock(person) }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(FavoriumTheme.accent)
                                        .disabled(unblocking.contains(person.user_id))
                                }
                                .padding(.vertical, 10)
                                if person.id != people.last?.id {
                                    Divider().overlay(FavoriumTheme.accentMuted.opacity(0.2))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            people = try await SupabaseService.shared.myBlocks()
        } catch {
            self.error = SupabaseService.errorMessage(error)
        }
        isLoading = false
    }

    private func unblock(_ person: SupabaseService.BlockedPerson) {
        unblocking.insert(person.user_id)
        Task {
            do {
                try await SupabaseService.shared.unblockUser(person.user_id)
                withAnimation { people.removeAll { $0.id == person.id } }
            } catch {
                self.error = SupabaseService.errorMessage(error)
            }
            unblocking.remove(person.user_id)
        }
    }
}

#Preview("Report") {
    ReportView(target: .user, targetId: UUID(), subject: "Alex")
}
