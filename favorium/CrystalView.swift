//
//  CrystalView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//
//  True 3D crystal renderer using SceneKit

import SwiftUI
import SceneKit

/// Renders a deterministic 3D crystal from DNA + transfer count
struct CrystalView: View {
    let model: CrystalModel
    let size: CGFloat
    
    @State private var orbitalAnimations: [String: Double] = [:]
    
    init(dna: CrystalDNA, transferCount: Int, size: CGFloat = 200) {
        self.model = CrystalEngine.derive(dna: dna, transferCount: transferCount)
        self.size = size
    }
    
    init(model: CrystalModel, size: CGFloat = 200) {
        self.model = model
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Aura/glow background
            if model.aura > 0.1 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryColor.opacity(model.aura * 0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 1.2, height: size * 1.2)
                    .blur(radius: size * 0.1)
            }
            
            // 3D Crystal using SceneKit
            Crystal3DView(model: model, size: size)
                .frame(width: size, height: size)  // Enforce square aspect ratio
            
            // Orbitals
            ForEach(model.orbitals) { orbital in
                OrbitalView(
                    orbital: orbital,
                    size: size,
                    phase: orbitalAnimations[orbital.id] ?? orbital.startAngle
                )
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)  // Maintain 1:1 aspect ratio
        .onAppear {
            startOrbitalAnimations()
        }
    }
    
    private var primaryColor: Color {
        Color(
            hue: model.primaryHue / 360.0,
            saturation: model.saturation,
            brightness: 0.9
        )
    }
    
    private func startOrbitalAnimations() {
        // Start orbital animations
        for orbital in model.orbitals {
            let initialPhase = orbital.startAngle
            orbitalAnimations[orbital.id] = initialPhase
            
            // Animate each orbital independently
            let duration = orbital.speed
            let endAngle = initialPhase + (2 * .pi * Double(orbital.direction))
            
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                orbitalAnimations[orbital.id] = endAngle
            }
        }
    }
}

// MARK: - 3D Crystal SceneKit View

/// Tunable version for experimentation
struct TunableCrystal3DView: UIViewRepresentable {
    let model: CrystalModel
    let size: CGFloat
    
    // Lighting controls
    let ambientIntensity: Double
    let keyIntensity: Double
    let fillIntensity: Double
    let rimIntensity: Double
    
    // Material controls
    let brightness: Double  // 0 = dark, 1 = bright
    let shininess: Double
    let roughness: Double
    let reflectivity: Double
    
