import ARKit
import RealityKit
import UIKit

extension ARCoordinator {

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        guard store.state.ar.placement == .placingVolcano else { return }
        guard !isPlacing else { return }

        let location = gesture.location(in: arView)
        var results = arView.raycast(from: location, allowing: .existingPlaneInfinite, alignment: .horizontal)
        if results.isEmpty {
            results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        }
        guard let result = results.first else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        if isTooClose(to: result.worldTransform) {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if let nearestEntity = volcanoEntity ?? beakerEntities[.sideA] ?? beakerEntities[.sideB] {  // added
                playSFX(.wrongPlacement, on: nearestEntity)             // added — best-effort position; refine once you have the actual invalid-tap location as an entity
            }                                                            // added
            return
        }

        isPlacing = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isPlacing = false }
            await placeScene(at: result.worldTransform,
                             planeAnchor: result.anchor as? ARPlaneAnchor,
                             in: arView)
            // One tap — advance through all three placement states at once.
            store.send(.ar(.placementAdvanced)) // .placingVolcano → .placingSideA
            store.send(.ar(.placementAdvanced)) // .placingSideA   → .placingSideB
            store.send(.ar(.placementAdvanced)) // .placingSideB   → .allPlaced

            guard store.state.ar.placement == .allPlaced else { return }
            hidePlaneVisualizations()
            let frozenConfig = ARWorldTrackingConfiguration()
            frozenConfig.planeDetection = []
            arView.session.run(frozenConfig)
            startTiltMonitoring()
            startShakeMonitoring()
            await spawnInteractiveEntities()
            setupExplosionSystem()
            subscribeToProximityUpdates()
        }
    }

    /// Places the volcano and both station entities in one shot under a single anchor.
    /// Anchoring to the detected ARPlaneAnchor keeps the entire layout stable on the
    /// surface as the user walks around — all children move with the plane rather than
    /// drifting independently due to world-tracking jitter.
    private func placeScene(at transform: simd_float4x4,
                            planeAnchor: ARPlaneAnchor?,
                            in arView: ARView) async {
        let pos = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

        switch store.state.ar.placement {
        case .placingVolcano:
            let volEnt = await loadAsset(.snowyVolcano, fallbackColor: .systemGray.withAlphaComponent(0.4), fallbackSize: [0.1, 0.2, 0.1])
            anchor.addChild(volEnt)
            arView.scene.addAnchor(anchor)
            volcanoAnchor = anchor
            volcanoPosition = pos
            volcanoEntity = volEnt
            playSFX(.volcanoPlacement, on: volEnt)                    // added

        case .placingSideA:
            arView.scene.addAnchor(anchor)
            stationAAnchor = anchor
            stationAPosition = pos
            await spawnMixingBeaker(on: anchor, side: .sideA)
            if let beaker = beakerEntities[.sideA] {                  // added
                playSFX(.placeGlass(.sideA), on: beaker)               // added
            }                                                          // added

        case .placingSideB:
            arView.scene.addAnchor(anchor)
            stationBAnchor = anchor
            stationBPosition = pos
            await spawnMixingBeaker(on: anchor, side: .sideB)
            if let beaker = beakerEntities[.sideB] {                  // added
                playSFX(.placeGlass(.sideB), on: beaker)               // added
            }                                                          // added

        case .allPlaced:
            break
        }

        // Project camera X-axis onto the horizontal plane so stations land to
        // the user's physical left and right regardless of world orientation.
        let camCol = arView.cameraTransform.matrix.columns.0
        let horiz = SIMD3<Float>(camCol.x, 0, camCol.z)
        let camRight = simd_length(horiz) > 0.001 ? normalize(horiz) : SIMD3(1, 0, 0)
        // Side A has 7 ingredients + beaker (cluster spans -0.36…+0.48 local X),
        // so it needs a larger offset to keep the beaker clear of the volcano.
        let stationAOffset: Float = 0.90
        let stationBOffset: Float = 0.60

        let volEnt = await loadAsset(.snowyVolcano,
                                     fallbackColor: .systemGray.withAlphaComponent(0.4),
                                     fallbackSize: [0.1, 0.2, 0.1])
        volEnt.position = base
        rootAnchor.addChild(volEnt)
        arView.scene.addAnchor(rootAnchor)
        volcanoAnchor = rootAnchor
        volcanoPosition = pos
        volcanoEntity = volEnt

        // Rotate each station so its local +X aligns with camRight.
        // This ensures ingredient/beaker positions (laid out along local X)
        // always spread in the camera-right direction, regardless of world orientation.
        let stationYaw = atan2(camRight.z, camRight.x)
        let stationRotation = simd_quatf(angle: stationYaw, axis: SIMD3<Float>(0, 1, 0))

        let stationA = Entity()
        stationA.position = base + (-camRight * stationAOffset)
        stationA.orientation = stationRotation
        rootAnchor.addChild(stationA)
        stationAAnchor = stationA

        let stationB = Entity()
        stationB.position = base + (camRight * stationBOffset)
        stationB.orientation = stationRotation
        rootAnchor.addChild(stationB)
        stationBAnchor = stationB

        await spawnMixingBeaker(on: stationA, side: .sideA)
        await spawnMixingBeaker(on: stationB, side: .sideB)
    }

    func isTooClose(to transform: simd_float4x4, minimumM: Float = 0.5) -> Bool {
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
}
