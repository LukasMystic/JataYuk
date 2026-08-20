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
                .snowyVolcano, .beaker,
                .dishsoap, .foodColoring, .h2o2, .kettle, .spoon
            ]
            await withTaskGroup(of: (ShaderDevAsset, Entity?).self) { group in
                for asset in allAssets {
                    group.addTask { [weak self] in
                        guard let self else { return (asset, nil) }
                        do {
                            let entity = try await ShaderDevAssets.load(asset)
                            return (asset, entity)
                        } catch {
                            return (asset, nil)
                        }
                    }
                }
                for await (asset, entity) in group {
                    if let entity { assetTemplates[asset] = entity }
                }
            }
        }
    }

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

    func spawnIngredients(_ ingredients: [Ingredient], on anchor: Entity, side: StationSide) async {
        let spacing: Float = 0.12
        let startX = -Float(ingredients.count - 1) * spacing / 2

        // Load all ingredient models in parallel.
        let pairs: [(index: Int, entity: Entity)] = await withTaskGroup(
            of: (Int, Entity).self
        ) { group in
            for (i, ingredient) in ingredients.enumerated() {
                group.addTask { [weak self] in
                    guard let self else { return (i, Entity()) }
                    let entity = await self.loadIngredientEntity(ingredient.type)
                    return (i, entity)
                }
            }
            var results: [(Int, Entity)] = []
            for await pair in group { results.append(pair) }
            return results.map { (index: $0.0, entity: $0.1) }
        }

        var foodColoringCount = 0
        let foodColorTints: [UIColor] = [.systemRed, .systemGreen, .systemBlue]

        for pair in pairs.sorted(by: { $0.index < $1.index }) {
            pair.entity.position = SIMD3(startX + Float(pair.index) * spacing, 0, 0)
            pair.entity.components.set(IngredientComponent(side: side, ingredientIndex: pair.index))
            if ingredients[pair.index].type == .foodColoring {
                let tint = foodColorTints[foodColoringCount % 3]
                let dot = ModelEntity(
                    mesh: .generateSphere(radius: 0.012),
                    materials: [SimpleMaterial(color: tint, isMetallic: false)]
                )
                dot.position = SIMD3(0, -0.02, 0)
                pair.entity.addChild(dot)
                foodColoringCount += 1
            }
            anchor.addChild(pair.entity)
        }
    }

    func spawnMixingBeaker(on anchor: Entity, side: StationSide) async {
        let entity = await loadAsset(
            .beaker,
            fallbackColor: UIColor.systemGray.withAlphaComponent(0.5),
            fallbackSize: [0.064, 0.07, 0.064]
        )
        // Place beaker beside the last ingredient in the row (same Z depth).
        let count = store.state.experiment[side].ingredients.count
        let spacing: Float = 0.12
        let endX = Float(count - 1) * spacing / 2 + spacing
        entity.position = SIMD3(endX, 0, 0)
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
