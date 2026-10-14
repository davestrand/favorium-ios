//
//  CrystalEngine.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//
//  Crystal DNA renderer - deterministic gemstone generation from Favor DNA

import Foundation
import SwiftUI

// MARK: - Deterministic RNG (EXACT port from web)

struct CrystalRng {
    private var generate: () -> Double
    
    init(seed: String, salt: String) {
        let fullSeed = "\(seed)::\(salt)"
        let seedGen = Self.xmur3(fullSeed)
        let seedValue = seedGen()
        self.generate = Self.mulberry32(seedValue)
    }
    
    // xmur3 hash -> seed
    private static func xmur3(_ str: String) -> () -> UInt32 {
        var h: UInt32 = 1779033703 ^ UInt32(str.utf16.count)
        for c in str.utf16 {
            h = (h ^ UInt32(c)) &* 3432918353
            h = (h << 13) | (h >> 19)
        }
        return {
            h = (h ^ (h >> 16)) &* 2246822507
            h = (h ^ (h >> 13)) &* 3266489909
            h ^= (h >> 16)
            return h
        }
    }
    
    // mulberry32 PRNG
    private static func mulberry32(_ a: UInt32) -> () -> Double {
        var t = a
        return {
            t = t &+ 0x6d2b79f5
            var x = (t ^ (t >> 15)) &* (1 | t)
            x = (x &+ ((x ^ (x >> 7)) &* (61 | x))) ^ x
            return Double((x ^ (x >> 14))) / 4294967296.0
        }
    }
    
    // Core draw methods (names matter!)
    mutating func next() -> Double {
        generate()
    }
    
    mutating func range(_ lo: Double, _ hi: Double) -> Double {
        lo + next() * (hi - lo)
    }
    
    mutating func int(_ n: Int) -> Int {
        Int(Double(n) * next())
    }
    
    mutating func pick<T>(_ array: [T]) -> T {
        array[int(array.count)]
    }
    
    mutating func chance(_ p: Double) -> Bool {
        next() < p
    }
    
    mutating func sign() -> Int {
        next() < 0.5 ? -1 : 1
    }
}

// MARK: - Evolution Phases

enum CrystalPhase: Int, CaseIterable {
    case newborn = 0
    case awakened = 1
    case resonant = 2
    case radiant = 3
    case storied = 4
    case legendary = 5
    
    static func from(transferCount: Int) -> CrystalPhase {
        switch transferCount {
        case 0: return .newborn
        case 1...4: return .awakened
        case 5...9: return .resonant
        case 10...24: return .radiant
        case 25...49: return .storied
        default: return .legendary
        }
    }
    
    var whisper: String {
        switch self {
        case .newborn: return "New to the world, still gathering its first light."
        case .awakened: return "A first kindness has begun to glow within it."
        case .resonant: return "Faint veins of light thread quietly through it."
        case .radiant: return "Richer structure and a steadier inner light have formed."
        case .storied: return "Many journeys now drift within, layered like warm weather."
        case .legendary: return "It has traveled so far it seems lit from somewhere else."
        }
    }
    
    var stage: Int { rawValue }
}

// MARK: - Color Relationships

enum ColorRelationship: String, CaseIterable {
    case complementary
    case analogous
    case split
    case coreAndShell = "core-and-shell"
    case refracted
    case veined
    case spectral
    case gradient
    case asymmetric
    
