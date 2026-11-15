//
//  SettingsView.swift
//  favorium
//
//  Account housekeeping, kept off the Profile page so it reads as a character sheet:
//  photo, email, notifications, help and legal pages, sign out, delete account.
//  Opened from the gear on Profile.
//

import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// Shared with Profile, for the Monday quest toggle
    let store: CharacterStore

    @State private var push = PushManager.shared
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var questPushError: String?
    // Profile photo
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSavingPhoto = false
    @State private var photoError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DecoBackdrop()
                ScrollView {
                    VStack(spacing: 24) {
                        accountSection
                        notificationsSection
                        linksSection
                        signOutButton
                        deleteAccountButton
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                    .containerRelativeFrame(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
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
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This happens right away. You\u{2019}ll be signed out and can\u{2019}t sign back in, your name and photo are removed, and favors that haven\u{2019}t started yet are cancelled. Gems you\u{2019}ve given and the favor history you share with others stay with them, shown as \u{201C}Deleted member\u{201D}. This can\u{2019}t be undone.")
            }
            .alert("Couldn\u{2019}t delete your account",
                   isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK") { }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        section("Account") {
            HStack(spacing: 14) {
                Button { showPhotoPicker = true } label: {
                    PersonAvatar(userId: appVM.userId, name: appVM.displayName, photo: appVM.avatarURL,
                                 level: appVM.helperLevel, size: 56)
                        .overlay {
                            if isSavingPhoto {
                                Circle().fill(.black.opacity(0.45))
                                ProgressView().tint(FavoriumTheme.ivory)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isSavingPhoto)
                .accessibilityLabel(appVM.avatarURL == nil ? "Add profile photo" : "Change profile photo")

                VStack(alignment: .leading, spacing: 6) {
                    Text(appVM.displayName.isEmpty ? "Your name" : appVM.displayName)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)
                    HStack(spacing: 16) {
                        Button(appVM.avatarURL == nil ? "Add photo" : "Change photo") { showPhotoPicker = true }
                        if appVM.avatarURL != nil {
                            Button("Remove", role: .destructive) { removePhoto() }
                                .foregroundColor(FavoriumTheme.ivoryDim)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(FavoriumTheme.accent)
                    .disabled(isSavingPhoto)
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            if let photoError {
                Text(photoError)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.amber)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            if !appVM.email.isEmpty {
                Label(appVM.email, systemImage: "envelope")
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            savePhoto(item)
        }
    }

    // MARK: - Notifications

    private var notificationsEnabled: Bool {
        push.authorizationStatus == .authorized || push.authorizationStatus == .provisional
            || push.authorizationStatus == .ephemeral
    }

    private var notificationsSection: some View {
        section("Notifications") {
            notificationsRow
            // Only members with a character have a Quest Board to hear about
            if store.character != nil {
                Divider().overlay(FavoriumTheme.accentMuted.opacity(0.2))
                Toggle(isOn: Binding(get: { store.mine?.questPush ?? false }, set: { setQuestPush($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New quests on Mondays")
                            .font(FavoriumTheme.bodyFont)
                            .foregroundColor(FavoriumTheme.ivory)
                        Text("And when a visitor comes to town")
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.ivoryDim)
                    }
                }
                .tint(FavoriumTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                if store.mine?.questPush == true {
                    hourPicker
                }
                if let questPushError {
                    Text(questPushError)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.amber)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
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

    /// Which morning-ish hour the Monday push arrives. The server only allows 7–21, so
    /// nothing earlier or later is offered; "Default" sends null.
    private var hourPicker: some View {
        let defaultHour = store.mine?.questPushDefaultHour ?? 8
        let isCustom = store.mine?.questPushHourIsCustom ?? false
        let selection = Binding<Int?>(
            get: { isCustom ? store.mine?.questPushHour : nil },
            set: { setQuestPushHour($0) }
        )
        return HStack {
            Text("Arrives at")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivory)
            Spacer()
            Picker("Arrives at", selection: selection) {
                Text("Default (\(hourLabel(defaultHour)))").tag(Int?.none)
                ForEach(7...21, id: \.self) { hour in
                    Text(hourLabel(hour)).tag(Optional(hour))
                }
            }
            .tint(FavoriumTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// "8 AM" / "20:00", following the person's clock setting
    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func setQuestPushHour(_ hour: Int?) {
        let previous = (store.mine?.questPushHour, store.mine?.questPushHourIsCustom)
        store.mine?.questPushHour = hour ?? store.mine?.questPushDefaultHour
        store.mine?.questPushHourIsCustom = hour != nil
        questPushError = nil
        Task {
            do {
                try await SupabaseService.shared.setQuestPushHour(hour)
            } catch {
                store.mine?.questPushHour = previous.0
                store.mine?.questPushHourIsCustom = previous.1
                questPushError = SupabaseService.errorMessage(error)
            }
        }
    }

    private func setQuestPush(_ enabled: Bool) {
        let previous = store.mine?.questPush
        store.mine?.questPush = enabled
        questPushError = nil
        Task {
            do {
                try await SupabaseService.shared.setQuestPush(enabled)
                if enabled, push.canAskPermission { await push.requestAuthorization() }
            } catch {
                store.mine?.questPush = previous
                questPushError = SupabaseService.errorMessage(error)
            }
        }
    }

    // MARK: - Help and legal

    private var linksSection: some View {
        section("About") {
            VStack(spacing: 1) {
                linkRow(icon: "questionmark.circle", label: "Help & Feedback", url: FavoriumWeb.help)
                linkRow(icon: "envelope", label: "Contact support",
                        url: FavoriumWeb.supportMail(subject: "Favorium iOS \u{2014} account help"))
                linkRow(icon: "info.circle", label: "About Favorium", url: FavoriumWeb.about)
                linkRow(icon: "lock", label: "Privacy", url: FavoriumWeb.privacy)
                linkRow(icon: "doc.text", label: "Terms", url: FavoriumWeb.terms)
            }
            // Web pages open in an in-app browser so people stay in Favorium
            .environment(\.openURL, OpenURLAction { url in .systemAction(url, prefersInApp: true) })
        }
    }

    private func linkRow(icon: String, label: String, url: URL) -> some View {
        Link(destination: url) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sign out / delete (App Store 5.1.1(v))

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

    private var deleteAccountButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                if isDeleting { ProgressView().tint(FavoriumTheme.ivoryDim) }
                Text("Delete Account")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(FavoriumTheme.ivoryDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .disabled(isDeleting)
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await appVM.deleteAccount(authVM: authVM)
            } catch {
                deleteError = SupabaseService.errorMessage(error)
            }
            isDeleting = false
        }
    }

    // MARK: - Photo (IOS_CONTRACT §11a)

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

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(FavoriumTheme.accent)
                .textCase(.uppercase)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .background(FavoriumTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                        .stroke(FavoriumTheme.accentMuted.opacity(0.2), lineWidth: 1)
                )
        }
    }
}
