//
//  ContentView.swift
//  favorium
//
//  Root view: shows AuthView until signed in, then the three-tab shell.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var appVM = AppViewModel()
    @State private var selectedTab: Tab = .collection
    @State private var notifications = FavorNotificationCenter()
    @State private var push = PushManager.shared
    @Environment(\.scenePhase) private var scenePhase

    enum Tab { case collection, favors, profile }

    var body: some View {
        Group {
            if appVM.isBootstrapping {
                splashView
            } else if !appVM.isAuthenticated {
                NavigationStack {
                    AuthView()
                }
                .environment(authVM)
                .task {
                    // If the user signs in via AuthView, bridge that signal here.
                    await watchAuthVM()
                }
            } else {
                mainTabs
            }
        }
        .task {
            await appVM.bootstrap()
        }
        // Live favor updates for whoever is signed in; stops on sign-out
        .task(id: appVM.userId) {
            if let userId = appVM.userId {
                // Foreground pushes refresh screens and show the in-app banner
                push.onForegroundPush = { [notifications] title, body, favorId, kind in
                    Task { await notifications.receivedForegroundPush(title: title, body: body, favorId: favorId, kind: kind) }
                }
                await push.signedIn(userId: userId)
                await notifications.start(userId: userId)
            } else {
                await notifications.stop()
            }
        }
        // A tapped push opens the matching tab
        .onChange(of: push.pendingRoute) { _, route in
            guard let route else { return }
            selectedTab = route == .collection ? .collection : .favors
            push.pendingRoute = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await notifications.appBecameActive() }
            }
        }
        .onChange(of: authVM.isAuthenticated) { _, newValue in
            if newValue {
                Task { await appVM.bootstrap() }
            }
        }
    }

    // MARK: - Tab Shell

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            CollectionView()
                .environment(appVM)
                .tag(Tab.collection)
                .tabItem {
                    Label("Collection", image: tabIcon(.collection, "tab_collection"))
                }

            FavorsView()
                .environment(appVM)
                .tag(Tab.favors)
                .badge(notifications.actionCount)
                .tabItem {
                    Label("Favors", image: tabIcon(.favors, "tab_favors"))
                }

            ProfileTabView()
                .environment(appVM)
                .environment(authVM)
                .tag(Tab.profile)
                .tabItem {
                    Label("Profile", image: tabIcon(.profile, "tab_profile"))
                }
        }
        .tint(FavoriumTheme.accent)
        .preferredColorScheme(.dark)
        .environment(notifications)
        // Slide-in banner for live favor changes
        .overlay(alignment: .top) {
            if let banner = notifications.banner {
                FavorBannerView(banner: banner) {
                    selectedTab = .favors
                    notifications.dismissBanner()
                } onDismiss: {
                    notifications.dismissBanner()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(banner.id)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notifications.banner)
        .sensoryFeedback(.success, trigger: notifications.banner) { _, new in new != nil }
    }

    /// Gem-cut tab glyph from the asset catalog; the selected tab gets the "lit"
    /// variant with translucent facets.
    private func tabIcon(_ tab: Tab, _ name: String) -> String {
        selectedTab == tab ? name + "_fill" : name
    }

    // MARK: - Splash

    private var splashView: some View {
        ZStack {
            DecoBackdrop()
            VStack(spacing: 16) {
                FavorGemView(
                    gemFamily: .lightning,
                    tier: .legacy,
                    gemColor: FavoriumTheme.accent,
                    size: 120,
                    showGlow: true
                )
                Text("Favorium")
                    .font(FavoriumTheme.titleFont)
                    .foregroundColor(FavoriumTheme.ivory)
                    .decoTitle()
                DecoDivider()
            }
        }
    }

    // Watches auth VM so external sign-out flows back to the login screen.
    private func watchAuthVM() async {
        while !authVM.isAuthenticated {
            try? await Task.sleep(for: .seconds(0.3))
        }
        await appVM.bootstrap()
    }
}

// MARK: - Theme

/// Centralized design tokens for the Favorium "Sovereign" aesthetic — art-deco
/// sci-fi: midnight-navy halls lit by sapphire light rays, polished gold metal,
/// and platinum-silver secondary text.
enum FavoriumTheme {
    // Colors
    static let background   = Color(red: 0.020, green: 0.039, blue: 0.110)  // #050A1C midnight navy
    static let backgroundTop = Color(red: 0.035, green: 0.078, blue: 0.200) // #091433 deep sapphire (top of backdrop)
    static let surface      = Color(red: 0.051, green: 0.102, blue: 0.227)  // #0D1A3A navy panel
    static let surfaceHigh  = Color(red: 0.086, green: 0.149, blue: 0.310)  // #16264F raised panel
    static let accent       = Color(red: 0.910, green: 0.722, blue: 0.290)  // #E8B84A polished gold
    static let accentMuted  = Color(red: 0.663, green: 0.510, blue: 0.184)  // #A9822F antique gold (spines, borders)
    static let silver       = Color(red: 0.788, green: 0.827, blue: 0.902)  // #C9D3E6 platinum silver
    static let sapphire     = Color(red: 0.239, green: 0.482, blue: 1.000)  // #3D7BFF electric sapphire
    static let sapphireGlow = Color(red: 0.776, green: 0.867, blue: 1.000)  // #C6DDFF pale ray light
    static let ivory        = Color(red: 0.957, green: 0.937, blue: 0.890)  // #F4EFE3 warm ivory
    static let ivoryDim     = silver                                         // secondary text
    static let gold         = Color(red: 0.85, green: 0.65, blue: 0.20)
    static let amber        = Color(red: 0.90, green: 0.60, blue: 0.10)

    /// Brushed-gold metal for primary actions: bright top edge falling to a deep bronze base.
    static let goldGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 1.000, green: 0.878, blue: 0.541), location: 0.0),   // #FFE08A highlight
            .init(color: Color(red: 0.878, green: 0.659, blue: 0.180), location: 0.55),  // #E0A82E body
            .init(color: Color(red: 0.604, green: 0.396, blue: 0.071), location: 1.0)    // #9A6512 shadow
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Dark text color for use on gold surfaces — warmer and richer than pure black.
    static let onGold       = Color(red: 0.16, green: 0.10, blue: 0.05)

    // Fonts
    // Expanded-width geometric sans for the deco marquee look
    static let titleFont    = Font.system(size: 30, weight: .light).width(.expanded)
    static let headingFont  = Font.system(size: 20, weight: .medium).width(.expanded)
    static let bodyFont     = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont  = Font.system(size: 13, weight: .regular, design: .default)

    // Geometry
    static let cardRadius: CGFloat = 16
    static let rowRadius: CGFloat  = 12
}

// MARK: - Metallic gold capsule

extension View {
    /// Polished-gold capsule for primary buttons: gradient metal body plus a thin
    /// specular rim so it reads as a physical, reflective surface.
    func metallicGoldCapsule() -> some View {
        self
            .foregroundColor(FavoriumTheme.onGold)
            .background(FavoriumTheme.goldGradient)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.05), .black.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: FavoriumTheme.gold.opacity(0.25), radius: 10, y: 4)
    }
}

// MARK: - Reusable star-sparkle header background

struct StarfieldHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(FavoriumTheme.titleFont)
                .foregroundColor(FavoriumTheme.ivory)
                .decoTitle()
                .shadow(color: FavoriumTheme.sapphire.opacity(0.6), radius: 12)
            DecoDivider()
            Text(subtitle)
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

#Preview {
    @Previewable @State var authVM = AuthViewModel()
    ContentView()
        .environment(authVM)
}
