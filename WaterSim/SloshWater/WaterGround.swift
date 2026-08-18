//
//  WaterGround.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import RealityKit
import simd

enum WaterGroundError: Error {
    case meshNotFound
    case notAFilledPlane
}

struct WaterGround {
    let positions: [SIMD2<Float>]
    let triangles: [UInt32]
    let rim: [Int]
    let toGround: simd_quatf

    var maxRimRadius: Float {
        rim.reduce(0) { max($0, simd_length(positions[$1])) }
    }

    func columnHeight(_ bounds: BoundingBox) -> Float {
        var best: Float = 0
        for x in [bounds.min.x, bounds.max.x] {
            for y in [bounds.min.y, bounds.max.y] {
                for z in [bounds.min.z, bounds.max.z] {
                    best = max(best, toGround.act(SIMD3(x, y, z)).y)
                }
            }
        }
        return max(best, 0.001)
    }

    static func extract(from entity: Entity) throws -> WaterGround {
        let extracted = triangles(from: entity)
        guard extracted.positions.count >= 3, extracted.triangles.count >= 3 else {
            throw WaterGroundError.meshNotFound
        }

        let flattened = flatten(extracted.positions)
        let welded = weld(positions: flattened.points, triangles: extracted.triangles)
        let oriented = orientUp(positions: welded.positions, triangles: welded.triangles)
        guard let rim = boundaryLoop(vertexCount: oriented.positions.count, triangles: oriented.triangles) else {
            throw WaterGroundError.notAFilledPlane
        }
        return WaterGround(
            positions: oriented.positions,
            triangles: oriented.triangles,
            rim: orientRim(rim, positions: oriented.positions),
            toGround: flattened.toGround
        )
    }

    private static func triangles(from entity: Entity) -> (positions: [SIMD3<Float>], triangles: [UInt32]) {
        var positions: [SIMD3<Float>] = []
        var triangles: [UInt32] = []

        func visit(_ node: Entity) {
            if let model = node.components[ModelComponent.self] {
                let offset = UInt32(positions.count)
                for meshModel in model.mesh.contents.models {
                    for part in meshModel.parts {
                        for position in part.positions {
                            positions.append(node.convert(position: position, to: entity))
                        }
                        if let indices = part.triangleIndices {
                            triangles.append(contentsOf: indices.map { $0 + offset })
                        }
                    }
                }
            }
            for child in node.children {
                visit(child)
            }
        }

        visit(entity)
        return (positions, triangles)
    }

    private static func flatten(_ positions: [SIMD3<Float>]) -> (points: [SIMD2<Float>], toGround: simd_quatf) {
        var minBounds = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for position in positions {
            minBounds = min(minBounds, position)
            maxBounds = max(maxBounds, position)
        }
        let extent = maxBounds - minBounds
        let thin: SIMD3<Float>
        if extent.y <= extent.x && extent.y <= extent.z {
            thin = SIMD3(0, 1, 0)
        } else if extent.z <= extent.x && extent.z <= extent.y {
            thin = SIMD3(0, 0, 1)
        } else {
            thin = SIMD3(1, 0, 0)
        }
        let up = SIMD3<Float>(0, 1, 0)
        let axis = simd_cross(thin, up)
        let toGround: simd_quatf
        if simd_length(axis) < 1e-5 {
            toGround = simd_dot(thin, up) > 0
                ? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                : simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
        } else {
            toGround = simd_quatf(from: thin, to: up)
        }
        let points = positions.map { point -> SIMD2<Float> in
            let ground = toGround.act(point)
            return SIMD2(ground.x, ground.z)
        }
        return (points, toGround)
    }

    private static func weld(
        positions: [SIMD2<Float>],
        triangles: [UInt32]
    ) -> (positions: [SIMD2<Float>], triangles: [UInt32]) {
        let quant: Float = 0.0001
        var unique: [SIMD2<Float>] = []
        var remap = [Int](repeating: 0, count: positions.count)
        var seen: [SIMD2<Int>: Int] = [:]

        for (index, position) in positions.enumerated() {
            let key = SIMD2(Int((position.x / quant).rounded()), Int((position.y / quant).rounded()))
            if let existing = seen[key] {
                remap[index] = existing
            } else {
                seen[key] = unique.count
                remap[index] = unique.count
                unique.append(position)
            }
        }

        var welded: [UInt32] = []
        for i in stride(from: 0, to: triangles.count, by: 3) {
            let a = UInt32(remap[Int(triangles[i])])
            let b = UInt32(remap[Int(triangles[i + 1])])
            let c = UInt32(remap[Int(triangles[i + 2])])
            if a == b || b == c || c == a { continue }
            welded += [a, b, c]
        }
        return (unique, welded)
    }

    private static func signedArea(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private static func orientUp(
        positions: [SIMD2<Float>],
        triangles: [UInt32]
    ) -> (positions: [SIMD2<Float>], triangles: [UInt32]) {
        var area: Float = 0
        for i in stride(from: 0, to: triangles.count, by: 3) {
            area += signedArea(
                positions[Int(triangles[i])],
                positions[Int(triangles[i + 1])],
                positions[Int(triangles[i + 2])]
            )
        }
        guard area < 0 else { return (positions, triangles) }
        var flipped = triangles
        for i in stride(from: 0, to: flipped.count, by: 3) {
            flipped.swapAt(i + 1, i + 2)
        }
        return (positions, flipped)
    }

    private static func boundaryLoop(vertexCount: Int, triangles: [UInt32]) -> [Int]? {
        struct Edge: Hashable {
            let a: Int
            let b: Int
            init(_ i: Int, _ j: Int) {
                a = min(i, j)
                b = max(i, j)
            }
        }

        var counts: [Edge: Int] = [:]
        for i in stride(from: 0, to: triangles.count, by: 3) {
            let a = Int(triangles[i]), b = Int(triangles[i + 1]), c = Int(triangles[i + 2])
            counts[Edge(a, b), default: 0] += 1
            counts[Edge(b, c), default: 0] += 1
            counts[Edge(c, a), default: 0] += 1
        }

        var next: [Int: [Int]] = [:]
        for (edge, count) in counts where count == 1 {
            next[edge.a, default: []].append(edge.b)
            next[edge.b, default: []].append(edge.a)
        }
        guard let start = next.keys.min(), var current = next[start]?.first else { return nil }

        var loop = [start]
        var previous = start
        while current != start {
            loop.append(current)
            let following = next[current]?.first { $0 != previous } ?? current
            previous = current
            current = following
            if loop.count > vertexCount + 2 { return nil }
        }
        return loop.count >= 3 ? loop : nil
    }

    private static func orientRim(_ rim: [Int], positions: [SIMD2<Float>]) -> [Int] {
        var area: Float = 0
        for i in 0..<rim.count {
            let a = positions[rim[i]]
            let b = positions[rim[(i + 1) % rim.count]]
            area += a.x * b.y - b.x * a.y
        }
        return area >= 0 ? rim : Array(rim.reversed())
    }
}
