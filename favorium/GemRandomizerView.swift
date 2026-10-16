//
//  GemRandomizerView.swift
//  favorium
//
//  Created by Assistant on 10/14/26.
//
//  Interactive random gem generator for device testing

import SwiftUI

// MARK: - Main Randomizer View

struct GemRandomizerView: View {
    @State private var currentGem: RandomGem = RandomGem.generate()
    @State private var favorites: [RandomGem] = []
    @State private var showingFavorites = false
    @State private var animateGeneration = false
    @State private var frameLevel: Double = 2.0 // 0-3 for seed, bloom, legacy, radiance
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(hue: currentGem.hue / 360.0, saturation: 0.3, brightness: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Current Gem Display
                        VStack(spacing: 12) {
                            // Gem - smaller for mobile
                            FavorGemView(
                                gemFamily: currentGem.gemFamily,
                                frameFamily: currentGem.frameFamily,
                                tier: selectedFrameTier,
                                gemColor: currentGem.color,
                                frameColor: currentGem.frameColor,
                                size: 220,
                                showGlow: false,
                                showShimmer: false
                            )
                            .scaleEffect(animateGeneration ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateGeneration)
                            .padding(.top, 20)
                            
                            // Info
                            VStack(spacing: 6) {
                                Text("\(currentGem.gemFamily.displayName) gem")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("\(currentGem.frameFamily.displayName) frame · \(selectedFrameTier.displayName)")
                                    .font(.subheadline)
                                    .foregroundColor(currentGem.frameColor)
                                
                                HStack(spacing: 16) {
                                    Label("\(transferCountForLevel)", systemImage: "arrow.triangle.swap")
                                    Label("Hue \(Int(currentGem.hue))°", systemImage: "paintpalette")
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.bottom, 10)
                        
                        // Frame Level Slider
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(.cyan)
                                Text("Frame Level")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text(selectedFrameTier.displayName)
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.2))
                                    .cornerRadius(6)
                            }
                            
