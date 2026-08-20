import RealityKit
import ShaderDev
import UIKit

/// Monolith prims, one per preview page. ShaderGraph is stripped on the
/// cached scene before any clone is shown.
@MainActor
enum ShaderPreviewObject: String, CaseIterable, Identifiable {
    case foodColoringRed
    case foodColoringGreen
    case foodColoringBlue
    case dishsoap
    case bowl
    case beakerA
    case beakerB
    case h2o2Seven
    case h2o2Five
    case h2o2Three
    case kettle
    case volcano
    case trayB

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foodColoringRed: return "Food coloring · Red"
        case .foodColoringGreen: return "Food coloring · Green"
        case .foodColoringBlue: return "Food coloring · Blue"
        case .dishsoap: return "Dish soap"
        case .bowl: return "Bowl + yeast + spoon"
        case .beakerA: return "Beaker 001"
        case .beakerB: return "Beaker 002"
        case .h2o2Seven: return "H2O2 · 7%"
        case .h2o2Five: return "H2O2 · 5%"
        case .h2o2Three: return "H2O2 · 3%"
        case .kettle: return "Kettle"
        case .volcano: return "Snowy volcano"
        case .trayB: return "Tray 001"
        }
    }

    var entityName: String {
        switch self {
        case .foodColoringRed: return "SM_Bottle_Food_Coloring_001"
        case .foodColoringGreen: return "SM_Bottle_Food_Coloring_002"
        case .foodColoringBlue: return "SM_Bottle_Food_Coloring_003"
        case .dishsoap: return "SM_Bottle_Dishsoap_001"
        case .bowl: return "SM_Bowl"
        case .beakerA: return "SM_Glass_Beaker_001"
        case .beakerB: return "SM_Glass_Beaker_002"
        case .h2o2Seven: return "SM_Bottle_H2O2_001"
        case .h2o2Five: return "SM_Bottle_H2O2_002"
        case .h2o2Three: return "SM_Bottle_H2O2_003"
        case .kettle: return "SM_Kettle_001"
        case .volcano: return "Mesh_0"
        case .trayB: return "TrayBody_001"
        }
    }

    var note: String {
        switch self {
        case .foodColoringRed: return "Label → FoodColoring_Label_Red"
        case .foodColoringGreen: return "Label → FoodColoring_Label_Green"
        case .foodColoringBlue: return "Label → FoodColoring_Label_Blue"
        case .dishsoap: return "Liquid → M_Water + PET green"
        case .bowl: return "Bowl → porcelain · yeast #E2C290 grain"
        default: return "Monolith · safe PBR"
        }
    }

    static func load(_ object: ShaderPreviewObject, into arView: ARView) async throws -> Entity {
        let scene = try await loadedMonolith(into: arView)
        guard let source = scene.findEntity(named: object.entityName) else {
            throw ShaderPreviewLoadError.missingEntity(object.entityName)
        }
        let clone = source.clone(recursive: true)
        clone.isEnabled = true
        enableTree(clone)
        clone.transform = Transform()
        clone.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        return clone
    }

    static func placeholder() -> Entity {
        var material = UnlitMaterial()
        material.color = .init(tint: .magenta)
        return ModelEntity(
            mesh: .generateBox(size: 0.08),
            materials: [material]
        )
    }

    @discardableResult
    static func fitInParent(_ entity: Entity, parent: Entity, maxExtent: Float) -> String {
        let bounds = entity.visualBounds(relativeTo: parent)
        let size = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        guard size > 0.0001 else { return "empty bounds" }
        entity.scale *= maxExtent / size
        let fitted = entity.visualBounds(relativeTo: parent)
        entity.position -= fitted.center
        return String(format: "size %.3f", maxExtent)
    }

    // MARK: - Monolith cache

    private static var monolith: Entity?
    private static var hiddenAnchor: AnchorEntity?

    private static func loadedMonolith(into arView: ARView) async throws -> Entity {
        if let monolith { return monolith }
        let loaded = try await loadNamed("USDC/Monolith_TraySetup_V2")
        loaded.findEntity(named: "env_light")?.isEnabled = false
        applySafeMaterials(to: loaded)

        let hidden = AnchorEntity(world: SIMD3(0, -80, -80))
        hidden.addChild(loaded)
        arView.scene.addAnchor(hidden)
        hiddenAnchor = hidden
        monolith = loaded
        return loaded
    }

    private static func enableTree(_ entity: Entity) {
        entity.isEnabled = true
        for child in entity.children {
            enableTree(child)
        }
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

    private static func applySafeMaterials(to entity: Entity, path: String = "") {
        let path = path.isEmpty ? entity.name : "\(path)/\(entity.name)"
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.enumerated().map { slot, material in
                resolve(material, path: path, slot: slot)
            }
            entity.components.set(model)
        }
        for child in entity.children {
            applySafeMaterials(to: child, path: path)
        }
    }

    private static func resolve(_ material: RealityKit.Material, path: String, slot: Int) -> RealityKit.Material {
        let token = materialToken(material)
        let pathLower = path.lowercased()
        let hay = "\(pathLower) \(token.lowercased())"
        let isGraph = material is ShaderGraphMaterial
            || token.localizedCaseInsensitiveContains("ShaderGraph")

        if pathLower.contains("liquid_dishsoap") {
            return ShaderPreviewMaterialID.mWaterDishSoap.make()
        }

        if pathLower.contains("food_coloring_001") {
            if pathLower.contains("circle") { return ShaderPreviewMaterialID.mWaterFCRed.make() }
            if hay.contains("материал") { return ShaderPreviewMaterialID.mLabelFCRed.make() }
            if hay.contains("glass") { return ShaderPreviewMaterialID.mGlass.make() }
            if hay.contains("pet") { return ShaderPreviewMaterialID.mPETFCRed.make() }
            switch slot {
            case 1: return ShaderPreviewMaterialID.mGlass.make()
            case 2: return ShaderPreviewMaterialID.mLabelFCRed.make()
            default: return ShaderPreviewMaterialID.mPETFCRed.make()
            }
        }
        if pathLower.contains("food_coloring_002") {
            if pathLower.contains("circle") { return ShaderPreviewMaterialID.mWaterFCGreen.make() }
            if hay.contains("материал") { return ShaderPreviewMaterialID.mLabelFCGreen.make() }
            if hay.contains("glass") { return ShaderPreviewMaterialID.mGlass.make() }
            if hay.contains("pet") { return ShaderPreviewMaterialID.mPETFCGreen.make() }
            switch slot {
            case 1: return ShaderPreviewMaterialID.mGlass.make()
            case 2: return ShaderPreviewMaterialID.mLabelFCGreen.make()
            default: return ShaderPreviewMaterialID.mPETFCGreen.make()
            }
        }
        if pathLower.contains("food_coloring_003") {
            if pathLower.contains("circle") { return ShaderPreviewMaterialID.mWaterFCBlue.make() }
            if hay.contains("материал") { return ShaderPreviewMaterialID.mLabelFCBlue.make() }
            if hay.contains("glass") { return ShaderPreviewMaterialID.mGlass.make() }
            if hay.contains("pet") { return ShaderPreviewMaterialID.mPETFCBlue.make() }
            switch slot {
            case 1: return ShaderPreviewMaterialID.mGlass.make()
            case 2: return ShaderPreviewMaterialID.mLabelFCBlue.make()
            default: return ShaderPreviewMaterialID.mPETFCBlue.make()
            }
        }

        if pathLower.contains("dishsoap") && (
            hay.contains("sticker")
                || pathLower.contains("plane")
                || hay.contains("label")
        ) {
            return ShaderPreviewMaterialID.dishSoapSticker.make()
        }

        if pathLower.contains("sm_bottle_h2o2") {
            if pathLower.contains("liquid") {
                return ShaderPreviewMaterialID.mWaterH2O2.make()
            }
            let label: ShaderPreviewMaterialID
            if pathLower.contains("h2o2_001") {
                label = .mLabelH2O27
            } else if pathLower.contains("h2o2_002") {
                label = .mLabelH2O25
            } else {
                label = .mLabelH2O23
            }
            if hay.contains("label") || hay.contains("glossy") || hay.contains("материал") {
                return label.make()
            }
            if hay.contains("tr_plastic") || hay.contains("transparent") {
                return ShaderPreviewMaterialID.mTrPlastic.make()
            }
            if hay.contains("pet") { return ShaderPreviewMaterialID.mPETH2O2.make() }
            switch slot {
            case 1: return ShaderPreviewMaterialID.mPETH2O2.make()
            case 2: return label.make()
            default: return ShaderPreviewMaterialID.mTrPlastic.make()
            }
        }

        if pathLower.contains("yeast") {
            return ShaderPreviewMaterialID.mYeast.make()
        }
        if pathLower.contains("spoon") {
            return ShaderPreviewMaterialID.mChrome.make()
        }

        if hay.contains("bowl"), !pathLower.contains("yeast"), !pathLower.contains("spoon") {
            return ShaderPreviewMaterialID.bowlPorcelain.make()
        }

        let mustReplace = isGraph
            || hay.contains("bowl")
            || pathLower.contains("liquid_dishsoap")
            || pathLower.contains("yeast")
            || pathLower.contains("spoon")
            || hay.contains("chrome")
            || hay.contains("label")
            || hay.contains("материал")
            || hay.contains("sticker")
            || hay.contains("glossy")
        guard mustReplace else { return material }

        if let match = ShaderPreviewMaterialID.matching("\(token) \(path)") {
            return match.make()
        }
        return ShaderPreviewMaterialID.mPET.make()
    }

    private static func materialToken(_ material: RealityKit.Material) -> String {
        var parts = [String(describing: type(of: material))]
        for child in Mirror(reflecting: material).children {
            guard let label = child.label, label.lowercased().contains("name") else { continue }
            if let value = child.value as? String { parts.append(value) }
        }
        return parts.joined(separator: " ")
    }
}

enum ShaderPreviewLoadError: Error, LocalizedError {
    case missingEntity(String)

    var errorDescription: String? {
        switch self {
        case .missingEntity(let name):
            return "missing \(name)"
        }
    }
}
