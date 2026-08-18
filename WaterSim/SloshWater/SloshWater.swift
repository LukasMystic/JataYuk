//
//  SloshWater.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import RealityKit
import simd

protocol SloshMotionProviding: AnyObject {
    var gravity: SIMD3<Float> { get }
    var userAcceleration: SIMD3<Float> { get }
}

final class SloshWater: Entity {
    convenience init(
        ground entity: Entity,
        innerHeight: Float,
        settings: SloshSettings,
        motion: any SloshMotionProviding
    ) throws {
        let ground = try WaterGround.extract(from: entity)
        let fill = simd_clamp(settings.defaultHeight, SloshWaterComponent.minFill, 0.98)
        let height = innerHeight * fill
        try self.init(
            ground: ground,
            height: height,
            headroom: max(innerHeight - height, 0.001),
            innerHeight: innerHeight,
            fill: fill,
            settings: settings,
            motion: motion,
            materials: Self.materials(from: entity)
        )
        position = entity.position
        scale = entity.scale
        orientation = entity.orientation * simd_inverse(ground.toGround)
        entity.isEnabled = false
    }

    init(
        ground: WaterGround,
        height: Float,
        headroom: Float,
        innerHeight: Float,
        fill: Float,
        settings: SloshSettings,
        motion: any SloshMotionProviding,
        materials: [any Material] = []
    ) {
        super.init()
        name = "SloshWater"
        Self.registerOnce()

        let viscosity = simd_clamp(settings.viscosity, 0, 1)
        let dynamicVertices = simd_clamp(settings.dynamicVertices, 0, 1)
        let mesh = WaterMesh(
            ground: ground,
            height: height,
            headroom: headroom,
            waveDamping: mix(2.5, 6.7, viscosity),
            waveScale: dynamicVertices * 2,
            materials: materials
        )
        addChild(mesh.entity)

        let radius = ground.maxRimRadius
        components.set(
            SloshWaterComponent(
                slosh: WaterSlosh(
                    stiffness: mix(16, 6, viscosity),
                    damping: mix(0.9, 2.5, viscosity),
                    maxTiltRadians: Self.maxTilt(height: height, headroom: headroom, radius: radius)
                ),
                mesh: mesh,
                motion: motion,
                applyWave: dynamicVertices > 0,
                settings: settings,
                innerHeight: innerHeight,
                radius: radius,
                fill: fill,
                lastDefaultHeight: fill,
                lastDecrementCount: settings.decrementCount
            )
        )
    }

    @MainActor required dynamic init() {
        super.init()
    }

    private static var didRegister = false

    private static func registerOnce() {
        guard !didRegister else { return }
        didRegister = true
        SloshWaterComponent.registerComponent()
        SloshWaterSystem.registerSystem()
    }

    static func maxTilt(height: Float, headroom: Float, radius: Float) -> Float {
        let clearance = min(height, headroom)
        guard radius > 0, clearance > 0 else { return 0.2 }
        return atan(clearance / radius)
    }

    private static func materials(from entity: Entity) -> [any Material] {
        if let materials = entity.components[ModelComponent.self]?.materials, !materials.isEmpty {
            return materials
        }
        for child in entity.children {
            let found = materials(from: child)
            if !found.isEmpty { return found }
        }
        return []
    }
}

struct SloshWaterComponent: Component {
    static let minFill: Float = 0.02

    var slosh: WaterSlosh
    let mesh: WaterMesh
    let motion: any SloshMotionProviding
    var applyWave: Bool
    let settings: SloshSettings
    let innerHeight: Float
    let radius: Float
    var fill: Float
    var lastDefaultHeight: Float
    var lastDecrementCount: Int
}

final class SloshWaterSystem: System {
    private static let query = EntityQuery(where: .has(SloshWaterComponent.self))

