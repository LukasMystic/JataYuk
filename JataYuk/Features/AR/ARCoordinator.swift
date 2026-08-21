//
//  ARCoordinator.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation
import AVFoundation
import RealityKit
import ARKit
import UIKit
import Combine

@MainActor
final class ARCoordinator: NSObject {
    weak var arView: ARView?
    let store: Store<RootState, RootAction>

    // Spatial audio (wav/mp3) via RealityKit AudioFileResource
    var preloadedSFX: [SoundEffect: AudioFileResource] = [:]
    // Fallback for .mov video-container files — played via AVPlayer (non-spatial)
    var sfxAVPlayers: [SoundEffect: AVPlayer] = [:]
    // Plane visualizations keyed by ARPlaneAnchor identifier
    var planeEntities: [UUID: AnchorEntity] = [:]

    // Root anchor for the whole scene; station entities are children of this.
    var volcanoAnchor: AnchorEntity?
    var stationAAnchor: Entity?
    var stationBAnchor: Entity?

    // World position of the tapped point — used for overlap detection.
    var volcanoPosition: SIMD3<Float>?

    // Cache of pre-loaded asset templates — cloned on spawn to avoid re-loading.
    var assetTemplates: [ShaderDevAsset: Entity] = [:]

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
    }

    func stopMotionMonitoring() {
        motionClient.stopTiltMonitoring()
        motionClient.stopShakeMonitoring()
        cancellables.removeAll()
    }

    func resetSession() {
        print("[Reset] resetSession called — arView:\(arView != nil)")
        guard let arView else {
            print("[Reset] aborting — arView is nil")
            return
        }
        tearDownExplosionSystem()
        detachCarriedEntity()
        stopMotionMonitoring()

        // Snapshot anchors first — removing while iterating live collection skips entries.
        let anchorsToRemove = Array(arView.scene.anchors).filter { $0 !== cameraAnchor }
        print("[Reset] anchors before removal: \(arView.scene.anchors.count), removing \(anchorsToRemove.count)")
        for a in anchorsToRemove {
            print("[Reset]  → \(type(of: a)) id:\(a.id) name:'\(a.name)'")
        }
        anchorsToRemove.forEach { arView.scene.removeAnchor($0) }
        print("[Reset] anchors after removal: \(arView.scene.anchors.count)")
        volcanoAnchor = nil; stationAAnchor = nil; stationBAnchor = nil
        volcanoPosition = nil
        volcanoEntity = nil; beakerEntities.removeAll(); assetTemplates.removeAll()
        planeEntities.removeAll()
        isPlacing = false

        lastSeenResetToken = store.state.ar.sessionResetToken
        lastSeenIsPaused = false       // prevent stale pause state from triggering resumeARSession()
        lastSeenVolcanoState = .locked // prevent stale volcano state from re-triggering explosion

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
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

    // Reparents the carried entity back while preserving its current world position,
    // then manually interpolates it to its resting spot so the animation is reliable
    // even immediately after a reparent (entity.move() has quirks in that window).
    func placebackEntity() {
        guard let entity = carriedEntity,
              let originalParent = carriedEntityOriginalParent else {
            detachCarriedEntity()
            return
        }
        let targetLocalPos = carriedEntityOriginalLocalPos

        // Reparent preserving world position — entity stays in place visually.
        // entity.position now holds the start in originalParent's local space.
        entity.setParent(originalParent, preservingWorldTransform: true)
        let startLocalPos = entity.position

        carriedEntity = nil
        carriedEntityOriginalParent = nil

        Task { @MainActor in
            let steps = 15
            let stepNs: UInt64 = 26_666_667   // 15 × 26.7 ms ≈ 0.4 s
            for i in 1...steps {
                guard entity.parent === originalParent else { return }
                let t = Float(i) / Float(steps)
                let eased = 1 - pow(1 - t, 3)  // cubic ease-out
                entity.position = startLocalPos + (targetLocalPos - startLocalPos) * eased
                try? await Task.sleep(nanoseconds: stepNs)
            }
            guard entity.parent === originalParent else { return }
            entity.position = targetLocalPos
        }
    }
}
