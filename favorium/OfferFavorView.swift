//
//  OfferFavorView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct OfferFavorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = OfferFavorViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.pink.gradient)
                        
                        Text("Offer a Favor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Help someone and create a meaningful connection")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // Search for recipient
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Who would you like to help?", systemImage: "person.fill.questionmark")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search by name...", text: $vm.searchQuery)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .onTapGesture {
                                    vm.isSearchFieldFocused = true
                                }
                            
                            if !vm.searchQuery.isEmpty {
                                Button {
                                    vm.searchQuery = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        
                        // Suggested friends (when field is focused but empty)
                        if vm.shouldShowSuggestions {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggested")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                
                                VStack(spacing: 0) {
                                    ForEach(vm.suggestedFriends.prefix(5)) { user in
                                        HStack {
                                            Image(systemName: "person.circle.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                            
                                            Text(user.displayName)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                vm.selectedUser = user
                                                vm.isSearchFieldFocused = false
                                            }
                                        }
                                        
                                        if user.id != vm.suggestedFriends.prefix(5).last?.id {
                                            Divider()
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            )
                        }
                        
                        // Search results
                        if vm.isSearching {
                            HStack {
                                ProgressView()
                                    .padding(.leading, 8)
                                Spacer()
                            }
                        } else if !vm.searchResults.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(vm.searchResults) { user in
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        
                                        Text(user.displayName)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if vm.selectedUser?.id == user.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(vm.selectedUser?.id == user.id ? Color.green.opacity(0.1) : Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            vm.selectedUser = user
                                            vm.searchQuery = "" // Clear search to collapse results
                                            vm.isSearchFieldFocused = false
                                        }
                                    }
                                    
                                    if user.id != vm.searchResults.last?.id {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            )
                        } else if !vm.searchQuery.isEmpty && !vm.isSearching {
                            Text("No users found")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                        
                        // Selected user display
                        if let selectedUser = vm.selectedUser {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(selectedUser.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                Button {
                                    vm.selectedUser = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What would you like to help with?", systemImage: "text.bubble")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack(alignment: .topLeading) {
                            if vm.description.isEmpty {
                                Text("Describe what you're offering to do...\n\nFor example:\n• Help with moving\n• Cook a meal\n• Give a ride to the airport\n• Design a logo")
                                    .font(.body)
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $vm.description)
                                .frame(minHeight: 150)
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        
                        Text("\(vm.description.count) / 500 characters")
                            .font(.caption)
                            .foregroundColor(vm.description.count > 500 ? .red : .secondary)
                    }
                    .padding(.horizontal)
                    
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
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Favor Offered!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Your offer has been sent. They'll be notified and can accept when ready.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.1))
                        )
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
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Send Offer") {
                        Task {
                            await vm.sendOffer()
                        }
                    }
                    .disabled(!vm.canSendOffer || vm.isSending || vm.isSuccess)
                    .fontWeight(.semibold)
                }
            }
            .overlay {
                if vm.isSending {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Sending offer...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 20)
                        )
                    }
                }
            }
            .onChange(of: vm.isSuccess) { _, newValue in
                if newValue {
                    // Auto-dismiss after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            }
            .task {
                // Load suggested friends when view appears
                await vm.loadSuggestedFriends()
            }
        }
    }
}

// MARK: - ViewModel
@Observable
final class OfferFavorViewModel {
    var searchQuery: String = "" {
        didSet {
            if searchQuery != oldValue {
                searchDebounceTask?.cancel()
                if searchQuery.count >= 2 {
                    searchDebounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await performSearch()
                    }
                } else {
                    searchResults = []
                }
            }
        }
    }
    var searchResults: [SupabaseService.UserProfile] = []
    var isSearching: Bool = false
    var selectedUser: SupabaseService.UserProfile?
    var description: String = ""
    var errorMessage: String?
    var isSending: Bool = false
    var isSuccess: Bool = false
    var suggestedFriends: [SupabaseService.UserProfile] = []
    var isLoadingSuggestions: Bool = false
    var isSearchFieldFocused: Bool = false
    
    private var searchDebounceTask: Task<Void, Never>?
    
    var shouldShowSuggestions: Bool {
        isSearchFieldFocused && searchQuery.isEmpty && !suggestedFriends.isEmpty
    }
    
    var canSendOffer: Bool {
        selectedUser != nil && 
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        description.count <= 500
    }
    
    @MainActor
    func loadSuggestedFriends() async {
        guard suggestedFriends.isEmpty else { return } // Only load once
        
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
        
        do {
            // First try to get the current user ID
            guard let session = try await SupabaseService.shared.currentSession(),
                  let userIdString = session.userId,
                  let userId = UUID(uuidString: userIdString) else {
                return
            }
            
            // Try to get connected users (people you've exchanged favors with)
            do {
                suggestedFriends = try await SupabaseService.shared.getConnectedUsers(userId: userId, limit: 10)
            } catch {
                // Fallback: just get recent users via empty search
                suggestedFriends = try await SupabaseService.shared.searchUsers(query: "")
            }
        } catch {
            // Silently fail for suggestions
            suggestedFriends = []
        }
    }
    
    @MainActor
    func performSearch() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil // Clear previous errors
        defer { isSearching = false }
        
        do {
            searchResults = try await SupabaseService.shared.searchUsers(query: searchQuery)
        } catch is CancellationError {
            // Ignore cancellation errors - they're expected when user is typing
            searchResults = []
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }
    }
    
    @MainActor
    func sendOffer() async {
        guard let toUser = selectedUser else { return }
        
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        
        do {
            try await SupabaseService.shared.proposeFavor(
                helpedUserId: toUser.id,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            isSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview
#Preview {
    OfferFavorView()
}
