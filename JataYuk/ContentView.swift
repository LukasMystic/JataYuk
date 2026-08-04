//
//  ContentView.swift
//  JataYuk
//

import SwiftUI
import RealityKit
import ARKit
import Combine

// MARK: - Root View

struct ContentView: View {
    @StateObject private var viewModel = ReactionViewModel()
    @State private var isPanelVisible = true

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)

            if !viewModel.isPlaced {
                PlacementHintView()
            }

            // Full-screen pour prompt shown when a source beaker is selected.
            if viewModel.selectedBeaker != nil {
                PourPromptView(viewModel: viewModel, onDismiss: viewModel.deselectBeaker)
                    .transition(.opacity)
            }

            // Status panel shown while no beaker is held (hides during prompt).
            if viewModel.isPlaced && viewModel.selectedBeaker == nil {
                VStack {
                    Spacer()
                    if isPanelVisible {
                        StatusPanelView(viewModel: viewModel, onHide: {
                            withAnimation(.spring(duration: 0.35)) { isPanelVisible = false }
                        })
                        .padding(.horizontal, 24)
                        .padding(.bottom, 44)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.35)) { isPanelVisible = true }
                            } label: {
                                Label("Show Panel", systemImage: "flask.fill")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .foregroundStyle(.primary)
                            }
                            .padding(.trailing, 24)
                        }
                        .padding(.bottom, 44)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .onChange(of: viewModel.isPlaced) { _, placed in
            if placed { viewModel.startMotionDetection() }
        }
        .onDisappear { viewModel.stopMotionDetection() }
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ReactionViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coaching)

        context.coordinator.arView = arView
        context.coordinator.setupSubscriptions()

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(ARViewCoordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> ARViewCoordinator { ARViewCoordinator(viewModel: viewModel) }
}

// MARK: - AR Coordinator

final class ARViewCoordinator: NSObject {

    weak var arView: ARView?
    private let viewModel: ReactionViewModel
    private var cancellables = Set<AnyCancellable>()

    // All entities live under this single anchor.
    private var mainAnchor: AnchorEntity?

    // Per source beaker: root container entity and its liquid fill.
    private var beakerEntities:   [BeakerType: Entity]       = [:]
    private var sourceLiquids:    [BeakerType: ModelEntity]  = [:]

    // Reaction vessel liquid.
    private var reactionLiquidEntity: ModelEntity?

    // Effect containers.
    private var foamContainer:   Entity?
    private var bubbleContainer: Entity?

    // Original anchor-local positions, used for reset and pour animation.
    private var originalPositions: [BeakerType: SIMD3<Float>] = [:]
    private var previousSelected:  BeakerType? = nil

    // Layout (anchor-local, y = 0 is surface level).
    //
    //         [YEAST]
    //  [H₂O₂] [REACTION] [SOAP]
    //
    private let sourcePositions: [BeakerType: SIMD3<Float>] = [
        .h2o2:  [-0.22, 0,  0.10],
        .soap:  [ 0.22, 0,  0.10],
        .yeast: [ 0.00, 0,  0.26],
    ]
    private let reactionPosition: SIMD3<Float> = [0, 0, -0.05]

    init(viewModel: ReactionViewModel) { self.viewModel = viewModel }

    // MARK: - Subscriptions

    func setupSubscriptions() {
        // Float the selected beaker up/down.
        viewModel.$selectedBeaker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                guard let self else { return }
                self.updateSelectionVisual(from: self.previousSelected, to: selected)
                self.previousSelected = selected
            }
            .store(in: &cancellables)

