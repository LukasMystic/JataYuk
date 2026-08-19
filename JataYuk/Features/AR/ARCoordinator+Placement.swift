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
            // Third advance — placeCurrentItem sends two advances inside so this
            // third one takes the state from .placingSideB to .allPlaced in one tap.
            store.send(.ar(.placementAdvanced))

            if store.state.ar.placement == .allPlaced {
                hidePlaneVisualizations()
                startTiltMonitoring()
                startShakeMonitoring()
                await spawnInteractiveEntities()
                setupExplosionSystem()
                subscribeToProximityUpdates()
            }
        }
    }

    func placeCurrentItem(at transform: simd_float4x4, planeAnchor: ARPlaneAnchor?, in arView: ARView) async {
        // The Monolith contains everything — only the first tap matters.
        guard store.state.ar.placement == .placingVolcano else { return }

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

        let setupEnt = await loadAsset(
            .tray,
            fallbackColor: UIColor(white: 0.88, alpha: 1),
            fallbackSize: [0.50, 0.25, 0.50]
        )
        setupEnt.position = entityOffset
        anchor.addChild(setupEnt)
        arView.scene.addAnchor(anchor)
        volcanoAnchor = anchor
        volcanoPosition = pos
        sceneEntity = setupEnt
        volcanoEntity = setupEnt.findEntity(named: "Snow_VolcanoC")
            ?? setupEnt.findEntity(named: "Mesh_0")
            ?? setupEnt

        // Advance twice so handleTap's third advance reaches .allPlaced — one tap places everything.
        store.send(.ar(.placementAdvanced)) // .placingVolcano → .placingSideA
        store.send(.ar(.placementAdvanced)) // .placingSideA  → .placingSideB
    }

    func isTooClose(to transform: simd_float4x4, minimumM: Float = 0.3) -> Bool {
        guard let pos = volcanoPosition else { return false }
        let candidate = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        return simd_distance(candidate, pos) < minimumM
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
