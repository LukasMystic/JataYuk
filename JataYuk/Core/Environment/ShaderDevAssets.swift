//
//  ShaderDevAssets.swift
//  JataYuk
//
//  Loads the active Reality Composer Pro models from the ShaderDev package.
//  Unused_* drafts in the package are intentionally not referenced.
//

import RealityKit
import ShaderDev

enum ShaderDevAsset: String, Equatable {
    case snowyVolcano = "USDC/SnowyVolcano"
    case beaker = "USDC/Beaker_V2"
    case dishsoap = "USDC/Dishsoap_V3"
    case foodColoring = "USDC/FoodColoring_V2"
    case h2o2 = "USDC/H202_V2"
    case kettle = "USDC/Kettle_V2"
    case spoon = "USDC/Spoon_V2"

    var maxExtent: Float {
        switch self {
        case .snowyVolcano: return 0.28
        case .beaker: return 0.14
        case .dishsoap, .h2o2, .foodColoring: return 0.15
        case .kettle: return 0.18
        case .spoon: return 0.12
        }
    }

    static func asset(for type: BeakerType) -> ShaderDevAsset {
        switch type {
        case .h2o2: return .h2o2
        case .soap: return .dishsoap
        case .foodColoring: return .foodColoring
        case .water: return .kettle
        case .yeast: return .spoon
        }
    }
}

enum ShaderDevAssets {
    static func load(_ asset: ShaderDevAsset) async throws -> Entity {
        let loaded = try await loadNamed(asset.rawValue)
        return wrap(loaded, maxExtent: asset.maxExtent)
    }

    static func loadIngredient(_ type: BeakerType) async throws -> Entity {
        try await load(ShaderDevAsset.asset(for: type))
    }

    private static func loadNamed(_ name: String) async throws -> Entity {
        do {
            return try await Entity(named: name, in: shaderDevBundle)
        } catch {
            let shortName = name.split(separator: "/").last.map(String.init) ?? name
            guard shortName != name else { throw error }
            return try await Entity(named: shortName, in: shaderDevBundle)
        }
    }

    // Wrapper keeps authored scale on the child so highlight/gray-out can scale the root.
    private static func wrap(_ loaded: Entity, maxExtent: Float) -> Entity {
        fit(loaded, maxExtent: maxExtent)
        let wrapper = Entity()
        wrapper.addChild(loaded)
        let bounds = loaded.visualBounds(relativeTo: wrapper)
        loaded.position.y -= bounds.min.y
        wrapper.generateCollisionShapes(recursive: true)
        return wrapper
    }

    private static func fit(_ entity: Entity, maxExtent: Float) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let size = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        guard size > 0.0001 else { return }
        entity.scale *= maxExtent / size
    }
}
