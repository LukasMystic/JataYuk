//
//  ARInteractionManager.swift
//  JataYuk
//
//  Created by Harley Ganisson on 07/08/26.
//

import UIKit
import RealityKit
import ARKit

final class ARObjectDragController: NSObject {

    private weak var arView: ARView?

    private var selectedEntity: Entity?
    private var originalTransform: Transform?

    private var panGesture: UIPanGestureRecognizer!

    init(arView: ARView) {
        self.arView = arView
        super.init()

        panGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )

        arView.addGestureRecognizer(panGesture)
    }

    @objc
    private func handlePan(_ gesture: UIPanGestureRecognizer) {

        guard let arView = arView else {
            return
        }

        let location = gesture.location(in: arView)

        switch gesture.state {

        case .began:
            beginDragging(at: location)

        case .changed:
            dragEntity(to: location)

        case .ended,
             .cancelled,
             .failed:

            finishDragging()

        default:
            break
        }
    }

    private func beginDragging(at location: CGPoint) {

        guard let arView = arView else {
            return
        }

        guard let entity = arView.entity(at: location) else {
            return
        }

        selectedEntity = entity
        originalTransform = entity.transform
    }

    private func dragEntity(to screenPosition: CGPoint) {

        guard let arView = arView,
              let entity = selectedEntity else {
            return
        }

        let results = arView.raycast(
            from: screenPosition,
            allowing: .estimatedPlane,
            alignment: .horizontal
        )

        guard let result = results.first else {
            return
        }

        let worldTransform = result.worldTransform

        let newPosition = SIMD3<Float>(
            worldTransform.columns.3.x,
            worldTransform.columns.3.y,
            worldTransform.columns.3.z
        )

        entity.setPosition(
            newPosition,
            relativeTo: nil
        )
    }

    private func finishDragging() {

        guard let entity = selectedEntity,
              let original = originalTransform else {
            return
        }

        entity.move(
            to: original,
            relativeTo: entity.parent,
            duration: 0.5,
            timingFunction: .easeOut
        )

        selectedEntity = nil
        originalTransform = nil
    }
}
