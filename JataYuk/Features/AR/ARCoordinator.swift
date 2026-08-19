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
    let store: Store<RootState, RootAction>

    // Plane visualizations keyed by ARPlaneAnchor identifier
    var planeEntities: [UUID: AnchorEntity] = [:]

    // Placed scene anchors
    var volcanoAnchor: AnchorEntity?
    var stationAAnchor: AnchorEntity?
    var stationBAnchor: AnchorEntity?

    // World positions captured at placement time — used for overlap detection.
    var volcanoPosition: SIMD3<Float>?
    var stationAPosition: SIMD3<Float>?
    var stationBPosition: SIMD3<Float>?

    // Local offsets within each plane anchor — needed when the anchor is at the
    // plane center rather than the tap point (plane-locked placement).
    var stationAEntityOffset: SIMD3<Float>?
    var stationBEntityOffset: SIMD3<Float>?

    // Direct entity references for visual-only updates (avoids anchor.children traversal).
    var volcanoEntity: Entity?
    var beakerEntities: [StationSide: Entity] = [:]
    var isPlacing = false

    let motionClient = MotionClient()
    var cancellables = Set<AnyCancellable>()

    // Camera anchor — entity is reparented here when carried.
    var cameraAnchor: AnchorEntity?
    var carriedEntity: Entity?
    var carriedEntityOriginalParent: Entity?
    var carriedEntityOriginalLocalPos: SIMD3<Float> = .zero

    // Pre-loaded asset templates — cloned at spawn time to avoid per-placement load stalls.
    var assetTemplates: [ShaderDevAsset: Entity] = [:]

    // Placement cursor — a flat disc that tracks the raycast hit point on detected planes
    // so the user sees exactly where the next tap will land.
    var placementCursor: ModelEntity?
    var placementCursorAnchor: AnchorEntity?

    // Explosion ECS/TCA runtime (live after allPlaced, nil otherwise)
    var explosionStore: ExplosionStore?
    var emissionSystem: EmissionSystem?
    var sphSystem: SPHSystem?
    var foamEntity: Entity?
    var lastSeenVolcanoState: VolcanoState = .locked

    // Tracks last reset token and pause state so updateUIView can detect changes.
    var lastSeenResetToken: Int = 0
    var lastSeenIsPaused: Bool = false

    init(store: Store<RootState, RootAction>) {
        self.store = store
    }

    func setupCameraAnchor() {
        guard let arView else { return }
        let cam = AnchorEntity(.camera)
        arView.scene.addAnchor(cam)
        cameraAnchor = cam
        startPlacementCursorUpdates()
    }

    func stopMotionMonitoring() {
        motionClient.stopTiltMonitoring()
        motionClient.stopShakeMonitoring()
        cancellables.removeAll()
    }

    func resetSession() {
        guard let arView else { return }
        tearDownExplosionSystem()
        detachCarriedEntity()
        stopMotionMonitoring()

        // Snapshot anchors first — removing while iterating live collection skips entries.
        let anchorsToRemove = Array(arView.scene.anchors).filter { $0 !== cameraAnchor }
        anchorsToRemove.forEach { arView.scene.removeAnchor($0) }
        volcanoAnchor = nil; stationAAnchor = nil; stationBAnchor = nil
        volcanoPosition = nil; stationAPosition = nil; stationBPosition = nil
        stationAEntityOffset = nil; stationBEntityOffset = nil
        volcanoEntity = nil; beakerEntities.removeAll()
        planeEntities.removeAll()
        assetTemplates.removeAll()
        placementCursor = nil; placementCursorAnchor = nil
        isPlacing = false

        lastSeenResetToken = store.state.ar.sessionResetToken
        lastSeenIsPaused = false       // prevent stale pause state from triggering resumeARSession()
        lastSeenVolcanoState = .locked // prevent stale volcano state from re-triggering explosion

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        startPlacementCursorUpdates()
    }

    // MARK: - Carry System

    func attachEntityToCamera(_ entity: Entity) {
        guard let cameraAnchor else { return }
        carriedEntityOriginalParent = entity.parent
        carriedEntityOriginalLocalPos = entity.position
        entity.setParent(cameraAnchor, preservingWorldTransform: false)
        entity.position = SIMD3(0, -0.05, -0.3)   // 30 cm in front, slightly below camera
        carriedEntity = entity
    }

    func detachCarriedEntity() {
        guard let entity = carriedEntity, let originalParent = carriedEntityOriginalParent else { return }
        entity.setParent(originalParent, preservingWorldTransform: false)
        entity.position = carriedEntityOriginalLocalPos
        carriedEntity = nil
        carriedEntityOriginalParent = nil
    }
}
