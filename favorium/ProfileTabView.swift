//
//  ProfileTabView.swift
//  favorium
//
//  Profile tab — wraps the existing auth-aware profile experience
//  in the midnight-teal shell. Sign-out delegates to AuthViewModel.
//

import SwiftUI

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
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                FavoriumTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // ── Header ────────────────────────────────────
                        StarfieldHeader(title: "Profile", subtitle: appVM.displayName)
                            .padding(.top, 44)
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
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [FavoriumTheme.accent.opacity(0.4), FavoriumTheme.accentMuted.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Text(String(appVM.displayName.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
            }
            .overlay(
                Circle().stroke(FavoriumTheme.accent.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: FavoriumTheme.accent.opacity(0.25), radius: 16)

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
