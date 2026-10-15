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
                            AnimatedFavorGemView(
                                shape: currentGem.shape,
                                gemColor: currentGem.color,
                                frameTier: currentGem.tier,
                                frameColor: currentGem.frameColor,
                                size: 220
                            )
                            .scaleEffect(animateGeneration ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animateGeneration)
                            .shadow(color: currentGem.color.opacity(0.6), radius: 30, y: 15)
                            .padding(.top, 20)
                            
                            // Info
                            VStack(spacing: 6) {
                                Text(currentGem.shape.displayName)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(currentGem.tier.displayName + " Frame")
                                    .font(.subheadline)
                                    .foregroundColor(currentGem.frameColor)
                                
                                HStack(spacing: 16) {
                                    Label("\(currentGem.transferCount)", systemImage: "arrow.triangle.swap")
                                    Label("Hue \(Int(currentGem.hue))°", systemImage: "paintpalette")
                                }
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.bottom, 10)
                        
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
    
    private func generateNew() {
        withAnimation {
            animateGeneration = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentGem = RandomGem.generate()
            
            withAnimation {
                animateGeneration = false
            }
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
    let shape: GemShape
    let hue: Double
    let saturation: Double
    let tier: FrameTier
    let transferCount: Int
    let frameHue: Double
    
    static var counter = 0
    
    var color: Color {
        Color(hue: hue / 360.0, saturation: saturation, brightness: 0.9)
    }
    
    var frameColor: Color {
        Color(hue: frameHue / 360.0, saturation: 0.7, brightness: 0.85)
    }
    
    static func generate() -> RandomGem {
        counter += 1
        
        let shape = GemShape.allCases.randomElement()!
        let hue = Double.random(in: 0...360)
        let saturation = Double.random(in: 0.6...1.0)
        let transferCount = Int.random(in: 0...60)
        let tier = FrameTier.from(transferCount: transferCount)
        
        // Frame hue can be related or contrasting
        let frameHue: Double
        if Bool.random() {
            // Complementary
            frameHue = (hue + 180).truncatingRemainder(dividingBy: 360)
        } else if Bool.random() {
            // Analogous
            frameHue = (hue + Double.random(in: 20...60)).truncatingRemainder(dividingBy: 360)
        } else {
            // Use tier default
            frameHue = tier == .bronze ? 28 : tier == .silver ? 0 : 54
        }
        
        return RandomGem(
            id: counter,
            shape: shape,
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
                shape: gem.shape,
                gemColor: gem.color,
                frameTier: gem.tier,
                frameColor: gem.frameColor,
                size: 140,
                showGlow: true,
                showShimmer: false
            )
            
            VStack(spacing: 4) {
                Text(gem.shape.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(gem.tier.displayName)
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
                                shape: gem.shape,
                                gemColor: gem.color,
                                frameTier: gem.tier,
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
                    
                    AnimatedFavorGemView(
                        shape: gem.shape,
                        gemColor: gem.color,
                        frameTier: gem.tier,
                        frameColor: gem.frameColor,
                        size: 320
                    )
                    .shadow(color: gem.color.opacity(0.6), radius: 50, y: 30)
                    
                    VStack(spacing: 16) {
                        Text(gem.shape.displayName)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(gem.tier.displayName + " Frame")
                            .font(.title3)
                            .foregroundColor(gem.frameColor)
                        
                        VStack(spacing: 12) {
                            DetailRow(label: "Gem ID", value: "#\(gem.id)")
                            DetailRow(label: "Transfers", value: "\(gem.transferCount)")
                            DetailRow(label: "Gem Hue", value: "\(Int(gem.hue))°")
                            DetailRow(label: "Saturation", value: "\(Int(gem.saturation * 100))%")
                            DetailRow(label: "Frame Hue", value: "\(Int(gem.frameHue))°")
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

// MARK: - Shape-Specific Generator

struct ShapeSpecificGeneratorView: View {
    let shape: GemShape
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
                                shape: gem.shape,
                                gemColor: gem.color,
                                frameTier: gem.tier,
                                frameColor: gem.frameColor,
                                size: 140,
                                showGlow: true,
                                showShimmer: false
                            )
                            
                            Text("Hue \(Int(gem.hue))°")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("\(shape.displayName) Variations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Generate 12") {
                    generateVariations()
                }
            }
        }
        .onAppear {
            if gems.isEmpty {
                generateVariations()
            }
        }
    }
    
    private func generateVariations() {
        gems.removeAll()
        
        // Generate 12 color variations of the same shape
        for _ in 0..<12 {
            var gem = RandomGem.generate()
            // Force the shape
            let newGem = RandomGem(
                id: gem.id,
                shape: shape,
                hue: gem.hue,
                saturation: gem.saturation,
                tier: gem.tier,
                transferCount: gem.transferCount,
                frameHue: gem.frameHue
            )
            gems.append(newGem)
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
                    Label("Shapes", systemImage: "square.on.circle")
                }
        }
    }
}

struct ShapeExplorerView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    ForEach(GemShape.allCases) { shape in
                        NavigationLink(destination: ShapeSpecificGeneratorView(shape: shape)) {
                            HStack {
                                FavorGemView(
                                    shape: shape,
                                    gemColor: .cyan,
                                    frameTier: .silver,
                                    size: 50,
                                    showGlow: false,
                                    showShimmer: false
                                )
                                
                                Text(shape.displayName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Gem Shapes")
            .navigationBarTitleDisplayMode(.inline)
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
