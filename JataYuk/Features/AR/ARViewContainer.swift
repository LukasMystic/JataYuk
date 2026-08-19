//
//  ARViewContainer.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    let store: Store<RootState, RootAction>
    // Value-type sentinels — SwiftUI diffs these to know when to call updateUIView.
    let sessionResetToken: Int
    let isPaused: Bool

    func makeCoordinator() -> ARCoordinator {
        ARCoordinator(store: store)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        // Grounding shadow rendering uses vsGeometryModifier + fsSurfaceMeshShadowCasterProgrammableBlending.
        // Those shaders require paramDrawIndices buffer at index 28 which RealityKit fails to bind
        // when materials declare outputs:realitykit:vertex without a fallback function constant.
        // Disabling grounding shadows keeps the crash out of the render path entirely.
        arView.renderOptions.insert(.disableGroundingShadows)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        arView.session.delegate = context.coordinator

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(ARCoordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        context.coordinator.arView = arView
        context.coordinator.setupCameraAnchor()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        let token = store.state.ar.sessionResetToken
        let isPaused = store.state.ar.isPaused
        print("[ARContainer] updateUIView — token:\(token) lastToken:\(context.coordinator.lastSeenResetToken) isPaused:\(isPaused) lastPaused:\(context.coordinator.lastSeenIsPaused)")

        if token != context.coordinator.lastSeenResetToken {
            print("[ARContainer] → dispatching resetSession()")
            context.coordinator.resetSession()
            return
        }

        if isPaused != context.coordinator.lastSeenIsPaused {
            context.coordinator.lastSeenIsPaused = isPaused
            if isPaused {
                print("[ARContainer] → dispatching pauseARSession()")
                context.coordinator.pauseARSession()
            } else {
                print("[ARContainer] → dispatching resumeARSession()")
                context.coordinator.resumeARSession()
            }
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ARCoordinator) {
        Task { @MainActor in coordinator.stopMotionMonitoring() }
    }
}
