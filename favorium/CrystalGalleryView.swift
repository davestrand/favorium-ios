//
//  CrystalGalleryView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//
//  Gallery view to showcase crystal evolution

import SwiftUI

struct CrystalGalleryView: View {
    let sampleDNAs: [CrystalDNA] = [
        // Purple complementary
        CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: 280,
                secondaryHue: 40,
                saturation: 0.75,
                materialFamily: "coloredGemstone",
                baseForm: "diamond",
                colorRelationship: "complementary",
                secondaryInfluence: 0.6
            ),
            personality: CrystalPersonality(
                complexityBias: 0.5,
                orbitalAffinity: 0.7,
                refraction: 0.8
            ),
            seed: "sample-purple-001"
        ),
        // Blue refracted
        CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: 200,
                secondaryHue: 320,
                saturation: 0.8,
                materialFamily: "spectral",
                baseForm: "diamond",
                colorRelationship: "refracted",
                secondaryInfluence: 0.7
            ),
            personality: CrystalPersonality(
                complexityBias: 0.9,
                orbitalAffinity: 0.95,
                refraction: 0.9
            ),
            seed: "sample-blue-002"
        ),
        // Green analogous
        CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: 140,
                secondaryHue: 180,
                saturation: 0.7,
                materialFamily: "opal",
                baseForm: "diamond",
                colorRelationship: "analogous",
                secondaryInfluence: 0.5
            ),
            personality: CrystalPersonality(
                complexityBias: 0.3,
                orbitalAffinity: 0.5,
                refraction: 0.6
            ),
            seed: "sample-green-003"
        ),
        // Orange gradient
        CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: 30,
                secondaryHue: 350,
                saturation: 0.85,
                materialFamily: "metallic",
                baseForm: "diamond",
                colorRelationship: "gradient",
                secondaryInfluence: 0.8
            ),
            personality: CrystalPersonality(
                complexityBias: 0.7,
                orbitalAffinity: 0.6,
                refraction: 0.7
            ),
            seed: "sample-orange-004"
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Title
                    VStack(spacing: 8) {
                        Text("Crystal Evolution")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Watch how favors grow with each journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Evolution stages for first DNA
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Journey of a Favor")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach([0, 1, 5, 10, 25, 60], id: \.self) { transferCount in
                                    VStack(spacing: 12) {
                                        CrystalView(
                                            dna: sampleDNAs[0],
                                            transferCount: transferCount,
                                            size: 140
                                        )
                                        .frame(width: 160, height: 160)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(Color(.systemGray6))
                                        )
                                        
                                        VStack(spacing: 4) {
                                            Text(CrystalPhase.from(transferCount: transferCount).rawValue.description)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            Text("\(transferCount) transfers")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Different crystal types
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Unique Identities")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            ForEach(Array(sampleDNAs.enumerated()), id: \.offset) { index, dna in
                                VStack(spacing: 12) {
                                    CrystalView(
                                        dna: dna,
                                        transferCount: 15,
                                        size: 140
                                    )
                                    .frame(width: 160, height: 160)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.systemGray6))
                                    )
                                    
                                    Text(dna.identity.colorRelationship ?? "Unique")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .textCase(.uppercase)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Crystal Gallery")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CrystalGalleryView()
}
