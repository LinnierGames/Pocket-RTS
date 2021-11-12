//
//  GameScene.swift
//  Pocket RTS Shared
//
//  Created by Erick Sanchez on 11/7/21.
//

import SpriteKit

class GameScene: SKScene {
    class func newGameScene() -> GameScene {
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            print("Failed to load GameScene.sks")
            abort()
        }

        scene.scaleMode = .aspectFill
        
        return scene
    }
    
    private var labelResources: SKLabelNode!
    private var labelStoneWorkers: SKLabelNode!
    private var labelGoldWorkers: SKLabelNode!
    private var labelWoodWorkers: SKLabelNode!
    private var base: SKSpriteNode!
    private var labelOpponentHP: SKLabelNode!
    private var buttonStone: SKButton!
    private var buttonGold: SKButton!
    private var buttonWood: SKButton!
    private var buttonWorker: SKButton!
    private var buttonBarracks: SKButton!
    private var buttonSoldier: SKButton!
    private var buttonDefend: SKButton!
    private var buttonAttack: SKButton!

    private var stoneWorkers = 0
    private var goldWorkers = 0
    private var woodWorkers = 0

    private var stone = 1110
    private var gold = 1110
    private var wood = 1110
    
    private var opponentHP = 200
    
    override func didMove(to view: SKView) {
        labelResources = childNode(withName: "lab_resources")! as! SKLabelNode
        labelStoneWorkers = childNode(withName: "lab_stone")! as! SKLabelNode
        labelGoldWorkers = childNode(withName: "lab_gold")! as! SKLabelNode
        labelWoodWorkers = childNode(withName: "lab_wood")! as! SKLabelNode
        base = childNode(withName: "base")! as! SKSpriteNode
        labelOpponentHP = childNode(withName: "lab_opponent_hp")! as! SKLabelNode
        buttonStone = childNode(withName: "butt_stone")! as! SKButton
        buttonGold = childNode(withName: "butt_gold")! as! SKButton
        buttonWood = childNode(withName: "butt_wood")! as! SKButton
        buttonWorker = childNode(withName: "butt_worker")! as! SKButton
        buttonBarracks = childNode(withName: "butt_barracks")! as! SKButton
        buttonSoldier = childNode(withName: "butt_soldier")! as! SKButton
        buttonDefend = childNode(withName: "butt_defend")! as! SKButton
        buttonAttack = childNode(withName: "butt_attack")! as! SKButton

        buttonWorker.touchUpInside = {
            let worker = Worker(imageNamed: "worker")
            worker.name = "worker"
            worker.position = self.base.position
            worker.position.y += self.base.size.height + .random(in: 0...32)
            let baseWidth = self.base.size.width / 2
            worker.position.x += .random(in: -baseWidth...baseWidth)
            self.addChild(worker)
        }
        
        buttonStone.touchUpInside = {
            self.findAndAssignWorker(to: .mineStone)
        }
        buttonGold.touchUpInside = {
            self.findAndAssignWorker(to: .mineGold)
        }
        buttonWood.touchUpInside = {
            self.findAndAssignWorker(to: .chopWood)
        }
        
        buttonBarracks.touchUpInside = {
            guard self.canAffordBarracks() else { return self.displayMessage("Missing resources!") }

            let nBarracks = self.count(ofNodeNames: "barracks")
            guard nBarracks < 3 else { return self.displayMessage("Can't build more!") }

            let barracks = Barracks(imageNamed: "barracks")
            barracks.name = "barracks"
            barracks.position = CGPoint(x: self.base.position.x - 50, y: self.base.position.y + 200)
            barracks.position.x += CGFloat(nBarracks) * 8
            barracks.position.y -= CGFloat(nBarracks) * 8
            self.addChild(barracks)
            
            self.buyBarracks()
        }
        
        buttonSoldier.touchUpInside = {
            guard self.count(ofNodeNames: "barracks") != 0, self.canAffordSoldier() else {
                self.displayMessage("Missing Resources!")
                return
            }
            
            self.enumerateChildNodes(withName: "barracks") { node, stop in
                guard let barracks = node as? Barracks else { return }
                
                guard self.canAffordSoldier() else {
                    stop.initialize(to: true)
                    return
                }
                
                if barracks.trainSoldier() {
                    self.buySoldier()
                }
            }
        }
        
        buttonDefend.touchUpInside = {
            var nDefendingSoldiers = self.count(ofNodeNames: "soldier") { (soldier: Soldier) in
                soldier.state == .defending
            }
            
            self.enumerateChildNodes(withName: "soldier") { node, _ in
                guard let soldier = node as? Soldier, soldier.state == .idle else { return }

                let destination = self.defendingPosition(index: nDefendingSoldiers)
                soldier.run(.sequence([
                    .move(to: destination, duration: 1),
                    .run { soldier.state = .defending },
                ]))

                nDefendingSoldiers += 1
            }
        }

        buttonAttack.touchUpInside = {
            self.enumerateChildNodes(withName: "soldier") { node, _ in
                guard let soldier = node as? Soldier, soldier.state == .defending else { return }

                let opponent = self.childNode(withName: "opponent")!
                let randomPosition = CGFloat.random(in: 0...opponent.frame.size.width)
                let destination = CGPoint(
                    x: opponent.frame.minX + randomPosition,
                    y: opponent.frame.minY - soldier.size.height / 2
                )

                soldier.state = .marching
                soldier.run(.sequence([
                    .move(to: destination, duration: 1),
                    .run { soldier.state = .attacking },
                    .run { soldier.attack(applyDamange: self.applyDamageToOpponent) },
                ]))
            }
        }
        
        // Game tick
        run(.repeatForever(.sequence([.run(updateGameTick), .wait(forDuration: 5)])), withKey: "game_tick")
    }
    
    private func applyDamageToOpponent(_ damage: Int) {
        opponentHP -= damage
        updateUI()
    }

    private func defendingPosition(index: Int) -> CGPoint {
        let soldier = SKTexture(imageNamed: "soldier")

        let horizontalPadding: CGFloat = 8
        let verticalPadding: CGFloat = 8
        let rowHeight: CGFloat = soldier.size().height + verticalPadding
        let columnWidth: CGFloat = soldier.size().width + horizontalPadding
        let defendingRect = CGRect(x: 32, y: 500, width: size.width - (32 * 2), height: rowHeight * 3)
        let maxSoldierColumnCount = Int((defendingRect.width / columnWidth))
        let row = Int(CGFloat(index) / CGFloat(maxSoldierColumnCount))
        let column = index % maxSoldierColumnCount

        var center = defendingRect
        center.origin.x = size.width / 2 - (CGFloat(maxSoldierColumnCount) * columnWidth) / 2 + horizontalPadding
        let destinationOrigin = center.origin

        return CGPoint(
            x: destinationOrigin.x + CGFloat(column) * columnWidth + soldier.size().width / 2,
            y: destinationOrigin.y + CGFloat(row) * rowHeight + soldier.size().height / 2
        )
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        buttonTap(at: location)
    }
    
    private func buttonTap(at location: CGPoint) {
        let node = atPoint(location)

        if let button = node as? SKButton {
            button.touchUpInside()
        }
    }

    private func displayMessage(_ message: String) {
        let label = SKLabelNode(text: message)
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 50, duration: 2),.fadeOut(withDuration: 2)]),
            .removeFromParent(),
        ]))
    }
    
    private func canAffordBarracks() -> Bool {
        stone >= 10 && wood >= 10 && gold >= 20
    }
    private func buyBarracks() {
        stone -= 10
        wood -= 10
        gold -= 20
        updateUI()
    }
    
    private func canAffordSoldier() -> Bool {
        stone >= 5 && wood >= 5 && gold >= 30
    }
    private func buySoldier() {
        stone -= 5
        wood -= 5
        gold -= 30
        updateUI()
    }
    
    private func updateUI() {
        labelResources.text = "S: \(stone) G: \(gold) W: \(wood)"
        labelOpponentHP.text = String(opponentHP)
    }
    
    private func updateGameTick() {
        stone += stoneWorkers
        gold += goldWorkers
        wood += woodWorkers
        updateUI()
    }
    
    private func findAndAssignWorker(to newJob: Job) {
        var foundWorker: Worker?
        
        enumerateChildNodes(withName: "worker") { workerNode, stop in
            guard let worker = workerNode as? Worker else { return }
            
            if worker.job == .idle {
                foundWorker = worker
                stop.initialize(to: true)
            }
        }
        
        guard let worker = foundWorker else { return }
        worker.job = newJob
        let jobPosition = point(for: newJob)
        
        // Move and assign the worker
        worker.run(
            .sequence([
                .move(to: jobPosition, duration: 2),
                .run { self.incrementJobCount(newJob) },
            ])
        )
    }
    
    private func incrementJobCount(_ job: Job) {
        switch job {
        case .idle:
            break
        case .mineStone:
            stoneWorkers += 1
            labelStoneWorkers.text = String(stoneWorkers)
        case .mineGold:
            goldWorkers += 1
            labelGoldWorkers.text = String(goldWorkers)
        case .chopWood:
            woodWorkers += 1
            labelWoodWorkers.text = String(woodWorkers)
        }
    }
    
    private func point(for job: Job) -> CGPoint {
        switch job {
        case .idle:
            return base.position
        case .mineGold:
            return buttonGold.position
        case .mineStone:
            return buttonStone.position
        case .chopWood:
            return buttonWood.position
        }
    }
}


