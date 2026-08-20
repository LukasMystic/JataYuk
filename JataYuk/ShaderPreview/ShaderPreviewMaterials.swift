import CoreGraphics
import RealityKit
import ShaderDev
import UIKit

/// One page in the preview. Order is `CaseIterable` declaration order.
@MainActor
enum ShaderPreviewMaterialID: String, CaseIterable, Identifiable {
    case mGlass
    case mTpPlastic
    case mTrPlastic
    case mWater
    case mPET
    case mChrome
    case mRubber
    case mYeast
    case mLabel
    case mGlassMonolith
    case mPETBlack
    case mRubberBlack
    case mPETDarkGray
    case mPETDishSoap
    case mPETFCGreen
    case mPETFCBlue
    case mPETFCRed
    case mWaterFCGreen
    case mWaterFCBlue
    case mWaterFCRed
    case mPETH2O2
    case mWaterH2O2
    case mLabelFCGreen
    case mLabelFCBlue
    case mLabelFCRed
    case mLabelH2O23
    case mLabelH2O25
    case mLabelH2O27
    case dishSoapSticker
    case mWaterDishSoap
    case bowlPorcelain
    case wood
    case polishedChromeMetal
    case snowVolcano

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mGlass: return "M_Glass"
        case .mTpPlastic: return "M_Tp_Plastic"
        case .mTrPlastic: return "M_Tr_Plastic"
        case .mWater: return "M_Water"
        case .mPET: return "M_PET"
        case .mChrome: return "M_Chrome"
        case .mRubber: return "M_Rubber"
        case .mYeast: return "M_Yeast"
        case .mLabel: return "M_Label"
        case .mGlassMonolith: return "M_Glass_Monolith"
        case .mPETBlack: return "M_PET_Black"
        case .mRubberBlack: return "M_Rubber_Black"
        case .mPETDarkGray: return "M_PET_DarkGray"
        case .mPETDishSoap: return "M_PET_DishSoap"
        case .mPETFCGreen: return "M_PET_FC_Green"
        case .mPETFCBlue: return "M_PET_FC_Blue"
        case .mPETFCRed: return "M_PET_FC_Red"
        case .mWaterFCGreen: return "M_Water_FC_Green"
        case .mWaterFCBlue: return "M_Water_FC_Blue"
        case .mWaterFCRed: return "M_Water_FC_Red"
        case .mPETH2O2: return "M_PET_H2O2"
        case .mWaterH2O2: return "M_Water_H2O2"
        case .mLabelFCGreen: return "M_Label_FC_Green"
        case .mLabelFCBlue: return "M_Label_FC_Blue"
        case .mLabelFCRed: return "M_Label_FC_Red"
        case .mLabelH2O23: return "M_Label_H2O2_3"
        case .mLabelH2O25: return "M_Label_H2O2_5"
        case .mLabelH2O27: return "M_Label_H2O2_7"
        case .dishSoapSticker: return "DishSoapSticker"
        case .mWaterDishSoap: return "M_Water (DishSoap green)"
        case .bowlPorcelain: return "Bowl (porcelain)"
        case .wood: return "Wood"
        case .polishedChromeMetal: return "Polished_Chrome_Metal"
        case .snowVolcano: return "Snow_Volcano"
        }
    }

    func make() -> PhysicallyBasedMaterial {
        switch self {
        case .mGlass:
            // RCP graph: mix(envRadiance cyan, white*fresnel, 0.96). Opacity is
            // (1 − N·V)^2.6 clamped 0.02…0.15 — PBR uses the mid-clamp.
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.mixP3(
                    (0.80967116, 0.96587574, 0.9918342),
                    (1, 1, 1),
                    t: 0.96
                ),
                roughness: 0.15,
                opacity: 0.10,
                specular: 0.85,
                clearcoat: 0,
                clearcoatRoughness: 0.35
            )
        case .mTpPlastic:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.mixP3(
                    (0.84503686, 1, 0.9952912),
                    (1, 1, 1),
                    t: 0.96
                ),
                roughness: 0.54,
                opacity: 0.10,
                specular: 0.85,
                clearcoat: 0.61,
                clearcoatRoughness: 0.3
            )
        case .mTrPlastic:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.mixP3(
                    (0.9085553, 0.99884105, 1),
                    (1, 1, 1),
                    t: 0.96
                ),
                roughness: 0.54,
                opacity: 0.08,
                specular: 0.85,
                clearcoat: 1,
                clearcoatRoughness: 0.47
            )
        case .mWater:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.p3(0.6174722, 0.86365557, 1),
                roughness: 0,
                opacity: 0.5,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0
            )
        case .mPET:
            return ShaderPreviewPBR.solid(
                tint: .white,
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mChrome:
            return ShaderPreviewPBR.solid(
                tint: UIColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1),
                roughness: 0.04,
                metallic: 1,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0.05
            )
        case .mRubber:
            return ShaderPreviewPBR.solid(
                tint: .white,
                roughness: 0.55,
                specular: 0.82,
                clearcoat: 0.64,
                clearcoatRoughness: 0.37
            )
        case .mYeast:
            return ShaderPreviewPBR.yeast()
        case .mLabel:
            return ShaderPreviewPBR.label(stem: "FoodColoring_ExampleSticker")
        case .mGlassMonolith:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.mixP3(
                    (0.80967116, 0.96587574, 0.9918342),
                    (1, 1, 1),
                    t: 0.96
                ),
                roughness: 0.41,
                opacity: 0.10,
                specular: 0.85,
                clearcoat: 0.3,
                clearcoatRoughness: 0.25
            )
        case .mPETBlack:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.081757054, 0.082558595, 0.082558595),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mRubberBlack:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.23900448, 0.24134766, 0.24134766),
                roughness: 0.55,
                specular: 0.82,
                clearcoat: 0.64,
                clearcoatRoughness: 0.37
            )
        case .mPETDarkGray:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.25256297, 0.25503907, 0.25503907),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mPETDishSoap:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.21321921, 0.47138673, 0.1413021),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mPETFCGreen:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.3882353, 0.65882355, 0.5058824),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mPETFCBlue:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.2509804, 0.8156863, 0.87058824),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mPETFCRed:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.87058824, 0.3647059, 0.34117648),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mWaterFCGreen:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.p3(0.13725491, 0.40784314, 0.25882354),
                roughness: 0,
                opacity: 0.9,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0
            )
        case .mWaterFCBlue:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.p3(0, 0.5647059, 0.62352943),
                roughness: 0,
                opacity: 0.9,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0
            )
        case .mWaterFCRed:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.p3(0.62352943, 0.11372549, 0.09411765),
                roughness: 0,
                opacity: 0.9,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0
            )
        case .mPETH2O2:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.71777344, 0.8432617, 0.85498047),
                roughness: 0.74,
                specular: 0.82,
                clearcoat: 0.57,
                clearcoatRoughness: 0.22
            )
        case .mWaterH2O2:
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.p3(0.74902344, 0.87841797, 0.8901367),
                roughness: 0,
                opacity: 0.5,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0
            )
        case .mLabelFCGreen:
            return ShaderPreviewPBR.label(stem: "FoodColoring_Label_Green")
        case .mLabelFCBlue:
            return ShaderPreviewPBR.label(stem: "FoodColoring_Label_Blue")
        case .mLabelFCRed:
            return ShaderPreviewPBR.label(stem: "FoodColoring_Label_Red")
        case .mLabelH2O23:
            return ShaderPreviewPBR.label(stem: "H2O2_Label_3")
        case .mLabelH2O25:
            return ShaderPreviewPBR.label(stem: "H2O2_Label_5")
        case .mLabelH2O27:
            return ShaderPreviewPBR.label(stem: "H2O2_Label_7")
        case .dishSoapSticker:
            return ShaderPreviewPBR.label(stem: "DishSoap_Label")
        case .mWaterDishSoap:
            // M_Water recipe, tinted to M_PET_DishSoap green.
            return ShaderPreviewPBR.transparent(
                tint: ShaderPreviewPBR.p3(0.21321921, 0.47138673, 0.1413021),
                roughness: 0,
                opacity: 0.55,
                specular: 1,
                clearcoat: 1,
                clearcoatRoughness: 0
            )
        case .bowlPorcelain:
            return ShaderPreviewPBR.solid(
                tint: ShaderPreviewPBR.p3(0.96, 0.94, 0.90),
                roughness: 0.17,
                specular: 0.55,
                clearcoat: 0.4,
                clearcoatRoughness: 0.08
            )
        case .wood:
            return ShaderPreviewPBR.mapped(
                tint: ShaderPreviewPBR.p3(0.45, 0.32, 0.18),
                base: "woodcreator_1_basecolor",
                roughness: "woodcreator_1_roughness",
                roughnessScale: 0.6,
                metallic: "woodcreator_1_metallic",
                normal: "woodcreator_1_normal",
                specular: 0.5
            )
        case .polishedChromeMetal:
            return ShaderPreviewMaterialID.mChrome.make()
        case .snowVolcano:
            return ShaderPreviewPBR.mapped(
                tint: UIColor(white: 0.72, alpha: 1),
                base: "BaseColor_Simpified",
                roughnessScale: 0.5,
                normal: "Normal Map_0",
                specular: 0.5
            )
        }
    }

    static func matching(_ token: String) -> ShaderPreviewMaterialID? {
        let name = token.lowercased()
        if name.contains("snow") { return .snowVolcano }
        if name.contains("wood") { return .wood }
        if name.contains("sticker") { return .dishSoapSticker }
        if name.contains("bowl") { return .bowlPorcelain }
        if name.contains("label_fc_green") { return .mLabelFCGreen }
        if name.contains("label_fc_blue") { return .mLabelFCBlue }
        if name.contains("label_fc_red") { return .mLabelFCRed }
        if name.contains("label_h2o2_3") { return .mLabelH2O23 }
        if name.contains("label_h2o2_7") { return .mLabelH2O27 }
        if name.contains("label_h2o2") { return .mLabelH2O25 }
        if name.contains("label") || name.contains("материал") { return .mLabel }
        if name.contains("yeast") { return .mYeast }
        if name.contains("rubber_black") { return .mRubberBlack }
        if name.contains("rubber") { return .mRubber }
        if name.contains("chrome") || name.contains("stylized_metal") || name.contains("polished") {
            return .mChrome
        }
        if name.contains("glass") || name.contains("crystal") { return .mGlass }
        if name.contains("tp_plastic") { return .mTpPlastic }
        if name.contains("tr_plastic") || name.contains("transparent_plastic") { return .mTrPlastic }
        if name.contains("water_fc_green") { return .mWaterFCGreen }
        if name.contains("water_fc_blue") { return .mWaterFCBlue }
        if name.contains("water_fc_red") { return .mWaterFCRed }
        if name.contains("water_h2o2") { return .mWaterH2O2 }
        if name.contains("water") { return .mWater }
        if name.contains("pet_black") || name.contains("black_plastic") { return .mPETBlack }
        if name.contains("pet_dark") || name.contains("m_pet_2") || name.contains("pm_t1") {
            return .mPETDarkGray
        }
        if name.contains("pet_dish") || name.contains("pearl_green") { return .mPETDishSoap }
        if name.contains("pet_fc_green") { return .mPETFCGreen }
        if name.contains("pet_fc_blue") || name.contains("blue_plastic") { return .mPETFCBlue }
        if name.contains("pet_fc_red") { return .mPETFCRed }
        if name.contains("pet_h2o2") || name.contains("m_pet_1") { return .mPETH2O2 }
        if name.contains("pet") || name.contains("white_plastic") { return .mPET }
        return nil
    }
}