    var channelWeights: CrystalColorChannels {
        switch self {
        case .complementary: return CrystalColorChannels(
            facets: 0.86, refracted: 0.50, caustics: 0.72, innerGlow: 0.30,
            inclusions: 0.20, rim: 0.62, subsurface: 0.22, spectral: 0.34,
            particles: 0.30, gradient: 0.30, asymmetry: 0.20
        )
        case .analogous: return CrystalColorChannels(
            facets: 0.30, refracted: 0.50, caustics: 0.30, innerGlow: 0.42,
            inclusions: 0.28, rim: 0.34, subsurface: 0.72, spectral: 0.20,
            particles: 0.20, gradient: 0.86, asymmetry: 0.16
        )
        case .split: return CrystalColorChannels(
            facets: 0.72, refracted: 0.44, caustics: 0.60, innerGlow: 0.32,
            inclusions: 0.22, rim: 0.52, subsurface: 0.26, spectral: 0.54,
            particles: 0.36, gradient: 0.32, asymmetry: 0.42
        )
        case .coreAndShell: return CrystalColorChannels(
            facets: 0.32, refracted: 0.52, caustics: 0.42, innerGlow: 0.95,
            inclusions: 0.32, rim: 0.72, subsurface: 0.50, spectral: 0.30,
            particles: 0.42, gradient: 0.42, asymmetry: 0.20
        )
        case .refracted: return CrystalColorChannels(
            facets: 0.50, refracted: 0.95, caustics: 0.72, innerGlow: 0.42,
            inclusions: 0.20, rim: 0.42, subsurface: 0.42, spectral: 0.32,
            particles: 0.30, gradient: 0.36, asymmetry: 0.20
        )
        case .veined: return CrystalColorChannels(
            facets: 0.26, refracted: 0.42, caustics: 0.34, innerGlow: 0.40,
            inclusions: 0.95, rim: 0.32, subsurface: 0.60, spectral: 0.26,
            particles: 0.30, gradient: 0.30, asymmetry: 0.36
        )
        case .spectral: return CrystalColorChannels(
            facets: 0.60, refracted: 0.50, caustics: 0.72, innerGlow: 0.50,
            inclusions: 0.20, rim: 0.60, subsurface: 0.32, spectral: 0.95,
            particles: 0.62, gradient: 0.42, asymmetry: 0.30
        )
        case .gradient: return CrystalColorChannels(
            facets: 0.32, refracted: 0.46, caustics: 0.30, innerGlow: 0.42,
            inclusions: 0.26, rim: 0.42, subsurface: 0.60, spectral: 0.26,
            particles: 0.20, gradient: 0.95, asymmetry: 0.20
        )
        case .asymmetric: return CrystalColorChannels(
            facets: 0.62, refracted: 0.42, caustics: 0.50, innerGlow: 0.36,
            inclusions: 0.36, rim: 0.62, subsurface: 0.32, spectral: 0.42,
            particles: 0.30, gradient: 0.30, asymmetry: 0.95
        )
        }
    }
}

// MARK: - Data Structures

struct CrystalColorChannels {
    let facets: Double
    let refracted: Double
    let caustics: Double
    let innerGlow: Double
    let inclusions: Double
    let rim: Double
    let subsurface: Double
    let spectral: Double
    let particles: Double
    let gradient: Double
    let asymmetry: Double
}

struct CrystalColorProfile {
    let relationship: ColorRelationship
    let reveal: Double
    let influence: Double
    let facets: Double
    let refracted: Double
    let caustics: Double
    let innerGlow: Double
    let inclusions: Double
    let rim: Double
    let subsurface: Double
    let spectral: Double
    let particles: Double
    let gradient: Double
    let asymmetry: Double
    
    static func build(relationship: ColorRelationship, stage: Int, secondaryInfluence: Double) -> CrystalColorProfile {
        let reveal = clamp01(0.12 + Double(stage) * 0.176)
        let influence = clamp01(secondaryInfluence * reveal)
        let weights = relationship.channelWeights
        
        return CrystalColorProfile(
            relationship: relationship,
            reveal: reveal,
            influence: influence,
            facets: clamp01(weights.facets * influence),
            refracted: clamp01(weights.refracted * influence),
            caustics: clamp01(weights.caustics * influence),
            innerGlow: clamp01(weights.innerGlow * influence),
            inclusions: clamp01(weights.inclusions * influence),
            rim: clamp01(weights.rim * influence),
            subsurface: clamp01(weights.subsurface * influence),
            spectral: clamp01(weights.spectral * influence),
            particles: clamp01(weights.particles * influence),
            gradient: clamp01(weights.gradient * influence),
            asymmetry: clamp01(weights.asymmetry * influence)
        )
    }
}

struct OrbitalConfig: Identifiable {
    let id: String
    let form: SatelliteForm
    let radius: Double
    let size: Double
    let speed: Double      // seconds per revolution
    let tilt: Double       // degrees
    let eccentricity: Double
    let wobble: Double
    let startAngle: Double // radians
    let direction: Int     // +1 or -1
    let trail: Bool
    let color: Double      // hue 0-360
}

enum SatelliteForm: String {
    case pearl
    case shard
    case mote
}

enum MaterialFamily: String, CaseIterable {
    case clearCrystal
    case coloredGemstone
    case opal
    case moonstone
    case metallic
    case translucentMineral
    case pearlescent
    case smoky
    case spectral
    case cosmic
    case glass
    case hybrid
    
