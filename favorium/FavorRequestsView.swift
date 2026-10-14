//
//  FavorRequestsView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct FavorRequestsView: View {
    @State private var vm = FavorRequestsViewModel()
    @State private var showingOfferSheet = false
    @State private var selectedFavorForCompletion: SupabaseService.Favor?
    let userId: UUID
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("", selection: $vm.selectedTab) {
                Text("Incoming").tag(FavorRequestsViewModel.Tab.incoming)
                Text("Outgoing").tag(FavorRequestsViewModel.Tab.outgoing)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = vm.errorMessage {
                Spacer()
                FavorErrorView(error: error) {
                    Task { await vm.load(userId: userId) }
                }
                Spacer()
            } else {
                if vm.selectedTab == .incoming {
                    IncomingFavorsList(
                        favors: vm.incomingFavors,
                        onAccept: { favor in
                            await vm.acceptFavor(favor)
                        },
                        onDecline: { favor in
                            await vm.declineFavor(favor)
                        },
                        onComplete: { favor in
                            selectedFavorForCompletion = favor
                        }
                    )
                } else {
                    OutgoingFavorsList(favors: vm.outgoingFavors)
                }
            }
        }
        .navigationTitle("Favor Requests")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingOfferSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingOfferSheet) {
            Task { await vm.load(userId: userId) }
        } content: {
            OfferFavorView()
        }
        .sheet(item: $selectedFavorForCompletion) { favor in
            CompleteFavorView(favor: favor)
                .onDisappear {
                    Task { await vm.load(userId: userId) }
                }
        }
        .task {
            await vm.load(userId: userId)
        }
        .refreshable {
            await vm.load(userId: userId)
        }
    }
}

// MARK: - Incoming Favors List
struct IncomingFavorsList: View {
    let favors: [SupabaseService.Favor]
    let onAccept: (SupabaseService.Favor) async -> Void
    let onDecline: (SupabaseService.Favor) async -> Void
    let onComplete: (SupabaseService.Favor) async -> Void
    
    var body: some View {
        if favors.isEmpty {
            EmptyFavorsView(
                icon: "tray.fill",
                title: "No Incoming Offers",
                message: "When someone offers to help you, it will appear here."
            )
        } else {
            List {
                ForEach(favors) { favor in
                    IncomingFavorRow(
                        favor: favor,
                        onAccept: { await onAccept(favor) },
                        onDecline: { await onDecline(favor) },
                        onComplete: { await onComplete(favor) }
                    )
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Outgoing Favors List
struct OutgoingFavorsList: View {
    let favors: [SupabaseService.Favor]
    
    var body: some View {
        if favors.isEmpty {
            EmptyFavorsView(
                icon: "paperplane.fill",
                title: "No Outgoing Offers",
                message: "Tap + to offer a favor to someone."
            )
        } else {
            List {
                ForEach(favors) { favor in
                    OutgoingFavorRow(favor: favor)
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Incoming Favor Row
struct IncomingFavorRow: View {
    let favor: SupabaseService.Favor
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    let onComplete: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        Text(favor.helper_name ?? "Someone")
                            .font(.headline)
                    }
                    
                    Text(formatDate(favor.created_at))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: favor.status)
            }
            
            // Description
            Text(favor.description)
                .font(.body)
                .foregroundColor(.primary)
            
            // Actions
            if favor.isProposed {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            isProcessing = true
                            await onAccept()
                            isProcessing = false
                        }
                    } label: {
                        Label("Accept", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                    
                    Button {
                        Task {
                            isProcessing = true
                            await onDecline()
                            isProcessing = false
                        }
                    } label: {
                        Label("Decline", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                    }
                    .disabled(isProcessing)
                }
            } else if favor.isAccepted {
                Button {
                    Task {
                        await onComplete()
                    }
                } label: {
                    Label("Mark as Done & Give Favor", systemImage: "gift.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            
            if isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
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

// MARK: - Outgoing Favor Row
struct OutgoingFavorRow: View {
    let favor: SupabaseService.Favor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                        Text(favor.helped_name ?? "Someone")
                            .font(.headline)
                    }
                    
                    Text(formatDate(favor.created_at))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: favor.status)
            }
            
            // Description
            Text(favor.description)
                .font(.body)
                .foregroundColor(.primary)
            
            // Status message
            if favor.isAccepted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Accepted! Complete the favor and they'll give you a Favor coin.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
            } else if favor.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.purple)
                    Text("Completed!")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
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

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch status {
        case "proposed": return Color.orange.opacity(0.2)
        case "accepted": return Color.green.opacity(0.2)
        case "completed": return Color.purple.opacity(0.2)
        case "transferred": return Color.blue.opacity(0.2)
        case "declined": return Color.red.opacity(0.2)
        case "cancelled": return Color.gray.opacity(0.2)
        default: return Color.gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case "proposed": return .orange
        case "accepted": return .green
        case "completed": return .purple
        case "transferred": return .blue
        case "declined": return .red
        case "cancelled": return .gray
        default: return .gray
        }
    }
}

// MARK: - Empty State
struct EmptyFavorsView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Error State
struct FavorErrorView: View {
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
final class FavorRequestsViewModel {
    enum Tab { case incoming, outgoing }
    
    var selectedTab: Tab = .incoming
    var incomingFavors: [SupabaseService.Favor] = []
    var outgoingFavors: [SupabaseService.Favor] = []
    var isLoading: Bool = false
    var errorMessage: String?
    
    @MainActor
    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            async let incoming = SupabaseService.shared.myIncomingFavors(userId: userId)
            async let outgoing = SupabaseService.shared.myOutgoingFavors(userId: userId)
            
            let (inc, out) = try await (incoming, outgoing)
            self.incomingFavors = inc
            self.outgoingFavors = out
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func acceptFavor(_ favor: SupabaseService.Favor) async {
        do {
            try await SupabaseService.shared.acceptFavor(favorId: favor.id)
            // Update local state
            if let index = incomingFavors.firstIndex(where: { $0.id == favor.id }) {
                incomingFavors[index] = SupabaseService.Favor(
                    id: favor.id,
                    helper_id: favor.helper_id,
                    helped_id: favor.helped_id,
                    description: favor.description,
                    status: "accepted",
                    created_at: favor.created_at,
                    accepted_at: ISO8601DateFormatter().string(from: Date()),
                    completed_at: favor.completed_at,
                    transferred_at: favor.transferred_at,
                    coin_id: favor.coin_id,
                    helper_name: favor.helper_name,
                    helped_name: favor.helped_name
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func declineFavor(_ favor: SupabaseService.Favor) async {
        do {
            try await SupabaseService.shared.declineFavor(favorId: favor.id)
            // Remove from local state
            incomingFavors.removeAll { $0.id == favor.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FavorRequestsView(userId: UUID())
    }
}
