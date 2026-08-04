//
//  ARViewCoordinator.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 04/08/26.
//

import Foundation
import RealityKit
import ARKit
import Combine

final class ARViewCoordinator: NSObject {

    weak var arView: ARView?
    private let viewModel: ReactionViewModel
    private var cancellables = Set<AnyCancellable>()

    private var mainAnchor: AnchorEntity?
    private var beakerEntities: [BeakerType: Entity] = [:]
    private var sourceLiquids: [BeakerType: ModelEntity] = [:]
    private var reactionLiquidEntity: ModelEntity?
    private var foamContainer: Entity?
    private var bubbleContainer: Entity?
    private var originalPositions: [BeakerType: SIMD3<Float>] = [:]
    private var previousSelected: BeakerType? = nil

    // Layout: [H2O2] [VESSEL] [SOAP]  /  [YEAST] at back
    private let sourcePositions: [BeakerType: SIMD3<Float>] = [
        .h2o2:  [-0.22, 0, 0.10],
        .soap:  [ 0.22, 0, 0.10],
        .yeast: [ 0.00, 0, 0.26],
    ]
    private let reactionPosition: SIMD3<Float> = [0, 0, -0.05]

    init(viewModel: ReactionViewModel) { self.viewModel = viewModel }

    func setupSubscriptions() {
        viewModel.$selectedBeaker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                guard let self else { return }
                self.updateSelectionVisual(from: self.previousSelected, to: selected)
                self.previousSelected = selected
            }
            .store(in: &cancellables)

