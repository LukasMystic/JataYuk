//
//  ARCoordinator+Spawning.swift
//  JataYuk
//

import RealityKit
import UIKit

extension ARCoordinator {

    func spawnInteractiveEntities() {
        if let anchorA = stationAAnchor {
            spawnIngredients(store.state.experiment.stationA.ingredients, on: anchorA, side: .sideA)
            spawnMixingBeaker(on: anchorA, side: .sideA)
        }
        if let anchorB = stationBAnchor {
            spawnIngredients(store.state.experiment.stationB.ingredients, on: anchorB, side: .sideB)
            spawnMixingBeaker(on: anchorB, side: .sideB)
        }
    }

    func spawnIngredients(_ ingredients: [Ingredient], on anchor: AnchorEntity, side: StationSide) {
        let spacing: Float = 0.065
        let startX = -Float(ingredients.count - 1) * spacing / 2
        for (i, ingredient) in ingredients.enumerated() {
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 0.027),
                materials: [SimpleMaterial(color: ingredientColor(ingredient.type), isMetallic: false)]
            )
            entity.position = SIMD3(startX + Float(i) * spacing, 0.06, 0)
            entity.components.set(IngredientComponent(side: side, ingredientIndex: i))
            anchor.addChild(entity)
        }
    }

    func spawnMixingBeaker(on anchor: AnchorEntity, side: StationSide) {
        let entity = ModelEntity(
            mesh: .generateCylinder(height: 0.07, radius: 0.032),
            materials: [SimpleMaterial(color: UIColor.systemGray.withAlphaComponent(0.5), isMetallic: false)]
        )
        entity.position = SIMD3(0, 0.07, -0.15)
        entity.components.set(MixingBeakerComponent(side: side))
        anchor.addChild(entity)
        beakerEntities[side] = entity
    }

    func ingredientColor(_ type: BeakerType) -> UIColor {
        switch type {
        case .h2o2:         return .systemBlue
        case .soap:         return .systemYellow
        case .foodColoring: return .systemRed
        case .water:        return .systemCyan
        case .yeast:        return .brown
        }
    }
}
