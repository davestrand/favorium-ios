//
//  ConnectView.swift
//  favorium
//
//  "Pair with someone" — the iOS side of PAIRING_CONTRACT. Three blocks:
//  invite with your code (QR + countdown), redeem someone else's code, and
//  "your circle" (real pairings only, read from `connections`).
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - Code rules

enum PairingCodeRules {
    static let length = 6

    /// The QR deep link (contract §5: `{origin}/connect?code=CODE`).
    static func connectURL(for code: String) -> String {
        "\(FavoriumWeb.origin)/connect?code=\(code)"
    }

    /// Matches the web: uppercase → strip everything outside A–Z / 0–9 → truncate to 6.
    static func normalize(_ raw: String) -> String {
        let kept = raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return String(kept.prefix(length))
    }
}

// MARK: - View model

@Observable
final class ConnectViewModel {
    enum Invite: Equatable {
        case checking
        case empty
        case creating
        /// `expiresAt` is on the local clock so the countdown starts at 10:00, not 09:58
        case live(code: String, expiresAt: Date)
        /// Seen by polling our own code row (contract §6.3)
        case paired(name: String)
    }

    enum CircleState: Equatable { case loading, loaded, failed(String) }

    var invite: Invite = .checking
    var inviteError: String?
    var copied = false

    var codeInput = "" {
        didSet {
            let normalized = PairingCodeRules.normalize(codeInput)
            if normalized != codeInput { codeInput = normalized }
        }
    }
    var isRedeeming = false
    var redeemError: String?
    var redeemSuccess: String?

    var circle: [SupabaseService.CircleMember] = []
    var circleState: CircleState = .loading

    var canRedeem: Bool { codeInput.count == PairingCodeRules.length && !isRedeeming }

    // MARK: Invite

    /// Restores a still-valid code so reopening doesn't silently replace a QR someone is scanning.
    func restoreInvite(userId: UUID) async {
        do {
            if let active = try await SupabaseService.shared.activePairingCode(userId: userId),
               let expiry = active.expiresAt {
                invite = .live(code: active.code, expiresAt: expiry)
            } else {
                invite = .empty
            }
        } catch {
            invite = .empty
            inviteError = "Could not check for an active code"
        }
    }

    /// Creates (or replaces) your code. Replacing expires the previous one server-side.
    func createCode() async {
        let previous = invite
        invite = .creating
        inviteError = nil
        do {
            let created = try await SupabaseService.shared.createPairingCode()
            let received = Date()
            // Trust the server's lifetime, but run it on our clock so device skew can't show 09:58
            let serverRemaining = created.expiresAt.map { $0.timeIntervalSince(received) } ?? 600
            let remaining = min(max(serverRemaining, 0), 600)
            invite = .live(code: created.code, expiresAt: received.addingTimeInterval(remaining))
        } catch {
            if case .live = previous { invite = previous } else { invite = .empty }
            inviteError = "Could not create a pairing code"
        }
    }

    func copy(_ code: String) async {
        UIPasteboard.general.string = code
        copied = true
        try? await Task.sleep(for: .seconds(2))
        copied = false
    }

    /// While a live code is on screen, checks every few seconds whether someone redeemed it,
    /// so the card can flip to "Paired with …". Ends on expiry, replacement, or cancellation.
    func watchForRedemption(code: String, expiresAt: Date, userId: UUID) async {
        while !Task.isCancelled, Date() < expiresAt {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, case .live(let current, _) = invite, current == code else { return }
            guard let redeemer = try? await SupabaseService.shared.pairingCodeRedeemer(code: code) else { continue }
            let profile = try? await SupabaseService.shared.getUserProfile(userId: redeemer)
            invite = .paired(name: Self.name(from: profile))
            await loadCircle(userId: userId)
            return
        }
    }

    // MARK: Redeem

    func redeem(userId: UUID) async {
        guard codeInput.count == PairingCodeRules.length else {
            redeemError = "A pairing code has 6 characters."
            return
        }
        isRedeeming = true
        redeemError = nil
        redeemSuccess = nil
        defer { isRedeeming = false }

        do {
            let otherId = try await SupabaseService.shared.redeemPairingCode(codeInput)
            let profile = try? await SupabaseService.shared.getUserProfile(userId: otherId)
            codeInput = ""
            redeemSuccess = "You are now paired with \(Self.name(from: profile))."
        } catch {
            // Server messages are shown verbatim, matching the web
            redeemError = error.localizedDescription
        }
        // Always reload: the server burns the code before replying, so a dropped
        // connection can still have paired you — the list is the source of truth.
        await loadCircle(userId: userId)
    }

    // MARK: Circle

    func loadCircle(userId: UUID) async {
        do {
            circle = try await SupabaseService.shared.myCircle(userId: userId)
            circleState = .loaded
        } catch {
            // Keep whatever is already on screen; only an empty list shows the failure
            if circle.isEmpty { circleState = .failed("Could not load your connections") }
        }
    }

