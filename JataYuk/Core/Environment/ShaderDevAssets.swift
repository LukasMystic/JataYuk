import RealityKit
import ShaderDev
import UIKit

enum ShaderDevAsset: String, Equatable {
    case tray = "USDC/Monolith_TraySetup_V2"
    var maxExtent: Float { 0.20 }
    var fallbackColor: UIColor { UIColor(red: 0.76, green: 0.78, blue: 0.82, alpha: 1) }
}

enum ShaderDevAssets {
    static func load(_ asset: ShaderDevAsset) async throws -> Entity {
        let loaded = try await loadNamed(asset.rawValue)
        return wrap(loaded, maxExtent: asset.maxExtent)
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

    private static func wrap(_ loaded: Entity, maxExtent: Float) -> Entity {
        // Disable env_light before measuring bounds so its spatial extent
        // doesn't corrupt the scale calculation.
        loaded.findEntity(named: "env_light")?.isEnabled = false
        fit(loaded, maxExtent: maxExtent)
        let wrapper = Entity()
        wrapper.addChild(loaded)
        let bounds = loaded.visualBounds(relativeTo: wrapper)
        if bounds.min.y < 0 { loaded.position.y -= bounds.min.y }
        // No generateCollisionShapes — the Monolith has 100+ meshes and
        // generateCollisionShapes(recursive:) exhausts Metal memory on device.
        // All interaction is distance-based, not physics-based.
        return wrapper
    }

    private static func fit(_ entity: Entity, maxExtent: Float) {
        let bounds = entity.visualBounds(relativeTo: nil)
        let size = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        guard size > 0.0001 else { return }
        entity.scale *= maxExtent / size
    }
}
