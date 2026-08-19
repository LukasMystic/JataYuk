//
//  ARCoordinator+Placement.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import ARKit
import Combine
import RealityKit
import UIKit

extension ARCoordinator {

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        guard store.state.ar.placement != .allPlaced else { return }
        guard !isPlacing else { return }

        let location = gesture.location(in: arView)

        // Require a real ARKit plane hit before allowing placement.
        // The world fallback (0.7 m camera-forward) was silently auto-placing the volcano
        // on accidental taps before any plane was detected, making the state jump unexpectedly.
        var results = arView.raycast(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal)
        if results.isEmpty {
            results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        }
        guard let hitResult = results.first else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        let worldTransform = hitResult.worldTransform
        let planeAnchor = hitResult.anchor as? ARPlaneAnchor

        if isTooClose(to: worldTransform) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        isPlacing = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isPlacing = false }
            await placeCurrentItem(at: worldTransform, planeAnchor: planeAnchor, in: arView)
            store.send(.ar(.placementAdvanced))

            if store.state.ar.placement == .allPlaced {
                hidePlaneVisualizations()
                // Plane events are already ignored for .allPlaced state in the session delegate,
                // so no session re-run is needed — world tracking continues uninterrupted.
                startTiltMonitoring()
                startShakeMonitoring()
                await spawnInteractiveEntities()
                setupExplosionSystem()
                subscribeToProximityUpdates()
            }
        }
    }

    func placeCurrentItem(at transform: simd_float4x4, planeAnchor: ARPlaneAnchor?, in arView: ARView) async {
        // When ARKit detected a real plane, anchor to it so the entity stays
        // pinned to the physical surface even as world tracking refines.
        // The entity is offset from the plane anchor's center to the tap point.
        // Without a plane hit, fall back to a world-space anchor (may drift).
        let anchor: AnchorEntity
        let entityOffset: SIMD3<Float>
        if let planeAnchor {
            anchor = AnchorEntity(anchor: planeAnchor)
            let localTransform = simd_inverse(planeAnchor.transform) * transform
            entityOffset = SIMD3<Float>(localTransform.columns.3.x, 0, localTransform.columns.3.z)
        } else {
            anchor = AnchorEntity(world: transform)
            entityOffset = .zero
        }

        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

        switch store.state.ar.placement {
        case .placingVolcano:
            let volEnt = await loadAsset(.snowyVolcano, fallbackColor: .systemGray.withAlphaComponent(0.4), fallbackSize: [0.1, 0.2, 0.1])
            let trayEnt = await loadAsset(.tray, fallbackColor: UIColor(white: 0.88, alpha: 1), fallbackSize: [0.38, 0.012, 0.28])
            volEnt.position = entityOffset
            trayEnt.position = entityOffset
            anchor.addChild(trayEnt)
            anchor.addChild(volEnt)
            arView.scene.addAnchor(anchor)
            volcanoAnchor = anchor
            volcanoPosition = pos
            volcanoEntity = volEnt
            // Start pre-loading all ingredient/beaker templates in the background while
            // the user places the two station benches — so spawn is near-instant at allPlaced.
            preloadAssets()

        case .placingSideA:
            arView.scene.addAnchor(anchor)
            stationAAnchor = anchor
            stationAPosition = pos
            stationAEntityOffset = entityOffset
            await spawnMixingBeaker(on: anchor, side: .sideA, offset: entityOffset)

        case .placingSideB:
            arView.scene.addAnchor(anchor)
            stationBAnchor = anchor
            stationBPosition = pos
            stationBEntityOffset = entityOffset
            await spawnMixingBeaker(on: anchor, side: .sideB, offset: entityOffset)

        case .allPlaced:
            break
        }
    }

    // Returns true when the candidate position is within 0.3 m of any already-placed item.
    func isTooClose(to transform: simd_float4x4, minimumM: Float = 0.3) -> Bool {
        let candidate = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        return [volcanoPosition, stationAPosition, stationBPosition]
            .compactMap { $0 }
            .contains { simd_distance(candidate, $0) < minimumM }
    }

    func makePlaceholder(color: UIColor, size: SIMD3<Float>) -> ModelEntity {
        ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: 0.005),
            materials: [SimpleMaterial(color: color.withAlphaComponent(0.85), isMetallic: false)]
        )
    }

    func hidePlaneVisualizations() {
        planeEntities.values.forEach { $0.isEnabled = false }
    }

    // MARK: - Placement cursor

    func startPlacementCursorUpdates() {
        guard let arView else { return }

        // Flat circular disc that hovers on detected planes to show where the next tap lands.
        var mat = SimpleMaterial()
        mat.color = .init(tint: UIColor.white.withAlphaComponent(0.65))
        let cursor = ModelEntity(
            mesh: .generatePlane(width: 0.09, depth: 0.09, cornerRadius: 0.045),
            materials: [mat]
        )
        cursor.isEnabled = false

        let cursorAnchor = AnchorEntity(world: .init(1))
        cursorAnchor.addChild(cursor)
        arView.scene.addAnchor(cursorAnchor)
        placementCursor = cursor
        placementCursorAnchor = cursorAnchor

        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePlacementCursor() }
        }
        .store(in: &cancellables)
    }

    private func updatePlacementCursor() {
        guard let arView,
              let cursor = placementCursor,
              let cursorAnchor = placementCursorAnchor else { return }

        guard store.state.ar.placement != .allPlaced else {
            cursor.isEnabled = false
            return
        }

        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        var results = arView.raycast(from: center, allowing: .existingPlaneInfinite, alignment: .horizontal)
        if results.isEmpty {
            results = arView.raycast(from: center, allowing: .estimatedPlane, alignment: .horizontal)
        }

        if let hit = results.first {
            cursor.isEnabled = !isPlacing
            cursorAnchor.transform = Transform(matrix: hit.worldTransform)
        } else {
            cursor.isEnabled = false
        }
    }
}