class SKButton: SKSpriteNode {
    var touchUpInside: () -> Void = {}
}

class SKButtonLabel: SKLabelNode {
    var touchUpInside: () -> Void = {}
}

enum Job {
    case idle
    case mineGold
    case mineStone
    case chopWood
}

class Worker: SKSpriteNode {
    var job = Job.idle
}

class Barracks: SKSpriteNode {
    private static let trainingDuration: TimeInterval = 1
    private var isTraining = false
    
    func trainSoldier() -> Bool {
        guard !isTraining else { return false }
        
        let counter = SKLabelNode(text: String(Int(Self.trainingDuration)))
        counter.position = .zero
        counter.position.y += 8
        addChild(counter)
        
        isTraining = true
        run(
            .sequence([
                .repeat(
                    .sequence([.wait(forDuration: 1), .run { self.progressTraining(counter: counter) }]),
                    count: Int(Self.trainingDuration)
                ),
                .run { counter.removeFromParent(); self.isTraining = false },
            ])
        )
        
        return true
    }
    
    private func progressTraining(counter: SKLabelNode) {
        let remainingTrainingDuration = Int(Float(counter.text!)!) - 1
        
        counter.text = String(remainingTrainingDuration)
        
        if remainingTrainingDuration == 0 {
            let solider = Soldier(imageNamed: "soldier")
            solider.name = "soldier"
            
            solider.position = self.position
            solider.position.y += self.size.height + .random(in: 0...16)
            let barracksWidth = self.size.width / 2
            solider.position.x += .random(in: -barracksWidth...barracksWidth)
            scene!.addChild(solider)
        }
    }
}