@MainActor
private enum ShaderPreviewPBR {
    static func p3(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(displayP3Red: r, green: g, blue: b, alpha: 1)
    }

    /// MaterialX `ND_mix_color3`: `(1 - t) * bg + t * fg` in Display P3.
    static func mixP3(
        _ fg: (CGFloat, CGFloat, CGFloat),
        _ bg: (CGFloat, CGFloat, CGFloat),
        t: CGFloat
    ) -> UIColor {
        p3(
            bg.0 + (fg.0 - bg.0) * t,
            bg.1 + (fg.1 - bg.1) * t,
            bg.2 + (fg.2 - bg.2) * t
        )
    }

    static func solid(
        tint: UIColor,
        roughness: Float,
        metallic: Float = 0,
        specular: Float,
        clearcoat: Float,
        clearcoatRoughness: Float,
        baseTexture: TextureResource? = nil
    ) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        applyCommon(
            &material,
            tint: tint,
            baseTexture: baseTexture,
            roughness: roughness,
            metallic: metallic,
            specular: specular,
            clearcoat: clearcoat,
            clearcoatRoughness: clearcoatRoughness
        )
        return material
    }

    static func transparent(
        tint: UIColor,
        roughness: Float,
        opacity: Float,
        specular: Float,
        clearcoat: Float,
        clearcoatRoughness: Float
    ) -> PhysicallyBasedMaterial {
        var material = solid(
            tint: tint,
            roughness: roughness,
            specular: specular,
            clearcoat: clearcoat,
            clearcoatRoughness: clearcoatRoughness
        )
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        material.faceCulling = .none
        return material
    }

    /// #E2C290 in sRGB, with fine sand-grain albedo + bump. Displacement is
    /// used as a normal so the grit reads in lighting, not as a specular map.
    static func yeast() -> PhysicallyBasedMaterial {
        let tint = UIColor(red: 226 / 255, green: 194 / 255, blue: 144 / 255, alpha: 1)
        let grain = YeastGrainMaps.shared
        var material = solid(
            tint: tint,
            roughness: 0.58,
            specular: 0.35,
            clearcoat: 0,
            clearcoatRoughness: 0,
            baseTexture: grain.albedo ?? loadTexture("Sand_Displacement 1")
        )
        if let resource = loadTexture("Sand_Roughness 1") ?? grain.roughness {
            material.roughness = .init(scale: 0.68, texture: .init(resource))
        }
        if let resource = grain.normal
            ?? loadTexture("Sand_Normal 1")
            ?? loadTexture("Sand_Displacement 1")
        {
            material.normal = .init(texture: .init(resource))
        }
        if let resource = loadTexture("Sand_Displacement 1") {
            material.specular = .init(scale: 0.4, texture: .init(resource))
        }
        return material
    }

    static func label(stem: String) -> PhysicallyBasedMaterial {
        guard let texture = loadTexture(stem) else {
            return solid(
                tint: .white,
                roughness: 1,
                specular: 0.5,
                clearcoat: 0,
                clearcoatRoughness: 0.03
            )
        }
        var material = solid(
            tint: .white,
            roughness: 1,
            specular: 0.5,
            clearcoat: 0,
            clearcoatRoughness: 0.03,
            baseTexture: texture
        )
        material.blending = .transparent(opacity: .init(scale: 1, texture: .init(texture)))
        return material
    }

    static func mapped(
        tint: UIColor,
        base: String? = nil,
        roughness: String? = nil,
        roughnessScale: Float,
        metallic: String? = nil,
        metallicScale: Float = 0,
        normal: String? = nil,
        specular: Float
    ) -> PhysicallyBasedMaterial {
        var material = solid(
            tint: tint,
            roughness: roughnessScale,
            metallic: metallicScale,
            specular: specular,
            clearcoat: 0,
            clearcoatRoughness: 0.03,
            baseTexture: base.flatMap(loadTexture)
        )
        if let resource = roughness.flatMap(loadTexture) {
            material.roughness = .init(scale: roughnessScale, texture: .init(resource))
        }
        if let resource = metallic.flatMap(loadTexture) {
            material.metallic = .init(scale: 1, texture: .init(resource))
        }
        if let resource = normal.flatMap(loadTexture) {
            material.normal = .init(texture: .init(resource))
        }
        return material
    }

    private static func applyCommon(
        _ material: inout PhysicallyBasedMaterial,
        tint: UIColor,
        baseTexture: TextureResource?,
        roughness: Float,
        metallic: Float,
        specular: Float,
        clearcoat: Float,
        clearcoatRoughness: Float
    ) {
        if let baseTexture {
            material.baseColor = .init(tint: tint, texture: .init(baseTexture))
        } else {
            material.baseColor = .init(tint: tint)
        }
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        material.specular = .init(floatLiteral: specular)
        material.clearcoat = .init(floatLiteral: clearcoat)
        material.clearcoatRoughness = .init(floatLiteral: clearcoatRoughness)
        material.faceCulling = .none
    }

    static func loadTexture(_ stem: String) -> TextureResource? {
        if let cached = textureCache[stem] { return cached }
        let resource = loadTextureUncached(stem)
        textureCache[stem] = resource
        return resource
    }

    private static var textureCache: [String: TextureResource?] = [:]

    private static func loadTextureUncached(_ stem: String) -> TextureResource? {
        let names = [stem, (stem as NSString).deletingPathExtension]
        let namedCandidates = names.flatMap { name -> [String] in
            [
                name,
                "USDC/textures/\(name)",
                "textures/\(name)",
                "Labels/\(name)",
                "ShaderPreview/Labels/\(name)",
            ]
        }
        for name in namedCandidates {
            if let resource = try? TextureResource.load(named: name, in: shaderDevBundle) {
                return resource
            }
            if let resource = try? TextureResource.load(named: name, in: .main) {
                return resource
            }
        }

        for url in textureFileURLs(stem: stem) {
            if let resource = texture(fromFile: url) { return resource }
        }
        return nil
    }

    private static func textureFileURLs(stem: String) -> [URL] {
        let fileName = (stem as NSString).lastPathComponent
        let base = (fileName as NSString).deletingPathExtension
        let exts = ["png", "jpg", "jpeg", "PNG", "JPG"]
        var urls: [URL] = []

        let subdirs = ["", "Labels", "ShaderPreview/Labels", "USDC/textures", "textures"]
        for bundle in [Bundle.main, shaderDevBundle] {
            for subdir in subdirs {
                let subdirectory: String? = subdir.isEmpty ? nil : subdir
                for ext in exts {
                    if let url = bundle.url(forResource: base, withExtension: ext, subdirectory: subdirectory) {
                        urls.append(url)
                    }
                    if let url = bundle.url(forResource: fileName, withExtension: nil, subdirectory: subdirectory) {
                        urls.append(url)
                    }
                }
            }
        }

        if let sourceDir {
            for ext in exts {
                urls.append(sourceDir.appendingPathComponent("\(base).\(ext)"))
            }
        }

        let previewLabels = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Labels")
        for ext in exts {
            urls.append(previewLabels.appendingPathComponent("\(base).\(ext)"))
        }

        return urls
    }

    private static let sourceDir: URL? = {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dir = repo.appendingPathComponent(
            "ShaderDev/Sources/ShaderDev/ShaderDev.rkassets/USDC/textures"
        )
        return FileManager.default.fileExists(atPath: dir.path) ? dir : nil
    }()

    private static func texture(fromFile url: URL) -> TextureResource? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let image = UIImage(contentsOfFile: url.path)?.cgImage {
            return try? TextureResource.generate(from: image, options: .init(semantic: .color))
        }
        return try? TextureResource.load(contentsOf: url)
    }
}