                            HStack(spacing: 12) {
                                Text("Seed")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Slider(value: $frameLevel, in: 0...3, step: 1)
                                    .tint(.cyan)
                                
                                Text("Radiance")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Stats - more compact
                        HStack(spacing: 12) {
                            StatCard(
                                title: "Generated",
                                value: "\(currentGem.id)",
                                icon: "sparkles",
                                color: .cyan
                            )
                            
                            StatCard(
                                title: "Favorites",
                                value: "\(favorites.count)",
                                icon: "heart.fill",
                                color: .pink
                            )
                        }
                        .padding(.horizontal)
                        
                        // Controls - compact
                        VStack(spacing: 12) {
                            // Main action buttons
                            HStack(spacing: 10) {
                                // Favorite button
                                Button(action: addToFavorites) {
                                    Label("Save", systemImage: "heart.fill")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            LinearGradient(
                                                colors: [.pink, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                }
                                
                                // Generate button
                                Button(action: generateNew) {
                                    Label("Generate", systemImage: "wand.and.stars")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            LinearGradient(
                                                colors: [.yellow, .orange],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                }
                            }
                            
                            // View favorites button
                            if !favorites.isEmpty {
                                Button(action: { showingFavorites = true }) {
                                    Label("View \(favorites.count) Favorites", systemImage: "star.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.15))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100) // Extra padding for tab bar
                    }
                }
            }
            .navigationTitle("Gem Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFavorites = true }) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                    .disabled(favorites.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { 
                        frameLevel = 3.0  // Jump to radiance
                    }) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingFavorites) {
                FavoritesView(
                    favorites: $favorites,
                    onSelect: { gem in
                        currentGem = gem
                        showingFavorites = false
                    }
                )
            }
        }
    }
    
    // Computed property to get the frame tier based on slider level
    private var selectedFrameTier: Tier {
        switch Int(frameLevel) {
        case 0: return .seed
        case 1: return .bloom
        case 2: return .legacy
        case 3: return .radiance
        default: return .legacy
        }
    }
    
    // Computed property to show appropriate transfer count for the level
    private var transferCountForLevel: Int {
        switch Int(frameLevel) {
        case 0: return 2      // Seed: 0-4
        case 1: return 8      // Bloom: 5-14
        case 2: return 20     // Legacy: 15-29
        case 3: return 40     // Radiance: 30+
        default: return 20
        }
    }
    
    private func generateNew() {
        withAnimation {
            animateGeneration = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentGem = RandomGem.generate()
            
            // Sync the frame level slider with the generated gem's tier
            frameLevel = Double(tierToLevel(currentGem.tier))
            
            withAnimation {
                animateGeneration = false
            }
        }
    }
    
    // Helper to convert tier to slider level
    private func tierToLevel(_ tier: Tier) -> Int {
        switch tier {
        case .seed:     return 0
        case .bloom:    return 1
        case .legacy:   return 2
        case .radiance: return 3
        }
    }
    
    private func addToFavorites() {
        guard !favorites.contains(where: { $0.id == currentGem.id }) else {
            // Already in favorites
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
            return
        }
        
        favorites.append(currentGem)
        
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
}

// MARK: - Random Gem Model

struct RandomGem: Identifiable {
    let id: Int
    let gemFamily: GemFamily
    let frameFamily: FrameFamily
    let hue: Double
    let saturation: Double
    let tier: Tier
    let transferCount: Int
    let frameHue: Double

    static var counter = 0

    var color: Color {
        // Treat very low saturation as white/diamond
        guard saturation > 0.08 else {
            return Color(white: 0.95)
        }
        return Color(hue: hue / 360.0, saturation: saturation, brightness: 0.9)
    }

    var frameColor: Color {
        Color(hue: frameHue / 360.0, saturation: 0.7, brightness: 0.85)
    }

    static func generate() -> RandomGem {
        counter += 1

        let gemFamily   = GemFamily.allCases.randomElement()!
        let frameFamily = FrameFamily.allCases.randomElement()!
        let hue         = Double.random(in: 0...360)
        // ~1 in 8 chance of a white/diamond gem (near-zero saturation)
        let isWhite     = Int.random(in: 0..<8) == 0
        let saturation  = isWhite ? Double.random(in: 0.0...0.08) : Double.random(in: 0.6...1.0)
        let transferCount = Int.random(in: 0...60)
        let tier        = Tier.from(transferCount: transferCount)

        // Frame hue — complementary, analogous, or tier-matched
        let frameHue: Double
        if Bool.random() {
            frameHue = (hue + 180).truncatingRemainder(dividingBy: 360)
        } else if Bool.random() {
            frameHue = (hue + Double.random(in: 20...60)).truncatingRemainder(dividingBy: 360)
        } else {
            switch tier {
            case .seed:     frameHue = 28   // earthy
            case .bloom:    frameHue = 198  // blue
            case .legacy:   frameHue = 54   // gold
            case .radiance: frameHue = 54   // platinum/gold
            }
        }

        return RandomGem(
            id: counter,
            gemFamily: gemFamily,
            frameFamily: frameFamily,
            hue: hue,
            saturation: saturation,
            tier: tier,
            transferCount: transferCount,
            frameHue: frameHue
        )
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @Binding var favorites: [RandomGem]
    let onSelect: (RandomGem) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if favorites.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Favorites Yet")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Tap the heart button to save gems you like")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 20) {
                            ForEach(favorites) { gem in
                                FavoriteGemCard(gem: gem)
                                    .onTapGesture {
                                        onSelect(gem)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                favorites.removeAll { $0.id == gem.id }
                                            }
                                        } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !favorites.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            withAnimation {
                                favorites.removeAll()
                            }
                        } label: {
                            Text("Clear All")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FavoriteGemCard: View {
    let gem: RandomGem

    var body: some View {
        VStack(spacing: 12) {
            FavorGemView(
                gemFamily: gem.gemFamily,
                frameFamily: gem.frameFamily,
                tier: gem.tier,
                gemColor: gem.color,
                frameColor: gem.frameColor,
                size: 140,
                showGlow: false,
                showShimmer: false
            )

            VStack(spacing: 4) {
                Text(gem.gemFamily.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text("\(gem.frameFamily.displayName) · \(gem.tier.displayName)")
                    .font(.caption)
                    .foregroundColor(gem.frameColor)

                Text("#\(gem.id)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Quick Batch Generator

struct GemBatchGeneratorView: View {
    @State private var gems: [RandomGem] = []
    @State private var selectedGem: RandomGem?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(gems) { gem in
                            FavorGemView(
                                gemFamily: gem.gemFamily,
                                frameFamily: gem.frameFamily,
                                tier: gem.tier,
                                gemColor: gem.color,
                                frameColor: gem.frameColor,
                                size: 100,
                                showGlow: false,
                                showShimmer: false
                            )
                            .onTapGesture {
                                selectedGem = gem
                                showingDetail = true
                            }
                        }
                    }
                    .padding()
                }
                
                if gems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Tap Generate to Create Gems")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Batch Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { generateBatch(count: 9) }) {
                            Label("Generate 9", systemImage: "sparkles")
                        }
                        
                        Button(action: { generateBatch(count: 24) }) {
                            Label("Generate 24", systemImage: "sparkles.rectangle.stack")
                        }
                        
                        Button(action: { generateBatch(count: 50) }) {
                            Label("Generate 50", systemImage: "star.fill")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { gems.removeAll() }) {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let gem = selectedGem {
                    GemDetailView(gem: gem)
                }
            }
        }
    }
    
    private func generateBatch(count: Int) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation {
            gems.removeAll()
            for _ in 0..<count {
                gems.append(RandomGem.generate())
            }
        }
    }
}

// MARK: - Gem Detail View

struct GemDetailView: View {
    let gem: RandomGem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(hue: gem.hue / 360.0, saturation: 0.3, brightness: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()

                    FavorGemView(
                        gemFamily: gem.gemFamily,
                        frameFamily: gem.frameFamily,
                        tier: gem.tier,
                        gemColor: gem.color,
                        frameColor: gem.frameColor,
                        size: 320,
                        showGlow: false,
                        showShimmer: false
                    )

                    VStack(spacing: 16) {
                        Text(gem.gemFamily.displayName)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(gem.frameFamily.displayName) frame · \(gem.tier.displayName)")
                            .font(.title3)
                            .foregroundColor(gem.frameColor)

                        VStack(spacing: 12) {
                            DetailRow(label: "Gem ID",     value: "#\(gem.id)")
                            DetailRow(label: "Transfers",  value: "\(gem.transferCount)")
                            DetailRow(label: "Gem Hue",    value: "\(Int(gem.hue))°")
                            DetailRow(label: "Saturation", value: "\(Int(gem.saturation * 100))%")
                            DetailRow(label: "Frame Hue",  value: "\(Int(gem.frameHue))°")
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Gem Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// MARK: - Family-Specific Generator

/// Shows all tier variations for a specific gem + frame family pairing
struct FamilySpecificGeneratorView: View {
    let gemFamily: GemFamily
    let frameFamily: FrameFamily
    @State private var gems: [RandomGem] = []

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(gems) { gem in
                        VStack {
                            FavorGemView(
                                gemFamily: gem.gemFamily,
                                frameFamily: gem.frameFamily,
                                tier: gem.tier,
                                gemColor: gem.color,
                                frameColor: gem.frameColor,
                                size: 140,
                                showGlow: false,
                                showShimmer: false
                            )

                            Text("Hue \(Int(gem.hue))° · \(gem.tier.displayName)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("\(gemFamily.displayName) / \(frameFamily.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Generate 12") {
                    generateVariations()
                }
            }
        }
        .onAppear {
            if gems.isEmpty { generateVariations() }
        }
    }

    private func generateVariations() {
        gems = (0..<12).map { _ in
            let base = RandomGem.generate()
            return RandomGem(
                id: base.id,
                gemFamily: gemFamily,
                frameFamily: frameFamily,
                hue: base.hue,
                saturation: base.saturation,
                tier: base.tier,
                transferCount: base.transferCount,
                frameHue: base.frameHue
            )
        }
    }
}

// MARK: - Family Explorer

struct ShapeExplorerView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                List {
                    ForEach(GemFamily.allCases) { gemFamily in
                        ForEach(FrameFamily.allCases) { frameFamily in
                            NavigationLink(destination: FamilySpecificGeneratorView(
                                gemFamily: gemFamily,
                                frameFamily: frameFamily
                            )) {
                                HStack {
                                    FavorGemView(
                                        gemFamily: gemFamily,
                                        frameFamily: frameFamily,
                                        tier: .seed,
                                        gemColor: .cyan,
                                        size: 50,
                                        showGlow: false,
                                        showShimmer: false
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(gemFamily.displayName) gem")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("\(frameFamily.displayName) frame")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Gem Families")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Main Tab View

struct GemTestingHub: View {
    var body: some View {
        TabView {
            GemRandomizerView()
                .tabItem {
                    Label("Generator", systemImage: "wand.and.stars")
                }

            GemBatchGeneratorView()
                .tabItem {
                    Label("Batch", systemImage: "square.grid.3x3")
                }

            ShapeExplorerView()
                .tabItem {
                    Label("Families", systemImage: "square.on.circle")
                }
        }
    }
}

// MARK: - Previews

#Preview("Random Generator") {
    GemRandomizerView()
}

#Preview("Batch Generator") {
    GemBatchGeneratorView()
}

#Preview("Testing Hub") {
    GemTestingHub()
}

#Preview("Lightning Tier Progression") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 30) {
            Text("Lightning Progression")
                .font(.title.bold())
                .foregroundColor(.white)

            Text("gem_lightning_{tier}  ·  frame_lightning_{tier}")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                ForEach(Tier.allCases) { tier in
                    VStack(spacing: 8) {
                        FavorGemView(
                            gemFamily: .lightning,
                            frameFamily: .lightning,
                            tier: tier,
                            gemColor: .cyan,
                            size: 140,
                            showGlow: false,
                            showShimmer: false
                        )
                        Text(tier.displayName)
                            .foregroundColor(tier.defaultColor)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
}