    // Prismatic/Chromatic controls
    let chromaticAberration: Double
    let fresnelIntensity: Double
    let useRainbowEnvironment: Bool
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        sceneView.rendersContinuously = true  // Enable continuous rendering for live updates
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Setup camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 4.0)
        scene.rootNode.addChildNode(cameraNode)
        
        // Tag the scene for updates
        context.coordinator.scene = scene
        context.coordinator.updateLighting(
            scene: scene,
            model: model,
            ambient: ambientIntensity,
            key: keyIntensity,
            fill: fillIntensity,
            rim: rimIntensity
        )
        
        // Create the crystal
        let crystalNode = context.coordinator.createCrystalNode(
            model: model,
            brightness: brightness,
            shininess: shininess,
            roughness: roughness,
            reflectivity: reflectivity,
            chromaticAberration: chromaticAberration,
            fresnelIntensity: fresnelIntensity,
            useRainbowEnvironment: useRainbowEnvironment
        )
        crystalNode.name = "crystal"  // Tag it for easy finding
        scene.rootNode.addChildNode(crystalNode)
        
        // Store crystal node in coordinator for momentum control
        context.coordinator.crystalNode = crystalNode
        
        // Add pan gesture for momentum-based rotation
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        sceneView.addGestureRecognizer(panGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        
        // Update lighting
        context.coordinator.updateLighting(
            scene: scene,
            model: model,
            ambient: ambientIntensity,
            key: keyIntensity,
            fill: fillIntensity,
            rim: rimIntensity
        )
        
        // Find and update the crystal node
        if let crystalNode = scene.rootNode.childNode(withName: "crystal", recursively: false) {
            context.coordinator.updateMaterial(
                node: crystalNode,
                model: model,
                brightness: brightness,
                shininess: shininess,
                roughness: roughness,
                reflectivity: reflectivity,
                chromaticAberration: chromaticAberration,
                fresnelIntensity: fresnelIntensity,
                useRainbowEnvironment: useRainbowEnvironment
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var scene: SCNScene?
        var crystalNode: SCNNode?
        
        // Momentum tracking
        private var lastPanTime: TimeInterval = 0
        private var lastPanTranslation: CGPoint = .zero
        private var angularVelocity: CGFloat = 0
        private var displayLink: CADisplayLink?
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let crystalNode = crystalNode else { return }
            
            let translation = gesture.translation(in: gesture.view)
            let currentTime = CACurrentMediaTime()
            
            switch gesture.state {
            case .began:
                // Stop any existing momentum
                displayLink?.invalidate()
                displayLink = nil
                angularVelocity = 0
                lastPanTranslation = translation
                lastPanTime = currentTime
                
            case .changed:
                // Calculate rotation based on drag
                let deltaX = translation.x - lastPanTranslation.x
                let deltaY = translation.y - lastPanTranslation.y
                let deltaTime = currentTime - lastPanTime
                
                // Rotate around Y axis for horizontal movement
                // Rotate around X axis for vertical movement
                let rotationY = Float(deltaX) * 0.01
                let rotationX = Float(deltaY) * 0.01
                
                // Apply rotation
                crystalNode.eulerAngles.y += rotationY
                crystalNode.eulerAngles.x -= rotationX
                
                // Calculate velocity for momentum (focusing on Y rotation)
                if deltaTime > 0 {
                    // Weight toward the dominant direction
                    let velocityX = deltaX / deltaTime
                    let velocityY = deltaY / deltaTime
                    
                    // Use the larger velocity component
                    if abs(velocityX) > abs(velocityY) {
                        angularVelocity = velocityX * 0.01
                    } else {
                        angularVelocity = velocityY * 0.01
                    }
                }
                
                lastPanTranslation = translation
                lastPanTime = currentTime
                
            case .ended, .cancelled:
                // Start momentum animation if velocity is significant
                if abs(angularVelocity) > 0.1 {
                    startMomentumAnimation()
                }
                
            default:
                break
            }
        }
        
        private func startMomentumAnimation() {
            displayLink?.invalidate()
            
            let displayLink = CADisplayLink(target: self, selector: #selector(updateMomentum))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
        
        @objc private func updateMomentum() {
            guard let crystalNode = crystalNode else {
                displayLink?.invalidate()
                displayLink = nil
                return
            }
            
            // Apply current velocity
            crystalNode.eulerAngles.y += Float(angularVelocity) * 0.016 // Approximate frame time
            
            // Apply friction/damping
            angularVelocity *= 0.98
            
            // Stop when velocity is very small
            if abs(angularVelocity) < 0.01 {
                displayLink?.invalidate()
                displayLink = nil
                angularVelocity = 0
            }
        }
        
        deinit {
            displayLink?.invalidate()
        }
        
        func updateLighting(scene: SCNScene, model: CrystalModel, ambient: Double, key: Double, fill: Double, rim: Double) {
            // Remove old lights
            scene.rootNode.childNodes.filter { $0.light != nil }.forEach { $0.removeFromParentNode() }
            
            // Ambient light - low to create contrast for facet highlights
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.color = UIColor.white
            ambientLight.light!.intensity = CGFloat(ambient)
            scene.rootNode.addChildNode(ambientLight)
            
            // Key light from upper right - main "flash" source
            // Using omni light so it responds to facet angles properly
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light!.type = .omni  // Changed from directional
            keyLight.light!.color = UIColor.white
            keyLight.light!.intensity = CGFloat(key)
            keyLight.light!.castsShadow = false
            keyLight.position = SCNVector3(x: 4, y: 4, z: 5)  // Upper right front, further out
            scene.rootNode.addChildNode(keyLight)
            
            // Accent light from opposite side for secondary sparkle
            let accentLight = SCNNode()
            accentLight.light = SCNLight()
            accentLight.light!.type = .omni  // Changed from directional
            accentLight.light!.color = UIColor.white
            accentLight.light!.intensity = CGFloat(key * 0.5)
            accentLight.light!.castsShadow = false
            accentLight.position = SCNVector3(x: -3, y: 3, z: 5)  // Upper left front
            scene.rootNode.addChildNode(accentLight)
            
            // Fill light with gem color - subtle colored glow
            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light!.type = .omni
            fillLight.light!.color = primaryUIColor(model: model)
            fillLight.light!.intensity = CGFloat(fill)
            fillLight.light!.castsShadow = false
            fillLight.position = SCNVector3(x: -2, y: -1, z: 3)  // Lower left
            scene.rootNode.addChildNode(fillLight)
            
            // Rim/backlight for edge brilliance
            let rimLight = SCNNode()
            rimLight.light = SCNLight()
            rimLight.light!.type = .omni
            rimLight.light!.color = UIColor.white
            rimLight.light!.intensity = CGFloat(rim)
            rimLight.light!.castsShadow = false
            rimLight.position = SCNVector3(x: 0, y: -3, z: -2)  // Below and behind
            scene.rootNode.addChildNode(rimLight)
        }
        
        func createCrystalNode(
            model: CrystalModel,
            brightness: Double,
            shininess: Double,
            roughness: Double,
            reflectivity: Double,
            chromaticAberration: Double,
            fresnelIntensity: Double,
            useRainbowEnvironment: Bool
        ) -> SCNNode {
            let geometry = createCrystalGeometry(baseForm: model.baseForm)
            let node = SCNNode(geometry: geometry)
            updateMaterial(
                node: node,
                model: model,
                brightness: brightness,
                shininess: shininess,
                roughness: roughness,
                reflectivity: reflectivity,
                chromaticAberration: chromaticAberration,
                fresnelIntensity: fresnelIntensity,
                useRainbowEnvironment: useRainbowEnvironment
            )
            return node
        }
        
        func updateMaterial(
            node: SCNNode,
            model: CrystalModel,
            brightness: Double,
            shininess: Double,
            roughness: Double,
            reflectivity: Double,
            chromaticAberration: Double,
            fresnelIntensity: Double,
            useRainbowEnvironment: Bool
        ) {
            guard let geometry = node.geometry else { return }
            
            // Get existing material or create new one
            let material = geometry.materials.first ?? SCNMaterial()
            
            // Base color with adjustable brightness
            let primaryColor = primaryUIColor(model: model, brightness: brightness)
            let secondaryColor = secondaryUIColor(model: model, brightness: brightness)
            let mixRatio = CGFloat(model.bodySecondaryMix)
            let blendedColor = blend(color1: primaryColor, color2: secondaryColor, ratio: mixRatio)
            
            // Semi-transparent diffuse for light to pass through
            // Use the colored material, not white/bright base
            material.diffuse.contents = blendedColor.withAlphaComponent(0.9)
            
            // Enable transparency
            material.transparency = 0.9
            material.transparencyMode = .aOne
            
            // BRILLIANT WHITE specular highlights - this creates the "flash" on facets
            // Sharp, small highlights that sweep across individual facets as it rotates
            material.specular.contents = UIColor.white
            material.specular.intensity = 2.5  // Fixed intensity
            material.shininess = CGFloat(shininess * 100)  // Higher = smaller, sharper highlights
            
            material.roughness.contents = NSNumber(value: roughness)
            material.metalness.contents = NSNumber(value: 0.0)
            
            // RAINBOW ENVIRONMENT MAP for prismatic reflections
            if useRainbowEnvironment {
                // Create a rainbow gradient environment map
                let environmentTexture = createRainbowEnvironmentTexture()
                material.reflective.contents = environmentTexture
                material.reflective.intensity = CGFloat(reflectivity * fresnelIntensity)
                material.fresnelExponent = CGFloat(2.0 / max(fresnelIntensity, 0.1))  // Lower fresnel = more edge glow
            } else {
                // Standard reflectivity with optional chromatic tint
                if chromaticAberration > 0.01 {
                    // Add subtle rainbow tint to reflections
                    let rainbowTexture = createRainbowEnvironmentTexture()
                    material.reflective.contents = rainbowTexture
                    material.reflective.intensity = CGFloat(reflectivity * 0.3 + chromaticAberration * 0.2)
                    material.fresnelExponent = CGFloat(1.0 / (1.0 + chromaticAberration))  // More aberration = more edge effect
                } else {
                    // No chromatic aberration
                    material.reflective.contents = UIColor(white: 1.0, alpha: reflectivity * 0.2)
                    material.reflective.intensity = 0.3
                    material.fresnelExponent = 0.5  // Very low = minimal edge glow
                }
            }
            
            // Inner glow
            if model.innerLightIntensity > 0 {
                let glowIntensity = min(model.innerLightIntensity * 0.7, 0.5)
                let emissionColor = secondaryColor.withAlphaComponent(glowIntensity)
                material.emission.contents = emissionColor
            } else {
                material.emission.contents = UIColor.black
            }
            
            material.isDoubleSided = true
            
            // Use Phong lighting model for sharp, crisp facet highlights
            material.lightingModel = .phong
            
            // Transparency settings
            material.readsFromDepthBuffer = true
            material.writesToDepthBuffer = false
            material.blendMode = .alpha
            node.renderingOrder = 100
            
            // Apply material if it's new
            if geometry.materials.isEmpty {
                geometry.materials = [material]
            }
            
            // Note: Chromatic aberration is now handled via reflective properties above
            // No need for ghost layers
        }
        
        // Helper to create a rainbow environment texture
        private func createRainbowEnvironmentTexture() -> UIImage {
            let size = CGSize(width: 512, height: 512)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let ctx = context.cgContext
                
                // Create a radial rainbow gradient
                let colors = [
                    UIColor(hue: 0.0, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,    // Red
                    UIColor(hue: 0.15, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Orange
                    UIColor(hue: 0.25, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Yellow
                    UIColor(hue: 0.4, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,    // Green
                    UIColor(hue: 0.55, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Cyan
                    UIColor(hue: 0.65, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Blue
                    UIColor(hue: 0.75, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Indigo
                    UIColor(hue: 0.85, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Violet
                    UIColor(hue: 1.0, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor     // Red
                ]
                
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors as CFArray,
                    locations: [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
                )!
                
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: size.width / 2,
                    options: []
                )
            }
        }
        
        // Helper to add chromatic aberration ghost layers
        private func addChromaticAberrationLayers(to node: SCNNode, model: CrystalModel, intensity: Double) {
            // Remove existing layers first
            removeChromaticAberrationLayers(from: node)
            
            // Only apply if intensity is meaningful
            guard intensity > 0.01, let geometry = node.geometry else { return }
            
            // Create very subtle colored edge highlights (not full overlays)
            // Just two complementary colors for cleaner dispersion
            let colors: [(hue: CGFloat, name: String, offset: Float)] = [
                (0.0, "chromatic_red", 0.008),      // Very small red shift
                (0.55, "chromatic_cyan", -0.006)    // Very small cyan shift (opposite)
            ]
            
            for (hue, name, offset) in colors {
                let ghostNode = SCNNode(geometry: geometry)
                ghostNode.name = name
                
                // Create a tinted edge-only material using fresnel
                let ghostMaterial = SCNMaterial()
                
                // Use the hue color but with much lower opacity
                let ghostColor = UIColor(hue: hue, saturation: 0.9, brightness: 1.0, alpha: 1.0)
                ghostMaterial.diffuse.contents = UIColor.clear  // No diffuse body color
                ghostMaterial.emission.contents = ghostColor  // Emit colored light only
                ghostMaterial.emission.intensity = intensity * 0.08  // Very subtle emission
                
                // Use fresnel to make effect appear only at edges
                ghostMaterial.fresnelExponent = 1.5  // Edge-focused
                
                ghostMaterial.transparency = 0.0  // Not transparent - just emissive at edges
                ghostMaterial.lightingModel = .constant
                ghostMaterial.blendMode = .add  // Additive for edge glow
                ghostMaterial.writesToDepthBuffer = false
                ghostMaterial.readsFromDepthBuffer = true
                
                ghostNode.geometry?.materials = [ghostMaterial]
                
                // Minimal scale offset for subtle dispersion
                let scale = 1.0 + CGFloat(offset) * CGFloat(intensity) * 0.5
                ghostNode.scale = SCNVector3(scale, scale, scale)
                ghostNode.renderingOrder = node.renderingOrder + 1
                
                node.addChildNode(ghostNode)
            }
        }
        
        // Helper to remove chromatic aberration layers
        private func removeChromaticAberrationLayers(from node: SCNNode) {
            node.childNodes
                .filter { $0.name?.starts(with: "chromatic_") == true }
                .forEach { $0.removeFromParentNode() }
        }
        
        private func createCrystalGeometry(baseForm: String) -> SCNGeometry {
            switch baseForm.lowercased() {
            case "diamond":
                return createDiamondGeometry()
            case "brilliant":
                return createBrilliantGeometry()
            case "heart":
                return createHeartGeometry()
            case "marquise":
                return createMarquiseGeometry()
            case "emerald", "baguette":
                return createEmeraldGeometry()
            case "hexagon":
                return createHexagonGeometry()
            case "pear", "teardrop":
                return createPearGeometry()
            case "sphere", "orb", "cabochon":
                return SCNSphere(radius: 1.0)
            case "octahedron":
                return createOctahedronGeometry()
            default:
                return createDiamondGeometry()
            }
        }
        
        // Copy all the geometry creation methods from Crystal3DView
        private func createDiamondGeometry() -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            vertices.append(SCNVector3(0, 1.2, 0))
            
            let crownHeight: Float = 0.4
            let crownRadius: Float = 0.8
            for i in 0..<8 {
                let angle = Float(i) * .pi / 4.0
                vertices.append(SCNVector3(
                    cos(angle) * crownRadius,
                    crownHeight,
                    sin(angle) * crownRadius
                ))
            }
            
            let girdleRadius: Float = 1.0
            for i in 0..<8 {
                let angle = Float(i) * .pi / 4.0
                vertices.append(SCNVector3(
                    cos(angle) * girdleRadius,
                    0,
                    sin(angle) * girdleRadius
                ))
            }
            
            let pavilionHeight: Float = -0.8
            let pavilionRadius: Float = 0.4
            for i in 0..<8 {
                let angle = Float(i) * .pi / 4.0
                vertices.append(SCNVector3(
                    cos(angle) * pavilionRadius,
                    pavilionHeight,
                    sin(angle) * pavilionRadius
                ))
            }
            
            vertices.append(SCNVector3(0, -1.4, 0))
            
            for i in 0..<8 {
                let next = (i + 1) % 8
                indices.append(contentsOf: [0, Int32(i + 1), Int32(next + 1)])
            }
            
            for i in 0..<8 {
                let next = (i + 1) % 8
                indices.append(contentsOf: [
                    Int32(i + 1), Int32(i + 9), Int32(next + 9),
                    Int32(i + 1), Int32(next + 9), Int32(next + 1)
                ])
            }
            
            for i in 0..<8 {
                let next = (i + 1) % 8
                indices.append(contentsOf: [
                    Int32(i + 9), Int32(i + 17), Int32(next + 17),
                    Int32(i + 9), Int32(next + 17), Int32(next + 9)
                ])
            }
            
            let culetIndex = Int32(vertices.count - 1)
            for i in 0..<8 {
                let next = (i + 1) % 8
                indices.append(contentsOf: [Int32(i + 17), culetIndex, Int32(next + 17)])
            }
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createBrilliantGeometry() -> SCNGeometry {
            // High-facet brilliant cut with 16 segments for maximum sparkle
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            let segments = 16  // Double the facets!
            
            // Table (top center point)
            vertices.append(SCNVector3(0, 1.2, 0))
            
            // Star facets ring (just below table)
            let starHeight: Float = 0.9
            let starRadius: Float = 0.5
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * starRadius,
                    starHeight,
                    sin(angle) * starRadius
                ))
            }
            
            // Upper crown ring
            let upperCrownHeight: Float = 0.6
            let upperCrownRadius: Float = 0.75
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * upperCrownRadius,
                    upperCrownHeight,
                    sin(angle) * upperCrownRadius
                ))
            }
            
            // Lower crown ring (near girdle)
            let lowerCrownHeight: Float = 0.3
            let lowerCrownRadius: Float = 0.9
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * lowerCrownRadius,
                    lowerCrownHeight,
                    sin(angle) * lowerCrownRadius
                ))
            }
            
            // Girdle (widest part)
            let girdleRadius: Float = 1.0
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * girdleRadius,
                    0,
                    sin(angle) * girdleRadius
                ))
            }
            
            // Upper pavilion ring
            let upperPavilionHeight: Float = -0.4
            let upperPavilionRadius: Float = 0.7
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * upperPavilionRadius,
                    upperPavilionHeight,
                    sin(angle) * upperPavilionRadius
                ))
            }
            
            // Lower pavilion ring
            let lowerPavilionHeight: Float = -0.9
            let lowerPavilionRadius: Float = 0.4
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * lowerPavilionRadius,
                    lowerPavilionHeight,
                    sin(angle) * lowerPavilionRadius
                ))
            }
            
            // Culet (bottom point)
            vertices.append(SCNVector3(0, -1.4, 0))
            
            // Now create all the facets
            let tableIndex: Int32 = 0
            let starStart = 1
            let upperCrownStart = starStart + segments
            let lowerCrownStart = upperCrownStart + segments
            let girdleStart = lowerCrownStart + segments
            let upperPavilionStart = girdleStart + segments
            let lowerPavilionStart = upperPavilionStart + segments
            let culetIndex = Int32(lowerPavilionStart + segments)
            
            // Table to star facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    tableIndex,
                    Int32(starStart + i),
                    Int32(starStart + next)
                ])
            }
            
            // Star to upper crown facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    Int32(starStart + i),
                    Int32(upperCrownStart + i),
                    Int32(upperCrownStart + next),
                    Int32(starStart + i),
                    Int32(upperCrownStart + next),
                    Int32(starStart + next)
                ])
            }
            
            // Upper crown to lower crown facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    Int32(upperCrownStart + i),
                    Int32(lowerCrownStart + i),
                    Int32(lowerCrownStart + next),
                    Int32(upperCrownStart + i),
                    Int32(lowerCrownStart + next),
                    Int32(upperCrownStart + next)
                ])
            }
            
            // Lower crown to girdle facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    Int32(lowerCrownStart + i),
                    Int32(girdleStart + i),
                    Int32(girdleStart + next),
                    Int32(lowerCrownStart + i),
                    Int32(girdleStart + next),
                    Int32(lowerCrownStart + next)
                ])
            }
            
            // Girdle to upper pavilion facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    Int32(girdleStart + i),
                    Int32(upperPavilionStart + i),
                    Int32(upperPavilionStart + next),
                    Int32(girdleStart + i),
                    Int32(upperPavilionStart + next),
                    Int32(girdleStart + next)
                ])
            }
            
            // Upper pavilion to lower pavilion facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    Int32(upperPavilionStart + i),
                    Int32(lowerPavilionStart + i),
                    Int32(lowerPavilionStart + next),
                    Int32(upperPavilionStart + i),
                    Int32(lowerPavilionStart + next),
                    Int32(upperPavilionStart + next)
                ])
            }
            
            // Lower pavilion to culet facets
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [
                    Int32(lowerPavilionStart + i),
                    culetIndex,
                    Int32(lowerPavilionStart + next)
                ])
            }
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createHeartGeometry() -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            // Create a proper heart shape using parametric heart curve
            let segments = 24  // More segments for smoother heart
            
            // Heart curve in the XZ plane (girdle)
            for i in 0..<segments {
                let t = Float(i) / Float(segments) * 2 * .pi
                
                // Parametric heart equations (scaled and centered)
                let x = 0.7 * (16 * pow(sin(t), 3)) / 16.0
                let z = 0.7 * (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) / 16.0
                
                vertices.append(SCNVector3(x, 0, -z))  // Negative z to orient correctly
            }
            
            // Top point
            vertices.append(SCNVector3(0, 1.0, 0))
            // Bottom point (culet)
            vertices.append(SCNVector3(0, -1.2, 0))
            
            let topIndex = Int32(segments)
            let bottomIndex = Int32(segments + 1)
            
            // Top facets (crown)
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [topIndex, Int32(i), Int32(next)])
            }
            
            // Bottom facets (pavilion)
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [bottomIndex, Int32(next), Int32(i)])
            }
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createMarquiseGeometry() -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            vertices.append(SCNVector3(0, 1.0, 0))
            
            let segments = 12
            for i in 0..<segments {
                let angle = Float(i) * 2 * .pi / Float(segments)
                vertices.append(SCNVector3(
                    cos(angle) * 0.5,
                    0,
                    sin(angle) * 1.2
                ))
            }
            
            vertices.append(SCNVector3(0, -1.0, 0))
            
            let topIndex: Int32 = 0
            let bottomIndex = Int32(segments + 1)
            
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [topIndex, Int32(i + 1), Int32(next + 1)])
            }
            
            for i in 0..<segments {
                let next = (i + 1) % segments
                indices.append(contentsOf: [bottomIndex, Int32(next + 1), Int32(i + 1)])
            }
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createEmeraldGeometry() -> SCNGeometry {
            return SCNBox(width: 1.4, height: 1.4, length: 1.0, chamferRadius: 0.2)
        }
        
        private func createHexagonGeometry() -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            for i in 0..<6 {
                let angle = Float(i) * .pi / 3.0
                vertices.append(SCNVector3(cos(angle), 0.8, sin(angle)))
            }
            
            for i in 0..<6 {
                let angle = Float(i) * .pi / 3.0
                vertices.append(SCNVector3(cos(angle), -0.8, sin(angle)))
            }
            
            for i in 1..<5 {
                indices.append(contentsOf: [0, Int32(i), Int32(i + 1)])
            }
            
            for i in 1..<5 {
                indices.append(contentsOf: [6, Int32(i + 7), Int32(i + 6)])
            }
            
            for i in 0..<6 {
                let next = (i + 1) % 6
                indices.append(contentsOf: [
                    Int32(i), Int32(i + 6), Int32(next + 6),
                    Int32(i), Int32(next + 6), Int32(next)
                ])
            }
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createPearGeometry() -> SCNGeometry {
            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            
            let topSegments = 8
            for i in 0..<topSegments {
                let angle = Float(i) * 2 * .pi / Float(topSegments)
                vertices.append(SCNVector3(
                    cos(angle) * 0.8,
                    0.5,
                    sin(angle) * 0.8
                ))
            }
            
            vertices.append(SCNVector3(0, 1.2, 0))
            vertices.append(SCNVector3(0, -1.5, 0))
            
            let topPointIndex = Int32(topSegments)
            let bottomPointIndex = Int32(topSegments + 1)
            
            for i in 0..<topSegments {
                let next = (i + 1) % topSegments
                indices.append(contentsOf: [topPointIndex, Int32(i), Int32(next)])
            }
            
            for i in 0..<topSegments {
                let next = (i + 1) % topSegments
                indices.append(contentsOf: [bottomPointIndex, Int32(next), Int32(i)])
            }
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createOctahedronGeometry() -> SCNGeometry {
            let vertices: [SCNVector3] = [
                SCNVector3(0, 1.2, 0),
                SCNVector3(1, 0, 0),
                SCNVector3(0, 0, 1),
                SCNVector3(-1, 0, 0),
                SCNVector3(0, 0, -1),
                SCNVector3(0, -1.2, 0)
            ]
            
            let indices: [Int32] = [
                0, 1, 2,
                0, 2, 3,
                0, 3, 4,
                0, 4, 1,
                5, 2, 1,
                5, 3, 2,
                5, 4, 3,
                5, 1, 4
            ]
            
            return createGeometryFromVertices(vertices: vertices, indices: indices)
        }
        
        private func createGeometryFromVertices(vertices: [SCNVector3], indices: [Int32]) -> SCNGeometry {
            // Create FLAT-SHADED geometry with per-face normals
            // This gives us sharp facet edges like a real diamond
            
            var flatVertices: [SCNVector3] = []
            var flatNormals: [SCNVector3] = []
            var flatIndices: [Int32] = []
            
            // For each triangle, create 3 new vertices with the same face normal
            for i in stride(from: 0, to: indices.count, by: 3) {
                let i1 = Int(indices[i])
                let i2 = Int(indices[i + 1])
                let i3 = Int(indices[i + 2])
                
                let v1 = vertices[i1]
                let v2 = vertices[i2]
                let v3 = vertices[i3]
                
                // Calculate face normal
                let edge1 = SCNVector3(v2.x - v1.x, v2.y - v1.y, v2.z - v1.z)
                let edge2 = SCNVector3(v3.x - v1.x, v3.y - v1.y, v3.z - v1.z)
                
                let normal = normalize(SCNVector3(
                    edge1.y * edge2.z - edge1.z * edge2.y,
                    edge1.z * edge2.x - edge1.x * edge2.z,
                    edge1.x * edge2.y - edge1.y * edge2.x
                ))
                
                // Add all 3 vertices with the SAME normal (flat shading)
                let baseIndex = Int32(flatVertices.count)
                flatVertices.append(contentsOf: [v1, v2, v3])
                flatNormals.append(contentsOf: [normal, normal, normal])
                flatIndices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
            }
            
            let vertexSource = SCNGeometrySource(vertices: flatVertices)
            let normalSource = SCNGeometrySource(normals: flatNormals)
            
            let indexData = Data(bytes: flatIndices, count: flatIndices.count * MemoryLayout<Int32>.size)
            let element = SCNGeometryElement(
                data: indexData,
                primitiveType: .triangles,
                primitiveCount: flatIndices.count / 3,
                bytesPerIndex: MemoryLayout<Int32>.size
            )
            
            return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        }
        
        private func add(_ v1: SCNVector3, _ v2: SCNVector3) -> SCNVector3 {
            SCNVector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
        }
        
        private func normalize(_ v: SCNVector3) -> SCNVector3 {
            let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            guard length > 0 else { return v }
            return SCNVector3(v.x / length, v.y / length, v.z / length)
        }
        
        private func primaryUIColor(model: CrystalModel, brightness: Double = 0.5) -> UIColor {
            UIColor(
                hue: CGFloat(model.primaryHue / 360.0),
                saturation: CGFloat(model.saturation),
                brightness: CGFloat(brightness),  // Much darker base color
                alpha: 1.0
            )
        }
        
        private func secondaryUIColor(model: CrystalModel, brightness: Double = 0.45) -> UIColor {
            UIColor(
                hue: CGFloat(model.secondaryHue / 360.0),
                saturation: CGFloat(model.saturation),
                brightness: CGFloat(brightness),  // Much darker base color
                alpha: 1.0
            )
        }
        
        private func blend(color1: UIColor, color2: UIColor, ratio: CGFloat) -> UIColor {
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            return UIColor(
                red: r1 * (1 - ratio) + r2 * ratio,
                green: g1 * (1 - ratio) + g2 * ratio,
                blue: b1 * (1 - ratio) + b2 * ratio,
                alpha: a1 * (1 - ratio) + a2 * ratio
            )
        }
    }
}

