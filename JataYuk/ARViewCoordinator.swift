//
//  ARViewCoordinator.swift
//  JataYuk
//
//  Coordinator — owns all RealityKit entities and drives AR animations.
//  Subscribes to ReactionViewModel publishers via Combine and translates
//  state changes into 3D scene updates.
//

import Foundation
import RealityKit
import ARKit
import Combine

final class ARViewCoordinator: NSObject {

    // MARK: - Properties

    weak var arView: ARView?
    private let viewModel: ReactionViewModel
    private var cancellables = Set<AnyCancellable>()

    // Single anchor — all scene content hangs off this.
    private var mainAnchor: AnchorEntity?

    // Per source beaker: root container and its liquid fill entity.
    private var beakerEntities: [BeakerType: Entity]      = [:]
    private var sourceLiquids:  [BeakerType: ModelEntity] = [:]

    // Reaction vessel liquid — resized and recoloured as ingredients are poured.
    private var reactionLiquidEntity: ModelEntity?

    // Effect containers (removed on reset / next reaction).
    private var foamContainer:   Entity?
    private var bubbleContainer: Entity?

    // Anchor-local resting positions — used for reset and float animation.
    private var originalPositions: [BeakerType: SIMD3<Float>] = [:]
    private var previousSelected:  BeakerType? = nil

    // MARK: Layout
    //
    //         [YEAST]
    //  [H₂O₂] [VESSEL] [SOAP]
    //
    private let sourcePositions: [BeakerType: SIMD3<Float>] = [
        .h2o2:  [-0.22, 0,  0.10],
        .soap:  [ 0.22, 0,  0.10],
        .yeast: [ 0.00, 0,  0.26],
    ]
    private let reactionPosition: SIMD3<Float> = [0, 0, -0.05]

    init(viewModel: ReactionViewModel) { self.viewModel = viewModel }

    // MARK: - Combine Subscriptions

    func setupSubscriptions() {
        // Float the selected beaker up; lower the previously selected one.
        viewModel.$selectedBeaker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                guard let self else { return }
                self.updateSelectionVisual(from: self.previousSelected, to: selected)
                self.previousSelected = selected
            }
            .store(in: &cancellables)

