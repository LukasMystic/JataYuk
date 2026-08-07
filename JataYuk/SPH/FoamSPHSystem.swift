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

    // Surface rendering: one mesh entity for the whole foam, rebuilt from the
    // particles each frame via Marching Cubes (see FoamSurfaceBuilder).
    private let surfaceBuilder = FoamSurfaceBuilder()
    private let surfaceEntity = ModelEntity()
    private let surfaceMaterial: RealityKit.Material
    /// Rebuild the (costly) surface mesh every N frames; positions between
    /// rebuilds barely change at 60 fps, so this halves the meshing cost.
    private let rebuildEvery = 2
    private var frameCounter = 0

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

        // White, matte foam skin with a faint wet sheen. faceCulling = .none so
        // the open underside of the blob (at the floor) never shows holes.
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(white: 0.98, alpha: 1.0))
        mat.roughness = 0.55
        mat.metallic = 0.0
        mat.clearcoat = 0.3
        mat.faceCulling = .none
        surfaceMaterial = mat

        surfaceEntity.isEnabled = false
        container.addChild(surfaceEntity)
    }

    /// Begin a run for the given chemistry model. Clears any previous particles.
    func start(model: FoamModel) {
        self.model = model
        self.emitter = ParticleEmitter(model: model,
                                       geometry: geometry,
                                       particleMass: solver.config.particleMass,
                                       maxParticles: solver.config.maxParticles)
        solver.clear()
        solver.runtimeViscosity = solver.config.viscosity   // reset thickness for the new run
        solver.runtimeCohesion = solver.config.cohesion
        surfaceEntity.isEnabled = false
        frameCounter = 0
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
                solver.liftCeiling = geometry.height + max(0.25, plume)
            } else {
                solver.gasLift = 0
                solver.liftCeiling = 0
            }

            // Time-based rheology: thick early so the foam STACKS into a mound,
            // then gradually thinner so it slowly OOZES to the sides. Starts
            // after the eruption (reactionDuration) and eases over `relaxSpan`.
            let relaxSpan = 12.0
            let k = Float(max(0, min(1, (elapsed - model.reactionDuration) / relaxSpan)))
            solver.runtimeCohesion  = solver.config.cohesion  * (1 - 0.20 * k)  // stays thick → keeps stacking
            solver.runtimeViscosity = solver.config.viscosity * (1 - 0.20 * k)  // only slightly runnier
        }
        // 1. Chemistry decides how many new particles and how fast (new only).
        solver.add(emitter.newParticles(at: elapsed, currentCount: solver.count))

        // 2. SPH owns all motion from here on.
        solver.update(dt: dt)

        // 3. Rebuild the foam surface mesh from the particles (throttled).
        frameCounter += 1
        if frameCounter % rebuildEvery == 0 { syncSurface() }

        // 4. Freeze once foam has decayed and settled (leaves the puddle visible).
        if elapsed >= stopTime { running = false }
    }

    /// Stop and clear everything (Reset).
    func reset() {
        running = false
        solver.clear()
        emitter = nil
        model = nil
        elapsed = 0
        surfaceEntity.isEnabled = false
    }

    // MARK: - Rendering

    /// Regenerate the single foam mesh from the current particle cloud. Marching
    /// Cubes turns the overlapping particle "bumps" into one connected surface.
    private func syncSurface() {
        guard let mesh = surfaceBuilder.buildMesh(from: solver.particles) else {
            return   // keep the last surface instead of blinking off
        }
        surfaceEntity.model = ModelComponent(mesh: mesh, materials: [surfaceMaterial])
        surfaceEntity.isEnabled = true
    }
}
