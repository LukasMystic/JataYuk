//
//  ARCoordinator+Spawning.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import RealityKit
import UIKit

extension ARCoordinator {

    // Called as soon as the volcano is placed so ingredient models are ready by
    // the time the user finishes placing the two station benches.
    func preloadAssets() {
        Task {
            let allAssets: [ShaderDevAsset] = [
                .snowyVolcano, .beaker, .tray,
                .dishsoap, .foodColoring, .h2o2, .kettle, .spoon
            ]
            for asset in allAssets {
                do {
                    let entity = try await ShaderDevAssets.load(asset)
                    assetTemplates[asset] = entity
                } catch {
                    // Skip silently — cloneOrLoad will fall back to a fresh load at spawn time.
                }
            }
        }
    }

    func spawnInteractiveEntities() async {
        if let anchorA = stationAAnchor {
            let offsetA = stationAEntityOffset ?? .zero
            await spawnIngredients(store.state.experiment.stationA.ingredients, on: anchorA, side: .sideA, offset: offsetA)
            if beakerEntities[.sideA] == nil {
                await spawnMixingBeaker(on: anchorA, side: .sideA, offset: offsetA)
            }
        }
        if let anchorB = stationBAnchor {
            let offsetB = stationBEntityOffset ?? .zero
            await spawnIngredients(store.state.experiment.stationB.ingredients, on: anchorB, side: .sideB, offset: offsetB)
            if beakerEntities[.sideB] == nil {
                await spawnMixingBeaker(on: anchorB, side: .sideB, offset: offsetB)
            }
        }
    }

    func spawnIngredients(_ ingredients: [Ingredient], on anchor: AnchorEntity, side: StationSide, offset: SIMD3<Float> = .zero) async {
        let spacing: Float = 0.18
        let startX = -Float(ingredients.count - 1) * spacing / 2

        for (i, ingredient) in ingredients.enumerated() {
            let entity = await loadIngredientEntity(ingredient.type)
            entity.position = offset + SIMD3(startX + Float(i) * spacing, 0, 0)
            entity.components.set(IngredientComponent(side: side, ingredientIndex: i))
            anchor.addChild(entity)
        }
    }

    func spawnMixingBeaker(on anchor: AnchorEntity, side: StationSide, offset: SIMD3<Float> = .zero) async {
        let entity = await loadAsset(
            .beaker,
            fallbackColor: UIColor.systemGray.withAlphaComponent(0.5),
            fallbackSize: [0.064, 0.07, 0.064]
        )
        entity.position = offset + SIMD3(0, 0, -0.25)
        entity.components.set(MixingBeakerComponent(side: side))
        anchor.addChild(entity)
        beakerEntities[side] = entity
    }

    func loadIngredientEntity(_ type: BeakerType) async -> Entity {
        do {
            return try await cloneOrLoad(ShaderDevAsset.asset(for: type))
        } catch {
            print("[ShaderDev] failed to load ingredient \(type): \(error)")
            return makePlaceholder(
                color: ingredientColor(type),
                size: [0.054, 0.054, 0.054]
            )
        }
    }

    func loadAsset(
        _ asset: ShaderDevAsset,
        fallbackColor: UIColor,
        fallbackSize: SIMD3<Float>
    ) async -> Entity {
        do {
            return try await cloneOrLoad(asset)
        } catch {
            print("[ShaderDev] failed to load \(asset.rawValue): \(error)")
            return makePlaceholder(color: fallbackColor, size: fallbackSize)
        }
    }

    // Returns a clone of the pre-loaded template if available, otherwise loads fresh.
    private func cloneOrLoad(_ asset: ShaderDevAsset) async throws -> Entity {
        if let template = assetTemplates[asset] {
            return template.clone(recursive: true)
        }
        return try await ShaderDevAssets.load(asset)
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
