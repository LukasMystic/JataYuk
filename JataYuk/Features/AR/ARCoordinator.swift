import Foundation
import RealityKit
import ARKit
import UIKit
import Combine

@MainActor
final class ARCoordinator: NSObject {
    weak var arView: ARView?
    let store: Store<RootState, RootAction>

    // Plane visualizations keyed by ARPlaneAnchor identifier.
    var planeEntities: [UUID: AnchorEntity] = [:]

    // Single anchor for the entire Monolith scene; world position for overlap detection.
    var volcanoAnchor: AnchorEntity?
    var volcanoPosition: SIMD3<Float>?

    // Root entity of the loaded Monolith scene (child of volcanoAnchor).
    var sceneEntity: Entity?

    // Tracked interactive entities — wired by name from Monolith prims after placement.
    var trackedIngredients: [(entity: Entity, side: StationSide, ingredientIndex: Int)] = []

    // Direct entity references for visual-only updates.
    var volcanoEntity: Entity?
    var beakerEntities: [StationSide: Entity] = [:]
    var isPlacing = false

    let motionClient = MotionClient()
    var cancellables = Set<AnyCancellable>()

    // Camera anchor — ingredient entity is reparented here when carried.
    var cameraAnchor: AnchorEntity?
    var carriedEntity: Entity?
    var carriedEntityOriginalParent: Entity?
    var carriedEntityOriginalLocalPos: SIMD3<Float> = .zero

    // Placement cursor — flat disc that tracks the raycast hit point on detected planes.
    var placementCursor: ModelEntity?
    var placementCursorAnchor: AnchorEntity?

    // Explosion ECS/TCA runtime (live after allPlaced, nil otherwise).
    var explosionStore: ExplosionStore?
    var emissionSystem: EmissionSystem?
    var sphSystem: SPHSystem?
    var foamEntity: Entity?
    var lastSeenVolcanoState: VolcanoState = .locked

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

        let anchorsToRemove = Array(arView.scene.anchors).filter { $0 !== cameraAnchor }
        anchorsToRemove.forEach { arView.scene.removeAnchor($0) }
        volcanoAnchor = nil
        volcanoPosition = nil
        sceneEntity = nil
        trackedIngredients.removeAll()
        volcanoEntity = nil
        beakerEntities.removeAll()
        planeEntities.removeAll()
        placementCursor = nil
        placementCursorAnchor = nil
        isPlacing = false

        lastSeenResetToken = store.state.ar.sessionResetToken
        lastSeenIsPaused = false
        lastSeenVolcanoState = .locked

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
        entity.position = SIMD3(0, -0.05, -0.3)
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