struct Crystal3DView: UIViewRepresentable {
    let model: CrystalModel
    let size: CGFloat
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.allowsCameraControl = false  // Disable default control for custom momentum
        sceneView.autoenablesDefaultLighting = false
        sceneView.antialiasingMode = .multisampling4X
        
        // Prevent stretching/distortion
        sceneView.contentMode = .scaleAspectFit
        
        // Enable continuous rendering for smooth momentum animation
        sceneView.rendersContinuously = true
        
        // Create scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Setup camera with better perspective
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.fieldOfView = 35  // Narrower field of view for less distortion
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 4.0)
        scene.rootNode.addChildNode(cameraNode)
        
        // Setup lighting for gem appearance
        setupLighting(scene: scene, model: model)
        
        // Create the crystal geometry
        let crystalNode = createCrystalNode(model: model)
        scene.rootNode.addChildNode(crystalNode)
        
        // Tilt the crystal based on shape to show it off better
        if model.baseForm.lowercased() == "heart" {
            // For heart shapes, tilt forward so we can see the heart outline
            crystalNode.eulerAngles = SCNVector3(x: -.pi / 6, y: 0, z: 0)  // Tilt 30 degrees forward
        }
        
        // Store crystal node in coordinator for momentum control
        context.coordinator.crystalNode = crystalNode
        context.coordinator.initialTilt = crystalNode.eulerAngles.x
        
        // Add pan gesture for momentum-based rotation
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        sceneView.addGestureRecognizer(panGesture)
        
        // Start with a gentle automatic rotation
        context.coordinator.startGentleRotation()
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var crystalNode: SCNNode?
        var initialTilt: Float = 0
        
        // Momentum tracking
        private var lastPanTime: TimeInterval = 0
        private var lastPanTranslation: CGPoint = .zero
        private var angularVelocityY: CGFloat = 0
        private var angularVelocityX: CGFloat = 0
        private var displayLink: CADisplayLink?
        
        func startGentleRotation() {
            // Start with a gentle automatic rotation
            angularVelocityY = 0.5
            startMomentumAnimation()
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let crystalNode = crystalNode else { return }
            
            let translation = gesture.translation(in: gesture.view)
            let currentTime = CACurrentMediaTime()
            
            switch gesture.state {
            case .began:
                // Stop any existing momentum
                displayLink?.invalidate()
                displayLink = nil
                angularVelocityY = 0
                angularVelocityX = 0
                lastPanTranslation = translation
                lastPanTime = currentTime
                
            case .changed:
                // Calculate rotation based on drag
                let deltaX = translation.x - lastPanTranslation.x
                let deltaY = translation.y - lastPanTranslation.y
                let deltaTime = currentTime - lastPanTime
                
                // Rotate around Y axis for horizontal movement
                // Rotate around X axis for vertical movement
                let rotationY = Float(deltaX) * 0.01
                let rotationX = Float(deltaY) * 0.01
                
                // Apply rotation
                crystalNode.eulerAngles.y += rotationY
                crystalNode.eulerAngles.x -= rotationX
                
                // Calculate velocity for momentum
                if deltaTime > 0 {
                    angularVelocityY = deltaX / deltaTime * 0.01
                    angularVelocityX = -deltaY / deltaTime * 0.01
                }
                
                lastPanTranslation = translation
                lastPanTime = currentTime
                
            case .ended, .cancelled:
                // Continue with momentum in the direction user indicated
                // Only set minimum speed if there was significant movement
                if abs(angularVelocityY) < 0.1 {
                    // Very slow or stopped - use the current rotation direction of the crystal
                    // to determine which way to spin at minimum speed
                    angularVelocityY = angularVelocityY >= 0 ? 0.3 : -0.3
                }
                startMomentumAnimation()
                
            default:
                break
            }
        }
        
        private func startMomentumAnimation() {
            displayLink?.invalidate()
            
            let displayLink = CADisplayLink(target: self, selector: #selector(updateMomentum))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
        
        @objc private func updateMomentum() {
            guard let crystalNode = crystalNode else {
                displayLink?.invalidate()
                displayLink = nil
                return
            }
            
            // Apply current velocity
            crystalNode.eulerAngles.y += Float(angularVelocityY) * 0.016 // Approximate frame time
            crystalNode.eulerAngles.x += Float(angularVelocityX) * 0.016
            
            // Keep X rotation constrained to prevent flipping upside down
            crystalNode.eulerAngles.x = max(-Float.pi / 3, min(Float.pi / 3, crystalNode.eulerAngles.x))
            
            // Apply very light friction/damping until we reach minimum speed
            let minSpeed: CGFloat = 0.3
            if abs(angularVelocityY) > minSpeed {
                angularVelocityY *= 0.995
            } else {
                // Lock at minimum speed in the current direction
                angularVelocityY = angularVelocityY > 0 ? minSpeed : -minSpeed
            }
            
            // Gradually slow down vertical rotation
            angularVelocityX *= 0.95
            
            // Stop X rotation when it gets very slow (no snap-back to initial tilt)
            if abs(angularVelocityX) < 0.01 {
                angularVelocityX = 0
            }
        }
        
        deinit {
            displayLink?.invalidate()
        }
    }
    
    private func setupLighting(scene: SCNScene, model: CrystalModel) {
        // Ambient light - tuned for better base visibility
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor.white
        ambientLight.light!.intensity = 111  // Optimized from tuning
        scene.rootNode.addChildNode(ambientLight)
        
        // Key light from upper right - main "flash" source
        // Using omni light so it responds to facet angles properly
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light!.type = .omni
        keyLight.light!.color = UIColor.white
        keyLight.light!.intensity = 602  // Optimized from tuning
        keyLight.light!.castsShadow = false
        keyLight.position = SCNVector3(x: 4, y: 4, z: 5)  // Upper right front, further out
        scene.rootNode.addChildNode(keyLight)
        
        // Accent light from opposite side for secondary sparkle
        let accentLight = SCNNode()
        accentLight.light = SCNLight()
        accentLight.light!.type = .omni
        accentLight.light!.color = UIColor.white
        accentLight.light!.intensity = 301  // Half of key light
        accentLight.light!.castsShadow = false
        accentLight.position = SCNVector3(x: -3, y: 3, z: 5)  // Upper left front
        scene.rootNode.addChildNode(accentLight)
        
        // Fill light with gem color - subtle colored glow
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light!.type = .omni
        fillLight.light!.color = primaryUIColor(model: model)
        fillLight.light!.intensity = 529  // Optimized from tuning
        fillLight.light!.castsShadow = false
        fillLight.position = SCNVector3(x: -2, y: -1, z: 3)  // Lower left
        scene.rootNode.addChildNode(fillLight)
        
        // Rim/backlight for edge brilliance
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light!.type = .omni
        rimLight.light!.color = UIColor.white
        rimLight.light!.intensity = 500  // Moderate rim for edge brilliance
        rimLight.light!.castsShadow = false
        rimLight.position = SCNVector3(x: 0, y: -3, z: -2)  // Below and behind
        scene.rootNode.addChildNode(rimLight)
    }
    
    private func createCrystalNode(model: CrystalModel) -> SCNNode {
        let geometry = createCrystalGeometry(baseForm: model.baseForm)
        let node = SCNNode(geometry: geometry)
        
        // Apply material for gem-like appearance
        let material = SCNMaterial()
        
        // Base color - blend primary and secondary colors
        let primaryColor = primaryUIColor(model: model)
        let secondaryColor = secondaryUIColor(model: model)
        
        // Mix colors based on secondary influence
        let mixRatio = CGFloat(model.bodySecondaryMix)
        let blendedColor = blend(color1: primaryColor, color2: secondaryColor, ratio: mixRatio)
        
        // Diffuse color - use the colored material, not white/bright base
        material.diffuse.contents = blendedColor.withAlphaComponent(0.9)
        
        // Enable transparency
        material.transparency = 0.9
        material.transparencyMode = .aOne
        
        // BRILLIANT WHITE specular highlights - this creates the "flash" on facets
        // Sharp, small highlights that sweep across individual facets as it rotates
        material.specular.contents = UIColor.white
        material.specular.intensity = 2.5
        material.shininess = CGFloat(0.85 * 100)  // Sharp, focused highlights on facet edges
        
        // Perfectly smooth polished surface
        material.roughness.contents = 0.0
        
        // No metalness - gems are dielectric
        material.metalness.contents = 0.0
        
        // CHROMATIC ABERRATION via refraction property
        // Use the crystal's refraction value to add rainbow dispersion at edges
        let chromaticAberration = model.refraction
        
        if chromaticAberration > 0.01 {
            // Add subtle rainbow tint to reflections based on refraction
            let rainbowTexture = createRainbowEnvironmentTexture()
            material.reflective.contents = rainbowTexture
            material.reflective.intensity = CGFloat(0.5 * 0.3 + chromaticAberration * 0.2)
            material.fresnelExponent = CGFloat(1.0 / (1.0 + chromaticAberration))  // More refraction = more edge effect
        } else {
            // No chromatic aberration
            material.reflective.contents = UIColor(white: 1.0, alpha: 0.2)
            material.reflective.intensity = 0.3
            material.fresnelExponent = 0.5  // Very low = minimal edge glow
        }
        
        // Inner glow from model
        if model.innerLightIntensity > 0 {
            let glowIntensity = min(model.innerLightIntensity * 0.7, 0.5)
            let emissionColor = secondaryUIColor(model: model).withAlphaComponent(glowIntensity)
            material.emission.contents = emissionColor
        }
        
        // Enable double-sided rendering
        material.isDoubleSided = true
        
        // Use Phong lighting model for sharp, crisp facet highlights
        material.lightingModel = .phong
        
        // Transparency settings
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = false
        material.blendMode = .alpha
        node.renderingOrder = 100
        
        geometry.materials = [material]
        
        return node
    }
    
    // Helper to create a rainbow environment texture
    private func createRainbowEnvironmentTexture() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Create a radial rainbow gradient
            let colors = [
                UIColor(hue: 0.0, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,    // Red
                UIColor(hue: 0.15, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Orange
                UIColor(hue: 0.25, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Yellow
                UIColor(hue: 0.4, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,    // Green
                UIColor(hue: 0.55, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Cyan
                UIColor(hue: 0.65, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Blue
                UIColor(hue: 0.75, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Indigo
                UIColor(hue: 0.85, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor,   // Violet
                UIColor(hue: 1.0, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor     // Red
            ]
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
            )!
            
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            ctx.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size.width / 2,
                options: []
            )
        }
    }
    
    private func createCrystalGeometry(baseForm: String) -> SCNGeometry {
        switch baseForm.lowercased() {
        case "diamond":
            return createDiamondGeometry()
        case "brilliant":
            return createBrilliantGeometry()
        case "heart":
            return createHeartGeometry()
        case "marquise":
            return createMarquiseGeometry()
        case "emerald", "baguette":
            return createEmeraldGeometry()
        case "hexagon":
            return createHexagonGeometry()
        case "pear", "teardrop":
            return createPearGeometry()
        case "sphere", "orb", "cabochon":
            return SCNSphere(radius: 1.0)
        case "octahedron":
            return createOctahedronGeometry()
        default:
            return createDiamondGeometry()
        }
    }
    
    // MARK: - Geometry Builders
    
    private func createDiamondGeometry() -> SCNGeometry {
        // Classic brilliant cut diamond
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Top point (table)
        vertices.append(SCNVector3(0, 1.2, 0))
        
        // Crown (upper girdle) - 8 points
        let crownHeight: Float = 0.4
        let crownRadius: Float = 0.8
        for i in 0..<8 {
            let angle = Float(i) * .pi / 4.0
            vertices.append(SCNVector3(
                cos(angle) * crownRadius,
                crownHeight,
                sin(angle) * crownRadius
            ))
        }
        
        // Girdle (widest part) - 8 points
        let girdleRadius: Float = 1.0
        for i in 0..<8 {
            let angle = Float(i) * .pi / 4.0
            vertices.append(SCNVector3(
                cos(angle) * girdleRadius,
                0,
                sin(angle) * girdleRadius
            ))
        }
        
        // Pavilion (lower) - 8 points
        let pavilionHeight: Float = -0.8
        let pavilionRadius: Float = 0.4
        for i in 0..<8 {
            let angle = Float(i) * .pi / 4.0
            vertices.append(SCNVector3(
                cos(angle) * pavilionRadius,
                pavilionHeight,
                sin(angle) * pavilionRadius
            ))
        }
        
        // Culet (bottom point)
        vertices.append(SCNVector3(0, -1.4, 0))
        
        // Create triangular facets
        // Top facets (table to crown)
        for i in 0..<8 {
            let next = (i + 1) % 8
            indices.append(contentsOf: [0, Int32(i + 1), Int32(next + 1)])
        }
        
        // Crown facets (crown to girdle)
        for i in 0..<8 {
            let next = (i + 1) % 8
            indices.append(contentsOf: [
                Int32(i + 1), Int32(i + 9), Int32(next + 9),
                Int32(i + 1), Int32(next + 9), Int32(next + 1)
            ])
        }
        
        // Pavilion facets (girdle to pavilion)
        for i in 0..<8 {
            let next = (i + 1) % 8
            indices.append(contentsOf: [
                Int32(i + 9), Int32(i + 17), Int32(next + 17),
                Int32(i + 9), Int32(next + 17), Int32(next + 9)
            ])
        }
        
        // Bottom facets (pavilion to culet)
        let culetIndex = Int32(vertices.count - 1)
        for i in 0..<8 {
            let next = (i + 1) % 8
            indices.append(contentsOf: [Int32(i + 17), culetIndex, Int32(next + 17)])
        }
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    private func createBrilliantGeometry() -> SCNGeometry {
        // High-facet brilliant cut with 16 segments for MAXIMUM SPARKLE
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        let segments = 16  // Double the facets for intense sparkle!
        
        // Table (top center point)
        vertices.append(SCNVector3(0, 1.2, 0))
        
        // Star facets ring (just below table)
        let starHeight: Float = 0.9
        let starRadius: Float = 0.5
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * starRadius,
                starHeight,
                sin(angle) * starRadius
            ))
        }
        
        // Upper crown ring
        let upperCrownHeight: Float = 0.6
        let upperCrownRadius: Float = 0.75
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * upperCrownRadius,
                upperCrownHeight,
                sin(angle) * upperCrownRadius
            ))
        }
        
        // Lower crown ring (near girdle)
        let lowerCrownHeight: Float = 0.3
        let lowerCrownRadius: Float = 0.9
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * lowerCrownRadius,
                lowerCrownHeight,
                sin(angle) * lowerCrownRadius
            ))
        }
        
        // Girdle (widest part)
        let girdleRadius: Float = 1.0
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * girdleRadius,
                0,
                sin(angle) * girdleRadius
            ))
        }
        
        // Upper pavilion ring
        let upperPavilionHeight: Float = -0.4
        let upperPavilionRadius: Float = 0.7
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * upperPavilionRadius,
                upperPavilionHeight,
                sin(angle) * upperPavilionRadius
            ))
        }
        
        // Lower pavilion ring
        let lowerPavilionHeight: Float = -0.9
        let lowerPavilionRadius: Float = 0.4
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * lowerPavilionRadius,
                lowerPavilionHeight,
                sin(angle) * lowerPavilionRadius
            ))
        }
        
        // Culet (bottom point)
        vertices.append(SCNVector3(0, -1.4, 0))
        
        // Now create all the facets
        let tableIndex: Int32 = 0
        let starStart = 1
        let upperCrownStart = starStart + segments
        let lowerCrownStart = upperCrownStart + segments
        let girdleStart = lowerCrownStart + segments
        let upperPavilionStart = girdleStart + segments
        let lowerPavilionStart = upperPavilionStart + segments
        let culetIndex = Int32(lowerPavilionStart + segments)
        
        // Table to star facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                tableIndex,
                Int32(starStart + i),
                Int32(starStart + next)
            ])
        }
        
        // Star to upper crown facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                Int32(starStart + i),
                Int32(upperCrownStart + i),
                Int32(upperCrownStart + next),
                Int32(starStart + i),
                Int32(upperCrownStart + next),
                Int32(starStart + next)
            ])
        }
        
        // Upper crown to lower crown facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                Int32(upperCrownStart + i),
                Int32(lowerCrownStart + i),
                Int32(lowerCrownStart + next),
                Int32(upperCrownStart + i),
                Int32(lowerCrownStart + next),
                Int32(upperCrownStart + next)
            ])
        }
        
        // Lower crown to girdle facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                Int32(lowerCrownStart + i),
                Int32(girdleStart + i),
                Int32(girdleStart + next),
                Int32(lowerCrownStart + i),
                Int32(girdleStart + next),
                Int32(lowerCrownStart + next)
            ])
        }
        
        // Girdle to upper pavilion facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                Int32(girdleStart + i),
                Int32(upperPavilionStart + i),
                Int32(upperPavilionStart + next),
                Int32(girdleStart + i),
                Int32(upperPavilionStart + next),
                Int32(girdleStart + next)
            ])
        }
        
        // Upper pavilion to lower pavilion facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                Int32(upperPavilionStart + i),
                Int32(lowerPavilionStart + i),
                Int32(lowerPavilionStart + next),
                Int32(upperPavilionStart + i),
                Int32(lowerPavilionStart + next),
                Int32(upperPavilionStart + next)
            ])
        }
        
        // Lower pavilion to culet facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [
                Int32(lowerPavilionStart + i),
                culetIndex,
                Int32(lowerPavilionStart + next)
            ])
        }
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    private func createHeartGeometry() -> SCNGeometry {
        // Proper heart-shaped gemstone
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Create a proper heart shape using parametric heart curve
        let segments = 24  // More segments for smoother heart
        
        // Heart curve in the XZ plane (girdle)
        for i in 0..<segments {
            let t = Float(i) / Float(segments) * 2 * .pi
            
            // Parametric heart equations (scaled and centered)
            let x = 0.7 * (16 * pow(sin(t), 3)) / 16.0
            let z = 0.7 * (13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) / 16.0
            
            vertices.append(SCNVector3(x, 0, -z))  // Negative z to orient correctly
        }
        
        // Top point
        vertices.append(SCNVector3(0, 1.0, 0))
        // Bottom point (culet)
        vertices.append(SCNVector3(0, -1.2, 0))
        
        let topIndex = Int32(segments)
        let bottomIndex = Int32(segments + 1)
        
        // Top facets (crown)
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [topIndex, Int32(i), Int32(next)])
        }
        
        // Bottom facets (pavilion)
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [bottomIndex, Int32(next), Int32(i)])
        }
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    private func createMarquiseGeometry() -> SCNGeometry {
        // Elongated marquise cut
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Top point
        vertices.append(SCNVector3(0, 1.0, 0))
        
        // Girdle ellipse (elongated)
        let segments = 12
        for i in 0..<segments {
            let angle = Float(i) * 2 * .pi / Float(segments)
            vertices.append(SCNVector3(
                cos(angle) * 0.5,  // narrower
                0,
                sin(angle) * 1.2   // elongated
            ))
        }
        
        // Bottom point
        vertices.append(SCNVector3(0, -1.0, 0))
        
        let topIndex: Int32 = 0
        let bottomIndex = Int32(segments + 1)
        
        // Top facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [topIndex, Int32(i + 1), Int32(next + 1)])
        }
        
        // Bottom facets
        for i in 0..<segments {
            let next = (i + 1) % segments
            indices.append(contentsOf: [bottomIndex, Int32(next + 1), Int32(i + 1)])
        }
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    private func createEmeraldGeometry() -> SCNGeometry {
        // Step cut (emerald cut) with beveled corners
        let box = SCNBox(width: 1.4, height: 1.4, length: 1.0, chamferRadius: 0.2)
        return box
    }
    
    private func createHexagonGeometry() -> SCNGeometry {
        // Hexagonal prism
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Top hexagon
        for i in 0..<6 {
            let angle = Float(i) * .pi / 3.0
            vertices.append(SCNVector3(cos(angle), 0.8, sin(angle)))
        }
        
        // Bottom hexagon
        for i in 0..<6 {
            let angle = Float(i) * .pi / 3.0
            vertices.append(SCNVector3(cos(angle), -0.8, sin(angle)))
        }
        
        // Top face
        for i in 1..<5 {
            indices.append(contentsOf: [0, Int32(i), Int32(i + 1)])
        }
        
        // Bottom face
        for i in 1..<5 {
            indices.append(contentsOf: [6, Int32(i + 7), Int32(i + 6)])
        }
        
        // Side facets
        for i in 0..<6 {
            let next = (i + 1) % 6
            indices.append(contentsOf: [
                Int32(i), Int32(i + 6), Int32(next + 6),
                Int32(i), Int32(next + 6), Int32(next)
            ])
        }
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    private func createPearGeometry() -> SCNGeometry {
        // Pear/teardrop shape
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Top rounded part
        let topSegments = 8
        for i in 0..<topSegments {
            let angle = Float(i) * 2 * .pi / Float(topSegments)
            vertices.append(SCNVector3(
                cos(angle) * 0.8,
                0.5,
                sin(angle) * 0.8
            ))
        }
        
        // Top point
        vertices.append(SCNVector3(0, 1.2, 0))
        
        // Bottom point
        vertices.append(SCNVector3(0, -1.5, 0))
        
        let topPointIndex = Int32(topSegments)
        let bottomPointIndex = Int32(topSegments + 1)
        
        // Top cap
        for i in 0..<topSegments {
            let next = (i + 1) % topSegments
            indices.append(contentsOf: [topPointIndex, Int32(i), Int32(next)])
        }
        
        // Bottom facets
        for i in 0..<topSegments {
            let next = (i + 1) % topSegments
            indices.append(contentsOf: [bottomPointIndex, Int32(next), Int32(i)])
        }
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    private func createOctahedronGeometry() -> SCNGeometry {
        // Double pyramid
        let vertices: [SCNVector3] = [
            SCNVector3(0, 1.2, 0),      // top
            SCNVector3(1, 0, 0),        // right
            SCNVector3(0, 0, 1),        // front
            SCNVector3(-1, 0, 0),       // left
            SCNVector3(0, 0, -1),       // back
            SCNVector3(0, -1.2, 0)      // bottom
        ]
        
        let indices: [Int32] = [
            // Top pyramid
            0, 1, 2,
            0, 2, 3,
            0, 3, 4,
            0, 4, 1,
            // Bottom pyramid
            5, 2, 1,
            5, 3, 2,
            5, 4, 3,
            5, 1, 4
        ]
        
        return createGeometryFromVertices(vertices: vertices, indices: indices)
    }
    
    // MARK: - Helpers
    
    private func createGeometryFromVertices(vertices: [SCNVector3], indices: [Int32]) -> SCNGeometry {
        // Create FLAT-SHADED geometry with per-face normals for sharp facet edges
        var flatVertices: [SCNVector3] = []
        var flatNormals: [SCNVector3] = []
        var flatIndices: [Int32] = []
        
        // For each triangle, create 3 new vertices with the same face normal
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i1 = Int(indices[i])
            let i2 = Int(indices[i + 1])
            let i3 = Int(indices[i + 2])
            
            let v1 = vertices[i1]
            let v2 = vertices[i2]
            let v3 = vertices[i3]
            
            // Calculate face normal
            let edge1 = SCNVector3(v2.x - v1.x, v2.y - v1.y, v2.z - v1.z)
            let edge2 = SCNVector3(v3.x - v1.x, v3.y - v1.y, v3.z - v1.z)
            
            let normal = normalize(SCNVector3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            ))
            
            // Add all 3 vertices with the SAME normal (flat shading)
            let baseIndex = Int32(flatVertices.count)
            flatVertices.append(contentsOf: [v1, v2, v3])
            flatNormals.append(contentsOf: [normal, normal, normal])
            flatIndices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
        }
        
        let vertexSource = SCNGeometrySource(vertices: flatVertices)
        let normalSource = SCNGeometrySource(normals: flatNormals)
        
        let indexData = Data(bytes: flatIndices, count: flatIndices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: flatIndices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    }
    
    private func add(_ v1: SCNVector3, _ v2: SCNVector3) -> SCNVector3 {
        SCNVector3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
    }
    
    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let length = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        guard length > 0 else { return v }
        return SCNVector3(v.x / length, v.y / length, v.z / length)
    }
    
    private func primaryUIColor(model: CrystalModel) -> UIColor {
        UIColor(
            hue: CGFloat(model.primaryHue / 360.0),
            saturation: CGFloat(model.saturation), // Use exact saturation from model
            brightness: 0.5,  // Much darker base - relies on lights to illuminate
            alpha: 1.0
        )
    }
    
    private func secondaryUIColor(model: CrystalModel) -> UIColor {
        UIColor(
            hue: CGFloat(model.secondaryHue / 360.0),
            saturation: CGFloat(model.saturation), // Use exact saturation from model
            brightness: 0.45,  // Much darker base - relies on lights to illuminate
            alpha: 1.0
        )
    }
    
    private func blend(color1: UIColor, color2: UIColor, ratio: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(
            red: r1 * (1 - ratio) + r2 * ratio,
            green: g1 * (1 - ratio) + g2 * ratio,
            blue: b1 * (1 - ratio) + b2 * ratio,
            alpha: a1 * (1 - ratio) + a2 * ratio
        )
    }
}

