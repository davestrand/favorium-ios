//
//  TestContext.swift
//  favorium
//
//  Created by David Levy on 10/5/26.
//

import SwiftUI

struct HelloWorld: View {
    @State private var status: String = "Idle"
    @State private var meText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Supabase Probe")
                .font(.headline)

            Text("Status: \(status)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !meText.isEmpty {
                Text(meText)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack {
                Button("Ping Health") {
                    Task { await pingHealth() }
                }
                Button("Who Am I") {
                    Task { await whoAmI() }
                }
            }
        }
        .padding()
    }

    private func pingHealth() async {
        status = "Pinging..."
        do {
            let health = try await HealthService.shared.ping()
            status = "Health: \(health.name) \(health.version ?? "")"
            print("[Probe] Health:", health)
        } catch {
            status = "Ping failed: \(error.localizedDescription)"
            print("[Probe] Health ping failed:", error)
        }
    }

    private func whoAmI() async {
        status = "Fetching profile..."
        do {
            let profile = try await ProfileService.shared.me()
            meText = "Me: id=\(profile.id) name=\(profile.display_name ?? "(none)") admin=\(profile.is_admin)"
            status = "Profile OK"
            print("[Probe] Profile:", profile)
        } catch {
            status = "WhoAmI failed: \(error.localizedDescription)"
            print("[Probe] WhoAmI failed:", error)
        }
    }
}
#Preview {
    HelloWorld()
}

