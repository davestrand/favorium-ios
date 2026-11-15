//
//  ProfileTabView.swift
//  favorium
//
//  Profile tab — wraps the existing auth-aware profile experience
//  in the midnight-teal shell. Sign-out delegates to AuthViewModel.
//

import SwiftUI
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

    @State private var stats = ProfileStatsModel()
    @State private var characterStore = CharacterStore()
    @State private var showSettings = false

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

                        if let pause = appVM.pause {
                            AccountPauseNotice(pause: pause)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                        }

                        // ── Portrait ──────────────────────────────────
                        portrait
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)

                        // ── Character & quests (QUESTS_CONTRACT) ──────
                        // With a character, its description is the name and title
                        CharacterSection(store: characterStore)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)

                        // ── Stats row ─────────────────────────────────
                        statsRow
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                    }
                    // Exactly the screen's width, so nothing on this page can make the
                    // scroll view wider than the screen and let it drift sideways
                    .containerRelativeFrame(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                // Content fades in over the fixed backdrop on the tab's first visit
                .fadeInOnFirstAppear()
                .refreshable {
                    await stats.load(userId: appVM.userId)
                    await appVM.refreshTitle()
                    await characterStore.load(userId: appVM.userId)
                }
            }
            // Account housekeeping lives behind the gear, off the character sheet
            .overlay(alignment: .topTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(FavoriumTheme.ivory)
                        .frame(width: 44, height: 44)
                        .background(FavoriumTheme.surface.opacity(0.7))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(FavoriumTheme.accentMuted.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 4)
                .accessibilityLabel("Settings")
            }
            .navigationBarHidden(true)
            // Re-runs whenever the tab appears, so counts reflect gems just given or received
            .task {
                await stats.load(userId: appVM.userId)
                await appVM.refreshTitle()
                await characterStore.load(userId: appVM.userId)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: characterStore)
                    .environment(appVM)
                    .environment(authVM)
            }
        }
    }

    // MARK: - Portrait

    /// The photo in its title frame. The name and title show here only until there's a
    /// character, whose description opens with them ("You see Dave, Samaritan of Favorium.").
    private var portrait: some View {
        VStack(spacing: 12) {
            PersonAvatar(userId: appVM.userId, name: appVM.displayName, photo: appVM.avatarURL,
                         level: appVM.helperLevel, size: 104)
                .shadow(color: FavoriumTheme.accent.opacity(0.25), radius: 16)
                // Room for the halo, which floats above the avatar
                .padding(.top, appVM.helperTitle == nil ? 0 : 22)
                .accessibilityHidden(true)

            if characterStore.hasLoaded && characterStore.character == nil {
                VStack(spacing: 4) {
                    Text(appVM.displayName.isEmpty ? "Your name" : appVM.displayName)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)
                        .multilineTextAlignment(.center)
                    // No title until 3 different people have confirmed your help
                    if let title = appVM.helperTitle {
                        Text(title.displayName)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundColor(FavoriumTheme.accent)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if let title = appVM.helperTitle {
                Text(title.meaning)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: stats.gemsHeld, label: "Gems held", icon: "tab_collection")
            Divider()
                .background(FavoriumTheme.accentMuted.opacity(0.3))
                .frame(height: 40)
            statCell(value: stats.originals, label: "Originals", icon: "stat_originals")
            Divider()
                .background(FavoriumTheme.accentMuted.opacity(0.3))
                .frame(height: 40)
            statCell(value: stats.favors, label: "Favors", icon: "tab_favors")
        }
        .padding(.vertical, 16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accentMuted.opacity(0.2), lineWidth: 1)
        )
    }

    /// `icon` names a faceted template image in the asset catalog, matching the tab bar icons.
    private func statCell(value: Int?, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
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

// MARK: - Web pages

/// favorium.app pages linked from the app.
enum FavoriumWeb {
    static let origin = "https://favorium.app"

    static let about   = page("about")
    static let help    = page("help")
    static let privacy = page("privacy")
    static let terms   = page("terms")
    /// Where the reset email's link lands; the web page sets the new password
    static let reset   = page("reset")

    /// A person reads this mailbox
    static let supportEmail = "support@favorium.app"

    /// A pre-addressed message with a subject, so mail never arrives as an anonymous "Hi".
    /// The person's own email is never pre-filled.
    static func supportMail(subject: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = supportEmail
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n---\nSent from the Favorium iOS app")
        ]
        return comps.url!
    }

    private static func page(_ path: String) -> URL {
        URL(string: "\(origin)/\(path)")!
    }
}