    private static func name(from profile: SupabaseService.UserProfile?) -> String {
        let trimmed = profile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "your new connection" : trimmed
    }
}

// MARK: - View

struct ConnectView: View {
    let userId: UUID?

    @State private var vm: ConnectViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var codeFieldFocused: Bool

    /// `viewModel` is injectable so previews can show each state without a session.
    init(userId: UUID?, viewModel: ConnectViewModel = ConnectViewModel()) {
        self.userId = userId
        _vm = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pair with someone")
                            .font(.system(size: 26, weight: .light).width(.expanded))
                            .foregroundColor(FavoriumTheme.ivory)
                        Text("Pairing links two people so favors can flow between them. Share your code with somebody in front of you, or type the code they show you.")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    inviteCard
                    redeemCard
                    circleSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                if let userId { await vm.loadCircle(userId: userId) }
            }
        }
        .task {
            guard let userId else { return }
            async let restore: Void = vm.restoreInvite(userId: userId)
            async let circle: Void = vm.loadCircle(userId: userId)
            _ = await (restore, circle)
        }
        // Polls only while a live code is showing; restarts when the code changes
        .task(id: vm.invite) {
            guard let userId, case .live(let code, let expiresAt) = vm.invite else { return }
            await vm.watchForRedemption(code: code, expiresAt: expiresAt, userId: userId)
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
            Text("Connect")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 16)
    }

    // MARK: Invite card

    private var inviteCard: some View {
        DecoCard {
            CardHeading(icon: "qrcode", title: "Invite with your code", subtitle: "Valid for 10 minutes, one person.")

            switch vm.invite {
            case .checking:
                ProgressView()
                    .tint(FavoriumTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            case .empty, .creating:
                VStack(spacing: 14) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(FavoriumTheme.accent)
                        .frame(width: 64, height: 64)
                        .background(FavoriumTheme.accent.opacity(0.12))
                        .clipShape(Circle())
                    Text("Create a one-time code and a QR to show. Whoever scans or types it becomes your connection.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    goldButton(vm.invite == .creating ? "Creating…" : "Create my pairing code",
                               disabled: vm.invite == .creating) {
                        Task { await vm.createCode() }
                    }
                }
                .frame(maxWidth: .infinity)
            case .live(let code, let expiresAt):
                liveCode(code, expiresAt: expiresAt)
            case .paired(let name):
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(FavoriumTheme.goldGradient)
                    Text("Paired with \(name)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                        .multilineTextAlignment(.center)
                    outlineButton("Create another code") { Task { await vm.createCode() } }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if let error = vm.inviteError {
                InlineError(message: error)
            }
        }
    }

    private func liveCode(_ code: String, expiresAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let secondsLeft = max(0, Int(ceil(expiresAt.timeIntervalSince(context.date))))
            let expired = secondsLeft == 0

            VStack(spacing: 14) {
                QRCodeImage(text: PairingCodeRules.connectURL(for: code))
                    .frame(width: 208, height: 208)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    .opacity(expired ? 0.3 : 1)
                    .allowsHitTesting(!expired)
                    .accessibilityLabel("QR code for pairing code \(code.map(String.init).joined(separator: " "))")

                Text(code)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .tracking(8)
                    .foregroundColor(expired ? FavoriumTheme.ivoryDim : FavoriumTheme.ivory)
                    .accessibilityLabel(code.map(String.init).joined(separator: " "))

                Text(expired ? "Expired" : String(format: "Expires in %02d:%02d", secondsLeft / 60, secondsLeft % 60))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundColor(expired ? FavoriumTheme.ivoryDim : FavoriumTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background((expired ? FavoriumTheme.ivoryDim : FavoriumTheme.accent).opacity(0.14))
                    .clipShape(Capsule())

                HStack(spacing: 10) {
                    if !expired {
                        outlineButton(vm.copied ? "Copied" : "Copy code",
                                      icon: vm.copied ? "checkmark" : "doc.on.doc") {
                            Task { await vm.copy(code) }
                        }
                    }
                    if expired {
                        goldButton("New code") { Task { await vm.createCode() } }
                    } else {
                        outlineButton("Replace code", icon: "arrow.clockwise") { Task { await vm.createCode() } }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Redeem card

    private var redeemCard: some View {
        DecoCard {
            CardHeading(icon: "key", title: "Have a code?", subtitle: "Type the 6 characters they show you.")

            CodeSlots(code: $vm.codeInput, isFocused: $codeFieldFocused)
                .onSubmit { submitCode() }

            goldButton(vm.isRedeeming ? "Connecting…" : "Connect with this code", disabled: !vm.canRedeem) {
                submitCode()
            }

            if let error = vm.redeemError {
                InlineError(message: error)
            }
            if let success = vm.redeemSuccess {
                Label(success, systemImage: "checkmark.circle.fill")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.accent)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .foregroundColor(FavoriumTheme.accentMuted)
                Text("Codes are single-use and expire after 10 minutes. You can never redeem your own code, and pairing only ever links two real accounts.")
                    .font(.system(size: 12))
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(FavoriumTheme.surfaceHigh.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
        }
    }

    private func submitCode() {
        guard let userId, vm.canRedeem else { return }
        codeFieldFocused = false
        Task { await vm.redeem(userId: userId) }
    }

    // MARK: Circle

    private var circleSection: some View {
        DecoCard {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your circle")
                        .font(.system(size: 11, weight: .semibold).width(.expanded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundColor(FavoriumTheme.accent)
                    Text("People you are paired with")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivory)
                }
                Spacer()
                if case .loaded = vm.circleState, !vm.circle.isEmpty {
                    Text("\(vm.circle.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FavoriumTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(FavoriumTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            switch vm.circleState {
            case .loading:
                ProgressView()
                    .tint(FavoriumTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            case .failed(let message):
                InlineError(message: message)
            case .loaded where vm.circle.isEmpty:
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(FavoriumTheme.accentMuted)
                    Text("No one paired yet")
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            case .loaded:
                VStack(spacing: 0) {
                    ForEach(vm.circle) { member in
                        HStack(spacing: 12) {
                            PersonAvatar(userId: member.id, name: member.displayName, photo: member.avatarURL,
                                         level: member.helperLevel, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(FavoriumTheme.ivory)
                                Text("Paired \(pairedDate(member.pairedAt))")
                                    .font(FavoriumTheme.captionFont)
                                    .foregroundColor(FavoriumTheme.ivoryDim)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                        if member.id != vm.circle.last?.id {
                            Divider().overlay(FavoriumTheme.accentMuted.opacity(0.2))
                        }
                    }
                }
            }
        }
    }

    private func pairedDate(_ raw: String) -> String {
        guard let date = SupabaseService.PairingCode.parseTimestamp(raw) else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: Buttons

    private func goldButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .metallicGoldCapsule()
                .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func outlineButton(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    Label(title, systemImage: icon)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(FavoriumTheme.goldGradient, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Building blocks

/// Navy (or cream) panel with a fine gold rim, used for each block on the screen.
private struct DecoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FavoriumTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                    .stroke(FavoriumTheme.accentMuted.opacity(0.3), lineWidth: 1)
            )
    }
}

private struct CardHeading: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(FavoriumTheme.accent)
                .frame(width: 44, height: 44)
                .background(FavoriumTheme.accent.opacity(0.12))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
        }
    }
}

/// Tinted inline error block — the contract asks for no alerts.
private struct InlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(FavoriumTheme.amber)
            Text(message)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivory)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(FavoriumTheme.amber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
    }
}

/// Six monospaced slots over a hidden text field, so pasting "abc-123" lands as ABC123.
private struct CodeSlots: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<PairingCodeRules.length, id: \.self) { index in
                    let character = index < code.count
                        ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
                    let isNext = isFocused.wrappedValue && index == min(code.count, PairingCodeRules.length - 1)
                    Text(character)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(FavoriumTheme.ivory)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FavoriumTheme.background.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isNext ? FavoriumTheme.accent : FavoriumTheme.accentMuted.opacity(0.35),
                                        lineWidth: isNext ? 1.5 : 1)
                        )
                }
            }
            .accessibilityHidden(true)

            // Real input, invisible: it owns focus, the keyboard, paste and VoiceOver
            TextField("Pairing code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.go)
                .focused(isFocused)
                .foregroundColor(.clear)
                .tint(.clear)
                .opacity(0.02)
                .frame(height: 52)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused.wrappedValue = true }
    }
}

/// Crisp QR for the pairing deep link: error correction M, ink #2a2118 on white (contract §5).
private struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.white
        }
    }

    private static func render(_ text: String) -> UIImage? {
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(text.utf8)
        generator.correctionLevel = "M"

        let colorize = CIFilter.falseColor()
        colorize.inputImage = generator.outputImage
        colorize.color0 = CIColor(red: 0x2a / 255, green: 0x21 / 255, blue: 0x18 / 255)
        colorize.color1 = CIColor(red: 1, green: 1, blue: 1)

        guard let output = colorize.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview("Live code") {
    let vm = ConnectViewModel()
    vm.invite = .live(code: "K7QX4M", expiresAt: .now.addingTimeInterval(542))
    vm.codeInput = "AB3"
    vm.circleState = .loaded
    vm.circle = [
        .init(id: UUID(), displayName: "Bilbo", avatarURL: nil, pairedAt: "2026-10-18T15:02:00+00:00"),
        .init(id: UUID(), displayName: "Jellybean", avatarURL: nil, pairedAt: "2026-09-30T09:12:00+00:00"),
    ]
    return ConnectView(userId: nil, viewModel: vm)
}

#Preview("No code yet") {
    let vm = ConnectViewModel()
    vm.invite = .empty
    vm.redeemError = "This code is invalid or has expired"
    vm.circleState = .loaded
    return ConnectView(userId: nil, viewModel: vm)
}
