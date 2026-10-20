//
//  ProfileTabView.swift
//  favorium
//
//  Profile tab — wraps the existing auth-aware profile experience
//  in the midnight-teal shell. Sign-out delegates to AuthViewModel.
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Stats model

@Observable
final class ProfileStatsModel {
    var gemsHeld: Int?
    var originals: Int?
    var favors: Int?

    /// Loads the three counts in parallel. Each is optional: a failed fetch shows "–"
    /// rather than blocking the others.
    @MainActor
    func load(userId: UUID?) async {
        guard let userId else { return }
        let service = SupabaseService.shared
        async let held      = try? service.myFavors(userId: userId)
        async let created   = try? service.myOriginals(userId: userId)
        async let incoming  = try? service.myIncomingFavors(userId: userId)
        async let outgoing  = try? service.myOutgoingFavors(userId: userId)

        gemsHeld  = await held?.count
        originals = await created?.count

        // Favors that finished with a gem, in either direction
        let inDone  = await incoming?.filter(\.isTransferred)
        let outDone = await outgoing?.filter(\.isTransferred)
        if inDone != nil || outDone != nil {
            favors = Set(((inDone ?? []) + (outDone ?? [])).map(\.id)).count
        }
    }
}

struct ProfileTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showSignOutConfirm = false
    @State private var stats = ProfileStatsModel()
    @State private var push = PushManager.shared
    // Profile photo
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSavingPhoto = false
    @State private var photoError: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()

                ScrollView {
                    VStack(spacing: 0) {
                        // ── Header ────────────────────────────────────
                        StarfieldHeader(title: "Profile", subtitle: appVM.displayName)
                            .padding(.top, 28)
                            .padding(.bottom, 24)

                        // ── Avatar / name ─────────────────────────────
                        avatarSection
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)

                        // ── Stats row ─────────────────────────────────
                        statsRow
                            .padding(.horizontal, 16)
                            .padding(.bottom, 28)

                        // ── Settings rows ─────────────────────────────
                        settingsSection
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)

                        // ── Sign out ──────────────────────────────────
                        signOutButton
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                    }
                }
                .refreshable { await stats.load(userId: appVM.userId) }
            }
            .navigationBarHidden(true)
            // Re-runs whenever the tab appears, so counts reflect gems just given or received
            .task { await stats.load(userId: appVM.userId) }
            .confirmationDialog(
                "Sign out of Favorium?",
                isPresented: $showSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await appVM.signOut(authVM: authVM) }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            // Same avatar others see for you — tap to add or change your photo
            Button { showPhotoPicker = true } label: {
                PersonAvatar(userId: appVM.userId, name: appVM.displayName, photo: appVM.avatarURL, size: 88)
                    .overlay {
                        if isSavingPhoto {
                            Circle().fill(.black.opacity(0.45))
                            ProgressView().tint(FavoriumTheme.ivory)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FavoriumTheme.onGold)
                            .frame(width: 28, height: 28)
                            .background(FavoriumTheme.goldGradient)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(FavoriumTheme.background, lineWidth: 2))
                    }
                    .shadow(color: FavoriumTheme.accent.opacity(0.25), radius: 16)
            }
            .buttonStyle(.plain)
            .disabled(isSavingPhoto)
            .accessibilityLabel(appVM.avatarURL == nil ? "Add profile photo" : "Change profile photo")

            HStack(spacing: 16) {
                Button(appVM.avatarURL == nil ? "Add photo" : "Change photo") { showPhotoPicker = true }
                if appVM.avatarURL != nil {
                    Button("Remove photo", role: .destructive) { removePhoto() }
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(FavoriumTheme.accent)
            .disabled(isSavingPhoto)

            if let photoError {
                Text(photoError)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.amber)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 4) {
                Text(appVM.displayName.isEmpty ? "Your name" : appVM.displayName)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
                    .multilineTextAlignment(.center)

                if !appVM.email.isEmpty {
                    Label(appVM.email, systemImage: "envelope")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            savePhoto(item)
        }
    }

    // MARK: - Photo upload (IOS_CONTRACT §11a)

    private func savePhoto(_ item: PhotosPickerItem) {
        guard let userId = appVM.userId else { return }
        isSavingPhoto = true
        photoError = nil
        Task {
            defer { isSavingPhoto = false; photoItem = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let jpeg = AvatarImage.squareJPEG(from: data) else {
                    photoError = "That photo couldn\u{2019}t be read. Try another one."
                    return
                }
                appVM.avatarURL = try await SupabaseService.shared.uploadAvatar(jpeg: jpeg, userId: userId)
            } catch {
                photoError = "Couldn\u{2019}t save your photo: \(error.localizedDescription)"
            }
        }
    }

    private func removePhoto() {
        isSavingPhoto = true
        photoError = nil
        Task {
            defer { isSavingPhoto = false }
            do {
                try await SupabaseService.shared.clearAvatar()
                appVM.avatarURL = nil
            } catch {
                photoError = "Couldn\u{2019}t remove your photo: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: stats.gemsHeld, label: "Gems held", icon: "diamond")
            Divider()
                .background(FavoriumTheme.accentMuted.opacity(0.3))
                .frame(height: 40)
            statCell(value: stats.originals, label: "Originals", icon: "star")
            Divider()
                .background(FavoriumTheme.accentMuted.opacity(0.3))
                .frame(height: 40)
            statCell(value: stats.favors, label: "Favors", icon: "heart")
        }
        .padding(.vertical, 16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accentMuted.opacity(0.2), lineWidth: 1)
        )
    }

    private func statCell(value: Int?, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(FavoriumTheme.accent)
            // "–" until loaded (or if that count couldn't be fetched)
            Text(value.map(String.init) ?? "–")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: value)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value.map(String.init) ?? "loading")")
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 1) {
            notificationsRow
            settingsRow(icon: "lock", label: "Privacy")
            settingsRow(icon: "questionmark.circle", label: "Help & Feedback")
            settingsRow(icon: "info.circle", label: "About Favorium")
        }
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accentMuted.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Notifications

    private var notificationsEnabled: Bool {
        push.authorizationStatus == .authorized || push.authorizationStatus == .provisional
            || push.authorizationStatus == .ephemeral
    }

    /// Never asked → show the system prompt. Allowed or denied → open the app's
    /// notification settings (iOS only lets an app ask once).
    private var notificationsRow: some View {
        Button {
            if push.canAskPermission {
                Task { await push.requestAuthorization() }
            } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: notificationsEnabled ? "bell.badge" : "bell.slash")
                    .font(.system(size: 16))
                    .foregroundColor(FavoriumTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(FavoriumTheme.bodyFont)
                        .foregroundColor(FavoriumTheme.ivory)
                    Text(notificationsEnabled
                         ? "New offers and gems you receive"
                         : (push.canAskPermission ? "Tap to turn on" : "Turn on in Settings"))
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
                Spacer()
                Text(notificationsEnabled ? "On" : "Off")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(notificationsEnabled ? FavoriumTheme.accent : FavoriumTheme.ivoryDim)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Re-check when returning from iOS Settings, where the user may have flipped it
        .task(id: scenePhase) {
            if scenePhase == .active { await push.refreshAuthorizationStatus() }
        }
        .accessibilityLabel("Notifications, \(notificationsEnabled ? "on" : "off")")
    }

    private func settingsRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(FavoriumTheme.accent)
                .frame(width: 24)
            Text(label)
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button { showSignOutConfirm = true } label: {
            Text("Sign Out")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(FavoriumTheme.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                        .stroke(FavoriumTheme.amber.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview("Profile") {
    @Previewable @State var appVM = AppViewModel()
    @Previewable @State var authVM = AuthViewModel()
    ProfileTabView()
        .environment(appVM)
        .environment(authVM)
}

// MARK: - Avatar image processing

/// Turns any picked photo into the contract's avatar format:
/// a centre-cropped square, 512×512, JPEG, safely under the bucket's 1 MB limit.
enum AvatarImage {
    static let side: CGFloat = 512

    static func squareJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let crop = min(size.width, size.height)
        guard crop > 0 else { return nil }
        // Draw so the centre square fills the 512×512 canvas
        let scale = side / crop
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1          // exactly 512×512 pixels, not points
        format.opaque = true
        let square = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        // Step quality down if needed to stay under the 1 MB limit
        for quality in [0.85, 0.7, 0.55] {
            if let jpeg = square.jpegData(compressionQuality: quality), jpeg.count < 900_000 {
                return jpeg
            }
        }
        return nil
    }
}
