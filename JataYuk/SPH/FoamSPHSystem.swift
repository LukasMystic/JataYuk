//
//  FoamSPHSystem.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import RealityKit
import UIKit
import simd

/// Bridges the SPH solver to RealityKit. Owns the solver, the emitter, and a
/// growable pool of white sphere entities that visualise the particles. Drive
/// it by calling `start(model:)` once, then `update(dt:)` every frame.
///
/// The pool grows as particles are emitted (spreading allocation over the
/// eruption instead of a 1000-entity hitch) and is reused across runs.
final class FoamSPHSystem {

    private let container: Entity
    private let geometry: ContainerGeometry
    private let solver: SPHSolver
    private var emitter: ParticleEmitter?
    private var model: FoamModel?

    private var spherePool: [ModelEntity] = []
    private let sphereMesh: MeshResource
    private let sphereMaterial: RealityKit.Material

    private var elapsed: Double = 0
    private var running = false
    /// Keep stepping a little past the chemistry decay so the puddle settles.
    private var stopTime: Double = .greatestFiniteMagnitude

    /// - Parameters:
    ///   - container: an Entity parented to the AR anchor at the vessel position;
    ///                particle positions are expressed in its local space.
    ///   - geometry:  vessel radius/height used for emission and collisions.
    init(container: Entity, geometry: ContainerGeometry) {
        self.container = container
        self.geometry = geometry
        self.solver = SPHSolver(config: SPHSolver.Config(), geometry: geometry)

        sphereMesh = .generateSphere(radius: 0.012)
        // White, matte foam with a slight wet sheen. Opaque so stacked particles
        // read clearly (no transparency sorting artifacts).
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(white: 0.98, alpha: 1.0))
        mat.roughness = 0.6          // matte, foamy — not glassy
        mat.metallic = 0.0
        mat.clearcoat = 0.3          // faint wet highlight
        mat.blending = .opaque
        sphereMaterial = mat
    }

    /// Begin a run for the given chemistry model. Clears any previous particles.
    func start(model: FoamModel) {
        self.model = model
        self.emitter = ParticleEmitter(model: model,
                                       geometry: geometry,
                                       particleMass: solver.config.particleMass,
                                       maxParticles: solver.config.maxParticles)
        solver.clear()
        hideAllSpheres()
        elapsed = 0
        stopTime = model.decayTime(to: 0.15) + 6.0   // + settle time
        running = true
    }

    /// Step chemistry-driven emission, then SPH, then sync the spheres. Safe to
    /// call every frame; no-ops when not running.
    func update(dt: Float) {
        guard running, let emitter else { return }
        elapsed += Double(dt)
        // Drive the gas-expansion lift from the chemistry. While peroxide is
        // still producing O₂, push the whole interior column upward; stronger/
        // hotter recipes (higher model.rate) erupt harder. Once production ends,
        // lift drops to 0 and the foam falls, spreads, and pools — all via SPH.
        if let model {
            if elapsed < model.reactionDuration {
                let vigor = Float(min(2.0, max(0.4, model.rate / 0.345)))
                solver.gasLift = 12 + 6 * vigor                     // gentle → lifts as a body, doesn't fling apart
                let plume = Float(model.height(at: elapsed) / 100.0) // cm → m, chemistry-driven
                solver.liftCeiling = geometry.height + max(0.12, plume)
            } else {
                solver.gasLift = 0
                solver.liftCeiling = 0
            }
        }
        // 1. Chemistry decides how many new particles and how fast (new only).
        solver.add(emitter.newParticles(at: elapsed, currentCount: solver.count))

        // 2. SPH owns all motion from here on.
        solver.update(dt: dt)

        // 3. Mirror particle positions onto the sphere pool.
        syncSpheres()

        // 4. Freeze once foam has decayed and settled (leaves the puddle visible).
        if elapsed >= stopTime { running = false }
    }

    /// Stop and clear everything (Reset). Spheres are hidden and reused later.
    func reset() {
        running = false
        solver.clear()
        emitter = nil
        model = nil
        elapsed = 0
        hideAllSpheres()
    }

    // MARK: - Rendering

    private func syncSpheres() {
        let particles = solver.particles
        ensurePool(count: particles.count)
        for i in spherePool.indices {
            if i < particles.count {
                spherePool[i].isEnabled = true
                spherePool[i].position = particles[i].position
            } else {
                spherePool[i].isEnabled = false
            }
        }
    }

    /// Grow the sphere pool on demand, cloning a shared mesh + material.
    private func ensurePool(count: Int) {
        while spherePool.count < count {
            let sphere = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
            sphere.isEnabled = false
            container.addChild(sphere)
            spherePool.append(sphere)
        }
    }

    private func hideAllSpheres() { spherePool.forEach { $0.isEnabled = false } }
}
