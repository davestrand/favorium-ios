//
//  ProfileTabView.swift
//  favorium
//
//  Profile tab — wraps the existing auth-aware profile experience
//  in the midnight-teal shell. Sign-out delegates to AuthViewModel.
//

import SwiftUI

struct ProfileTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showSignOutConfirm = false

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
            }
            .navigationBarHidden(true)
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
                            colors: [FavoriumTheme.teal.opacity(0.4), FavoriumTheme.tealMuted.opacity(0.2)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)

                Text(String(appVM.displayName.prefix(1)).uppercased())
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundColor(FavoriumTheme.ivory)
            }
            .overlay(
                Circle().stroke(FavoriumTheme.teal.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: FavoriumTheme.teal.opacity(0.25), radius: 16)

            Text(appVM.displayName.isEmpty ? "Your name" : appVM.displayName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(FavoriumTheme.ivory)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "Gems held", icon: "diamond")
            Divider()
                .background(FavoriumTheme.tealMuted.opacity(0.3))
                .frame(height: 40)
            statCell(label: "Originals", icon: "star")
            Divider()
                .background(FavoriumTheme.tealMuted.opacity(0.3))
                .frame(height: 40)
            statCell(label: "Favors", icon: "heart")
        }
        .padding(.vertical, 16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.tealMuted.opacity(0.2), lineWidth: 1)
        )
    }

    private func statCell(label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(FavoriumTheme.teal)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 1) {
            settingsRow(icon: "bell", label: "Notifications")
            settingsRow(icon: "lock", label: "Privacy")
            settingsRow(icon: "questionmark.circle", label: "Help & Feedback")
            settingsRow(icon: "info.circle", label: "About Favorium")
        }
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.tealMuted.opacity(0.2), lineWidth: 1)
        )
    }

    private func settingsRow(icon: String, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(FavoriumTheme.teal)
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
