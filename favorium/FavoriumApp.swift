//
//  FavoriumApp.swift
//  favorium
//
//  App entry point. Uses the SwiftUI App lifecycle, which is scene-based —
//  required for apps built with the iOS 27 SDK (the old UIApplicationDelegate
//  + UIWindow setup no longer launches, including in Xcode Previews).
//

import SwiftUI

@main
struct FavoriumApp: App {
    @State private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authVM)
        }
    }
}