// MARK: - Orbital Satellite

struct OrbitalView: View {
    let orbital: OrbitalConfig
    let size: CGFloat
    let phase: Double
    
    var body: some View {
        let orbitalRadius = size * 0.35 * orbital.radius
        let x = orbitalRadius * cos(phase) * (1 - orbital.eccentricity * 0.5)
        let y = orbitalRadius * sin(phase)
        
        ZStack {
            // Trail effect
            if orbital.trail {
                ForEach(0..<5, id: \.self) { i in
                    let trailPhase = phase - Double(i) * 0.15
                    let trailX = orbitalRadius * cos(trailPhase) * (1 - orbital.eccentricity * 0.5)
                    let trailY = orbitalRadius * sin(trailPhase)
                    
                    Circle()
                        .fill(satelliteColor.opacity(0.3 / Double(i + 1)))
                        .frame(width: satelliteSize * 0.8, height: satelliteSize * 0.8)
                        .offset(x: trailX, y: trailY)
                }
            }
            
            // Main satellite
            Circle()
                .fill(satelliteColor)
                .frame(width: satelliteSize, height: satelliteSize)
                .shadow(color: satelliteColor.opacity(0.6), radius: 3)
                .offset(x: x, y: y)
        }
        .rotation3DEffect(
            .degrees(orbital.tilt),
            axis: (x: 1, y: 0, z: 0)
        )
    }
    
