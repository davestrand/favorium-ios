//
//  CompleteFavorView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct CompleteFavorView: View {
    let favor: SupabaseService.Favor
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CompleteFavorViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        // Animated sparkle/gift icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                                .opacity(0.6)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 20)
                        
                        Text("Create a Favor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Thank \(favor.helper_name ?? "them") by giving a beautiful Favor coin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // What they did
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What they did for you", systemImage: "heart.circle.fill")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(favor.description)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Name the favor
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Name this Favor", systemImage: "textformat")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Give it a poetic name that captures its essence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        TextField("e.g., Amber Hearth, Jade Ripple, Seafoam Bloom", text: $vm.favorName)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                        
                        // Suggestions
                        if !vm.favorName.isEmpty {
                            Text("\(vm.favorName.count) / 50 characters")
                                .font(.caption)
                                .foregroundColor(vm.favorName.count > 50 ? .red : .secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Need inspiration?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(vm.nameSuggestions, id: \.self) { suggestion in
                                            Button {
                                                vm.favorName = suggestion
                                            } label: {
                                                Text(suggestion)
                                                    .font(.caption)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.purple.opacity(0.1))
                                                    )
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Preview
                    if !vm.favorName.isEmpty {
                        VStack(spacing: 12) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            FavorCoinPreview(name: vm.favorName)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Error message
                    if let error = vm.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Success state
                    if vm.isSuccess {
                        VStack(spacing: 16) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Favor Given!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("The Favor has been created and given to \(favor.helper_name ?? "them"). It now begins its journey.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .padding(.horizontal)
                    }
                    
                    // Create button
                    if !vm.isSuccess {
                        Button {
                            Task {
                                await vm.completeFavor(favorId: favor.id)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Create & Give Favor")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: vm.canComplete ? [.purple, .pink] : [.gray, .gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(!vm.canComplete || vm.isCreating)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(vm.isCreating)
                }
            }
            .onChange(of: vm.isSuccess) { _, newValue in
                if newValue {
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Favor Coin Preview
struct FavorCoinPreview: View {
    let name: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Procedural crystal preview
            CrystalView(
                dna: generatedDNA,
                transferCount: 0,
                size: 160
            )
            
            Text(name)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var generatedDNA: CrystalDNA {
        // Generate deterministic DNA from name for preview
        let hash = abs(name.hashValue)
        let primaryColor = Double((hash * 137) % 360)
        let secondaryColor = Double(((hash * 97) + 180) % 360)
        let accentColor = Double(((hash * 61) + 90) % 360)

        return CrystalDNA(
            identity: CrystalIdentity(
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                accentColor: accentColor,
                materialFamily: "coloredGemstone",
                baseForm: "diamond",
                colorRelationship: "complementary",
                secondaryInfluence: 0.6,
                saturation: 0.75,
                refraction: nil,
                luster: nil,
                transparency: nil,
                innerLight: nil,
                inclusionType: nil,
                inclusionDensity: nil,
                facetCount: nil,
                facetPattern: nil,
                symmetry: nil,
                surfaceCharacter: nil,
                palette: nil,
                frameHue: nil
            ),
            personality: CrystalPersonality(
                complexityBias: 0.5,
                orbitalAffinity: 0.4,
                evolutionFamily: nil,
                secondaryFamily: nil,
                metallicAffinity: nil,
                fractalAffinity: nil,
                spectralAffinity: nil,
                organicAffinity: nil,
                celestialAffinity: nil,
                particleAffinity: nil,
                refraction: nil
            ),
            seed: "preview-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        )
    }
}

// MARK: - ViewModel
@Observable
final class CompleteFavorViewModel {
    var favorName: String = ""
    var isCreating: Bool = false
    var isSuccess: Bool = false
    var errorMessage: String?
    
    var canComplete: Bool {
        !favorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        favorName.count <= 50
    }
    
    var nameSuggestions: [String] = [
        "Amber Hearth",
        "Jade Ripple",
        "Seafoam Bloom",
        "Honey Promise",
        "Twilight Echo",
        "Silver Whisper",
        "Ruby Flame",
        "Sapphire Dream"
    ]
    
    @MainActor
    func completeFavor(favorId: UUID) async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        
        do {
            let coinId = try await SupabaseService.shared.completeFavorAndMintCoin(
                favorId: favorId,
                coinName: favorName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            print("Created coin with ID: \(coinId)")
            isSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview
#Preview {
    CompleteFavorView(
        favor: SupabaseService.Favor(
            id: UUID(),
            helper_id: UUID(),
            helped_id: UUID(),
            description: "Help moving furniture to new apartment",
            status: "accepted",
            created_at: ISO8601DateFormatter().string(from: Date()),
            accepted_at: ISO8601DateFormatter().string(from: Date()),
            completed_at: nil,
            transferred_at: nil,
            coin_id: nil,
            helper_name: "Alex",
            helped_name: "Jordan"
        )
    )
}
