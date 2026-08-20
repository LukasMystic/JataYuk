//
//  ARCoordinator+Spawning.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import RealityKit
import UIKit

extension ARCoordinator {

    func spawnInteractiveEntities() async {
        if let anchorA = stationAAnchor {
            await spawnIngredients(store.state.experiment.stationA.ingredients, on: anchorA, side: .sideA)
            if beakerEntities[.sideA] == nil {
                await spawnMixingBeaker(on: anchorA, side: .sideA)
            }
        }
        if let anchorB = stationBAnchor {
            await spawnIngredients(store.state.experiment.stationB.ingredients, on: anchorB, side: .sideB)
            if beakerEntities[.sideB] == nil {
                await spawnMixingBeaker(on: anchorB, side: .sideB)
            }
        }
    }

    func spawnIngredients(_ ingredients: [Ingredient], on anchor: AnchorEntity, side: StationSide) async {
        let spacing: Float = 0.18
        let startX = -Float(ingredients.count - 1) * spacing / 2
        for (i, ingredient) in ingredients.enumerated() {
            let entity = await loadIngredientEntity(ingredient.type)
            entity.position = SIMD3(startX + Float(i) * spacing, 0, 0)
            entity.components.set(IngredientComponent(side: side, ingredientIndex: i))
            anchor.addChild(entity)
        }
    }

    func spawnMixingBeaker(on anchor: AnchorEntity, side: StationSide) async {
        let entity = await loadAsset(
            .beaker,
            fallbackColor: UIColor.systemGray.withAlphaComponent(0.5),
            fallbackSize: [0.064, 0.07, 0.064]
        )
        entity.position = SIMD3(0, 0, -0.25)
        entity.components.set(MixingBeakerComponent(side: side))
        anchor.addChild(entity)
        beakerEntities[side] = entity
    }

    func loadIngredientEntity(_ type: BeakerType) async -> Entity {
        do {
            return try await ShaderDevAssets.loadIngredient(type)
        } catch {
            print("[ShaderDev] failed to load ingredient \(type): \(error)")
            return makePlaceholder(
                color: ingredientColor(type),
                size: [0.054, 0.054, 0.054]
            )
        }
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
