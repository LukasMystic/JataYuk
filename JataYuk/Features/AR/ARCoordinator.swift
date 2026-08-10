//
//  ARCoordinator.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation
import RealityKit
import ARKit
import UIKit
import Combine

@MainActor
final class ARCoordinator: NSObject {
    weak var arView: ARView?
    private let store: Store<RootState, RootAction>

    // Plane visualizations keyed by ARPlaneAnchor identifier
    private var planeEntities: [UUID: AnchorEntity] = [:]

    // Placed scene anchors
    private var volcanoAnchor: AnchorEntity?
    private var stationAAnchor: AnchorEntity?
    private var stationBAnchor: AnchorEntity?

    private let motionClient = MotionClient()
    private var cancellables = Set<AnyCancellable>()

    init(store: Store<RootState, RootAction>) {
        self.store = store
    }

    func stopMotionMonitoring() {
        motionClient.stopTiltMonitoring()
        motionClient.stopShakeMonitoring()
        cancellables.removeAll()
    }

    // MARK: - Tap to Place

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        guard store.state.ar.placement != .allPlaced else { return }

        let location = gesture.location(in: arView)
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        guard let result = results.first else { return }

        placeCurrentItem(at: result.worldTransform, in: arView)
        store.send(.ar(.placementAdvanced))

        if store.state.ar.placement == .allPlaced {
            hidePlaneVisualizations()
            startTiltMonitoring()
            startShakeMonitoring()
            spawnInteractiveEntities()
            subscribeToProximityUpdates()
        }
    }

    private func placeCurrentItem(at transform: simd_float4x4, in arView: ARView) {
        let anchor = AnchorEntity(world: transform)

        switch store.state.ar.placement {
        case .placingVolcano:
            // Orange tall box — placeholder until real USDZ is ready
            anchor.addChild(makePlaceholder(color: .systemOrange, size: [0.1, 0.2, 0.1]))
            arView.scene.addAnchor(anchor)
            volcanoAnchor = anchor

        case .placingSideA:
            // Blue wide bench — placeholder
            anchor.addChild(makePlaceholder(color: .systemBlue, size: [0.35, 0.04, 0.2]))
            arView.scene.addAnchor(anchor)
            stationAAnchor = anchor

        case .placingSideB:
            // Green wide bench — placeholder
            anchor.addChild(makePlaceholder(color: .systemGreen, size: [0.35, 0.04, 0.2]))
            arView.scene.addAnchor(anchor)
            stationBAnchor = anchor

        case .allPlaced:
            break
        }
    }

    private func makePlaceholder(color: UIColor, size: SIMD3<Float>) -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: 0.005),
            materials: [SimpleMaterial(color: color.withAlphaComponent(0.85), isMetallic: false)]
        )
    }

    // MARK: - Tilt / Pour

    private func startTiltMonitoring() {
        motionClient.startTiltMonitoring { [weak self] in
            guard let self,
                  let (side, index) = activePourTarget() else { return }
            store.send(.ar(.pourIngredient(side, index)))
        }
    }

    // Returns the station side and ingredient index that is currently held by the player.
    private func activePourTarget() -> (StationSide, Int)? {
        for side in [StationSide.sideA, .sideB] {
            let station = store.state.experiment[side]
            for (i, ingredient) in station.ingredients.enumerated() where ingredient.proximityState == .inHand {
                return (side, i)
            }
        }
        return nil
    }

    // MARK: - Shake / Mix

    private func startShakeMonitoring() {
        motionClient.startShakeMonitoring { [weak self] in
            guard let self,
                  let side = activeShakerTarget() else { return }
            store.send(.ar(.shakeMixingBeaker(side)))
        }
    }

    // Returns the side whose mixing beaker is currently held by the player.
    private func activeShakerTarget() -> StationSide? {
        for side in [StationSide.sideA, .sideB] {
            if store.state.experiment[side].mixingBeaker.proximityState == .inHand {
                return side
            }
        }
        return nil
    }

    // MARK: - Entity Spawning

    private func spawnInteractiveEntities() {
        if let anchorA = stationAAnchor {
            spawnIngredients(store.state.experiment.stationA.ingredients, on: anchorA, side: .sideA)
            spawnMixingBeaker(on: anchorA, side: .sideA)
        }
        if let anchorB = stationBAnchor {
            spawnIngredients(store.state.experiment.stationB.ingredients, on: anchorB, side: .sideB)
            spawnMixingBeaker(on: anchorB, side: .sideB)
        }
    }

    private func spawnIngredients(_ ingredients: [Ingredient], on anchor: AnchorEntity, side: StationSide) {
        let spacing: Float = 0.065
        let startX = -Float(ingredients.count - 1) * spacing / 2
        for (i, ingredient) in ingredients.enumerated() {
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 0.027),
                materials: [SimpleMaterial(color: ingredientColor(ingredient.type), isMetallic: false)]
            )
            entity.position = SIMD3(startX + Float(i) * spacing, 0.06, 0)
            entity.components.set(IngredientComponent(side: side, ingredientIndex: i))
            anchor.addChild(entity)
        }
    }

    private func spawnMixingBeaker(on anchor: AnchorEntity, side: StationSide) {
        let entity = ModelEntity(
            mesh: .generateCylinder(height: 0.07, radius: 0.032),
            materials: [SimpleMaterial(color: .white.withAlphaComponent(0.75), isMetallic: false)]
        )
        entity.position = SIMD3(0, 0.07, -0.07)
        entity.components.set(MixingBeakerComponent(side: side))
        anchor.addChild(entity)
    }

    private func ingredientColor(_ type: BeakerType) -> UIColor {
        switch type {
        case .h2o2:         return .systemBlue
        case .soap:         return .systemYellow
        case .foodColoring: return .systemRed
        case .water:        return .systemCyan
        case .yeast:        return .brown
        }
    }

    // MARK: - Proximity Detection

    // Camera must be within these distances (meters) for state transitions.
    private static let inHandDistanceM: Float      = 0.15
    private static let highlightedDistanceM: Float = 0.35

    private func subscribeToProximityUpdates() {
        guard let arView else { return }
        // frameCount lives on the RealityKit update thread — safely captured by the closure.
        var frameCount = 0
        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            frameCount += 1
            guard frameCount % 10 == 0 else { return }  // ~6 Hz, avoids flooding MainActor
            Task { @MainActor [weak self] in self?.updateProximity() }
        }
        .store(in: &cancellables)
    }

    private func updateProximity() {
        guard let arView else { return }
        let cameraPos = arView.cameraTransform.translation

        for anchor in [stationAAnchor, stationBAnchor].compactMap({ $0 }) {
            for child in anchor.children {
                if let comp = child.components[IngredientComponent.self] {
                    updateIngredientProximity(entity: child, comp: comp, cameraPos: cameraPos)
                } else if let comp = child.components[MixingBeakerComponent.self] {
                    updateBeakerProximity(entity: child, comp: comp, cameraPos: cameraPos)
                }
            }
        }
    }

    private func updateIngredientProximity(entity: Entity, comp: IngredientComponent, cameraPos: SIMD3<Float>) {
        let ingredient = store.state.experiment[comp.side].ingredients[comp.ingredientIndex]
        guard ingredient.isInteractive else { return }

        let distance = simd_distance(cameraPos, entity.position(relativeTo: nil))
        let newState = proximityState(for: distance)
        let current = ingredient.proximityState
        guard newState != current else { return }

        switch (current, newState) {
        case (_, .inHand) where !anythingInHand():
            store.send(.ar(.pickupIngredient(comp.side, comp.ingredientIndex)))
        case (.inHand, _):
            store.send(.ar(.releaseIngredient(comp.side, comp.ingredientIndex)))
        default:
            store.send(.ar(.ingredientProximityChanged(comp.side, comp.ingredientIndex, newState)))
        }
    }

    private func updateBeakerProximity(entity: Entity, comp: MixingBeakerComponent, cameraPos: SIMD3<Float>) {
        let distance = simd_distance(cameraPos, entity.position(relativeTo: nil))
        let newState = proximityState(for: distance)
        let current = store.state.experiment[comp.side].mixingBeaker.proximityState
        guard newState != current else { return }

        if newState == .inHand, anythingInHand() { return }
        store.send(.ar(.mixingBeakerProximityChanged(comp.side, newState)))
    }

    private func proximityState(for distance: Float) -> ARProximityState {
        if distance < Self.inHandDistanceM      { return .inHand }
        if distance < Self.highlightedDistanceM { return .highlighted }
        return .far
    }

    // Returns true when any ingredient or beaker is already held, preventing simultaneous holds.
    private func anythingInHand() -> Bool {
        for side in [StationSide.sideA, StationSide.sideB] {
            if store.state.experiment[side].ingredients.contains(where: { $0.proximityState == .inHand }) { return true }
            if store.state.experiment[side].mixingBeaker.proximityState == .inHand { return true }
        }
        return false
    }

    // MARK: - Plane Visualizations

    private func hidePlaneVisualizations() {
        planeEntities.values.forEach { $0.isEnabled = false }
    }
}

