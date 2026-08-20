//
//  SPHSystem.swift
//  JataYuk
//
//  ECS system: GPU SPH motion + foam surface mesh → RealityKit.
//  Runs every frame while the foam pipeline is active.
//

import RealityKit
import UIKit

final class SPHSystem {

    private let gpuSolver: GPUSPHSolver
    private let surfaceBuilder = FoamSurfaceBuilder()
    private let surfaceEntity = ModelEntity()

    private let meshQueue = DispatchQueue(label: "com.jatayuk.foammesh", qos: .userInitiated)
    private var isMeshing = false
    private var meshGeneration = 0
    private var frameCounter = 0

    init(container: Entity, geometry: ContainerGeometry = ContainerGeometry()) {
        self.gpuSolver = GPUSPHSolver(config: SPHConfig(), geometry: geometry)
        container.addChild(surfaceEntity)
        surfaceEntity.isEnabled = false
    }

    var particleCount: Int { gpuSolver.count }
    var particles: [Particle] { gpuSolver.particles }

    func applyForces(from sph: SPHComponent) {
        gpuSolver.gasLift = sph.gasLift
        gpuSolver.liftCeiling = sph.liftCeiling
        gpuSolver.runtimeViscosity = sph.runtimeViscosity
        gpuSolver.runtimeCohesion = sph.runtimeCohesion
    }

    func addParticles(_ newParticles: [Particle]) {
        gpuSolver.add(newParticles)
    }

    /// Step 4 — move everything on the GPU (does not clear; accumulates across frames).
    func updatePhysics(deltaTime: Float) {
        guard gpuSolver.count > 0 else { return }
        gpuSolver.update(dt: min(deltaTime, ExplosionSandboxConstants.Loop.maxDeltaTime))
    }

    /// Steps 5–7 — Marching Cubes on background thread, upload mesh on main.
    func syncSurface() {
        frameCounter += 1
        guard frameCounter % ExplosionSandboxConstants.Surface.rebuildEvery == 0 else { return }
        guard !isMeshing else { return }
        guard gpuSolver.count >= ExplosionSandboxConstants.Surface.minParticlesForMesh else { return }

        let snapshot = gpuSolver.particles
        let gen = meshGeneration
        isMeshing = true

        meshQueue.async { [weak self] in
            guard let self else { return }
            let mesh = self.surfaceBuilder.buildMesh(from: snapshot)
            DispatchQueue.main.async {
                defer { self.isMeshing = false }
                guard gen == self.meshGeneration else { return }
                if let mesh {
                    self.surfaceEntity.model = ModelComponent(mesh: mesh, materials: [self.foamMaterial])
                    self.surfaceEntity.isEnabled = true
                }
            }
        }
    }

    func reset() {
        gpuSolver.clear()
        meshGeneration += 1
        isMeshing = false
        frameCounter = 0
        surfaceEntity.isEnabled = false
        surfaceEntity.model = nil
    }

    private var foamMaterial: RealityKit.Material = {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(white: 0.98, alpha: 1.0))
        mat.roughness = 0.55
        mat.metallic = 0.0
        mat.clearcoat = 0.3
        mat.faceCulling = .none
        return mat
    }()

    func setFoamColor(_ color: UIColor) {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: color)
        mat.roughness = 0.55
        mat.metallic = 0.0
        mat.clearcoat = 0.3
        mat.faceCulling = .none
        foamMaterial = mat
        if let model = surfaceEntity.model {
            surfaceEntity.model = ModelComponent(mesh: model.mesh, materials: [foamMaterial])
        }
    }
}
