//
//  CoinDetailView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI
import Helpers

struct CoinDetailView: View {
    let coinId: UUID
    @State private var vm = CoinDetailViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if vm.isLoading {
                    ProgressView()
                        .padding(40)
                } else if let error = vm.errorMessage {
                    ErrorStateView(error: error, onRetry: {
                        Task { await vm.load(coinId: coinId) }
                    })
                } else if let journey = vm.journey {
                    CoinDetailContent(journey: journey)
                } else {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Favor Journey")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(coinId: coinId)
        }
    }
}

// MARK: - Content View
struct CoinDetailContent: View {
    let journey: SupabaseService.CoinJourneyPayload
    
    var body: some View {
        VStack(spacing: 24) {
            // Header Section
            CoinHeaderSection(journey: journey)
            
            Divider()
                .padding(.horizontal)
            
            // Attributes Section
            CoinAttributesSection(journey: journey)
            
            Divider()
                .padding(.horizontal)
            
            // Journey Timeline
            JourneyTimelineSection(journey: journey)
        }
        .padding(.vertical)
    }
}

// MARK: - Header Section
struct CoinHeaderSection: View {
    let journey: SupabaseService.CoinJourneyPayload
    
    var body: some View {
        VStack(spacing: 16) {
            // Crystal visualization
            if let dna = Self.parseDNA(journey.dna) {
                CrystalView(
                    dna: dna,
                    transferCount: journey.transfer_count,
                    size: 200
                )
                .padding(.top, 20)
            } else {
                // Fallback crystal with generated DNA
                let fallbackDNA = Self.generateFallbackDNA(
                    name: journey.name,
                    seed: journey.seed ?? "fallback-\(journey.id.uuidString)"
                )
                CrystalView(
                    dna: fallbackDNA,
                    transferCount: journey.transfer_count,
                    size: 200
                )
                .padding(.top, 20)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .padding(4)
                }
            }
            
            // Phase whisper
            Text(CrystalPhase.from(transferCount: journey.transfer_count).whisper)
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Coin Name
            Text(journey.name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            // Serial Number
            Text(journey.serial)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            
            // Transfer Count
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                Text("\(journey.transfer_count) transfer\(journey.transfer_count == 1 ? "" : "s")")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            // Creator/Owner Info
            VStack(spacing: 6) {
                if journey.is_owner {
                    Label("You own this Favor", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                if journey.is_creator {
                    Label("You created this Favor", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                } else if let creatorName = journey.creator_name {
                    HStack(spacing: 4) {
                        Text("Created by")
                        Text(creatorName)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - DNA Parsing Helper
    
    // Helper to extract numeric value as Double from either int or double
    private static func numericValue(from json: AnyJSON?) -> Double? {
        if let doubleVal = json?.doubleValue {
            return doubleVal
        } else if let intVal = json?.intValue {
            return Double(intVal)
        }
        return nil
    }
    
    private static func parseDNA(_ dna: JSONObject?) -> CrystalDNA? {
        guard let dna = dna else {
            print("❌ DNA is nil")
            return nil
        }
        
        print("🔍 Parsing DNA: \(dna)")
        
        guard let identityObj = dna["identity"]?.objectValue else {
            print("❌ No identity object found")
            print("   Available keys: \(dna.keys)")
            return nil
        }
        
        guard let personalityObj = dna["personality"]?.objectValue else {
            print("❌ No personality object found")
            return nil
        }
        
        // Parse identity - support both old and new DNA formats
        // New format uses "primary_color", old format uses "primary_hue"
        let primaryHue: Double
        if let primaryColor = numericValue(from: identityObj["primary_color"]) {
            primaryHue = primaryColor
        } else if let primaryHueValue = numericValue(from: identityObj["primary_hue"]) ?? numericValue(from: identityObj["primaryHue"]) {
            primaryHue = primaryHueValue
        } else {
            print("❌ No primary hue/color found")
            print("   primary_color value: \(identityObj["primary_color"]?.description ?? "nil")")
            return nil
        }
        
        // Secondary hue is optional in new format
        let secondaryHue: Double
        if let value = numericValue(from: identityObj["secondary_hue"]) {
            secondaryHue = value
        } else if let value = numericValue(from: identityObj["secondaryHue"]) {
            secondaryHue = value
        } else if let value = numericValue(from: identityObj["secondary_color"]) {
            secondaryHue = value
        } else if let value = numericValue(from: identityObj["accent_color"]) {
            secondaryHue = value
        } else {
            secondaryHue = (primaryHue + 180).truncatingRemainder(dividingBy: 360)
        }
        
        // Saturation is optional in new format, default to reasonable value
        let saturation = numericValue(from: identityObj["saturation"]) ?? 0.75
        
        guard let materialFamily = identityObj["material_family"]?.stringValue ?? identityObj["materialFamily"]?.stringValue,
              let baseForm = identityObj["base_form"]?.stringValue ?? identityObj["baseForm"]?.stringValue else {
            print("❌ Missing required identity fields")
            print("  primaryHue: \(primaryHue)")
            print("  secondaryHue: \(secondaryHue)")
            print("  saturation: \(saturation)")
            print("  materialFamily: \(identityObj["material_family"]?.stringValue ?? "nil")")
            print("  baseForm: \(identityObj["base_form"]?.stringValue ?? "nil")")
            return nil
        }
        
        let colorRelationship = identityObj["color_relationship"]?.stringValue ?? identityObj["colorRelationship"]?.stringValue
        let secondaryInfluence = numericValue(from: identityObj["secondary_influence"]) ?? numericValue(from: identityObj["secondaryInfluence"])
        
        // Parse personality
        guard let complexityBias = numericValue(from: personalityObj["complexity_bias"]) ?? numericValue(from: personalityObj["complexityBias"]),
              let orbitalAffinity = numericValue(from: personalityObj["orbital_affinity"]) ?? numericValue(from: personalityObj["orbitalAffinity"]),
              let refraction = numericValue(from: personalityObj["refraction"]) ?? numericValue(from: identityObj["refraction"]) else {
            print("❌ Missing required personality fields")
            return nil
        }
        
        // Get seed - try multiple locations
        let seed = dna["seed"]?.stringValue ?? identityObj["seed"]?.stringValue ?? "fallback-seed-\(UUID().uuidString)"
        
        print("✅ Successfully parsed DNA with primaryHue: \(primaryHue)")
        
        let identity = CrystalIdentity(
            primaryHue: primaryHue,
            secondaryHue: secondaryHue,
            saturation: saturation,
            materialFamily: materialFamily,
            baseForm: baseForm,
            colorRelationship: colorRelationship,
            secondaryInfluence: secondaryInfluence,
            gemFamily: identityObj["gem_family"]?.stringValue,
            frameFamily: identityObj["frame_family"]?.stringValue
        )
        
        let personality = CrystalPersonality(
            complexityBias: complexityBias,
            orbitalAffinity: orbitalAffinity,
            refraction: refraction
        )
        
        return CrystalDNA(identity: identity, personality: personality, seed: seed)
    }
    
    private static func generateFallbackDNA(name: String, seed: String) -> CrystalDNA {
        // Generate deterministic DNA from name/seed for fallback
        // Use truncatingRemainder to avoid integer overflow
        let hashValue = name.hashValue
        let primaryHue = Double(abs(hashValue) % 360)
        let secondaryHue = (primaryHue + 180.0).truncatingRemainder(dividingBy: 360.0)
        
        print("⚠️ Using fallback DNA for: \(name)")
        
        return CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: primaryHue,
                secondaryHue: secondaryHue,
                saturation: 0.75,
                materialFamily: "coloredGemstone",
                baseForm: "diamond",
                colorRelationship: "complementary",
                secondaryInfluence: 0.6,
                gemFamily: nil,
                frameFamily: nil
            ),
            personality: CrystalPersonality(
                complexityBias: 0.5,
                orbitalAffinity: 0.6,
                refraction: 0.7
            ),
            seed: seed
        )
    }
}

// MARK: - Attributes Section
struct CoinAttributesSection: View {
    let journey: SupabaseService.CoinJourneyPayload
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attributes")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            // DNA Version
            HStack {
                Label("DNA Version", systemImage: "doc.text.magnifyingglass")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(journey.dna_version)")
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            
            // Seed (if available)
            if let seed = journey.seed {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Seed", systemImage: "leaf")
                        .foregroundColor(.secondary)
                    Text(seed)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .padding(.horizontal)
            }
            
            // Traits
            if let traits = journey.traits, !traits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Traits", systemImage: "sparkle")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Array(traits.keys.sorted()), id: \.self) { key in
                            TraitCard(
                                label: key.capitalized,
                                value: traits[key]?.description ?? "—"
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // DNA
            if let dna = journey.dna, !dna.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("DNA", systemImage: "aqi.medium")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(dna.keys.sorted()), id: \.self) { key in
                            HStack {
                                Text(key.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(dna[key]?.description ?? "—")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.05))
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Trait Card
struct TraitCard: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Journey Timeline Section
struct JourneyTimelineSection: View {
    let journey: SupabaseService.CoinJourneyPayload
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journey")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            if journey.history.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "timeline.selection")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No journey history yet")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(journey.history.enumerated()), id: \.element.id) { index, item in
                        JourneyEventRow(
                            event: item,
                            isFirst: index == 0,
                            isLast: index == journey.history.count - 1
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Journey Event Row
struct JourneyEventRow: View {
    let event: SupabaseService.CoinHistoryItem
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 16)
                }
                
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(eventColor.opacity(0.3), lineWidth: 4)
                    )
                
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            
            // Event content
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eventTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        // Participants
                        if let fromName = event.from_name, let toName = event.to_name {
                            HStack(spacing: 4) {
                                Text((event.is_from_me == true) ? "You" : fromName)
                                    .fontWeight((event.is_from_me == true) ? .semibold : .regular)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                Text((event.is_to_me == true) ? "You" : toName)
                                    .fontWeight((event.is_to_me == true) ? .semibold : .regular)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    Text(formatDate(event.created_at))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, isLast ? 0 : 8)
        }
    }
    
    private var eventTitle: String {
        switch event.event_type {
        case "birth":
            return "Created"
        case "transfer":
            return "Transferred"
        case "given":
            return "Given"
        default:
            return event.event_type.capitalized
        }
    }
    
    private var eventColor: Color {
        switch event.event_type {
        case "birth":
            return .purple
        case "transfer":
            return .blue
        case "given":
            return .green
        default:
            return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Parse ISO 8601 date string
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let error: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding(40)
    }
}

// MARK: - ViewModel
@Observable
final class CoinDetailViewModel {
    var journey: SupabaseService.CoinJourneyPayload?
    var isLoading: Bool = false
    var errorMessage: String?
    
    @MainActor
    func load(coinId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            print("🔍 Fetching coin journey for: \(coinId)")
            journey = try await SupabaseService.shared.coinJourney(coinID: coinId)
            print("✅ Successfully loaded journey for: \(journey?.name ?? "unknown")")
        } catch let decodingError as DecodingError {
            print("❌ Decoding error: \(decodingError)")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("  Missing key: \(key.stringValue)")
                print("  Context: \(context.debugDescription)")
                errorMessage = "Missing data field: \(key.stringValue)"
            case .typeMismatch(let type, let context):
                print("  Type mismatch: expected \(type)")
                print("  Context: \(context.debugDescription)")
                errorMessage = "Data type mismatch: \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                print("  Value not found: \(type)")
                print("  Context: \(context.debugDescription)")
                errorMessage = "Missing value: \(context.debugDescription)"
            case .dataCorrupted(let context):
                print("  Data corrupted: \(context.debugDescription)")
                errorMessage = "Data format error: \(context.debugDescription)"
            @unknown default:
                errorMessage = decodingError.localizedDescription
            }
        } catch {
            print("❌ General error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CoinDetailView(coinId: UUID())
    }
}
