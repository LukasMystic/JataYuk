//
//  SPHSystem.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import RealityKit
import UIKit

// ERD: queries FoamComponent (+ all FoamParticlePhysicsComponent children).
// Runs every frame while foam.isRunning.
final class SPHSystem {

    // Inject your existing BoomPoC types here
    private let gpuSolver: GPUSPHSolver
    private let surfaceBuilder = FoamSurfaceBuilder()
    private let surfaceEntity = ModelEntity()

    private let meshQueue = DispatchQueue(label: "com.jatayuk.foammesh", qos: .userInitiated)
    private var isMeshing = false
    private var meshGeneration = 0
    private var frameCounter = 0

    init(container: Entity, geometry: ContainerGeometry) {
        self.gpuSolver = GPUSPHSolver(
            config: SPHSolver.Config(),
            geometry: geometry
        )
        container.addChild(surfaceEntity)
        surfaceEntity.isEnabled = false
    }

    func applyForces(from sph: SPHComponent) {
        gpuSolver.gasLift = sph.gasLift
        gpuSolver.liftCeiling = sph.liftCeiling
        gpuSolver.runtimeViscosity = sph.runtimeViscosity
        gpuSolver.runtimeCohesion = sph.runtimeCohesion
    }

    // Step 4 — move everything (GPU)
    func updatePhysics(deltaTime: Float, particles: [Particle]) {
        guard !particles.isEmpty else { return }
        gpuSolver.clear()
        gpuSolver.add(particles)
        gpuSolver.update(dt: min(deltaTime, ExplosionSandboxConstants.Loop.maxDeltaTime))
    }

    // Steps 5–6 — surface on background thread, upload on main
    func syncSurface(from solverParticles: [Particle]) {
        frameCounter += 1
        guard frameCounter % ExplosionSandboxConstants.Surface.rebuildEvery == 0 else { return }
        guard !isMeshing else { return }
        guard solverParticles.count >= ExplosionSandboxConstants.Surface.minParticlesForMesh else { return }

        let snapshot = solverParticles
        let gen = meshGeneration
        isMeshing = true

        meshQueue.async { [weak self] in
            guard let self else { return }
            let mesh = self.surfaceBuilder.buildMesh(from: snapshot)
            DispatchQueue.main.async {
                defer { self.isMeshing = false }
                guard gen == self.meshGeneration else { return }
                if let mesh {
                    // Step 6: hand mesh to RealityKit
                    self.surfaceEntity.model = ModelComponent(mesh: mesh, materials: [Self.foamMaterial])
                    self.surfaceEntity.isEnabled = true
                    // Step 7: RealityKit draws it automatically next frame
                }
            }
        }
    }

    func reset() {
        gpuSolver.clear()
        meshGeneration += 1
        surfaceEntity.isEnabled = false
    }

    var particles: [Particle] { gpuSolver.particles }

    private static var foamMaterial: RealityKit.Material = {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: .init(white: 0.98, alpha: 1.0))
        mat.roughness = 0.55
        mat.metallic = 0.0
        mat.clearcoat = 0.3
        mat.faceCulling = .none
        return mat
    }()
}
