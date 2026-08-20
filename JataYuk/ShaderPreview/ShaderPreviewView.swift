import ARKit
import CoreGraphics
import RealityKit
import SwiftUI

struct ShaderPreviewView: View {
    @State private var objectIndex = 0
    @State private var status = "Loading…"

    private var current: ShaderPreviewObject {
        ShaderPreviewObject.allCases[objectIndex]
    }

    var body: some View {
        ZStack {
            ShaderPreviewARView(objectIndex: objectIndex, status: $status)
                .ignoresSafeArea()

            VStack {
                header
                Spacer()
                controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(current.displayName)
                .font(.headline)
            Text(current.note)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(status)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Drag to orbit")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button("Prev") { step(-1) }
                .buttonStyle(.borderedProminent)
            Text("\(objectIndex + 1) / \(ShaderPreviewObject.allCases.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white)
                .shadow(radius: 4)
            Button("Next") { step(1) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func step(_ delta: Int) {
        let count = ShaderPreviewObject.allCases.count
        objectIndex = (objectIndex + delta + count) % count
    }
}

private struct ShaderPreviewARView: UIViewRepresentable {
    var objectIndex: Int
    @Binding var status: String

    func makeCoordinator() -> ShaderPreviewCoordinator {
        ShaderPreviewCoordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.renderOptions.insert(.disableGroundingShadows)

        let config = ARWorldTrackingConfiguration()
        arView.session.run(config)

        arView.environment.lighting.intensityExponent = 0.7

        let rotator = Entity()
        rotator.position = SIMD3(0, 0, -0.4)

        let light = PointLight()
        light.light.intensity = 4500
        light.light.attenuationRadius = 6
        light.position = SIMD3(0.14, 0.22, 0.08)

        let key = DirectionalLight()
        key.light.intensity = 3200
        key.orientation = simd_normalize(
            simd_quatf(angle: -.pi / 5, axis: SIMD3(1, 0, 0))
                * simd_quatf(angle: .pi / 5, axis: SIMD3(0, 1, 0))
        )

        let fill = DirectionalLight()
        fill.light.intensity = 1100
        fill.orientation = simd_quatf(angle: .pi * 0.7, axis: SIMD3(0, 1, 0))

        let cameraAnchor = AnchorEntity(.camera)
        cameraAnchor.addChild(rotator)
        cameraAnchor.addChild(light)
        cameraAnchor.addChild(key)
        cameraAnchor.addChild(fill)
        arView.scene.addAnchor(cameraAnchor)

        Task { @MainActor in
            if let ibl = await ShaderPreviewStudioIBL.make() {
                arView.environment.lighting.resource = ibl
            }
        }

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(ShaderPreviewCoordinator.handlePan(_:))
        )
        arView.addGestureRecognizer(pan)

        context.coordinator.arView = arView
        context.coordinator.rotator = rotator
        context.coordinator.onStatus = { status = $0 }
        context.coordinator.show(objectIndex: objectIndex)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.onStatus = { status = $0 }
        context.coordinator.show(objectIndex: objectIndex)
    }
}

final class ShaderPreviewCoordinator: NSObject {
    var arView: ARView?
    var rotator: Entity?
    var onStatus: ((String) -> Void)?
    private var shownIndex: Int = -1
    private var loadGeneration: Int = 0
    private var yaw: Float = 0.5
    private var pitch: Float = 0.32

    func show(objectIndex: Int) {
        guard objectIndex != shownIndex else { return }
        shownIndex = objectIndex
        loadGeneration += 1
        let generation = loadGeneration

        rotator?.children.forEach { $0.removeFromParent() }
        rotator?.addChild(ShaderPreviewObject.placeholder())
        onStatus?("Loading…")

        let object = ShaderPreviewObject.allCases[objectIndex]
        guard let arView else {
            onStatus?("No ARView")
            return
        }

        Task { @MainActor in
            let entity: Entity
            var status: String
            do {
                entity = try await ShaderPreviewObject.load(object, into: arView)
                status = object.entityName
            } catch {
                entity = ShaderPreviewObject.placeholder()
                status = "Load failed: \(error.localizedDescription)"
            }
            guard generation == self.loadGeneration, let rotator = self.rotator else { return }
            rotator.children.forEach { $0.removeFromParent() }
            entity.transform = Transform()
            entity.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
            rotator.addChild(entity)
            self.resetOrbit()
            let fitted = ShaderPreviewObject.fitInParent(entity, parent: rotator, maxExtent: 0.18)
            if fitted == "empty bounds" {
                rotator.addChild(ShaderPreviewObject.placeholder())
            }
            self.onStatus?("\(status) · \(fitted)")
        }
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        gesture.setTranslation(.zero, in: gesture.view)
        yaw += Float(translation.x) * 0.008
        pitch = max(-1.15, min(1.15, pitch + Float(translation.y) * 0.008))
        applyOrbit()
    }

    private func resetOrbit() {
        yaw = 0.5
        pitch = 0.32
        applyOrbit()
    }

    private func applyOrbit() {
        let pitchQ = simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
        let yawQ = simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        rotator?.orientation = simd_normalize(pitchQ * yawQ)
    }
}

/// Soft studio dome so chrome has something metallic to reflect.
private enum ShaderPreviewStudioIBL {
    static func make() async -> EnvironmentResource? {
        let width = 256
        let height = 128
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let v = Float(y) / Float(height - 1)
            for x in 0..<width {
                let u = Float(x) / Float(width - 1)
                let horizon = exp(-pow((v - 0.52) * 8, 2))
                let sky = max(0, 1 - v * 1.15)
                let ground = max(0, v - 0.55) * 1.4
                let window = exp(-pow((u - 0.22) * 9, 2)) * exp(-pow((v - 0.28) * 6, 2))
                let r = min(1, 0.22 + sky * 0.55 + horizon * 0.35 + window * 0.9 + ground * 0.12)
                let g = min(1, 0.24 + sky * 0.62 + horizon * 0.32 + window * 0.85 + ground * 0.10)
                let b = min(1, 0.28 + sky * 0.78 + horizon * 0.28 + window * 0.7 + ground * 0.08)
                let i = (y * width + x) * 4
                pixels[i] = UInt8(r * 255)
                pixels[i + 1] = UInt8(g * 255)
                pixels[i + 2] = UInt8(b * 255)
                pixels[i + 3] = 255
            }
        }
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            return nil
        }
        return try? await EnvironmentResource(equirectangular: image)
    }
}

#Preview {
    ShaderPreviewView()
}
