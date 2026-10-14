//
//  GameScene.swift
//  favorium
//
//  Created by David Levy on 10/5/26.
//

import SpriteKit
import GameplayKit
import Foundation

fileprivate extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var existing = components.queryItems ?? []
        existing.append(contentsOf: queryItems)
        components.queryItems = existing
        return components.url ?? self
    }
}

class GameScene: SKScene {
    
    private var testButton: SKShapeNode?
    
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    
    override func didMove(to view: SKView) {
        
        // Get label node from scene and store it for use later
        self.label = self.childNode(withName: "//helloLabel") as? SKLabelNode
        if let label = self.label {
            label.alpha = 0.0
            label.run(SKAction.fadeIn(withDuration: 2.0))
        }
        
        // Create shape node to use during mouse interaction
        let w = (self.size.width + self.size.height) * 0.05
        self.spinnyNode = SKShapeNode.init(rectOf: CGSize.init(width: w, height: w), cornerRadius: w * 0.3)
        
        if let spinnyNode = self.spinnyNode {
            spinnyNode.lineWidth = 2.5
            
            spinnyNode.run(SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat(Double.pi), duration: 1)))
            spinnyNode.run(SKAction.sequence([SKAction.wait(forDuration: 0.5),
                                              SKAction.fadeOut(withDuration: 0.5),
                                              SKAction.removeFromParent()]))
        }
        
        // Add a simple button to test Supabase connection
        let buttonSize = CGSize(width: self.size.width * 0.6, height: 50)
        let button = SKShapeNode(rectOf: buttonSize, cornerRadius: 12)
        button.name = "testSupabaseButton"
        button.fillColor = .systemBlue
        button.strokeColor = .white
        button.lineWidth = 2
        button.position = CGPoint(x: self.frame.midX, y: self.frame.minY + buttonSize.height * 1.5)

        let title = SKLabelNode(text: "Test Supabase")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 20
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .center
        title.fontColor = .white
        title.name = "testSupabaseButtonTitle"
        button.addChild(title)

        self.addChild(button)
        self.testButton = button
    }
    
    
    func touchDown(atPoint pos : CGPoint) {
        if let node = self.atPoint(pos) as? SKNode, node.name == "testSupabaseButton" || node.parent?.name == "testSupabaseButton" {
            runButtonTapFeedback()
            testSupabaseConnection()
            return
        }
        if let n = self.spinnyNode?.copy() as? SKShapeNode {
            n.position = pos
            n.strokeColor = SKColor.green
            self.addChild(n)
        }
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        if let n = self.spinnyNode?.copy() as? SKShapeNode {
            n.position = pos
            n.strokeColor = SKColor.blue
            self.addChild(n)
        }
    }
    
    func touchUp(atPoint pos : CGPoint) {
        if let node = self.atPoint(pos) as? SKNode, node.name == "testSupabaseButton" || node.parent?.name == "testSupabaseButton" {
            return
        }
        if let n = self.spinnyNode?.copy() as? SKShapeNode {
            n.position = pos
            n.strokeColor = SKColor.red
            self.addChild(n)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let label = self.label {
            label.run(SKAction.init(named: "Pulse")!, withKey: "fadeInOut")
        }
        
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
    private func runButtonTapFeedback() {
        guard let button = self.testButton else { return }
        let down = SKAction.scale(to: 0.96, duration: 0.06)
        let up = SKAction.scale(to: 1.0, duration: 0.08)
        button.run(SKAction.sequence([down, up]))
    }

    private func testSupabaseConnection() {
        // Update the on-screen label to show progress
        DispatchQueue.main.async {
            self.label?.text = "Testing Supabase…"
            self.label?.alpha = 1.0
        }

        Task { [weak self] in
            do {
                let message = try await SupabaseService.shared.testCoinsCount()
                self?.showResult(message)
            } catch {
                self?.showResult("Error: \(error.localizedDescription)")
            }
        }
    }

    private func showResult(_ message: String) {
        DispatchQueue.main.async {
            if self.label == nil {
                let lbl = SKLabelNode(text: message)
                lbl.name = "helloLabel"
                lbl.fontName = "HelveticaNeue"
                lbl.fontSize = 18
                lbl.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
                self.addChild(lbl)
                self.label = lbl
            } else {
                self.label?.text = message
            }
        }
    }
}