        viewModel.$isPouring
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in
                guard let beaker = self?.viewModel.lastPouredBeaker else { return }
                self?.animatePour(for: beaker)
            }
            .store(in: &cancellables)

        viewModel.$reactionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleReactionState(state) }
            .store(in: &cancellables)

        viewModel.resetPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.resetScene() }
            .store(in: &cancellables)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = gesture.location(in: arView)

        if !viewModel.isPlaced {
            let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
            guard let hit = results.first else { return }
            placeBeakers(at: hit.worldTransform, in: arView)
            viewModel.isPlaced = true
        } else if !viewModel.isPouring && viewModel.selectedBeaker == nil {
            if let entity = arView.entity(at: point) { handleEntityTap(entity) }
        }
    }

    private func handleEntityTap(_ entity: Entity) {
        var current: Entity? = entity
        while let e = current {
            if !e.name.isEmpty, let beaker = BeakerType(rawValue: e.name) {
                viewModel.selectBeaker(beaker); return
            }
            current = e.parent
        }
    }

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

        let floor = Entity()
        floor.components.set(CollisionComponent(shapes: [.generateBox(size: [8, 0.01, 8])]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default,
                                                   material: .generate(friction: 0.4, restitution: 0.35),
                                                   mode: .static))
        floor.position = [0, -0.005, 0]
        anchor.addChild(floor)

        arView.scene.addAnchor(anchor)
    }

    private func makeSourceBeaker(type: BeakerType, at pos: SIMD3<Float>) -> (Entity, ModelEntity) {
        let group = Entity()
        group.name = type.rawValue
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
        body.components.set(CollisionComponent(shapes: [.generateBox(size: [0.07, 0.13, 0.07])], mode: .trigger))

        let liquid = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.06, radius: 0.023),
            materials: [SimpleMaterial(color: liquidColor(for: type), roughness: 0.5, isMetallic: false)]
        )
        liquid.position = [0, 0.033, 0]

        group.addChild(base); group.addChild(body); group.addChild(liquid)
        return (group, liquid)
    }

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

        group.addChild(base); group.addChild(body); group.addChild(liquid)
        return (group, liquid)
    }

    private func updateSelectionVisual(from old: BeakerType?, to new: BeakerType?) {
        if let old, let e = beakerEntities[old] {
            var t = Transform(); t.translation = originalPositions[old]!
            e.move(to: t, relativeTo: mainAnchor, duration: 0.30, timingFunction: .easeOut)
        }
        if let new, let e = beakerEntities[new] {
            let base = originalPositions[new]!
            var t = Transform(); t.translation = [base.x, base.y + 0.06, base.z]
            e.move(to: t, relativeTo: mainAnchor, duration: 0.30, timingFunction: .easeOut)
        }
    }

    private func animatePour(for beaker: BeakerType) {
        guard let entity = beakerEntities[beaker] else { return }
        playSound(named: beaker.useShake ? "fizz" : "pour")
        beaker.useShake
            ? animateShake(entity: entity, basePos: originalPositions[beaker]!)
            : animateTilt(entity: entity, beaker: beaker)
    }

    private func animateTilt(entity: Entity, beaker: BeakerType) {
        let pos = originalPositions[beaker]!
        var liftedT = Transform()
        liftedT.translation = [pos.x, pos.y + 0.07, pos.z]
        liftedT.rotation = simd_quatf(angle: pos.x < 0 ? -.pi * 0.45 : .pi * 0.45, axis: [0, 0, 1])
        entity.move(to: liftedT, relativeTo: mainAnchor, duration: 0.50, timingFunction: .easeInOut)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in self?.spawnPourStream(for: beaker) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self, weak entity] in
            guard let self, let entity else { return }
            var t = Transform(); t.translation = pos
            entity.move(to: t, relativeTo: self.mainAnchor, duration: 0.40, timingFunction: .easeOut)
            self.sourceLiquids[beaker]?.isEnabled = false
            self.updateReactionVesselLiquid()
        }
    }

    private func animateShake(entity: Entity, basePos: SIMD3<Float>) {
        for i in 0..<7 {
            let xOff: Float = (i == 6) ? 0 : (i % 2 == 0 ? 0.05 : -0.05)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) { [weak self, weak entity] in
                guard let self, let entity else { return }
                var t = Transform()
                t.translation = [basePos.x + xOff, basePos.y + (i == 6 ? 0 : 0.04), basePos.z]
                entity.move(to: t, relativeTo: self.mainAnchor, duration: 0.07, timingFunction: .linear)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in self?.spawnPourStream(for: .yeast) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.sourceLiquids[.yeast]?.isEnabled = false
            self?.updateReactionVesselLiquid()
        }
    }

    private func spawnPourStream(for beaker: BeakerType) {
        guard let anchor = mainAnchor else { return }
        let srcPos = sourcePositions[beaker]!
        let color = liquidColor(for: beaker)

        for i in 0..<7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) { [weak anchor] in
                guard let anchor else { return }
                let drop = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: 0.008),
                    materials: [SimpleMaterial(color: color, roughness: 0.3, isMetallic: false)]
                )
                let jx = Float.random(in: -0.01...0.01), jz = Float.random(in: -0.01...0.01)
                drop.position = [srcPos.x + jx, srcPos.y + 0.12, srcPos.z + jz]
                anchor.addChild(drop)

                var dest = Transform()
                dest.translation = [self.reactionPosition.x + jx * 0.5, self.reactionPosition.y + 0.09, self.reactionPosition.z + jz * 0.5]
                drop.move(to: dest, relativeTo: anchor, duration: 0.35, timingFunction: .easeIn)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { drop.removeFromParent() }
            }
        }
    }

    private func updateReactionVesselLiquid() {
        guard let liquid = reactionLiquidEntity else { return }
        let poured = viewModel.pouredIngredients
        let h = poured.contains(.h2o2), s = poured.contains(.soap)
        let color: UIColor
        switch (h, s) {
        case (true, true):  color = UIColor.systemPurple.withAlphaComponent(0.92)
        case (true, false): color = UIColor.systemYellow.withAlphaComponent(0.92)
        case (false, true): color = UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.92)
        default:            color = UIColor.systemBlue.withAlphaComponent(0.40)
        }
        liquid.model?.materials = [SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)]

        let yscale: Float = 1.0 + Float(poured.filter { $0 != .yeast }.count) * 0.55
        var target = Transform()
        target.scale = [1, yscale, 1]
        target.translation = [0, 0.002 + (0.04 * yscale / 2), 0]
        liquid.move(to: target, relativeTo: liquid.parent, duration: 0.40, timingFunction: .easeOut)
    }

    private func handleReactionState(_ state: ReactionState) {
        switch state {
        case .idle, .mixing: break
        case .failed:  triggerFizzEffect()
        case .success: triggerFoamExplosion()
        }
    }

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
            let sx = Float.random(in: -0.026...0.026), sz = Float.random(in: -0.026...0.026)
            bubble.position = [sx, 0.04, sz]
            container.addChild(bubble)

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) { [weak container, weak bubble] in
                guard let bubble, container != nil else { return }
                var dest = Transform()
                dest.scale = SIMD3<Float>(repeating: 0.05)
                dest.translation = [sx, 0.13 + Float.random(in: 0...0.025), sz]
                bubble.move(to: dest, relativeTo: container, duration: 0.65 + Double(i) * 0.04, timingFunction: .easeIn)
            }
        }
    }

    private func removeBubbles() { bubbleContainer?.removeFromParent(); bubbleContainer = nil }

    private func triggerFoamExplosion() {
        guard let anchor = mainAnchor else { return }
        playSound(named: "eruption")
        removeBubbles(); removeFoam()

        let group = Entity()
        group.position = reactionPosition
        foamContainer = group
        anchor.addChild(group)

        let intensity = Float((viewModel.h2o2Amount + viewModel.soapAmount) / 2.0)

        // phase 1 — column
        for i in 0..<8 {
            let r: Float = 0.055 - Float(i) * 0.004
            let up: Float = 3.2 + Float(i) * 0.45 + intensity * 1.5 + Float.random(in: 0...0.3)
            let sx: Float = Float.random(in: -0.07...0.07), sz: Float = Float.random(in: -0.07...0.07)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.065) { [weak group] in
                guard let group else { return }
                let ball = ModelEntity(mesh: MeshResource.generateSphere(radius: r),
                                       materials: [SimpleMaterial(color: UIColor(white: 0.98, alpha: 1), roughness: 0.84, isMetallic: false)])
                ball.position = [0, 0.16, 0]
                ball.components.set(CollisionComponent(shapes: [.generateSphere(radius: r)]))
                ball.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.45, restitution: 0.22), mode: .dynamic))
                ball.components.set(PhysicsMotionComponent(linearVelocity: [sx, up, sz]))
                group.addChild(ball)
            }
        }

        // phase 2 — overflow
        let overflowCount = Int(14 + intensity * 18)
        for i in 0..<overflowCount {
            let frac = Float(i) / Float(max(1, overflowCount - 1))
            let r: Float = Float.random(in: 0.018...0.044) * (1.0 - frac * 0.4)
            let angle = Float.random(in: 0...(2 * .pi))
            let out: Float = Float.random(in: 0.15...1.3) * (1 + intensity * 0.9)
            let up: Float  = Float.random(in: 1.4...3.8) * (0.8 + intensity * 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30 + Double(i) * 0.055) { [weak group] in
                guard let group else { return }
                let ball = ModelEntity(
                    mesh: MeshResource.generateSphere(radius: r),
                    materials: [SimpleMaterial(color: UIColor(white: Double(Float.random(in: 0.93...1.0)), alpha: 1), roughness: 0.82, isMetallic: false)]
                )
                ball.position = [0, 0.15, 0]
                ball.components.set(CollisionComponent(shapes: [.generateSphere(radius: r)]))
                ball.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.5, restitution: 0.12), mode: .dynamic))
                ball.components.set(PhysicsMotionComponent(linearVelocity: [cos(angle) * out, up, sin(angle) * out]))
                group.addChild(ball)
            }
        }

        // phase 3 — droplets
        let dropColor = reactionColor(for: viewModel.pouredIngredients)
        let dropCount = Int(30 + intensity * 30)
        for i in 0..<dropCount {
            let r: Float = Float.random(in: 0.006...0.013)
            let angle = Float.random(in: 0...(2 * .pi))
            let out: Float = Float.random(in: 0.4...4.2) * (0.7 + intensity * 0.9)
            let up: Float  = Float.random(in: 0.6...4.8) * (0.7 + intensity * 0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.028) { [weak group] in
                guard let group else { return }
                let drop = ModelEntity(mesh: MeshResource.generateSphere(radius: r),
                                       materials: [SimpleMaterial(color: dropColor, roughness: 0.12, isMetallic: false)])
                drop.position = [0, 0.14, 0]
                drop.components.set(CollisionComponent(shapes: [.generateSphere(radius: r)]))
                drop.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.08, restitution: 0.62), mode: .dynamic))
                drop.components.set(PhysicsMotionComponent(linearVelocity: [cos(angle) * out, up, sin(angle) * out]))
                group.addChild(drop)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in self?.removeFoam() }
    }

    private func removeFoam() { foamContainer?.removeFromParent(); foamContainer = nil }

    private func resetScene() {
        removeBubbles(); removeFoam()
        for (beaker, entity) in beakerEntities {
            var t = Transform(); t.translation = originalPositions[beaker]!
            entity.move(to: t, relativeTo: mainAnchor, duration: 0.35, timingFunction: .easeOut)
            sourceLiquids[beaker]?.isEnabled = true
        }
        reactionLiquidEntity?.model?.materials = [SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.25), roughness: 0.5, isMetallic: false)]
        if var t = reactionLiquidEntity?.transform {
            t.scale = .one; t.translation.y = 0.022
            reactionLiquidEntity?.transform = t
        }
        previousSelected = nil
    }

    private func reactionColor(for poured: Set<BeakerType>) -> UIColor {
        switch (poured.contains(.h2o2), poured.contains(.soap)) {
        case (true, true):  return UIColor.systemPurple.withAlphaComponent(0.95)
        case (true, false): return UIColor.systemYellow.withAlphaComponent(0.95)
        case (false, true): return UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.95)
        default:            return UIColor.systemBlue.withAlphaComponent(0.95)
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
        print("[Audio] ▶ \(name)")
    }
}
