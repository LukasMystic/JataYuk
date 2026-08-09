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

    func makeCoordinator() -> ARCoordinator {
        ARCoordinator(store: store)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)

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
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
