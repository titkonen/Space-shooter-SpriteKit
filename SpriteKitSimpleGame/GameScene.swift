//
//  GameScene.swift
//  SpriteKitSimpleGame
//
//  Created by Toni Koti on 08/11/2017.
//  Copyright © 2017 Kirijaki. All rights reserved.
//

import SpriteKit

    struct PhysicsCategory {
        static let None      : UInt32 = 0
        static let All       : UInt32 = UInt32.max
        static let Monster   : UInt32 = 0b1       // 1
        static let Projectile: UInt32 = 0b10      // 2
    }

    // en ole varma pitikö nämä laittaa tänne. Toinen paikka on classin sisään??
    func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }

    func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }

    func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * scalar, y: point.y * scalar)
    }

    func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x / scalar, y: point.y / scalar)
    }

    #if !(arch(x86_64) || arch(arm64))
        func sqrt(a: CGFloat) -> CGFloat {
            return CGFloat(sqrtf(Float(a)))
        }
    #endif

    extension CGPoint {
        func length() -> CGFloat {
            return sqrt(x*x + y*y)
        }
        
        func normalized() -> CGPoint {
            return self / length()
        }
    }// END

class GameScene: SKScene, SKPhysicsContactDelegate {

    // 1
    let player = SKSpriteNode(imageNamed: "player")
    
    // En tiedä tuleeko tämä tänne???????
    var monstersDestroyed = 0
    
    override func didMove(to view: SKView) {
        // 2 add scene background
        backgroundColor = SKColor.black
        
        // 3 add player position to the scene
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        // 4 add player to the scene
        addChild(player)
        
        // Nämä piti laittaa pelaajan lisäämisen jälkeen
        physicsWorld.gravity = CGVector.zero
        physicsWorld.contactDelegate = self
        
        run(SKAction.repeatForever(
            SKAction.sequence([
                SKAction.run(addMonster),
                SKAction.wait(forDuration: 1.0)
            ])
        ))
        
        // Lisää taustamusiikin peliin
        let backgroundMusic = SKAudioNode(fileNamed: "background-music-aac.caf")
        backgroundMusic.autoplayLooped = true
        addChild(backgroundMusic)
        
    }
    
    func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return random() * (max-min) + min
    }
    
    func addMonster() {
        
        //Create sprite
        let monster = SKSpriteNode(imageNamed: "monster")
        
        // Nämä piti laittaa monsterin lisäämisen perään
        monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size) // 1
        monster.physicsBody?.isDynamic = true // 2
        monster.physicsBody?.categoryBitMask = PhysicsCategory.Monster // 3
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.Projectile // 4
        monster.physicsBody?.collisionBitMask = PhysicsCategory.None // 5
        
        // Determine where to spawn the monster along the Y axis
        let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
        
        // Position the monster slightly off-screen along the right edge,
        // and along a random position along the Y axis as calculated above
        monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
        
        // add the monster to the scene
        addChild(monster)
        
        // Determine speed of the monster. This is quite ok speed now.
        let actualDuration = random(min: CGFloat(3.0), max: CGFloat(6.0))
        
        // Create the actions
        let actionMove = SKAction.move(to: CGPoint(x: -monster.size.width/2, y: actualY), duration:TimeInterval(actualDuration))
        let actionMoveDone = SKAction.removeFromParent()
        /* monster.run(SKAction.sequence([actionMove, actionMoveDone]))  */
        
        let loseAction = SKAction.run() {
            let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            let gameOverScene = GameOverScene(size: self.size, won: false)
            self.view?.presentScene(gameOverScene, transition: reveal)
        }
        monster.run(SKAction.sequence([actionMove, loseAction, actionMoveDone]))
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        run(SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false))
        
        // 1 - Choose one of the touches to work with
        guard let touch = touches.first else {
            return
        }
        let touchLocation = touch.location(in: self)
        
        // 2 - Set up initial location of projectile
        let projectile = SKSpriteNode(imageNamed: "projectile")
        projectile.position = player.position
        
        //Nämä piti laittaa projectile positionin perään
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.Projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.None
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        // 3 - Determine offset of location to projectile
        let offset = touchLocation - projectile.position
        
        // 4 - Bail out if you are shooting down or backwards
        if (offset.x < 0) { return }
        
        // 5 - OK to add now - you've double checked position
        addChild(projectile)
        
        // 6 - Get the direction of where to shoot
        let direction = offset.normalized()
        
        // 7 - Make it shoot far enough to be guaranteed off screen
        let shootAmount = direction * 1000
        
        // 8 - Add the shoot amount to the current position
        let realDest = shootAmount + projectile.position
        
        // 9 - Create the actions
        let actionMove = SKAction.move(to: realDest, duration: 2.0)
        let actionMoveDone = SKAction.removeFromParent()
        projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
        
    }
    
    func projectileDidCollideWithMonster(projectile: SKSpriteNode, monster: SKSpriteNode) {
        print("Hit")
        projectile.removeFromParent()
        monster.removeFromParent()
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        
        // 1
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // 2
        if ((firstBody.categoryBitMask & PhysicsCategory.Monster != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.Projectile != 0)) {
            if let monster = firstBody.node as? SKSpriteNode, let
                projectile = secondBody.node as? SKSpriteNode {
                projectileDidCollideWithMonster(projectile: projectile, monster: monster)
            }
            
            monstersDestroyed += 1
            // tällä luvulla määritellään, että montako pitää ampua päästäkseen seuraavalle tasolle.
            if (monstersDestroyed > 4) {
                let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
                let gameOverScene = GameOverScene(size: self.size, won: true)
                self.view?.presentScene(gameOverScene, transition: reveal)
            }
            
            
            
            
        }
        
    }
    
}

