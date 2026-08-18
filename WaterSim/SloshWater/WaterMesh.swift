//
//  WaterMesh.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import RealityKit
import UIKit
import simd

final class WaterMesh {
    let entity: ModelEntity

    private var height: Float
    private var headroom: Float
    private var restPositions: [SIMD3<Float>]
    private let restNormals: [SIMD3<Float>]
    private let roles: [VertexRole]
    private let ringIndex: [Int]
    private let indices: [UInt32]
    private let mesh: MeshResource
    private var wave: WaterRingWave

    private enum VertexRole {
        case side
        case bottomCap
        case topCap
        case topCapBack
    }

    init(
        ground: WaterGround,
        height: Float,
        headroom: Float,
        waveDamping: Float,
        waveScale: Float,
        materials: [any Material] = []
    ) {
        self.height = height
        self.headroom = headroom

        let built = Self.extrude(ground: ground, height: height)
        restPositions = built.positions
        restNormals = built.normals
        roles = built.roles
        ringIndex = built.ringIndex
        indices = built.indices
        wave = WaterRingWave(restXZ: built.ringXZ, damping: waveDamping, scale: waveScale)

        let generated = Self.makeMesh(positions: built.positions, normals: built.normals, indices: built.indices)
            ?? MeshResource.generateCylinder(height: height, radius: max(ground.maxRimRadius, 0.001))
        mesh = generated
        entity = ModelEntity(
            mesh: generated,
            materials: materials.isEmpty ? [Self.waterMaterial()] : materials
        )
        entity.name = "Water"
    }

    func setColumn(height: Float, headroom: Float) {
        if self.height > 0, abs(height - self.height) > 0.0001 {
            let scale = height / self.height
            for index in restPositions.indices {
                restPositions[index].y *= scale
            }
        }
        self.height = height
        self.headroom = headroom
    }

    func setWave(damping: Float, scale: Float) {
        wave.damping = damping
        wave.scale = scale
    }

    func apply(
        deltaTime: Float,
        up: SIMD3<Float>,
        userAcceleration: SIMD3<Float>,
        angularVelocity: SIMD3<Float>,
        applyWave: Bool
    ) {
        if applyWave {
            wave.update(deltaTime: deltaTime, userAcceleration: userAcceleration, angularVelocity: angularVelocity)
        }

        let n = simd_length(up) > 0.001 ? simd_normalize(up) : SIMD3<Float>(0, 1, 0)
        let ny = n.y >= 0 ? max(n.y, 0.12) : min(n.y, -0.12)
        let slopeX = -n.x / ny
        let slopeZ = -n.z / ny
        let yMax = height + headroom - 0.004
        let centerWave = applyWave ? wave.averageHeight : 0

        var positions = restPositions
        var normals = restNormals

        for index in restPositions.indices {
            let rest = restPositions[index]
            let t = height > 0 ? rest.y / height : 0
            var y = rest.y + t * (slopeX * rest.x + slopeZ * rest.z)
            if applyWave, t > 0.5 {
                let ring = ringIndex[index]
                y += ring >= 0 ? wave.height(at: ring) : centerWave
            }
            y = simd_clamp(y, 0.002, yMax)
            positions[index] = SIMD3(rest.x, y, rest.z)

            switch roles[index] {
            case .side, .bottomCap:
                break
            case .topCap:
                normals[index] = n
            case .topCapBack:
                normals[index] = -n
            }
        }

        guard let replacement = Self.makeMesh(positions: positions, normals: normals, indices: indices) else { return }
        try? mesh.replace(with: replacement.contents)
    }

