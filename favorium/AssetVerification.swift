//
//  AssetVerification.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Verify that all gemstone and frame assets are properly loaded

import SwiftUI

// MARK: - Asset Verification System

struct AssetVerification {

    /// Check if a specific asset exists in the bundle.
    static func assetExists(_ name: String) -> Bool {
        UIImage(named: name) != nil
    }

    /// Verify all gem assets across every family and tier.
    static func verifyGems() -> [String: Bool] {
        var results: [String: Bool] = [:]
        for family in GemFamily.allCases {
            for tier in Tier.allCases {
                let name = family.assetName(tier: tier)
                results[name] = assetExists(name)
            }
        }
        return results
    }

    /// Verify all frame assets across every family and tier.
    static func verifyFrames() -> [String: Bool] {
        var results: [String: Bool] = [:]
        for family in FrameFamily.allCases {
            for tier in Tier.allCases {
                let name = family.assetName(tier: tier)
                results[name] = assetExists(name)
            }
        }
        return results
    }

    /// Total number of assets expected given current families.
    static var expectedCount: Int {
        GemFamily.allCases.count * Tier.allCases.count +
        FrameFamily.allCases.count * Tier.allCases.count
    }

    /// Verify all assets at once.
    static func verifyAll() -> AssetVerificationResult {
        let gems   = verifyGems()
        let frames = verifyFrames()
        let all    = gems.merging(frames) { _, new in new }

        return AssetVerificationResult(
            totalExpected: expectedCount,
            totalFound: all.values.filter { $0 }.count,
            totalMissing: all.values.filter { !$0 }.count,
            foundAssets: all.filter { $0.value }.map(\.key).sorted(),
            missingAssets: all.filter { !$0.value }.map(\.key).sorted(),
            gemResults: gems,
            frameResults: frames
        )
    }
}

struct AssetVerificationResult {
    let totalExpected: Int
    let totalFound: Int
    let totalMissing: Int
    let foundAssets: [String]
    let missingAssets: [String]
    let gemResults: [String: Bool]
    let frameResults: [String: Bool]
    
    var allAssetsFound: Bool {
        totalMissing == 0
    }
    
    var percentageComplete: Double {
        Double(totalFound) / Double(totalExpected)
    }
}

// MARK: - Verification View

struct AssetVerificationView: View {
    let result: AssetVerificationResult
    
    init() {
        self.result = AssetVerification.verifyAll()
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: result.allAssetsFound ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(result.allAssetsFound ? .green : .orange)
                        
                        Text("Asset Verification")
                            .font(.largeTitle.bold())
                        
                        Text("\(result.totalFound) of \(result.totalExpected) assets found")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Completion")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(result.percentageComplete * 100))%")
                                .font(.headline.monospacedDigit())
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: result.allAssetsFound ? [.green, .cyan] : [.orange, .yellow],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * result.percentageComplete)
                            }
                        }
                        .frame(height: 20)
                    }
                    .padding(.horizontal)
                    
                    // Summary cards
                    HStack(spacing: 16) {
                        SummaryCard(
                            title: "Found",
                            value: "\(result.totalFound)",
                            color: .green,
                            icon: "checkmark.circle"
                        )
                        
                        SummaryCard(
                            title: "Missing",
                            value: "\(result.totalMissing)",
                            color: result.totalMissing > 0 ? .orange : .gray,
                            icon: "xmark.circle"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Gemstone verification
                    AssetCategorySection(
                        title: "Gems (\(GemFamily.allCases.count * Tier.allCases.count) expected)",
                        results: result.gemResults
                    )

                    // Frame verification by family
                    ForEach(FrameFamily.allCases) { family in
                        let familyResults = result.frameResults.filter {
                            $0.key.hasPrefix("frame_\(family.rawValue)_")
                        }
                        AssetCategorySection(
                            title: "\(family.displayName) Frames (\(Tier.allCases.count) expected)",
                            results: familyResults
                        )
                    }
                    
                    // Missing assets list (if any)
                    if !result.missingAssets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Missing Assets")
                                .font(.title2.bold())
                                .foregroundColor(.orange)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(result.missingAssets, id: \.self) { asset in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(asset)
                                            .font(.system(.body, design: .monospaced))
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Instructions
                    if !result.allAssetsFound {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Next Steps")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InstructionStep(
                                    number: 1,
                                    text: "Add missing assets to Assets.xcassets"
                                )
                                InstructionStep(
                                    number: 2,
                                    text: "Set each asset's 'Render As' to 'Template Image'"
                                )
                                InstructionStep(
                                    number: 3,
                                    text: "Clean build folder (Cmd+Shift+K)"
                                )
                                InstructionStep(
                                    number: 4,
                                    text: "Rebuild and re-run this verification"
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    } else {
                        // Success message
                        VStack(spacing: 16) {
                            Text("🎉 All Assets Verified!")
                                .font(.title2.bold())
                                .foregroundColor(.green)
                            
                            Text("You're ready to use FavorGemView in your app.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button(action: {}) {
                                Label("Open Gallery", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [.cyan, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 30)
                    }
                    
                    Color.clear.frame(height: 40)
                }
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct AssetCategorySection: View {
    let title: String
    let results: [String: Bool]
    
    var foundCount: Int {
        results.values.filter { $0 }.count
    }
    
    var totalCount: Int {
        results.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(foundCount)/\(totalCount)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(foundCount == totalCount ? .green : .orange)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(results.keys.sorted()), id: \.self) { assetName in
                    AssetStatusCell(
                        name: assetName,
                        found: results[assetName] ?? false
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AssetStatusCell: View {
    let name: String
    let found: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: found ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(found ? .green : .red)
                .font(.caption)
            
            Text(name)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(found ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.cyan))
            
            Text(text)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

// MARK: - Quick Verification Badge

/// Small badge showing asset status - can be overlaid on any view during development
struct AssetVerificationBadge: View {
    let result: AssetVerificationResult
    @State private var isExpanded = false
    
    init() {
        self.result = AssetVerification.verifyAll()
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: result.allAssetsFound ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.allAssetsFound ? .green : .orange)
                        
                        if isExpanded {
                            Text("\(result.totalFound)/\(result.totalExpected)")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Verification View") {
    AssetVerificationView()
}

#Preview("Verification Badge") {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        Text("Your App Content")
            .font(.title)
        
        AssetVerificationBadge()
    }
}

// MARK: - Console Report

extension AssetVerification {
    
    /// Print a detailed report to console
    static func printReport() {
        let result = verifyAll()
        
        print("\n" + "=".repeated(60))
        print("FAVORIUM ASSET VERIFICATION REPORT")
        print("=".repeated(60))
        print("\nSummary:")
        print("  Total Expected: \(result.totalExpected)")
        print("  Total Found:    \(result.totalFound)")
        print("  Total Missing:  \(result.totalMissing)")
        print("  Completion:     \(Int(result.percentageComplete * 100))%")
        
        if !result.missingAssets.isEmpty {
            print("\n⚠️  Missing Assets (\(result.missingAssets.count)):")
            for asset in result.missingAssets {
                print("  ❌ \(asset)")
            }
        }
        
        if result.allAssetsFound {
            print("\n✅ All assets verified successfully!")
        }
        
        print("\n" + "=".repeated(60) + "\n")
    }
}

extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}

// MARK: - App Launch Helper

/// Add this to your app to run verification on launch in debug builds
struct AssetVerificationOnLaunch {
    
    static func verify() {
        #if DEBUG
        AssetVerification.printReport()
        #endif
    }
}

// Usage in your App file:
// init() {
//     AssetVerificationOnLaunch.verify()
// }