    private var satelliteSize: CGFloat {
        size * 0.12 * orbital.size
    }
    
    private var satelliteColor: Color {
        Color(hue: orbital.color / 360.0, saturation: 0.7, brightness: 0.95)
    }
}

// MARK: - Preview Helpers

#Preview("Newborn Crystal") {
    let dna = CrystalDNA(
        identity: CrystalIdentity(
            primaryHue: 280,
            secondaryHue: 40,
            saturation: 0.7,
            materialFamily: "coloredGemstone",
            baseForm: "diamond",
            colorRelationship: "complementary",
            secondaryInfluence: 0.5
        ),
        personality: CrystalPersonality(
            complexityBias: 0.6,
            orbitalAffinity: 0.7,
            refraction: 0.8
        ),
        seed: "preview-seed-123"
    )
    
    VStack(spacing: 20) {
        CrystalView(dna: dna, transferCount: 0, size: 200)
        Text("Newborn")
            .font(.caption)
    }
    .padding()
}

#Preview("Legendary Crystal") {
    let dna = CrystalDNA(
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
        seed: "legendary-preview-seed"
    )
    
    VStack(spacing: 20) {
        CrystalView(dna: dna, transferCount: 60, size: 250)
        Text("Legendary • 60 Transfers")
            .font(.caption)
    }
    .padding()
    .background(Color.black)
}

