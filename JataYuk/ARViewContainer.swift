//
//  ARViewContainer.swift
//  JataYuk
//
//  UIViewRepresentable bridge — wraps ARView so it can live inside a SwiftUI ZStack.
//  Scene setup (coaching overlay, gesture recognizer) lives here; all AR entity
//  logic is in ARViewCoordinator.
//

import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ReactionViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
        coaching.activatesAutomatically = true
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coaching)

        context.coordinator.arView = arView
        context.coordinator.setupSubscriptions()

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(ARViewCoordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> ARViewCoordinator { ARViewCoordinator(viewModel: viewModel) }
}