    private static func extrude(ground: WaterGround, height: Float) -> (
        positions: [SIMD3<Float>],
        roles: [VertexRole],
        ringIndex: [Int],
        ringXZ: [SIMD2<Float>],
        normals: [SIMD3<Float>],
        indices: [UInt32]
    ) {
        let rim = ground.rim
        let rimCount = rim.count

        var positions: [SIMD3<Float>] = []
        var roles: [VertexRole] = []
        var ringIndex: [Int] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var ringXZ: [SIMD2<Float>] = []

        func append(_ position: SIMD3<Float>, role: VertexRole, normal: SIMD3<Float>, ring: Int) {
            positions.append(position)
            roles.append(role)
            normals.append(normal)
            ringIndex.append(ring)
        }

        var outward = [SIMD3<Float>](repeating: SIMD3(0, 0, 1), count: rimCount)
        for i in 0..<rimCount {
            let prev = ground.positions[rim[(i + rimCount - 1) % rimCount]]
            let current = ground.positions[rim[i]]
            let next = ground.positions[rim[(i + 1) % rimCount]]
            let combined = SIMD2(next.y - prev.y, prev.x - next.x)
            let length = simd_length(combined)
            outward[i] = length > 1e-5 ? SIMD3(combined.x / length, 0, combined.y / length) : SIMD3(0, 0, 1)
            ringXZ.append(current)
        }

        for i in 0..<rimCount {
            let xz = ground.positions[rim[i]]
            append(SIMD3(xz.x, 0, xz.y), role: .side, normal: outward[i], ring: -1)
        }
        for i in 0..<rimCount {
            let xz = ground.positions[rim[i]]
            append(SIMD3(xz.x, height, xz.y), role: .side, normal: outward[i], ring: i)
        }
        for i in 0..<rimCount {
            let next = (i + 1) % rimCount
            indices += [
                UInt32(i), UInt32(rimCount + i), UInt32(next),
                UInt32(next), UInt32(rimCount + i), UInt32(rimCount + next),
                UInt32(i), UInt32(next), UInt32(rimCount + i),
                UInt32(next), UInt32(rimCount + next), UInt32(rimCount + i)
            ]
        }

        var originalToRim = [Int](repeating: -1, count: ground.positions.count)
        for (ring, vertex) in rim.enumerated() {
            originalToRim[vertex] = ring
        }

        func appendCap(y: Float, role: VertexRole, normal: SIMD3<Float>, flip: Bool) {
            let start = UInt32(positions.count)
            for (index, xz) in ground.positions.enumerated() {
                append(SIMD3(xz.x, y, xz.y), role: role, normal: normal, ring: role == .bottomCap ? -1 : originalToRim[index])
            }
            for i in stride(from: 0, to: ground.triangles.count, by: 3) {
                let a = start + ground.triangles[i]
                let b = start + ground.triangles[i + 1]
                let c = start + ground.triangles[i + 2]
                indices += flip ? [a, c, b] : [a, b, c]
            }
        }

        appendCap(y: 0, role: .bottomCap, normal: SIMD3(0, -1, 0), flip: true)
        appendCap(y: height, role: .topCap, normal: SIMD3(0, 1, 0), flip: false)
        appendCap(y: height, role: .topCapBack, normal: SIMD3(0, -1, 0), flip: true)

        return (positions, roles, ringIndex, ringXZ, normals, indices)
    }

    private static func makeMesh(
        positions: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        indices: [UInt32]
    ) -> MeshResource? {
        var descriptor = MeshDescriptor(name: "water")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .allFaces(0)
        return try? MeshResource.generate(from: [descriptor])
    }

    private static func waterMaterial() -> SimpleMaterial {
        var material = SimpleMaterial(
            color: UIColor(red: 0.16, green: 0.48, blue: 0.88, alpha: 0.72),
            roughness: 0.22,
            isMetallic: false
        )
        material.faceCulling = .none
        return material
    }
}

struct WaterRingWave {
    private let restXZ: [SIMD2<Float>]
    var damping: Float
    var scale: Float
    private var heights: [Float]
    private var velocities: [Float]
    private var microHeights: [Float]
    private var microVelocities: [Float]
    private let microPhase: [Float]
    private let microFrequency: [Float]
    private var smoothedAcceleration = SIMD2<Float>.zero
    private var smoothedSpin = SIMD2<Float>.zero
    private var elapsed: Float = 0