#Preview("Various Cuts") {
    let cuts = ["diamond", "heart", "pear", "emerald", "hexagon", "marquise", "octahedron"]
    
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
            ForEach(cuts, id: \.self) { cut in
                VStack(spacing: 8) {
                    let dna = CrystalDNA(
                        identity: CrystalIdentity(
                            primaryHue: Double.random(in: 0...360),
                            secondaryHue: Double.random(in: 0...360),
                            saturation: 0.75,
                            materialFamily: "coloredGemstone",
                            baseForm: cut,
                            colorRelationship: "complementary",
                            secondaryInfluence: 0.6
                        ),
                        personality: CrystalPersonality(
                            complexityBias: 0.6,
                            orbitalAffinity: 0.7,
                            refraction: 0.8
                        ),
                        seed: "preview-\(cut)"
                    )
                    
                    CrystalView(dna: dna, transferCount: 10, size: 120)
                    
                    Text(cut.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Tuning Studio") {
    CrystalTuningView()
}

// MARK: - Tuning Studio

struct CrystalTuningView: View {
    // Lighting controls - optimized from user testing
    @State private var ambientIntensity: Double = 111
    @State private var keyIntensity: Double = 602
    @State private var fillIntensity: Double = 529
    @State private var rimIntensity: Double = 500
    
    // Material controls - tuned for brilliant gem appearance
    @State private var brightness: Double = 0.5  // Base material color (dark = relies on lights)
    @State private var shininess: Double = 0.85   // Sharp facet highlights (higher = smaller)
    @State private var roughness: Double = 0.0    // Perfectly smooth
    @State private var reflectivity: Double = 0.5  // Moderate reflectivity for sparkle
    
    // NEW: Chromatic/Prismatic controls
    @State private var chromaticAberration: Double = 0.0  // Amount of rainbow dispersion
    @State private var fresnelIntensity: Double = 1.0  // Edge rainbow intensity
    @State private var useRainbowEnvironment: Bool = false  // Use rainbow environment map
    
    // Color controls
    @State private var primaryHue: Double = 226  // Purple/violet
    @State private var colorSaturation: Double = 1.0  // Fully saturated
    
    var testDNA: CrystalDNA {
        CrystalDNA(
            identity: CrystalIdentity(
                primaryHue: primaryHue,
                secondaryHue: primaryHue + 60,  // Complementary
                saturation: colorSaturation,  // Use tunable saturation
                materialFamily: "coloredGemstone",
                baseForm: "brilliant",  // High-facet brilliant cut
                colorRelationship: "complementary",
                secondaryInfluence: 0.3
            ),
            personality: CrystalPersonality(
                complexityBias: 0.6,
                orbitalAffinity: 0.0, // No orbitals for testing
                refraction: 0.8
            ),
            seed: "tuning-test"
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Crystal Tuning Studio")
                    .font(.title.bold())
                
                Text("Hue \(Int(primaryHue))° - \(colorName) | Sat \(Int(colorSaturation * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Crystal preview with explicit frame and professional gem photography background
                ZStack {
                    // Professional dark gradient background (like gem photography)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.25),  // Dark gray at top
                                    Color(white: 0.15)   // Almost black at bottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Subtle reflection surface at bottom third
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 100)
                    }
                    
                    // Crystal with reflection
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Main crystal - positioned in upper portion (already rotating from TunableCrystal3DView)
                        TunableCrystal3DView(
                            model: CrystalEngine.derive(dna: testDNA, transferCount: 5),
                            size: 200,
                            ambientIntensity: ambientIntensity,
                            keyIntensity: keyIntensity,
                            fillIntensity: fillIntensity,
                            rimIntensity: rimIntensity,
                            brightness: brightness,
                            shininess: shininess,
                            roughness: roughness,
                            reflectivity: reflectivity,
                            chromaticAberration: chromaticAberration,
                            fresnelIntensity: fresnelIntensity,
                            useRainbowEnvironment: useRainbowEnvironment
                        )
                        .frame(width: 200, height: 200)
                        .offset(y: -20)  // Shift up a bit
                        
                        // Gap for separation
                        Spacer()
                            .frame(height: 30)
                        
                        // Reflection (flipped and faded)
                        TunableCrystal3DView(
                            model: CrystalEngine.derive(dna: testDNA, transferCount: 5),
                            size: 200,
                            ambientIntensity: ambientIntensity * 0.15,
                            keyIntensity: keyIntensity * 0.15,
                            fillIntensity: fillIntensity * 0.2,
                            rimIntensity: rimIntensity * 0.15,
                            brightness: brightness * 0.3,
                            shininess: shininess,
                            roughness: roughness,
                            reflectivity: reflectivity * 0.3,
                            chromaticAberration: chromaticAberration * 0.3,
                            fresnelIntensity: fresnelIntensity * 0.3,
                            useRainbowEnvironment: useRainbowEnvironment
                        )
                        .frame(width: 200, height: 60)
                        .scaleEffect(x: 1, y: -1)  // Flip vertically
                        .offset(y: -80)  // Position below with gap
                        .opacity(0.2)
                        .blur(radius: 4)
                        .mask(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        Spacer()
                    }
                    
                    // Border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    
                    // Label
                    VStack {
                        Text("3D Preview")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 8)
                        Spacer()
                    }
                }
                .frame(width: 300, height: 300)
                
                // Color Section
                GroupBox("Color") {
                    VStack(spacing: 12) {
                        SliderControl(title: "Hue", value: $primaryHue, range: 0...360)
                        SliderControl(title: "Saturation", value: $colorSaturation, range: 0...1)
                    }
                }
                
                // NEW: Prismatic/Rainbow Effects Section
                GroupBox("Prismatic Effects") {
                    VStack(spacing: 12) {
                        Toggle("Rainbow Environment", isOn: $useRainbowEnvironment)
                        SliderControl(title: "Chromatic Aberration", value: $chromaticAberration, range: 0...1)
                        SliderControl(title: "Fresnel Rainbow", value: $fresnelIntensity, range: 0...2)
                    }
                }
                
                // Lighting Section
                GroupBox("Lighting") {
                    VStack(spacing: 12) {
                        SliderControl(title: "Ambient", value: $ambientIntensity, range: 0...500)
                        SliderControl(title: "Key Light", value: $keyIntensity, range: 0...1000)
                        SliderControl(title: "Fill Light", value: $fillIntensity, range: 0...800)
                        SliderControl(title: "Rim Light", value: $rimIntensity, range: 0...800)
                    }
                }
                
                // Material Section
                GroupBox("Material") {
                    VStack(spacing: 12) {
                        SliderControl(title: "Brightness", value: $brightness, range: 0.3...1.0)
                        SliderControl(title: "Shininess", value: $shininess, range: 0...1)
                        SliderControl(title: "Roughness", value: $roughness, range: 0...0.5)
                        SliderControl(title: "Reflectivity", value: $reflectivity, range: 0...1)
                    }
                }
                
                // Reset button
                Button("Reset to Current Settings") {
                    resetToDefaults()
                }
                .buttonStyle(.borderedProminent)
                
                // Copy code button
                Button("Print Code") {
                    printCurrentSettings()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
    
    private var colorName: String {
        switch Int(primaryHue) {
        case 0..<15, 345...360: return "Red"
        case 15..<45: return "Orange"
        case 45..<75: return "Yellow"
        case 75..<165: return "Green"
        case 165..<255: return "Blue"
        case 255..<285: return "Purple"
        case 285..<345: return "Magenta"
        default: return "Unknown"
        }
    }
    
    private func resetToDefaults() {
        primaryHue = 226  // Purple/violet
        colorSaturation = 1.0  // Fully saturated for vibrant color
        ambientIntensity = 111  // Ambient for overall visibility
        keyIntensity = 602  // Moderate key for brilliant highlights
        fillIntensity = 529  // Strong fill to illuminate facets with color
        rimIntensity = 500  // Moderate rim for edge brilliance
        brightness = 0.5  // Darker base material (lights bring out color)
        shininess = 0.85  // Sharp facet highlights (higher = smaller, sharper)
        roughness = 0.0  // Perfectly smooth
        reflectivity = 0.5  // Moderate for facet sparkle without border glow
        chromaticAberration = 0.3  // Moderate rainbow dispersion
        fresnelIntensity = 1.5  // Enhanced edge rainbows
        useRainbowEnvironment = true  // Enable rainbow reflections
    }
    
    private func printCurrentSettings() {
        print("""
        
        // Current Tuning Settings:
        Color:
          hue: \(primaryHue)
          saturation: \(colorSaturation)
        
        Lighting:
          ambient: \(ambientIntensity)
          key: \(keyIntensity)
          fill: \(fillIntensity)
          rim: \(rimIntensity)
        
        Material:
          brightness: \(brightness)
          shininess: \(shininess)
          roughness: \(roughness)
          reflectivity: \(reflectivity)
        
        Prismatic:
          chromaticAberration: \(chromaticAberration)
          fresnelIntensity: \(fresnelIntensity)
          useRainbowEnvironment: \(useRainbowEnvironment)
        
        """)
    }
}

struct SliderControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Classic Gemstone Shapes (unused - kept for reference)
// These 2D shapes are not currently used since we're rendering in 3D with SceneKit


struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Top point
        path.move(to: CGPoint(x: width * 0.5, y: 0))
        
        // Top-right
        path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.35))
        
        // Right point
        path.addLine(to: CGPoint(x: width, y: height * 0.5))
        
        // Bottom-right
        path.addLine(to: CGPoint(x: width * 0.85, y: height * 0.65))
        
        // Bottom point
        path.addLine(to: CGPoint(x: width * 0.5, y: height))
        
        // Bottom-left
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.65))
        
        // Left point
        path.addLine(to: CGPoint(x: 0, y: height * 0.5))
        
        // Top-left
        path.addLine(to: CGPoint(x: width * 0.15, y: height * 0.35))
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Ornamental Shapes