        // Trigger the pour animation the moment isPouring flips true.
        viewModel.$isPouring
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in
                guard let beaker = self?.viewModel.lastPouredBeaker else { return }
                self?.animatePour(for: beaker)
            }
            .store(in: &cancellables)

        // Explosion / fizzle on reaction outcome.
        viewModel.$reactionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleReactionState(state) }
            .store(in: &cancellables)

        // Full scene reset.
        viewModel.resetPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.resetScene() }
            .store(in: &cancellables)
    }

    // MARK: - Tap Handler

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = gesture.location(in: arView)

        if !viewModel.isPlaced {
            let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
            guard let hit = results.first else { return }
            placeBeakers(at: hit.worldTransform, in: arView)
            viewModel.isPlaced = true
        } else if !viewModel.isPouring && viewModel.selectedBeaker == nil {
            if let entity = arView.entity(at: point) {
                handleEntityTap(entity)
            }
        }
    }

    /// Walks the entity hierarchy to find a container named with a BeakerType raw value.
    private func handleEntityTap(_ entity: Entity) {
        var current: Entity? = entity
        while let e = current {
            if !e.name.isEmpty, let beaker = BeakerType(rawValue: e.name) {
                viewModel.selectBeaker(beaker)
                return
            }
            current = e.parent
        }
    }

    // MARK: - Scene Construction

    private func placeBeakers(at worldTransform: simd_float4x4, in arView: ARView) {
        let anchor = AnchorEntity(world: worldTransform)
        mainAnchor = anchor

        for beaker in BeakerType.allCases {
            let pos = sourcePositions[beaker]!
            let (group, liquid) = makeSourceBeaker(type: beaker, at: pos)
            beakerEntities[beaker] = group
            sourceLiquids[beaker] = liquid
            originalPositions[beaker] = pos
            anchor.addChild(group)
        }

        let (rvGroup, rvLiquid) = makeReactionVessel(at: reactionPosition)
        reactionLiquidEntity = rvLiquid
        anchor.addChild(rvGroup)

        // Static floor so physics droplets bounce on the AR surface.
        let floor = Entity()
        floor.components.set(CollisionComponent(shapes: [.generateBox(size: [8, 0.01, 8])]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default,
                                                   material: .generate(friction: 0.4, restitution: 0.35),
                                                   mode: .static))
        floor.position = [0, -0.005, 0]
        anchor.addChild(floor)

        arView.scene.addAnchor(anchor)
    }

    /// Source beaker: cylinder + trigger collision (for entity(at:)) + coloured liquid fill.
    private func makeSourceBeaker(type: BeakerType, at pos: SIMD3<Float>) -> (Entity, ModelEntity) {
        let group = Entity()
        group.name = type.rawValue   // read by handleEntityTap
        group.position = pos

        let base = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.005, radius: 0.034),
            materials: [SimpleMaterial(color: UIColor(white: 0.25, alpha: 1), roughness: 0.85, isMetallic: false)]
        )
        base.position = [0, 0.0025, 0]

        let body = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.11, radius: 0.030),
            materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.28), roughness: 0.0, isMetallic: false)]
        )
        body.position = [0, 0.060, 0]
        body.components.set(CollisionComponent(
            shapes: [.generateBox(size: [0.07, 0.13, 0.07])],
            mode: .trigger
        ))

        let liquid = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.06, radius: 0.023),
            materials: [SimpleMaterial(color: liquidColor(for: type), roughness: 0.5, isMetallic: false)]
        )
        liquid.position = [0, 0.033, 0]

        group.addChild(base)
        group.addChild(body)
        group.addChild(liquid)
        return (group, liquid)
    }

    /// Reaction vessel: wider cylinder, starts nearly empty, grows as ingredients arrive.
    private func makeReactionVessel(at pos: SIMD3<Float>) -> (Entity, ModelEntity) {
        let group = Entity()
        group.position = pos

        let base = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.006, radius: 0.045),
            materials: [SimpleMaterial(color: UIColor(white: 0.22, alpha: 1), roughness: 0.85, isMetallic: false)]
        )
        base.position = [0, 0.003, 0]

        let body = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.14, radius: 0.041),
            materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.28), roughness: 0.0, isMetallic: false)]
        )
        body.position = [0, 0.076, 0]

        let liquid = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.04, radius: 0.032),
            materials: [SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.25), roughness: 0.5, isMetallic: false)]
        )
        liquid.position = [0, 0.022, 0]

        group.addChild(base)
        group.addChild(body)
        group.addChild(liquid)
        return (group, liquid)
    }

    // MARK: - Selection Visual

    private func updateSelectionVisual(from old: BeakerType?, to new: BeakerType?) {
        if let old, let entity = beakerEntities[old] {
            var t = Transform(); t.translation = originalPositions[old]!
            entity.move(to: t, relativeTo: mainAnchor, duration: 0.30, timingFunction: .easeOut)
        }
        if let new, let entity = beakerEntities[new] {
            let base = originalPositions[new]!
            var t = Transform(); t.translation = [base.x, base.y + 0.06, base.z]
            entity.move(to: t, relativeTo: mainAnchor, duration: 0.30, timingFunction: .easeOut)
        }
    }

    // MARK: - Pour Animation

    private func animatePour(for beaker: BeakerType) {
        guard let entity = beakerEntities[beaker] else { return }
        playSound(named: beaker.useShake ? "fizz" : "pour")

        if beaker.useShake {
            animateShake(entity: entity, basePos: originalPositions[beaker]!)
        } else {
            animateTilt(entity: entity, beaker: beaker)
        }
    }

    private func animateTilt(entity: Entity, beaker: BeakerType) {
        let pos = originalPositions[beaker]!
        let tiltAngle: Float = pos.x < 0 ? -.pi * 0.45 : .pi * 0.45

        var liftedT = Transform()
        liftedT.translation = [pos.x, pos.y + 0.07, pos.z]
        liftedT.rotation = simd_quatf(angle: tiltAngle, axis: [0, 0, 1])
        entity.move(to: liftedT, relativeTo: mainAnchor, duration: 0.50, timingFunction: .easeInOut)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.spawnPourStream(for: beaker)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self, weak entity] in
            guard let self, let entity else { return }
            var returnT = Transform(); returnT.translation = pos
            entity.move(to: returnT, relativeTo: self.mainAnchor, duration: 0.40, timingFunction: .easeOut)
            self.sourceLiquids[beaker]?.isEnabled = false
            self.updateReactionVesselLiquid()
        }
    }

    private func animateShake(entity: Entity, basePos: SIMD3<Float>) {
        for i in 0..<7 {
            let delay = Double(i) * 0.08
            let xOff: Float = (i == 6) ? 0 : (i % 2 == 0 ? 0.05 : -0.05)
            let yLift: Float = (i == 6) ? 0 : 0.04
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak entity] in
                guard let self, let entity else { return }
                var t = Transform()
                t.translation = [basePos.x + xOff, basePos.y + yLift, basePos.z]
                entity.move(to: t, relativeTo: self.mainAnchor, duration: 0.07, timingFunction: .linear)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
            self?.spawnPourStream(for: .yeast)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.sourceLiquids[.yeast]?.isEnabled = false
            self?.updateReactionVesselLiquid()
        }
    }

    private func spawnPourStream(for beaker: BeakerType) {
        guard let anchor = mainAnchor else { return }
        let srcPos = sourcePositions[beaker]!
        let dstPos = reactionPosition
        let color = liquidColor(for: beaker)

        for i in 0..<7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) { [weak anchor] in
                guard let anchor else { return }
                let drop = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: 0.008),
                    materials: [SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)]
                )
                let jx = Float.random(in: -0.01...0.01)
                let jz = Float.random(in: -0.01...0.01)
                drop.position = [srcPos.x + jx, srcPos.y + 0.12, srcPos.z + jz]
                anchor.addChild(drop)

                var dest = Transform()
                dest.translation = [dstPos.x + jx * 0.5, dstPos.y + 0.09, dstPos.z + jz * 0.5]
                drop.move(to: dest, relativeTo: anchor, duration: 0.35, timingFunction: .easeIn)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak drop] in
                    drop?.removeFromParent()
                }
            }
        }
    }

    // MARK: - Reaction Vessel Liquid

    private func updateReactionVesselLiquid() {
        guard let liquid = reactionLiquidEntity else { return }
        let poured = viewModel.pouredIngredients
        let h = poured.contains(.h2o2), s = poured.contains(.soap)
        let color: UIColor
        switch (h, s) {
        case (true, true):   color = UIColor.systemPurple.withAlphaComponent(0.92)
        case (true, false):  color = UIColor.systemYellow.withAlphaComponent(0.92)
        case (false, true):  color = UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.92)
        default:             color = UIColor.systemBlue.withAlphaComponent(0.40)
        }
        liquid.model?.materials = [SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)]

        let count = Float(poured.filter { $0 != .yeast }.count)
        let yscale: Float = 1.0 + count * 0.55
        let newCenterY = 0.002 + (0.04 * yscale / 2)
        var target = Transform()
        target.scale = [1, yscale, 1]
        target.translation = [0, newCenterY, 0]
        liquid.move(to: target, relativeTo: liquid.parent, duration: 0.40, timingFunction: .easeOut)
    }

    // MARK: - Reaction State

    private func handleReactionState(_ state: ReactionState) {
        switch state {
        case .idle, .mixing: break
        case .failed:  triggerFizzEffect()
        case .success: triggerFoamExplosion()
        }
    }

    // MARK: - Fizzle

    private func triggerFizzEffect() {
        guard let anchor = mainAnchor else { return }
        playSound(named: "fizz")
        removeBubbles()

        let container = Entity()
        bubbleContainer = container
        container.position = reactionPosition
        anchor.addChild(container)

        for i in 0..<12 {
            let radius = Float.random(in: 0.004...0.009)
            let bubble = ModelEntity(
                mesh: MeshResource.generateSphere(radius: radius),
                materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.72), roughness: 0.05, isMetallic: false)]
            )
            let sx = Float.random(in: -0.026...0.026)
            let sz = Float.random(in: -0.026...0.026)
            bubble.position = [sx, 0.04, sz]
            container.addChild(bubble)

            let delay = Double(i) * 0.08
            let endY: Float = 0.13 + Float.random(in: 0...0.025)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak container, weak bubble] in
                guard let bubble, container != nil else { return }
                var dest = Transform()
                dest.scale = SIMD3<Float>(repeating: 0.05)
                dest.translation = [sx, endY, sz]
                bubble.move(to: dest, relativeTo: container, duration: 0.65 + Double(i) * 0.04, timingFunction: .easeIn)
            }
        }
    }

    private func removeBubbles() {
        bubbleContainer?.removeFromParent()
        bubbleContainer = nil
    }

    // MARK: - Volcanic Foam Explosion

    /// Three-phase eruption scaled by the amount sliders:
    ///   Phase 1 (0–0.5 s)   — tight column of large foam balls shoots straight up
    ///   Phase 2 (0.3–1.8 s) — overflow fans out in all directions
    ///   Phase 3 (0–1.5 s)   — coloured liquid droplets scatter and bounce off the floor
    private func triggerFoamExplosion() {
        guard let anchor = mainAnchor else { return }
        playSound(named: "eruption")
        removeBubbles()
        removeFoam()

        let group = Entity()
        group.position = reactionPosition
        foamContainer = group
        anchor.addChild(group)

        let intensity = Float((viewModel.h2o2Amount + viewModel.soapAmount) / 2.0)

        // Phase 1: Central column
        for i in 0..<8 {
            let delay = Double(i) * 0.065
            let radius: Float = 0.055 - Float(i) * 0.004
            let upSpeed: Float = 3.2 + Float(i) * 0.45 + intensity * 1.5 + Float.random(in: 0...0.3)
            let sx: Float = Float.random(in: -0.07...0.07)
            let sz: Float = Float.random(in: -0.07...0.07)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak group] in
                guard let group else { return }
                let ball = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: radius),
                    materials: [SimpleMaterial(color: UIColor(white: 0.98, alpha: 1), roughness: 0.84, isMetallic: false)]
                )
                ball.position = [0, 0.16, 0]
                ball.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
                ball.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: .generate(friction: 0.45, restitution: 0.22),
                                                         mode: .dynamic))
                ball.components.set(PhysicsMotionComponent(linearVelocity: [sx, upSpeed, sz]))
                group.addChild(ball)
            }
        }

        // Phase 2: Overflow
        let overflowCount = Int(14 + intensity * 18)
        for i in 0..<overflowCount {
            let delay = 0.30 + Double(i) * 0.055
            let frac = Float(i) / Float(max(1, overflowCount - 1))
            let radius: Float = Float.random(in: 0.018...0.044) * (1.0 - frac * 0.4)
            let angle = Float.random(in: 0...(2 * .pi))
            let outSpeed: Float = Float.random(in: 0.15...1.3) * (1 + intensity * 0.9)
            let upSpeed: Float  = Float.random(in: 1.4...3.8) * (0.8 + intensity * 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak group] in
                guard let group else { return }
                let ball = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: radius),
                    materials: [SimpleMaterial(
                        color: UIColor(white: Double(Float.random(in: 0.93...1.0)), alpha: 1),
                        roughness: 0.82, isMetallic: false)]
                )
                ball.position = [0, 0.15, 0]
                ball.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
                ball.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: .generate(friction: 0.5, restitution: 0.12),
                                                         mode: .dynamic))
                ball.components.set(PhysicsMotionComponent(
                    linearVelocity: [cos(angle) * outSpeed, upSpeed, sin(angle) * outSpeed]
                ))
                group.addChild(ball)
            }
        }

        // Phase 3: Liquid droplets
        let poured = viewModel.pouredIngredients
        let dropColor = reactionColor(for: poured)
        let dropletCount = Int(30 + intensity * 30)
        for i in 0..<dropletCount {
            let delay = Double(i) * 0.028
            let r: Float = Float.random(in: 0.006...0.013)
            let angle = Float.random(in: 0...(2 * .pi))
            let outSpeed: Float = Float.random(in: 0.4...4.2) * (0.7 + intensity * 0.9)
            let upSpeed: Float  = Float.random(in: 0.6...4.8) * (0.7 + intensity * 0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak group] in
                guard let group else { return }
                let drop = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: r),
                    materials: [SimpleMaterial(color: dropColor, roughness: 0.12, isMetallic: false)]
                )
                drop.position = [0, 0.14, 0]
                drop.components.set(CollisionComponent(shapes: [.generateSphere(radius: r)]))
                drop.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: .generate(friction: 0.08, restitution: 0.62),
                                                         mode: .dynamic))
                drop.components.set(PhysicsMotionComponent(
                    linearVelocity: [cos(angle) * outSpeed, upSpeed, sin(angle) * outSpeed]
                ))
                group.addChild(drop)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in self?.removeFoam() }
    }

    private func removeFoam() {
        foamContainer?.removeFromParent()
        foamContainer = nil
    }

    // MARK: - Scene Reset

    private func resetScene() {
        removeBubbles()
        removeFoam()

        for (beaker, entity) in beakerEntities {
            let pos = originalPositions[beaker]!
            var t = Transform(); t.translation = pos
            entity.move(to: t, relativeTo: mainAnchor, duration: 0.35, timingFunction: .easeOut)
            sourceLiquids[beaker]?.isEnabled = true
        }

        reactionLiquidEntity?.model?.materials = [
            SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.25), roughness: 0.5, isMetallic: false)
        ]
        if var t = reactionLiquidEntity?.transform {
            t.scale = .one
            t.translation.y = 0.022
            reactionLiquidEntity?.transform = t
        }

        previousSelected = nil
    }

    // MARK: - Helpers

    private func reactionColor(for poured: Set<BeakerType>) -> UIColor {
        let h = poured.contains(.h2o2), s = poured.contains(.soap)
        switch (h, s) {
        case (true, true):   return UIColor.systemPurple.withAlphaComponent(0.95)
        case (true, false):  return UIColor.systemYellow.withAlphaComponent(0.95)
        case (false, true):  return UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.95)
        default:             return UIColor.systemBlue.withAlphaComponent(0.95)
        }
    }

    private func liquidColor(for beaker: BeakerType) -> UIColor {
        switch beaker {
        case .h2o2:  return UIColor.systemYellow.withAlphaComponent(0.90)
        case .soap:  return UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.90)
        case .yeast: return UIColor(red: 0.70, green: 0.50, blue: 0.30, alpha: 0.90)
        }
    }

    private func playSound(named name: String) {
        // Replace with AVAudioPlayer once audio files are in the bundle.
        print("[Audio] ▶ \(name)")
    }
}
