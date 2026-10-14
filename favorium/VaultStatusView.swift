//
//  VaultStatusView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct VaultStatusView: View {
    @State private var userId: UUID?
    @State private var count: Int?
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Vault")
                .font(.largeTitle)
                .bold()

            if let error {
                Text(error)
                    .foregroundColor(.red)
            }

            if isLoading {
                ProgressView()
            } else if let c = count {
                if c == 0 {
                    Text("Your vault is empty.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                } else {
                    Text("You have \(c) Favor\(c == 1 ? "" : "s") in your vault.")
                        .font(.title3)
                }
            } else {
                Text("Loading…")
            }

            HStack {
                Button("Refresh") { Task { await load() } }
                    .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .task { await load() }
        .navigationTitle("Vault")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await SupabaseService.shared.currentSession(),
                  let userIdString = session.userId,
                  let uid = UUID(uuidString: userIdString) else {
                self.error = "Not signed in."
                return
            }
            self.userId = uid
            let coins = try await SupabaseService.shared.myFavors(userId: uid)
            self.count = coins.count
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { VaultStatusView() }
}
