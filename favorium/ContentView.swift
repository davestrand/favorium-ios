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
                    Label("Collection", systemImage: "diamond")
                }

            FavorsView()
                .environment(appVM)
                .tag(Tab.favors)
                .tabItem {
                    Label("Favors", systemImage: "heart")
                }

            ProfileTabView()
                .environment(appVM)
                .environment(authVM)
                .tag(Tab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .tint(FavoriumTheme.teal)
        .preferredColorScheme(.dark)
    }

    // MARK: - Splash

    private var splashView: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                FavorGemView(
                    gemFamily: .lightning,
                    tier: .legacy,
                    gemColor: FavoriumTheme.teal,
                    size: 120,
                    showGlow: true
                )
                Text("Favorium")
                    .font(FavoriumTheme.titleFont)
                    .foregroundColor(FavoriumTheme.ivory)
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

/// Centralized design tokens for the Favorium midnight-teal aesthetic.
enum FavoriumTheme {
    // Colors
    static let background   = Color(red: 0.04, green: 0.10, blue: 0.12)   // midnight teal
    static let surface      = Color(red: 0.07, green: 0.14, blue: 0.17)   // slightly lighter panel
    static let surfaceHigh  = Color(red: 0.10, green: 0.19, blue: 0.22)
    static let teal         = Color(red: 0.20, green: 0.85, blue: 0.75)   // vivid teal accent
    static let tealMuted    = Color(red: 0.15, green: 0.55, blue: 0.50)
    static let ivory        = Color(red: 0.96, green: 0.94, blue: 0.88)   // warm off-white
    static let ivoryDim     = Color(red: 0.96, green: 0.94, blue: 0.88).opacity(0.55)
    static let gold         = Color(red: 0.85, green: 0.65, blue: 0.20)
    static let amber        = Color(red: 0.90, green: 0.60, blue: 0.10)

    // Fonts
    static let titleFont    = Font.system(size: 36, weight: .bold, design: .serif)
    static let headingFont  = Font.system(size: 22, weight: .semibold, design: .default)
    static let bodyFont     = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont  = Font.system(size: 13, weight: .regular, design: .default)

    // Geometry
    static let cardRadius: CGFloat = 16
    static let rowRadius: CGFloat  = 12
}

// MARK: - Reusable star-sparkle header background

struct StarfieldHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            // Subtle arc glow behind the header
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [FavoriumTheme.teal.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .offset(y: -10)
                .blur(radius: 20)

            VStack(spacing: 4) {
                Text(title)
                    .font(FavoriumTheme.titleFont)
                    .foregroundColor(FavoriumTheme.ivory)
                Text(subtitle)
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.ivoryDim)
            }
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