class Soldier: SKSpriteNode {
    enum State {
        case idle
        case defending
        case marching
        case attacking
    }
    var state = State.idle
    
    func attack(applyDamange: @escaping (Int) -> Void) {
        guard state == .attacking else { return }
        
        let attackPath = UIBezierPath()
        attackPath.move(to: .zero)
        attackPath.addLine(to: CGPoint(x: 0, y: -5))
        attackPath.addLine(to: CGPoint(x: 0, y: 10))
        attackPath.addLine(to: .zero)

        run(.repeatForever(.sequence([
            .wait(forDuration: 0.5 + .random(in: 0...1)),
            .follow(attackPath.cgPath, asOffset: true, orientToPath: false, duration: 1),
            .run { applyDamange(5) },
        ])), withKey: "attacking")
    }
}

extension SKNode {
    func count(ofNodeNames name: String) -> Int {
        var count = 0
        enumerateChildNodes(withName: name) { node, _ in
            count += 1
        }

        return count
    }

    func count<T>(ofNodeNames name: String, condition: @escaping (T) -> Bool = { _ in true }) -> Int {
        var count = 0
        enumerateChildNodes(withName: name) { node, _ in
            guard let tNode = node as? T, condition(tNode) else { return }
            count += 1
        }
        
        return count
    }
}
