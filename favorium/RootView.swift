//
//  RootView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct RootView: View {
    @State private var vm = AuthViewModel()

    var body: some View {
        Group {
            if vm.isAuthenticated {
                NavigationStack {
                    MainView(onSignOut: {
                        Task { await vm.signOut() }
                    })
                }
            } else {
                NavigationStack {
                    AuthView()
                        .environment(vm)
                        .onAppear {
                            Task {
                                // Try to restore an existing session
                                if let _ = try? await SupabaseService.shared.currentSession() {
                                    vm.isAuthenticated = true
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    RootView()
}