struct RoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w * 0.5
        let cy = h * 0.5
        
        // Rose cut - domed top with triangular facets
        // Simplified as a multi-point rounded shape
        let points = 6
        for i in 0..<points {
            let angle = (Double(i) * 2 * .pi / Double(points)) - .pi / 2
            let nextAngle = (Double(i + 1) * 2 * .pi / Double(points)) - .pi / 2
            
            let radius = min(w, h) * 0.45
            let x1 = cx + cos(angle) * radius
            let y1 = cy + sin(angle) * radius
            let x2 = cx + cos(nextAngle) * radius
            let y2 = cy + sin(nextAngle) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x1, y: y1))
            }
            
            // Curve between points
            let controlAngle = angle + .pi / Double(points)
            let controlRadius = radius * 1.1
            let cx1 = cx + cos(controlAngle) * controlRadius
            let cy1 = cy + sin(controlAngle) * controlRadius
            
            path.addQuadCurve(
                to: CGPoint(x: x2, y: y2),
                control: CGPoint(x: cx1, y: cy1)
            )
        }
        path.closeSubpath()
        
        return path
    }
}

struct BrioletteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Teardrop/briolette - elongated pear
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        
        path.addCurve(
            to: CGPoint(x: w * 0.8, y: h * 0.6),
            control1: CGPoint(x: w * 0.75, y: h * 0.2),
            control2: CGPoint(x: w * 0.8, y: h * 0.4)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.8, y: h * 0.8),
            control2: CGPoint(x: w * 0.65, y: h * 0.95)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.2, y: h * 0.6),
            control1: CGPoint(x: w * 0.35, y: h * 0.95),
            control2: CGPoint(x: w * 0.2, y: h * 0.8)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.2, y: h * 0.4),
            control2: CGPoint(x: w * 0.25, y: h * 0.2)
        )
        
        return path
    }
}

