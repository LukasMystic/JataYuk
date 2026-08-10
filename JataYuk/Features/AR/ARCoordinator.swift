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

    init(store: Store<RootState, RootAction>) {
        self.store = store
    }

    func stopMotionMonitoring() {
        motionClient.stopTiltMonitoring()
        motionClient.stopShakeMonitoring()
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
