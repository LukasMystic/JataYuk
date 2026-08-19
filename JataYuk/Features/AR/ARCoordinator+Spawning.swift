import RealityKit
import UIKit

extension ARCoordinator {

    func spawnInteractiveEntities() async {
        guard let scene = sceneEntity else { return }
        wireMonolithEntities(in: scene)
    }

    // MARK: - Monolith entity wiring

    private func wireMonolithEntities(in scene: Entity) {
        #if DEBUG
        debugPrintEntityHierarchy(scene)
        #endif

        // Station A: H2O2 variants (indices 0–2)
        for (name, idx) in [("SM_Bottle_H2O2_001", 0), ("SM_Bottle_H2O2_002", 1), ("SM_Bottle_H2O2_003", 2)] {
            if let e = scene.findEntity(named: name) { wire(e, side: .sideA, index: idx) }
            else { print("[Monolith] '\(name)' not found") }
        }

        // Station A: Soap (index 3)
        if let soap = scene.findEntity(named: "SM_Bottle_Dishsoap_001") {
            wire(soap, side: .sideA, index: 3)
        } else { print("[Monolith] 'SM_Bottle_Dishsoap_001' not found") }

        // Station A: Food coloring (index 4)
        if let fc = scene.findEntity(named: "SM_Bottle_Food_Coloring_001") {
            wire(fc, side: .sideA, index: 4)
        } else { print("[Monolith] 'SM_Bottle_Food_Coloring_001' not found") }

        // Station B: Kettle/water (index 0)
        if let kettle = scene.findEntity(named: "SM_Kettle_001") {
            wire(kettle, side: .sideB, index: 0)
        } else { print("[Monolith] 'SM_Kettle_001' not found") }

        // Station B: Yeast (index 1) — child of SM_Bowl
        if let yeast = scene.findEntity(named: "SM_Yeast") {
            wire(yeast, side: .sideB, index: 1)
        } else { print("[Monolith] 'SM_Yeast' not found") }

        // Beakers: SM_Glass_Beaker_001 (inside TrayBody) = sideA, _002 (root-level) = sideB
        if let beakerA = scene.findEntity(named: "SM_Glass_Beaker_001") {
            beakerA.components.set(MixingBeakerComponent(side: .sideA))
            beakerEntities[.sideA] = beakerA
        } else { print("[Monolith] 'SM_Glass_Beaker_001' not found") }

        if let beakerB = scene.findEntity(named: "SM_Glass_Beaker_002") {
            beakerB.components.set(MixingBeakerComponent(side: .sideB))
            beakerEntities[.sideB] = beakerB
        } else { print("[Monolith] 'SM_Glass_Beaker_002' not found") }
    }

    private func wire(_ entity: Entity, side: StationSide, index: Int) {
        entity.components.set(IngredientComponent(side: side, ingredientIndex: index))
        trackedIngredients.append((entity: entity, side: side, ingredientIndex: index))
    }

    // MARK: - Asset loading

    func loadAsset(_ asset: ShaderDevAsset, fallbackColor: UIColor, fallbackSize: SIMD3<Float>) async -> Entity {
        do {
            return try await ShaderDevAssets.load(asset)
        } catch {
            print("[ShaderDev] failed to load \(asset.rawValue): \(error)")
            return makePlaceholder(color: fallbackColor, size: fallbackSize)
        }
    }

    // MARK: - Debug

    #if DEBUG
    private func debugPrintEntityHierarchy(_ entity: Entity, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)
        let tag = entity.components[ModelComponent.self] != nil ? " [model]" : ""
        print("\(indent)'\(entity.name)'\(tag)")
        for child in entity.children {
            debugPrintEntityHierarchy(child, depth: depth + 1)
        }
    }
    #endif
}
