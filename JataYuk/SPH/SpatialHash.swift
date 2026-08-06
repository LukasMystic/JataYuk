//
//  SpatialHash.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import simd

/// Explicit integer cell coordinate used as a dictionary key. Using a struct
/// (rather than folding three ints into one hash) guarantees no key collisions,
/// so neighbour queries never return particles from an unrelated cell.
private struct CellKey: Hashable {
    let x: Int32
    let y: Int32
    let z: Int32
}

/// Uniform-grid spatial hash giving O(n) neighbour search instead of O(n²).
///
/// Particles are bucketed into cubic cells of side `cellSize`. The SPH kernels
/// vanish beyond the smoothing radius `h`, so with `cellSize == h` every
/// possible neighbour lies in the particle's own cell or the 26 cells around
/// it — 27 cells total.
final class SpatialHash {
    private let cellSize: Float
    private var buckets: [CellKey: [Int]] = [:]

    init(cellSize: Float) {
        self.cellSize = cellSize
    }

    /// Rebuild the grid from scratch — called once per substep because
    /// positions change every substep.
    func build(_ particles: [Particle]) {
        buckets.removeAll(keepingCapacity: true)
        for i in particles.indices {
            buckets[key(for: particles[i].position), default: []].append(i)
        }
    }

    /// Invoke `body` for every particle index in the 27-cell neighbourhood
    /// around `position`. The caller still applies the exact radius test.
    @inline(__always)
    func forEachNeighbour(of position: SIMD3<Float>, _ body: (Int) -> Void) {
        let base = cell(for: position)
        for dz in -1...1 {
            for dy in -1...1 {
                for dx in -1...1 {
                    let k = CellKey(x: base.x + Int32(dx),
                                    y: base.y + Int32(dy),
                                    z: base.z + Int32(dz))
                    if let bucket = buckets[k] {
                        for idx in bucket { body(idx) }
                    }
                }
            }
        }
    }

    @inline(__always)
    private func cell(for p: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3<Int32>(Int32(floor(p.x / cellSize)),
                     Int32(floor(p.y / cellSize)),
                     Int32(floor(p.z / cellSize)))
    }

    @inline(__always)
    private func key(for p: SIMD3<Float>) -> CellKey {
        let c = cell(for: p)
        return CellKey(x: c.x, y: c.y, z: c.z)
    }
}