    required init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var component = entity.components[SloshWaterComponent.self] else { continue }
            syncKnobs(&component)
            let motion = component.motion
            component.slosh.update(
                deltaTime: dt,
                gravity: motion.gravity,
                userAcceleration: motion.userAcceleration
            )
            component.mesh.apply(
                deltaTime: dt,
                up: component.slosh.upVector,
                userAcceleration: motion.userAcceleration,
                angularVelocity: component.slosh.angularVelocity,
                applyWave: component.applyWave
            )
            entity.components.set(component)
        }
    }

    private func syncKnobs(_ component: inout SloshWaterComponent) {
        let settings = component.settings
        let viscosity = simd_clamp(settings.viscosity, 0, 1)
        let dynamicVertices = simd_clamp(settings.dynamicVertices, 0, 1)
        component.slosh.stiffness = mix(16, 6, viscosity)
        component.slosh.damping = mix(0.9, 2.5, viscosity)
        component.mesh.setWave(damping: mix(2.5, 6.7, viscosity), scale: dynamicVertices * 2)
        component.applyWave = dynamicVertices > 0

        let defaultHeight = simd_clamp(settings.defaultHeight, SloshWaterComponent.minFill, 0.98)
        var fill = component.fill
        if abs(defaultHeight - component.lastDefaultHeight) > 0.0001 {
            fill = defaultHeight
        }
        component.lastDefaultHeight = defaultHeight

        if settings.canDecrement {
            let events = settings.decrementCount - component.lastDecrementCount
            if events > 0 {
                fill = max(
                    SloshWaterComponent.minFill,
                    fill - max(settings.decrementValue, 0) * Float(events)
                )
            }
        }
        component.lastDecrementCount = settings.decrementCount
        applyFill(&component, fill)
    }

    private func applyFill(_ component: inout SloshWaterComponent, _ fill: Float) {
        guard abs(fill - component.fill) > 0.0001 else { return }
        component.fill = fill
        let height = component.innerHeight * fill
        let headroom = max(component.innerHeight - height, 0.001)
        component.mesh.setColumn(height: height, headroom: headroom)
        component.slosh.maxTiltRadians = SloshWater.maxTilt(
            height: height,
            headroom: headroom,
            radius: component.radius
        )
    }
}

struct WaterSlosh {
    var orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    var angularVelocity = SIMD3<Float>.zero
    var stiffness: Float
    var damping: Float
    var maxTiltRadians: Float
    private let accelerationGain: Float = 14

    var upVector: SIMD3<Float> {
        orientation.act(SIMD3<Float>(0, 1, 0))
    }

    mutating func update(deltaTime: Float, gravity: SIMD3<Float>, userAcceleration: SIMD3<Float>) {
        let dt = min(max(deltaTime, 0), 1.0 / 30.0)
        guard dt > 0 else { return }

        let gravityLength = simd_length(gravity)
        let down = gravityLength > 0.001 ? gravity / gravityLength : SIMD3<Float>(0, -1, 0)
        let currentUp = orientation.act(SIMD3<Float>(0, 1, 0))
        angularVelocity += rotationError(from: currentUp, to: -down) * stiffness * dt
        angularVelocity += SIMD3(-userAcceleration.z, 0, userAcceleration.x) * accelerationGain * dt
        angularVelocity -= angularVelocity * damping * dt

        let omega = simd_length(angularVelocity)
        if omega > 1e-5 {
            orientation = simd_normalize(
                simd_quatf(angle: omega * dt, axis: angularVelocity / omega) * orientation
            )
        }
        clampTilt()
    }

    private mutating func clampTilt() {
        let worldUp = SIMD3<Float>(0, 1, 0)
        let up = orientation.act(worldUp)
        let tilt = acos(simd_clamp(simd_dot(up, worldUp), -1, 1))
        guard tilt > maxTiltRadians else { return }

        let axis = simd_cross(worldUp, up)
        let axisLength = simd_length(axis)
        guard axisLength > 1e-5 else { return }

        let clampAxis = axis / axisLength
        orientation = simd_quatf(angle: maxTiltRadians, axis: clampAxis)
        let outward = simd_dot(angularVelocity, clampAxis)
        if outward > 0 {
            angularVelocity -= clampAxis * (outward * 1.65)
        }
    }

    private func rotationError(from currentUp: SIMD3<Float>, to targetUp: SIMD3<Float>) -> SIMD3<Float> {
        let cross = simd_cross(currentUp, targetUp)
        let dot = simd_clamp(simd_dot(currentUp, targetUp), -1, 1)
        let crossLength = simd_length(cross)
        if crossLength < 1e-5 {
            return dot > 0 ? .zero : SIMD3<Float>(1, 0, 0) * Float.pi
        }
        return (cross / crossLength) * acos(dot)
    }
}

private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
}
