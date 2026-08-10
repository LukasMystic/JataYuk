//
//  ARCoordinator+Session.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import ARKit
import RealityKit

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
        Task { @MainActor [weak self] in _ = self }
    }

    // Resume tracking on return from background without resetting the world map.
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self, let arView else { return }
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = store.state.ar.placement != .allPlaced ? [.horizontal] : []
            arView.session.run(config)
        }
    }

    // MARK: - Plane helpers

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
            entity.model?.mesh = .generatePlane(width: plane.planeExtent.width, depth: plane.planeExtent.height)
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
