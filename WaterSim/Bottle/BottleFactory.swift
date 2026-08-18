//
//  BottleFactory.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import RealityKit
import ShaderDev
import UIKit

enum BottleFactory {
    private static let bottleScale: Float = 0.10

    static func makeScene(motion: MotionSource, settings: SloshSettings, ar: Bool) async throws -> Entity {
        let root = Entity()
        let bottle = try await Entity(named: "USDC/Dishsoap_V2", in: shaderDevBundle)
        bottle.scale = SIMD3(repeating: bottleScale)

        if let pet = await shader("M_PET"),
           let plastic = await shader("M_Tp_Plastic"),
           let cylinder = bottle.findEntity(named: "Cylinder_007"),
           var model = cylinder.components[ModelComponent.self] {
            model.materials = [pet, plastic]
            cylinder.components.set(model)
        }

        let waterMat = await shader("M_Water")
        if let waterMat {
            apply(waterMat, to: "Cylinder_001", on: bottle)
        }

        if let liquid = bottle.findEntity(named: "SM_Liquid_Dishsoap"),
           let body = bottle.findEntity(named: "SM_Bottle_Dishsoap") {
            let ground = try WaterGround.extract(from: liquid)
            let water = try SloshWater(
                ground: liquid,
                innerHeight: ground.columnHeight(body.visualBounds(relativeTo: liquid)),
                settings: settings,
                motion: motion
            )
            if let waterMat, let mesh = water.findEntity(named: "Water") as? ModelEntity {
                mesh.model?.materials = [waterMat]
            }
            liquid.parent?.addChild(water)
        }

        let bounds = bottle.visualBounds(relativeTo: nil)
        bottle.position -= bounds.center
        root.addChild(bottle)

        if ar {
            root.position = [0, -0.08, -0.45]
        } else {
            addLighting(to: root)
            addBackdrop(to: root)
            addCamera(to: root)
        }
        return root
    }

    private static func shader(_ name: String) async -> ShaderGraphMaterial? {
        let paths = ["/BaseMaterials/\(name)", name]
        for scene in ["RCP/BaseMat", "BaseMat"] {
            for path in paths {
                if let material = try? await ShaderGraphMaterial(named: path, from: scene, in: shaderDevBundle) {
                    return material
                }
            }
        }
        return nil
    }

    private static func apply(_ material: ShaderGraphMaterial, to name: String, on root: Entity) {
        guard let entity = root.findEntity(named: name),
              var model = entity.components[ModelComponent.self]
        else { return }
        model.materials = [material]
        entity.components.set(model)
    }

    private static func addLighting(to root: Entity) {
        let key = Entity()
        key.components.set(DirectionalLightComponent(color: .white, intensity: 14000, isRealWorldProxy: false))
        key.look(at: .zero, from: [0.28, 0.5, 0.38], relativeTo: nil)
        root.addChild(key)
    }

    private static func addBackdrop(to root: Entity) {
        let plane = ModelEntity(
            mesh: .generatePlane(width: 1.4, height: 1.8),
            materials: [UnlitMaterial(color: UIColor(red: 0.07, green: 0.11, blue: 0.16, alpha: 1))]
        )
        plane.position = [0, 0.05, -0.22]
        root.addChild(plane)
    }

    private static func addCamera(to root: Entity) {
        let camera = Entity()
        camera.components.set(PerspectiveCameraComponent(fieldOfViewInDegrees: 36))
        camera.look(at: .zero, from: [0, 0.06, 0.45], relativeTo: nil)
        root.addChild(camera)
    }
}
