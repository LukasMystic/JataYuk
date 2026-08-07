//
//  ARDragPreview.swift
//  JataYuk
//
//  Created by Harley Ganisson on 07/08/26.
//

import SwiftUI
import RealityKit
import ARKit

// MARK: - Main Demo View

struct ARDragPreview: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(
            frame: .zero,
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )

        context.coordinator.setupScene(in: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {

        var arView: ARView?

        var draggableObject: ModelEntity?
        var dropZone: ModelEntity?

        var originalTransform: Transform?

        var isDragging = false

        func setupScene(in arView: ARView) {

            self.arView = arView


            let camera = PerspectiveCamera()

            camera.position = [
                0,
                0.8,
                2.5
            ]

            camera.look(
                at: [0, 0, 0],
                from: camera.position,
                relativeTo: nil
            )

            arView.scene.addAnchor(
                AnchorEntity(world: [0, 0, 0])
            )

            let cameraAnchor = AnchorEntity(world: [0, 0, 0])
            cameraAnchor.addChild(camera)

            arView.scene.addAnchor(cameraAnchor)


            // --------------------------------
            // Ground
            // --------------------------------

            let ground = ModelEntity(
                mesh: .generatePlane(
                    width: 2.5,
                    depth: 2.5
                ),
                materials: [
                    SimpleMaterial(
                        color: .lightGray,
                        isMetallic: false
                    )
                ]
            )

            ground.position = [
                0,
                -0.05,
                0
            ]

            let groundAnchor = AnchorEntity(
                world: [0, 0, 0]
            )

            groundAnchor.addChild(ground)

            arView.scene.addAnchor(groundAnchor)


            // --------------------------------
            // Object
            // --------------------------------

            let object = ModelEntity(
                mesh: .generateBox(
                    size: [0.25, 0.25, 0.25]
                ),
                materials: [
                    SimpleMaterial(
                        color: .systemBlue,
                        isMetallic: false
                    )
                ]
            )

            object.name = "HydrogenPeroxide"

            object.position = [
                -0.6,
                0.125,
                0
            ]

            // Required for ARView.entity(at:)
            object.generateCollisionShapes(
                recursive: false
            )

            let objectAnchor = AnchorEntity(
                world: [0, 0, 0]
            )

            objectAnchor.addChild(object)

            arView.scene.addAnchor(objectAnchor)

            draggableObject = object


            // --------------------------------
            // Drop Zone
            // --------------------------------

            let target = ModelEntity(
                mesh: .generateBox(
                    size: [0.45, 0.05, 0.45]
                ),
                materials: [
                    SimpleMaterial(
                        color: .systemGreen,
                        isMetallic: false
                    )
                ]
            )

            target.name = "DropZone"

            target.position = [
                0.5,
                0.025,
                0
            ]

            let targetAnchor = AnchorEntity(
                world: [0, 0, 0]
            )

            targetAnchor.addChild(target)

            arView.scene.addAnchor(targetAnchor)

            dropZone = target


            // --------------------------------
            // Gesture
            // --------------------------------

            let pan = UIPanGestureRecognizer(
                target: self,
                action: #selector(handlePan(_:))
            )

            arView.addGestureRecognizer(pan)
        }


        // MARK: - Pan Gesture

        @objc
        func handlePan(
            _ gesture: UIPanGestureRecognizer
        ) {

            guard let arView = arView,
                  let object = draggableObject
            else {
                return
            }

            let location = gesture.location(
                in: arView
            )

            switch gesture.state {

            case .began:

                beginDrag(
                    object: object,
                    at: location
                )


            case .changed:

                if isDragging {
                    moveObject(
                        object,
                        to: location
                    )
                }


            case .ended,
                 .cancelled:

                if isDragging {
                    finishDrag(
                        object: object
                    )
                }


            default:
                break
            }
        }


        // MARK: - Begin Drag

        func beginDrag(
            object: ModelEntity,
            at location: CGPoint
        ) {

            guard let arView = arView else {
                return
            }

            guard let touchedEntity =
                    arView.entity(at: location)
            else {
                return
            }

            // Make sure we only grab our object
            guard touchedEntity === object else {
                return
            }

            isDragging = true

            // Save original position
            originalTransform = object.transform

            // Make object slightly larger while holding
            object.scale = [
                1.15,
                1.15,
                1.15
            ]
        }


        // MARK: - Move

        func moveObject(
            _ object: ModelEntity,
            to location: CGPoint
        ) {

            guard let arView = arView else {
                return
            }

            // --------------------------------
            // REAL iPAD AR
            // --------------------------------

            let results = arView.raycast(
                from: location,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )

            if let result = results.first {

                let worldTransform =
                    result.worldTransform

                object.position = [
                    worldTransform.columns.3.x,
                    worldTransform.columns.3.y + 0.125,
                    worldTransform.columns.3.z
                ]

                return
            }


            // --------------------------------
            // XCODE PREVIEW
            // --------------------------------

            moveObjectForPreview(
                object,
                screenLocation: location
            )
        }


        // MARK: - Preview Movement

        func moveObjectForPreview(
            _ object: ModelEntity,
            screenLocation: CGPoint
        ) {

            guard let arView = arView else {
                return
            }

            guard let ray = arView.ray(
                through: screenLocation
            ) else {
                return
            }

            // Horizontal plane
            let planeY: Float = 0.125

            let directionY = ray.direction.y

            guard abs(directionY) > 0.001 else {
                return
            }

            let distance =
                (planeY - ray.origin.y)
                / directionY

            guard distance > 0 else {
                return
            }

            let position =
                ray.origin +
                ray.direction * distance

            object.position = [
                position.x,
                planeY,
                position.z
            ]
        }


        // MARK: - Finish Drag

        func finishDrag(
            object: ModelEntity
        ) {

            isDragging = false

            // Restore scale
            object.scale = [
                1,
                1,
                1
            ]

            guard let target = dropZone,
                  let original = originalTransform
            else {
                return
            }

            // --------------------------------
            // Check drop position
            // --------------------------------

            let objectPosition =
                object.position

            let targetPosition =
                target.position

            let distance = simd_distance(
                objectPosition,
                targetPosition
            )

            let correctDistance: Float = 0.30


            if distance < correctDistance {

                // --------------------------------
                // CORRECT
                // --------------------------------

                print("✅ Correct placement!")

                object.position = [
                    targetPosition.x,
                    0.15,
                    targetPosition.z
                ]

            } else {

                // --------------------------------
                // WRONG
                // --------------------------------

                print("❌ Wrong placement — returning")

                object.move(
                    to: original,
                    relativeTo: object.parent,
                    duration: 0.5,
                    timingFunction: .easeOut
                )
            }

            originalTransform = nil
        }
    }
}


// MARK: - Preview

#Preview {
    ARDragPreview()
        .ignoresSafeArea()
}
