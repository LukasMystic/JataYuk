//
//  ShaderDevAssets.swift
//  JataYuk
//
//  Loads the active Reality Composer Pro models from the ShaderDev package.
//  Unused_* drafts in the package are intentionally not referenced.
//

import RealityKit
import ShaderDev
import UIKit

enum ShaderDevAsset: String, Equatable {
    case snowyVolcano = "USDC/SnowyVolcano"
    case beaker = "USDC/Beaker_V2"
    case dishsoap = "USDC/Dishsoap_V3"
    case foodColoring = "USDC/FoodColoring_V2"
    case h2o2 = "USDC/H202_V2"
    case kettle = "USDC/Kettle_V2"
    case spoon = "USDC/Spoon_V2"
    case tray = "USDC/Tray_V2"

    var maxExtent: Float {
        switch self {
        case .snowyVolcano: return 0.28
        case .beaker: return 0.14
        case .dishsoap, .h2o2, .foodColoring: return 0.15
        case .kettle: return 0.18
        case .spoon: return 0.12
        case .tray: return 0.40
        }
    }

    // Used after material stripping (ShaderGraph materials are replaced to suppress geometry
    // modifier crash). Tint matches the original intent of each model so they remain visually
    // distinguishable even without the ShaderGraph surface effects.
    var fallbackColor: UIColor {
        switch self {
        case .snowyVolcano:   return UIColor(white: 0.72, alpha: 1)
        case .beaker:         return UIColor(red: 0.78, green: 0.90, blue: 1.00, alpha: 1)
        case .dishsoap:       return UIColor(red: 1.00, green: 0.85, blue: 0.20, alpha: 1)
        case .foodColoring:   return UIColor(red: 0.90, green: 0.18, blue: 0.18, alpha: 1)
        case .h2o2:           return UIColor(white: 0.95, alpha: 1)
        case .kettle:         return UIColor(red: 0.62, green: 0.62, blue: 0.68, alpha: 1)
        case .spoon:          return UIColor(red: 0.80, green: 0.80, blue: 0.84, alpha: 1)
        case .tray:           return UIColor(red: 0.76, green: 0.78, blue: 0.82, alpha: 1)
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
        // If ShaderGraph models still crash with vsGeometryModifier, call stripMaterials here:
        // stripMaterials(loaded, color: asset.fallbackColor)
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

    // Replaces every material in the hierarchy with a PhysicallyBasedMaterial.
    // ShaderDev USDC materials declare outputs:realitykit:vertex (geometry modifier) without a
    // connected function, which causes vsGeometryModifier + fsSurfaceMeshShadowCasterProgrammableBlending
    // to crash when Metal API Validation is active. Swapping to PBR removes the geometry modifier path
    // entirely. faceCulling = .none ensures both faces render regardless of winding order, preventing
    // the "skeleton" wireframe appearance on models whose normals face inward.
    private static func stripMaterials(_ entity: Entity, color: UIColor) {
        if var model = entity.components[ModelComponent.self] {
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: color)
            mat.roughness = .init(floatLiteral: 0.45)
            mat.metallic = .init(floatLiteral: 0.05)
            mat.faceCulling = .none
            model.materials = Array(repeating: mat, count: max(1, model.materials.count))
            entity.components.set(model)
        }
        for child in entity.children {
            stripMaterials(child, color: color)
        }
    }
}
