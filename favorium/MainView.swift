//
//  MainView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct MainView: View {
    var onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // We'll fetch the current user id via session
            CoinsListContainer(onSignOut: onSignOut)
        }
        .navigationTitle("Favorium")
    }
}

struct CoinsListContainer: View {
    var onSignOut: () -> Void
    @State private var userId: UUID?
    @State private var error: String?

    var body: some View {
        Group {
            if let userId {
                CoinsListView(userId: userId)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            NavigationLink(destination: FavorRequestsView(userId: userId)) {
                                Image(systemName: "arrow.left.arrow.right.circle")
                            }
                        }
                        
                        // 🎲 Crystal Playground - for testing
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(destination: MagicalCrystalPlayground()) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.cyan)
                            }
                        }
                        
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Sign Out") { onSignOut() }
                        }
                    }
            } else if let error {
                VStack(spacing: 12) {
                    Text("Failed to load session")
                    Text(error).font(.footnote).foregroundColor(.red)
                    Button("Retry") { Task { await loadSession() } }
                }
                .padding()
            } else {
                ProgressView().task { await loadSession() }
            }
        }
    }

    private func loadSession() async {
        do {
            if let session = try await SupabaseService.shared.currentSession(), let id = session.userId {
                self.userId = UUID(uuidString: id)
            } else {
                self.error = "No session. Please sign in again."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    MainView(onSignOut: {})
}