/// Fine yeast grit. Sand maps from RCP are low-frequency on typical UVs, so
/// this bakes high-frequency speckle as albedo + a matching normal.
@MainActor
private struct YeastGrainMaps {
    static let shared = YeastGrainMaps.make()

    let albedo: TextureResource?
    let normal: TextureResource?
    let roughness: TextureResource?

    private static func make() -> YeastGrainMaps {
        let size = 256
        var albedoPixels = [UInt8](repeating: 0, count: size * size * 4)
        var normalPixels = [UInt8](repeating: 0, count: size * size * 4)
        var roughnessPixels = [UInt8](repeating: 0, count: size * size * 4)
        var height = [Float](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                let n0 = valueNoise(x, y, size: size, freq: 36, seed: 19)
                let n1 = valueNoise(x, y, size: size, freq: 72, seed: 91)
                let n2 = valueNoise(x, y, size: size, freq: 140, seed: 247)
                let speckle = n0 * 0.45 + n1 * 0.35 + n2 * 0.20
                height[y * size + x] = speckle
            }
        }

        for y in 0..<size {
            for x in 0..<size {
                let i = y * size + x
                let h = height[i]
                let base = 4 * i
                let shade = 0.78 + h * 0.32
                let gAlbedo = u8(shade * 255)
                albedoPixels[base] = gAlbedo
                albedoPixels[base + 1] = gAlbedo
                albedoPixels[base + 2] = gAlbedo
                albedoPixels[base + 3] = 255

                let hx = height[y * size + (x + 1) % size] - height[y * size + (x + size - 1) % size]
                let hy = height[((y + 1) % size) * size + x] - height[((y + size - 1) % size) * size + x]
                let nx = -hx * 8
                let ny = -hy * 8
                let inv = 1 / max(0.0001, sqrt(nx * nx + ny * ny + 1))
                normalPixels[base] = u8((nx * inv * 0.5 + 0.5) * 255)
                normalPixels[base + 1] = u8((ny * inv * 0.5 + 0.5) * 255)
                normalPixels[base + 2] = u8((inv * 0.5 + 0.5) * 255)
                normalPixels[base + 3] = 255

                let rough = 0.42 + (1 - h) * 0.45
                let g = u8(rough * 255)
                roughnessPixels[base] = g
                roughnessPixels[base + 1] = g
                roughnessPixels[base + 2] = g
                roughnessPixels[base + 3] = 255
            }
        }