        // Trigger pour animation as soon as isPouring flips true.
        viewModel.$isPouring
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in
                guard let beaker = self?.viewModel.lastPouredBeaker else { return }
                self?.animatePour(for: beaker)
            }
            .store(in: &cancellables)

        // Reaction outcome → explosion or fizzle.
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
            // First tap → place all beakers.
            let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
            guard let hit = results.first else { return }
            placeBeakers(at: hit.worldTransform, in: arView)
            viewModel.isPlaced = true
        } else if !viewModel.isPouring && viewModel.selectedBeaker == nil {
            // Subsequent taps → try to pick up a source beaker.
            if let entity = arView.entity(at: point) {
                handleEntityTap(entity)
            }
        }
    }

    /// Walks up the entity hierarchy to find a container named with a BeakerType raw value.
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

        // Static floor plane — gives physics droplets a surface to bounce on.
        let floor = Entity()
        floor.components.set(CollisionComponent(shapes: [.generateBox(size: [8, 0.01, 8])]))
        floor.components.set(PhysicsBodyComponent(massProperties: .default,
                                                   material: .generate(friction: 0.4, restitution: 0.35),
                                                   mode: .static))
        floor.position = [0, -0.005, 0]
        anchor.addChild(floor)

        arView.scene.addAnchor(anchor)
    }

    /// Builds a small source beaker (body + liquid) and names the root container
    /// with the BeakerType raw value so tap detection can identify it.
    private func makeSourceBeaker(type: BeakerType, at pos: SIMD3<Float>) -> (Entity, ModelEntity) {
        let group = Entity()
        group.name = type.rawValue      // used by handleEntityTap
        group.position = pos

        // Base disc
        let base = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.005, radius: 0.034),
            materials: [SimpleMaterial(color: UIColor(white: 0.25, alpha: 1), roughness: 0.85, isMetallic: false)]
        )
        base.position = [0, 0.0025, 0]

        // Glass body — has a trigger collision so entity(at:) can detect taps.
        let body = ModelEntity(
            mesh: MeshResource.generateCylinder(height: 0.11, radius: 0.030),
            materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.28), roughness: 0.0, isMetallic: false)]
        )
        body.position = [0, 0.060, 0]
        body.components.set(CollisionComponent(
            shapes: [.generateBox(size: [0.07, 0.13, 0.07])],
            mode: .trigger
        ))

        // Liquid fill — colour represents the ingredient.
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

    /// Builds the central reaction vessel — larger than the source beakers.
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

        // Starts nearly empty; fills and changes colour as ingredients are poured.
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

    // MARK: - Selection Visual (float up / down)

    private func updateSelectionVisual(from old: BeakerType?, to new: BeakerType?) {
        // Lower the previously selected beaker.
        if let old, let entity = beakerEntities[old] {
            let basePos = originalPositions[old]!
            var t = Transform()
            t.translation = basePos
            entity.move(to: t, relativeTo: mainAnchor, duration: 0.30, timingFunction: .easeOut)
        }
        // Raise the newly selected beaker by 6 cm.
        if let new, let entity = beakerEntities[new] {
            let basePos = originalPositions[new]!
            var t = Transform()
            t.translation = [basePos.x, basePos.y + 0.06, basePos.z]
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

    /// Tilts the beaker toward the reaction vessel, pours a stream, then returns it upright.
    private func animateTilt(entity: Entity, beaker: BeakerType) {
        let pos = originalPositions[beaker]!
        // Left beaker tilts right; right beaker tilts left (both pour toward centre).
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
            var returnT = Transform()
            returnT.translation = pos
            entity.move(to: returnT, relativeTo: self.mainAnchor, duration: 0.40, timingFunction: .easeOut)
            self.sourceLiquids[beaker]?.isEnabled = false
            self.updateReactionVesselLiquid()
        }
    }

    /// Oscillates the beaker rapidly (shake gesture for Yeast).
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

    /// Animates a short stream of coloured droplets from the source beaker to the
    /// reaction vessel using keyframe animation (no physics needed for the stream).
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

    /// Updates the colour and fill level of the reaction vessel as ingredients are poured.
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

        // Grow the fill height (keep bottom fixed at y≈0.002).
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

    // MARK: - Failed State: Fizzle Bubbles

    private func triggerFizzEffect() {
        guard let anchor = mainAnchor else { return }
        playSound(named: "fizz")
        removeBubbles()

        let container = Entity()
        bubbleContainer = container
        // Attach bubbles at the reaction vessel position.
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

    // MARK: - Success State: Physics Foam Explosion

    /// Three-phase volcanic eruption scaled by the amount sliders:
    ///   Phase 1 (0–0.5 s)  — narrow column of large foam balls shoots straight up
    ///   Phase 2 (0.3–1.8 s) — spreading overflow fans out in all directions
    ///   Phase 3 (0–1.5 s)  — coloured liquid droplets scatter and bounce
    private func triggerFoamExplosion() {
        guard let anchor = mainAnchor else { return }
        playSound(named: "eruption")
        removeBubbles()
        removeFoam()

        let group = Entity()
        group.position = reactionPosition
        foamContainer = group
        anchor.addChild(group)

        let intensity = Float((viewModel.h2o2Amount + viewModel.soapAmount) / 2.0)  // 0–1

        // Phase 1: Tight central column — 8 large balls straight up.
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

        // Phase 2: Overflow — balls fan out in all directions over ~1.5 s.
        let overflowCount = Int(14 + intensity * 18)  // 14–32
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

        // Phase 3: Coloured droplets — high restitution so they bounce visibly off the floor.
        let poured = viewModel.pouredIngredients
        let dropColor = reactionColor(for: poured)
        let dropletCount = Int(30 + intensity * 30)  // 30–60

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

        // Clean up after 10 s — long enough for everything to settle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in self?.removeFoam() }
    }

    /// Derives the dominant liquid colour from the set of poured ingredients.
    private func reactionColor(for poured: Set<BeakerType>) -> UIColor {
        let h = poured.contains(.h2o2), s = poured.contains(.soap)
        switch (h, s) {
        case (true, true):   return UIColor.systemPurple.withAlphaComponent(0.95)
        case (true, false):  return UIColor.systemYellow.withAlphaComponent(0.95)
        case (false, true):  return UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.95)
        default:             return UIColor.systemBlue.withAlphaComponent(0.95)
        }
    }

    private func removeFoam() {
        foamContainer?.removeFromParent()
        foamContainer = nil
    }

    // MARK: - Scene Reset

    private func resetScene() {
        removeBubbles()
        removeFoam()

        // Restore source beakers to original positions, upright, liquid visible.
        for (beaker, entity) in beakerEntities {
            let pos = originalPositions[beaker]!
            var t = Transform()
            t.translation = pos
            entity.move(to: t, relativeTo: mainAnchor, duration: 0.35, timingFunction: .easeOut)
            sourceLiquids[beaker]?.isEnabled = true
        }

        // Clear the reaction vessel liquid.
        reactionLiquidEntity?.model?.materials = [SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.25), roughness: 0.5, isMetallic: false)]
        if var t = reactionLiquidEntity?.transform {
            t.scale = .one
            t.translation.y = 0.022
            reactionLiquidEntity?.transform = t
        }

        previousSelected = nil
    }

    // MARK: - Helpers

    private func liquidColor(for beaker: BeakerType) -> UIColor {
        switch beaker {
        case .h2o2:  return UIColor.systemYellow.withAlphaComponent(0.90)
        case .soap:  return UIColor(red: 0.1, green: 0.85, blue: 0.4, alpha: 0.90)
        case .yeast: return UIColor(red: 0.70, green: 0.50, blue: 0.30, alpha: 0.90)
        }
    }

    private func playSound(named name: String) {
        // Replace with AVAudioPlayer once audio files are in the bundle:
        //   guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        //   let player = try? AVAudioPlayer(contentsOf: url)
        //   player?.play()
        print("[Audio] ▶ \(name)")
    }
}

