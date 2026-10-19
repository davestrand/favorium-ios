//
//  CoinDetailView.swift
//  favorium
//
//  Legacy detail view — kept for any nav paths that still point here.
//  Prefer GemDetailView for new navigation. Updated 2026-10-19 to match
//  the authoritative contract (camelCase CodingKeys, GemDNA, Bool?).
//

import SwiftUI

struct CoinDetailView: View {
    let coinId: UUID
    @State private var vm = CoinDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if vm.isLoading {
                    ProgressView().padding(40)
                } else if let error = vm.errorMessage {
                    ErrorStateView(error: error) {
                        Task { await vm.load(coinId: coinId) }
                    }
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
        .task { await vm.load(coinId: coinId) }
    }
}

// MARK: - Content View

struct CoinDetailContent: View {
    let journey: SupabaseService.CoinJourneyPayload

    var body: some View {
        VStack(spacing: 24) {
            CoinHeaderSection(journey: journey)
            Divider().padding(.horizontal)
            CoinAttributesSection(journey: journey)
            Divider().padding(.horizontal)
            JourneyTimelineSection(journey: journey)
        }
        .padding(.vertical)
    }
}

// MARK: - Header Section

struct CoinHeaderSection: View {
    let journey: SupabaseService.CoinJourneyPayload

    private var tier: Tier { Tier.from(transferCount: journey.transferCount) }
    private var gemFamily: GemFamily { GemFamily.from(journey.dna?.resolvedFamily) }
    private var gemColor: Color {
        guard let dna = journey.dna else { return tier.defaultColor }
        return Color(hue: dna.resolvedHue / 360.0, saturation: dna.resolvedSaturation, brightness: 0.9)
    }

    var body: some View {
        VStack(spacing: 16) {
            AnimatedFavorGemView(
                gemFamily: gemFamily,
                tier: tier,
                gemColor: gemColor,
                size: 200
            )
            .padding(.top, 20)

            Text(CrystalPhase.from(transferCount: journey.transferCount).whisper)
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text(journey.name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(journey.serial)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath").font(.caption)
                Text("\(journey.transferCount) transfer\(journey.transferCount == 1 ? "" : "s")")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            VStack(spacing: 6) {
                if journey.isOwner == true {
                    Label("You own this Favor", systemImage: "checkmark.seal.fill")
                        .font(.subheadline).foregroundColor(.green)
                }
                if journey.isCreator == true {
                    Label("You created this Favor", systemImage: "sparkles")
                        .font(.subheadline).foregroundColor(.purple)
                } else if let creatorName = journey.creatorName {
                    HStack(spacing: 4) {
                        Text("Created by")
                        Text(creatorName).fontWeight(.semibold)
                    }
                    .font(.subheadline).foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal)
    }
}

// MARK: - Attributes Section

struct CoinAttributesSection: View {
    let journey: SupabaseService.CoinJourneyPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attributes")
                .font(.title3).fontWeight(.semibold)
                .padding(.horizontal)

            HStack {
                Label("DNA Version", systemImage: "doc.text.magnifyingglass")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(journey.dnaVersion)").fontWeight(.medium)
            }
            .padding(.horizontal)

            if let seed = journey.seed {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Seed", systemImage: "leaf").foregroundColor(.secondary)
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
        }
    }
}

// MARK: - Journey Timeline Section

struct JourneyTimelineSection: View {
    let journey: SupabaseService.CoinJourneyPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journey")
                .font(.title3).fontWeight(.semibold)
                .padding(.horizontal)

            if journey.history.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "timeline.selection")
                            .font(.largeTitle).foregroundColor(.secondary)
                        Text("No journey history yet").foregroundColor(.secondary)
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
            // Timeline spine
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 16)
                }
                Circle()
                    .fill(eventColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(eventColor.opacity(0.3), lineWidth: 4))
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eventTitle)
                            .font(.subheadline).fontWeight(.semibold)

                        if let desc = event.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let fromName = event.fromName, let toName = event.toName {
                            HStack(spacing: 4) {
                                Text(event.isFromMe == true ? "You" : fromName)
                                    .fontWeight(event.isFromMe == true ? .semibold : .regular)
                                Image(systemName: "arrow.right").font(.caption2)
                                Text(event.isToMe == true ? "You" : toName)
                                    .fontWeight(event.isToMe == true ? .semibold : .regular)
                            }
                            .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(formatDate(event.createdAt))
                        .font(.caption2).foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, isLast ? 0 : 8)
        }
    }

    private var eventTitle: String {
        switch event.eventType {
        case "minted":      return "Brought into the world"
        case "transferred": return "Transferred"
        default:            return event.eventType.capitalized
        }
    }

    private var eventColor: Color {
        switch event.eventType {
        case "minted":      return .purple
        case "transferred": return .blue
        default:            return .gray
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        guard let date else { return dateString }
        let c = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: .now)
        if let d = c.day,    d > 0 { return d == 1 ? "1 day ago"  : "\(d) days ago" }
        if let h = c.hour,   h > 0 { return h == 1 ? "1 hour ago" : "\(h) hours ago" }
        if let m = c.minute, m > 0 { return m == 1 ? "1 min ago"  : "\(m) mins ago" }
        return "Just now"
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle).foregroundColor(.orange)
            Text("Error").font(.headline)
            Text(error)
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button("Retry", action: onRetry).buttonStyle(.bordered)
        }
        .padding(40)
    }
}

// MARK: - View Model

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
            journey = try await SupabaseService.shared.coinJourney(coinID: coinId)
        } catch is CancellationError {
            // View dismissed mid-load — not an error
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, _):
                errorMessage = "Missing data field: \(key.stringValue)"
            case .typeMismatch(_, let ctx):
                errorMessage = "Data type mismatch: \(ctx.debugDescription)"
            case .valueNotFound(_, let ctx):
                errorMessage = "Missing value: \(ctx.debugDescription)"
            case .dataCorrupted(let ctx):
                errorMessage = "Data format error: \(ctx.debugDescription)"
            @unknown default:
                errorMessage = decodingError.localizedDescription
            }
        } catch {
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
