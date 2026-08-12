//
//  FoamSPHSystem.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import RealityKit
import UIKit
import simd

// Bridges the SPH solver to RealityKit.
//  • Owns the solver, the emitter, and a growable pool of white sphere entities that visualise the particles.
//  • Drive it by calling `start(model:)` once, then `update(dt:)` every frame.

//  • The pool grows as particles are emitted (spreading allocation over the eruption instead of a 1000-entity hitch)
//  • and is reused across runs.
final class FoamSPHSystem {

    private let geometry: ContainerGeometry
    private let solver: GPUSPHSolver
    private var emitter: ParticleEmitter?
    private var chemistry: FoamChemistryResult?

    // Surface rendering: one mesh entity for the whole foam
    //  • rebuilt from the particles each frame via Marching Cubes (see FoamSurfaceBuilder).
    private let surfaceBuilder = FoamSurfaceBuilder()
    private let surfaceEntity = ModelEntity()
    private let surfaceMaterial: RealityKit.Material
    // Rebuild the (costly) surface mesh every N frames;
    //  • positions between rebuilds barely change at 60 fps, so this halves the meshing cost.
    private let rebuildEvery = ExplosionSandboxConstants.Surface.rebuildEvery
    private var frameCounter = 0
    // Background meshing: marching cubes runs off the main thread so it never
    // blocks rendering. Only one build runs at a time (isMeshing), and a
    // generation token drops stale builds after a reset/restart.
    private let meshQueue = DispatchQueue(label: "com.jatayuk.foammesh", qos: .userInitiated)
    private var isMeshing = false
    private var meshGeneration = 0

    private var elapsed: Double = 0
    private var running = false
    
    // Keep stepping a little past the chemistry decay so the puddle settles.
    private var stopTime: Double = .greatestFiniteMagnitude

    // - Parameters:
    //   - container: an Entity parented to the AR anchor at the vessel position.
    //   - geometry:  vessel radius/height used for emission and collisions.
    init(container: Entity, geometry: ContainerGeometry) {
        self.geometry = geometry
        self.solver = GPUSPHSolver(config: SPHSolver.Config(), geometry: geometry)

        // White, matte foam skin with a faint wet sheen. faceCulling = .none
        //  • so the open underside of the blob (at the floor) never shows holes.
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

    // Begin a run for the given chemistry model. Clears any previous particles.
    func start(model: FoamModel) {
        self.chemistry = FoamChemistry.calculate(from: model)
        self.emitter = ParticleEmitter(model: model,
                                       geometry: geometry,
                                       particleMass: solver.config.particleMass,
                                       maxParticles: solver.config.maxParticles,
                                       gravity: -solver.config.gravity.y)   // sim gravity → realistic launch
        solver.clear()
        solver.runtimeViscosity = solver.config.viscosity   // reset thickness for the new run
        solver.runtimeCohesion = solver.config.cohesion
        surfaceEntity.isEnabled = false
        frameCounter = 0
        meshGeneration += 1   // invalidate any in-flight background mesh
        elapsed = 0
        stopTime = chemistry?.stopTime ?? .greatestFiniteMagnitude
        running = true
    }

    // Step chemistry-driven emission, then SPH, then sync the spheres. Safe to call every frame; no-ops when not running.
    func update(dt: Float) {
        guard running, let emitter else { return }
        elapsed += Double(dt)
        // Drive the gas-expansion lift from the chemistry.
        //  • While peroxide is still producing O₂, push the whole interior column upward;
        //  • stronger/hotter recipes (higher chemistry rate) erupt harder.
        //  • Once production ends, lift drops to 0 and the foam falls, spreads, and pools — all via SPH.
        if let chemistry {
            // Reaction length is set by the CATALYST only (emitter.emissionDuration), not by the amount of peroxide.
            let duration = emitter.emissionDuration
            if elapsed < duration {
                // Lift scales with the catalyst (vigor), with NO high floor:
                //  • weak recipes barely lift → foam just wells up and overflows the rim sideways;
                //  • strong recipes get a forceful upward beam.
                let vigor = Float(min(
                    Double(ExplosionSandboxConstants.SPH.vigorCap),
                    chemistry.rate / ExplosionSandboxConstants.SPH.referenceModelRate
                ))
                solver.gasLift = ExplosionSandboxConstants.SPH.gasLiftBase
                    + ExplosionSandboxConstants.SPH.gasLiftScale * vigor
                // Absolute foam height from the floor.
                //  • Weak recipes (foam below the rim) are floored to just over the rim
                //  • so they gently OVERFLOW instead of shooting;
                //  • strong recipes reach full height.
                let plume = Float(chemistry.peakHeightCm / 100.0)
                solver.liftCeiling = max(
                    geometry.height + ExplosionSandboxConstants.SPH.rimOverflowPadding,
                    plume
                )
            } else {
                solver.gasLift = 0
                solver.liftCeiling = 0
            }

            // Time-based rheology: thick early so the foam STACKS into a mound,
            //  • then gradually thinner so it slowly OOZES to the sides.
            //  • Starts after the eruption and eases over `relaxSpan`.
            let relaxSpan = ExplosionSandboxConstants.SPH.rheologyRelaxSpan
            let k = Float(max(0, min(1, (elapsed - duration) / relaxSpan)))
            solver.runtimeCohesion = solver.config.cohesion
                * (1 - ExplosionSandboxConstants.SPH.rheologyCohesionFade * k)
            solver.runtimeViscosity = solver.config.viscosity
                * (1 - ExplosionSandboxConstants.SPH.rheologyViscosityFade * k)
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

    // Stop and clear everything (Reset).
    func reset() {
        running = false
        solver.clear()
        emitter = nil
        chemistry = nil
        elapsed = 0
        meshGeneration += 1   // invalidate any in-flight background mesh
        surfaceEntity.isEnabled = false
    }

    // MARK: - Rendering

    // Regenerate the single foam mesh from the current particle cloud.
    //  • Marching Cubes turns the overlapping particle "bumps" into one connected surface.
    private func syncSurface() {
        guard !isMeshing else { return }         // previous build still running — skip this frame
        let snapshot = solver.particles          // value-type (COW) snapshot, safe for the bg thread
        guard snapshot.count >= 4 else { return }
        let gen = meshGeneration
        isMeshing = true
        meshQueue.async { [weak self] in
            guard let self else { return }
            let mesh = self.surfaceBuilder.buildMesh(from: snapshot)   // heavy work, off main
            DispatchQueue.main.async {
                defer { self.isMeshing = false }
                guard gen == self.meshGeneration else { return }       // stale (reset/restart) — drop it
                if let mesh {
                    self.surfaceEntity.model = ModelComponent(mesh: mesh, materials: [self.surfaceMaterial])
                    self.surfaceEntity.isEnabled = true
                }
            }
        }
    }
}
