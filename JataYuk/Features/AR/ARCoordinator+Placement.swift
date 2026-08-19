//
//  ARCoordinator+Placement.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import ARKit
import RealityKit
import UIKit

extension ARCoordinator {

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }
        guard store.state.ar.placement != .allPlaced else { return }
        guard !isPlacing else { return }

        let location = gesture.location(in: arView)
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        guard let result = results.first else { return }

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
            await placeCurrentItem(at: result.worldTransform, in: arView)
            store.send(.ar(.placementAdvanced))

            if store.state.ar.placement == .allPlaced {
                hidePlaneVisualizations()
                // Stop plane detection — world tracking continues so placed entities stay put.
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
    }

    func placeCurrentItem(at transform: simd_float4x4, in arView: ARView) async {
        let anchor = AnchorEntity(world: transform)
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
    }

    // Returns true when the candidate position is within 0.5 m of any already-placed item.
    func isTooClose(to transform: simd_float4x4, minimumM: Float = 0.5) -> Bool {
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

    func loadAsset(
        _ asset: ShaderDevAsset,
        fallbackColor: UIColor,
        fallbackSize: SIMD3<Float>
    ) async -> Entity {
        do {
            return try await ShaderDevAssets.load(asset)
        } catch {
            print("[ShaderDev] failed to load \(asset.rawValue): \(error)")
            return makePlaceholder(color: fallbackColor, size: fallbackSize)
        }
    }

    func hidePlaneVisualizations() {
        planeEntities.values.forEach { $0.isEnabled = false }
    }
}