        return YeastGrainMaps(
            albedo: texture(from: albedoPixels, size: size, semantic: .color),
            normal: texture(from: normalPixels, size: size, semantic: .normal),
            roughness: texture(from: roughnessPixels, size: size, semantic: .scalar)
        )
    }

    private static func texture(
        from pixels: [UInt8],
        size: Int,
        semantic: TextureResource.Semantic
    ) -> TextureResource? {
        var pixels = pixels
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: space,
            bitmapInfo: bitmapInfo
        ), let image = context.makeImage() else {
            return nil
        }
        return try? TextureResource.generate(from: image, options: .init(semantic: semantic))
    }

    private static func valueNoise(_ x: Int, _ y: Int, size: Int, freq: Int, seed: UInt32) -> Float {
        let fx = Float(x) / Float(size) * Float(freq)
        let fy = Float(y) / Float(size) * Float(freq)
        let x0 = Int(floor(fx))
        let y0 = Int(floor(fy))
        let tx = fx - Float(x0)
        let ty = fy - Float(y0)
        let sx = tx * tx * (3 - 2 * tx)
        let sy = ty * ty * (3 - 2 * ty)
        let a = hash(x0, y0, seed)
        let b = hash(x0 + 1, y0, seed)
        let c = hash(x0, y0 + 1, seed)
        let d = hash(x0 + 1, y0 + 1, seed)
        let u = a + (b - a) * sx
        let v = c + (d - c) * sx
        return u + (v - u) * sy
    }

    private static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Float {
        var n = seed &+ UInt32(bitPattern: Int32(truncatingIfNeeded: x)) &* 374_761_393
        n = n &+ UInt32(bitPattern: Int32(truncatingIfNeeded: y)) &* 668_265_263
        n = (n ^ (n >> 13)) &* 1_274_126_177
        return Float(n & 0xFFFF) / 65_535
    }

    private static func u8(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, value.rounded())))
    }
}