// MARK: - Organic/Irregular Shapes

struct ShardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Crystalline shard
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.7))
        path.addLine(to: CGPoint(x: w * 0.5, y: h))
        path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.25))
        path.closeSubpath()
        
        return path
    }
}

struct RoundedOpalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Organic rounded shape
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.4),
            control1: CGPoint(x: w * 0.8, y: h * 0.1),
            control2: CGPoint(x: w, y: h * 0.2)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.6, y: h),
            control1: CGPoint(x: w, y: h * 0.7),
            control2: CGPoint(x: w * 0.8, y: h * 0.9)
        )
        
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.5),
            control1: CGPoint(x: w * 0.3, y: h),
            control2: CGPoint(x: 0, y: h * 0.8)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: 0, y: h * 0.2),
            control2: CGPoint(x: w * 0.2, y: 0)
        )
        
        return path
    }
}

struct IrregularOpalShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Very organic irregular shape
        path.move(to: CGPoint(x: w * 0.4, y: 0))
        
        path.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.35),
            control1: CGPoint(x: w * 0.7, y: h * 0.05),
            control2: CGPoint(x: w * 0.9, y: h * 0.15)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.9),
            control1: CGPoint(x: w, y: h * 0.6),
            control2: CGPoint(x: w * 0.95, y: h * 0.75)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.2, y: h * 0.95),
            control1: CGPoint(x: w * 0.6, y: h),
            control2: CGPoint(x: w * 0.4, y: h)
        )
        
        path.addCurve(
            to: CGPoint(x: 0.05 * w, y: h * 0.4),
            control1: CGPoint(x: 0, y: h * 0.85),
            control2: CGPoint(x: 0, y: h * 0.6)
        )
        
        path.addCurve(
            to: CGPoint(x: w * 0.4, y: 0),
            control1: CGPoint(x: w * 0.1, y: h * 0.2),
            control2: CGPoint(x: w * 0.2, y: h * 0.05)
        )
        
        return path
    }
}

struct OrganicMineralShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Chunky, rough mineral shape
        path.move(to: CGPoint(x: w * 0.3, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.15))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.95))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.75))
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.2, y: h * 0.25))
        path.closeSubpath()
        
        return path
    }
}

struct NautilusShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w * 0.5
        let cy = h * 0.5
        
        // Spiral shell shape
        path.move(to: CGPoint(x: cx, y: cy))
        
        // Create a logarithmic spiral approximation
        let turns = 2.0
        let segments = 50
        
        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let angle = t * turns * 2 * .pi
            let radius = (t * min(w, h) * 0.4)
            let x = cx + cos(angle) * radius
            let y = cy + sin(angle) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Close with outer curve
        path.addCurve(
            to: CGPoint(x: cx, y: cy),
            control1: CGPoint(x: cx + w * 0.4, y: cy + h * 0.2),
            control2: CGPoint(x: cx + w * 0.2, y: cy + h * 0.3)
        )
        
        return path
    }
}

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Preview Helpers

#Preview("Newborn Crystal") {
    let dna = CrystalDNA(
        identity: CrystalIdentity(
            primaryHue: 280,
            secondaryHue: 40,
            saturation: 0.7,
            materialFamily: "coloredGemstone",
            baseForm: "diamond",
            colorRelationship: "complementary",
            secondaryInfluence: 0.5
        ),
        personality: CrystalPersonality(
            complexityBias: 0.6,
            orbitalAffinity: 0.7,
            refraction: 0.8
        ),
        seed: "preview-seed-123"
    )
    
    VStack(spacing: 20) {
        CrystalView(dna: dna, transferCount: 0, size: 200)
        Text("Newborn")
            .font(.caption)
    }
    .padding()
}

#Preview("Legendary Crystal") {
    let dna = CrystalDNA(
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
        seed: "legendary-preview-seed"
    )
    
    VStack(spacing: 20) {
        CrystalView(dna: dna, transferCount: 60, size: 250)
        Text("Legendary • 60 Transfers")
            .font(.caption)
    }
    .padding()
    .background(Color.black)
}
#Preview("Various Cuts") {
    let cuts = ["diamond", "heart", "pear", "emerald", "star", "cushion", "octahedron", "rose"]
    
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
            ForEach(cuts, id: \.self) { cut in
                VStack(spacing: 8) {
                    let dna = CrystalDNA(
                        identity: CrystalIdentity(
                            primaryHue: Double.random(in: 0...360),
                            secondaryHue: Double.random(in: 0...360),
                            saturation: 0.75,
                            materialFamily: "coloredGemstone",
                            baseForm: cut,
                            colorRelationship: "complementary",
                            secondaryInfluence: 0.6
                        ),
                        personality: CrystalPersonality(
                            complexityBias: 0.6,
                            orbitalAffinity: 0.7,
                            refraction: 0.8
                        ),
                        seed: "preview-\(cut)"
                    )
                    
                    CrystalView(dna: dna, transferCount: 10, size: 120)
                    
                    Text(cut.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