// MARK: - Pour Prompt Overlay

/// Full-screen overlay shown when the user has picked up a source beaker.
/// Displays an animated instruction for the appropriate gesture plus an
/// amount slider for H₂O₂ and Dish Soap (not Yeast).
struct PourPromptView: View {
    @ObservedObject var viewModel: ReactionViewModel
    let onDismiss: () -> Void

    @State private var arrowPhase = false
    @State private var shakeOffset: CGFloat = 0

    private var beaker: BeakerType { viewModel.selectedBeaker ?? .h2o2 }

    private var amountBinding: Binding<Double> {
        switch beaker {
        case .h2o2:  return $viewModel.h2o2Amount
        case .soap:  return $viewModel.soapAmount
        case .yeast: return .constant(1.0)
        }
    }

    var body: some View {
        ZStack {
            // Dim background — tap anywhere outside the card to put the beaker back.
            Color.black.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                // Ingredient identity
                Image(systemName: beaker.sfSymbol)
                    .font(.system(size: 46))
                    .foregroundStyle(accentColor)

                Text(beaker.displayName)
                    .font(.title.bold())

                Divider().padding(.horizontal)

                // Gesture animation + optional vertical amount slider side-by-side.
                if beaker.useShake {
                    shakeInstruction
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        tiltInstruction
                            .frame(maxWidth: .infinity)
                        verticalAmountSlider
                    }
                }

                Button("Put Back", action: onDismiss)
                    .buttonStyle(.bordered)
                    .tint(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 12)
            .padding(.horizontal, 44)
        }
    }

    // MARK: Vertical Amount Slider

    /// A tall, narrow slider on the right edge of the card — easier to reach
    /// on iPad than a full-width horizontal track.
    private var verticalAmountSlider: some View {
        VStack(spacing: 8) {
            Text("\(Int(amountBinding.wrappedValue * 100))%")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(accentColor)

            // Rotate the slider track -90° so it runs bottom→top.
            // The .frame(width:) before rotation becomes the visual height.
            Slider(value: amountBinding, in: 0.1...1.0)
                .rotationEffect(.degrees(-90))
                .frame(width: 150)
                .frame(width: 44, height: 150)
                .tint(accentColor)

            Text("Amount")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Instruction Views

    private var tiltInstruction: some View {
        VStack(spacing: 14) {
            HStack(spacing: 28) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(accentColor)
                    .opacity(arrowPhase ? 1.0 : 0.20)
                Image(systemName: "ipad.landscape")
                    .font(.system(size: 48))
                Image(systemName: "arrow.right")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(accentColor)
                    .opacity(arrowPhase ? 0.20 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    arrowPhase = true
                }
            }
            Text("Tilt Left or Right")
                .font(.title2.bold())
            Text("to pour \(beaker.displayName) into the beaker")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var shakeInstruction: some View {
        VStack(spacing: 14) {
            Image(systemName: "ipad.landscape")
                .font(.system(size: 58))
                .offset(x: shakeOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
                        shakeOffset = 14
                    }
                }
            Text("Shake your iPad!")
                .font(.title2.bold())
            Text("to pour the Yeast catalyst into the beaker")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var accentColor: Color {
        switch beaker {
        case .h2o2:  return .yellow
        case .soap:  return Color(red: 0.1, green: 0.80, blue: 0.45)
        case .yeast: return .orange
        }
    }
}

// MARK: - Status Panel

struct StatusPanelView: View {
    @ObservedObject var viewModel: ReactionViewModel
    var onHide: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Status line
            HStack(spacing: 8) {
                Image(systemName: statusSymbol)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Ingredient progress chips
            HStack(spacing: 8) {
                ForEach(BeakerType.allCases, id: \.self) { beaker in
                    ingredientChip(beaker)
                }
            }

            Button(action: viewModel.reset) {
                Label("Reset Experiment", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            Button(action: onHide) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }

    private var statusSymbol: String {
        switch viewModel.reactionState {
        case .idle:    return "flask"
        case .mixing:  return "plus.circle"
        case .failed:  return "exclamationmark.bubble"
        case .success: return "party.popper"
        }
    }

    private var statusText: String {
        switch viewModel.reactionState {
        case .idle:
            return "Tap a beaker to pick it up!"
        case .mixing:
            if !viewModel.isYeastLocked {
                return "Now add the Yeast catalyst!"
            }
            let remaining = BeakerType.allCases
                .filter { $0 != .yeast && !viewModel.pouredIngredients.contains($0) }
                .map(\.displayName)
                .joined(separator: " + ")
            return remaining.isEmpty ? "Pick up the Yeast!" : "Still need: \(remaining)"
        case .failed:
            return "Missing Dish Soap! Reset and try again 🫧"
        case .success:
            return "Elephant Toothpaste! 🐘"
        }
    }

    private var statusColor: Color {
        switch viewModel.reactionState {
        case .idle, .mixing: return .primary
        case .failed:        return .orange
        case .success:       return .green
        }
    }

    private func ingredientChip(_ beaker: BeakerType) -> some View {
        let poured = viewModel.pouredIngredients.contains(beaker)
        let locked = beaker == .yeast && viewModel.isYeastLocked

        return HStack(spacing: 4) {
            Image(systemName: poured ? "checkmark.circle.fill" : (locked ? "lock.fill" : "circle"))
                .font(.caption)
            Text(beaker.displayName)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(chipBackground(poured: poured, locked: locked), in: Capsule())
        .foregroundStyle(poured ? Color.green : (locked ? Color.secondary : Color.primary))
    }

    private func chipBackground(poured: Bool, locked: Bool) -> Color {
        if poured  { return Color.green.opacity(0.20) }
        if locked  { return Color.gray.opacity(0.15) }
        return Color.secondary.opacity(0.12)
    }
}

// MARK: - Placement Hint

struct PlacementHintView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.10 : 0.92)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

                Text("Move iPad slowly to detect a flat surface")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Then tap to place the beakers")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 44)

            Spacer().frame(height: 130)
        }
        .onAppear { pulse = true }
    }
}

#Preview {
    ContentView()
}