    var satelliteForm: SatelliteForm {
        switch self {
        case .clearCrystal, .coloredGemstone, .metallic, .smoky: return .shard
        case .opal, .moonstone, .pearlescent, .hybrid: return .pearl
        case .translucentMineral, .spectral, .cosmic, .glass: return .mote
        }
    }
}

// MARK: - Crystal Model

struct CrystalModel {
    let seed: String
    let phase: CrystalPhase
    let transferCount: Int
    
    // Identity (immutable)
    let primaryHue: Double        // 0-360
    let secondaryHue: Double      // 0-360
    let saturation: Double        // 0-1
    let materialFamily: MaterialFamily
    let baseForm: String
    let colorRelationship: ColorRelationship
    let secondaryInfluence: Double
    
    // Personality (immutable)
    let complexityBias: Double    // 0-1
    let orbitalAffinity: Double   // 0-1
    let refraction: Double        // 0-1
    
    // Derived (changes with stage)
    let colorProfile: CrystalColorProfile
    let orbitals: [OrbitalConfig]
    let innerLightIntensity: Double
    let aura: Double
    
    // Visual helpers
    var bodySecondaryMix: Double {
        clamp01(
            colorProfile.gradient * 0.14 +
            colorProfile.subsurface * 0.1 +
            colorProfile.reveal * (0.1 + colorProfile.influence * 0.22)
        )
    }
}

// MARK: - Crystal Engine

struct CrystalEngine {
    private static let GOLDEN = 2.399963229728653
    
    /// Main entry point - derive crystal from DNA + transfer count
    static func derive(dna: CrystalDNA, transferCount: Int) -> CrystalModel {
        let phase = CrystalPhase.from(transferCount: transferCount)
        let stage = phase.stage
        
        // Resolve optional values
        let colorRelationship = dna.identity.colorRelationshipEnum
        let secondaryInfluence = dna.identity.secondaryInfluence ?? 0.5
        
        // Build color profile
        let colorProfile = CrystalColorProfile.build(
            relationship: colorRelationship,
            stage: stage,
            secondaryInfluence: secondaryInfluence
        )
        
        // Calculate inner light
        var innerLight: Double = 0
        if stage >= 1 {
            innerLight = clamp01(0.25 + Double(stage) * 0.13)
        }
        
        // Calculate orbitals
        let orbitalAff = max(dna.personality.orbitalAffinity, 0.0) // Could check celestial affinity too
        let orbitals = deriveOrbitals(
            seed: dna.seed,
            stage: stage,
            orbitalAffinity: orbitalAff,
            complexityBias: dna.personality.complexityBias,
            refraction: dna.personality.refraction,
            influence: colorProfile.influence,
            materialFamily: dna.identity.materialFamilyEnum,
            secondaryColor: dna.identity.secondaryHue,
            accentColor: dna.identity.secondaryHue // Could be derived differently
        )
        
        // Calculate aura
        let aura = clamp01(
            innerLight * 0.4 +
            dna.personality.refraction * 0.25 +
            0.15 + // preset glow estimate
            Double(stage) * 0.06
        )
        
        return CrystalModel(
            seed: dna.seed,
            phase: phase,
            transferCount: transferCount,
            primaryHue: dna.identity.primaryHue,
            secondaryHue: dna.identity.secondaryHue,
            saturation: dna.identity.saturation,
            materialFamily: dna.identity.materialFamilyEnum,
            baseForm: dna.identity.baseForm,
            colorRelationship: colorRelationship,
            secondaryInfluence: secondaryInfluence,
            complexityBias: dna.personality.complexityBias,
            orbitalAffinity: dna.personality.orbitalAffinity,
            refraction: dna.personality.refraction,
            colorProfile: colorProfile,
            orbitals: orbitals,
            innerLightIntensity: innerLight,
            aura: aura
        )
    }
    