// MARK: - ARSessionDelegate

extension ARCoordinator: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return }
        Task { @MainActor [weak self] in self?.addPlanes(planes) }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return }
        Task { @MainActor [weak self] in self?.updatePlanes(planes) }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return }
        Task { @MainActor [weak self] in self?.removePlanes(planes) }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            // TODO: send .ar availability action when error handling is wired
            _ = self
        }
    }

    // MARK: Plane helpers (MainActor)

    private func addPlanes(_ planes: [ARPlaneAnchor]) {
        guard let arView, store.state.ar.placement != .allPlaced else { return }
        for plane in planes {
            let anchor = AnchorEntity(anchor: plane)
            anchor.addChild(makePlaneVisualization(for: plane))
            arView.scene.addAnchor(anchor)
            planeEntities[plane.identifier] = anchor
        }
    }

    private func updatePlanes(_ planes: [ARPlaneAnchor]) {
        for plane in planes {
            guard let anchor = planeEntities[plane.identifier],
                  let entity = anchor.children.first as? ModelEntity else { continue }
            entity.model?.mesh = .generatePlane(
                width: plane.planeExtent.width,
                depth: plane.planeExtent.height
            )
        }
    }

    private func removePlanes(_ planes: [ARPlaneAnchor]) {
        guard let arView else { return }
        for plane in planes {
            if let anchor = planeEntities.removeValue(forKey: plane.identifier) {
                arView.scene.removeAnchor(anchor)
            }
        }
    }

    private func makePlaneVisualization(for plane: ARPlaneAnchor) -> ModelEntity {
        var material = SimpleMaterial()
        material.color = .init(tint: .white.withAlphaComponent(0.25))
        let mesh = MeshResource.generatePlane(
            width: max(plane.planeExtent.width, 0.1),
            depth: max(plane.planeExtent.height, 0.1)
        )
        return ModelEntity(mesh: mesh, materials: [material])
    }
}