    init(restXZ: [SIMD2<Float>], damping: Float, scale: Float) {
        self.restXZ = restXZ
        self.damping = damping
        self.scale = scale
        let count = restXZ.count
        heights = Array(repeating: 0, count: count)
        velocities = Array(repeating: 0, count: count)
        microHeights = Array(repeating: 0, count: count)
        microVelocities = Array(repeating: 0, count: count)
        microPhase = (0..<count).map { Float($0) * 1.7 + 0.4 }
        microFrequency = (0..<count).map { 1.6 + 0.35 * sin(Float($0) * 2.1) }
    }

    var averageHeight: Float {
        guard !heights.isEmpty else { return 0 }
        var sum: Float = 0
        for index in heights.indices {
            sum += height(at: index)
        }
        return sum / Float(heights.count)
    }

    func height(at index: Int) -> Float {
        heights[index] + microHeights[index]
    }

    mutating func update(deltaTime: Float, userAcceleration: SIMD3<Float>, angularVelocity: SIMD3<Float>) {
        let dt = min(max(deltaTime, 0), 1.0 / 30.0)
        let count = heights.count
        guard dt > 0, count > 0 else { return }

        let blend = min(1, 6 * dt)
        let rawAcceleration = SIMD2(
            simd_clamp(userAcceleration.x, -1.2, 1.2),
            simd_clamp(userAcceleration.z, -1.2, 1.2)
        )
        let rawSpin = SIMD2(
            simd_clamp(-angularVelocity.z, -4, 4),
            simd_clamp(angularVelocity.x, -4, 4)
        )
        smoothedAcceleration += (rawAcceleration - smoothedAcceleration) * blend
        smoothedSpin += (rawSpin - smoothedSpin) * blend

        var nextVelocities = velocities
        for index in 0..<count {
            let previous = heights[(index + count - 1) % count]
            let next = heights[(index + 1) % count]
            nextVelocities[index] += (140 * (previous + next - 2 * heights[index]) - 12 * heights[index]) * dt

            let radial = restXZ[index]
            let radialLength = simd_length(radial)
            guard radialLength > 1e-5 else { continue }
            let dir = radial / radialLength
            let kick = simd_dot(smoothedAcceleration, dir) * (0.28 * scale)
                + simd_dot(smoothedSpin, dir) * (0.06 * scale)
            nextVelocities[index] += simd_clamp(kick, -0.35, 0.35) * dt
        }

        var sum: Float = 0
        for index in 0..<count {
            var velocity = nextVelocities[index]
            velocity *= max(0, 1 - damping * dt)
            let height = simd_clamp(heights[index] + velocity * dt, -0.007, 0.007)
            velocities[index] = velocity
            heights[index] = height
            sum += height
        }

        let mean = sum / Float(count)
        let motion = simd_length(smoothedAcceleration) + simd_length(smoothedSpin) * 0.08
        elapsed += dt
        var microSum: Float = 0
        for index in 0..<count {
            heights[index] -= mean
            let energy = min(1, abs(heights[index]) / 0.007 + motion * 0.45)
            let target = sin(elapsed * microFrequency[index] + microPhase[index])
                * (0.00028 * scale + 0.0011 * scale * energy)
            var microVelocity = microVelocities[index]
            microVelocity += (target - microHeights[index]) * 14 * dt
            microVelocity *= max(0, 1 - 5.5 * dt)
            let micro = simd_clamp(microHeights[index] + microVelocity * dt, -0.0018, 0.0018)
            microVelocities[index] = microVelocity
            microHeights[index] = micro
            microSum += micro
        }
        let microMean = microSum / Float(count)
        for index in 0..<count {
            microHeights[index] -= microMean
        }
    }
}