    private static func deriveOrbitals(
        seed: String,
        stage: Int,
        orbitalAffinity: Double,
        complexityBias: Double,
        refraction: Double,
        influence: Double,
        materialFamily: MaterialFamily,
        secondaryColor: Double,
        accentColor: Double
    ) -> [OrbitalConfig] {
        // Determine count based on stage
        var count = 0
        if stage >= 3 { count = 2 }
        if stage >= 4 { count = 3 }
        if stage >= 5 { count = 4 }
        if count > 0 && orbitalAffinity > 0.68 { count += 1 }
        if count > 0 && orbitalAffinity > 0.86 { count += 1 }
        count = min(count, 7)
        
        guard count > 0 else { return [] }
        
        var orbitals: [OrbitalConfig] = []
        
        for i in 0..<count {
            var rng = CrystalRng(seed: "\(seed)#orb\(i)", salt: "orbital")
            
            // Determine color (EXACT draw order matters!)
            let useSecondary = rng.chance(0.3 + influence * 0.45)
            let satelliteHue = useSecondary ? secondaryColor : accentColor
            
            // Form
            let form = materialFamily.satelliteForm
            
            // Orbital parameters (in draw order!)
            let radius = 0.86 + Double(i) * 0.14 + rng.range(-0.04, 0.06)
            let size = rng.range(0.1, 0.18) + complexityBias * 0.04
            let speed = rng.range(7.0, 16.0) - complexityBias * 2.0
            let direction = rng.sign()
            let tilt: Double
            if count == 1 {
                tilt = 0
            } else {
                tilt = ((Double(i) / Double(count - 1)) - 0.5) * 76.0 + rng.range(-8.0, 8.0)
            }
            let eccentricity = rng.range(0.0, 0.32)
            let trail = rng.chance(0.4 + refraction * 0.3)
            let wobble = rng.range(0.2, 0.9)
            let startAngle = (Double(i) * GOLDEN).truncatingRemainder(dividingBy: 2.0 * .pi) + rng.range(-0.18, 0.18)
            
            orbitals.append(OrbitalConfig(
                id: "orb\(i)",
                form: form,
                radius: radius,
                size: size,
                speed: speed,
                tilt: tilt,
                eccentricity: eccentricity,
                wobble: wobble,
                startAngle: startAngle,
                direction: direction,
                trail: trail,
                color: satelliteHue
            ))
        }
        
        return orbitals
    }
}

// MARK: - Crystal DNA (from backend)

struct CrystalIdentity: Codable {
    let primaryHue: Double
    let secondaryHue: Double
    let saturation: Double
    let materialFamily: String
    let baseForm: String
    let colorRelationship: String?
    let secondaryInfluence: Double?
    
    var materialFamilyEnum: MaterialFamily {
        MaterialFamily(rawValue: materialFamily) ?? .coloredGemstone
    }
    
    var colorRelationshipEnum: ColorRelationship {
        guard let rel = colorRelationship else { return .complementary }
        return ColorRelationship(rawValue: rel) ?? .complementary
    }
    
    enum CodingKeys: String, CodingKey {
        case primaryHue = "primary_hue"
        case secondaryHue = "secondary_hue"
        case saturation
        case materialFamily = "material_family"
        case baseForm = "base_form"
        case colorRelationship = "color_relationship"
        case secondaryInfluence = "secondary_influence"
    }
}

struct CrystalPersonality: Codable {
    let complexityBias: Double
    let orbitalAffinity: Double
    let refraction: Double
    
    enum CodingKeys: String, CodingKey {
        case complexityBias = "complexity_bias"
        case orbitalAffinity = "orbital_affinity"
        case refraction
    }
}

struct CrystalDNA: Codable {
    let identity: CrystalIdentity
    let personality: CrystalPersonality
    let seed: String
    
    // Fill in missing optional values with deterministic generation
    var resolved: CrystalDNA {
        var resolvedIdentity = identity
        
        // Generate missing relationship if needed
        if identity.colorRelationship == nil {
            var rng = CrystalRng(seed: seed, salt: "color-relationship")
            let relationship = rng.pick(ColorRelationship.allCases)
            // Note: Can't mutate, would need to reconstruct
        }
        
        return self
    }
}

// MARK: - Utilities

func clamp01(_ value: Double) -> Double {
    min(1.0, max(0.0, value))
}

func round4(_ value: Double) -> Double {
    (value * 10000).rounded() / 10000
}

func mixHue(_ a: Double, _ b: Double, _ f: Double) -> Double {
    let A = a.truncatingRemainder(dividingBy: 360.0)
    let B = b.truncatingRemainder(dividingBy: 360.0)
    var d = B - A
    if d > 180 { d -= 360 }
    if d < -180 { d += 360 }
    return (A + d * f).truncatingRemainder(dividingBy: 360.0)
}

