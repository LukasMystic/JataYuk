//
//  EmissionSystem.swift
//  JataYuk
//
//  ECS system: chemistry setup + particle emission.
//  Emission only while volcanoState == .reacting.
//  Clock lives on FoamComponent (advanced by the simulation client).
//

import RealityKit
import simd

final class EmissionSystem {

    private let geometry = ContainerGeometry()

    @discardableResult
    func setup(foamEntity: Entity, model: FoamModel) -> (chemistry: FoamChemistryResult, sph: SPHComponent) {
        let chemistry = FoamChemistry.calculate(from: model)

        foamEntity.components[FoamComponent.self] = FoamComponent(
            foamModel: model,
            foamResult: FoamResult(
                peakVolumeL: chemistry.peakVolumeL,
                peakHeightCm: chemistry.peakHeightCm,
                oxygenL: chemistry.oxygenL,
                reactionDuration: chemistry.reactionDuration,
                totalParticles: Double(chemistry.totalParticles)
            ),
            chemistry: chemistry,
            elapsedTime: 0,
            stopTime: chemistry.stopTime,
            isRunning: true
        )

        let sph = SPHComponent(
            emissionDuration: chemistry.emissionDuration,
            gasLift: 0,
            liftCeiling: 0,
            runtimeViscosity: ExplosionSandboxConstants.SPH.viscosity,
            runtimeCohesion: ExplosionSandboxConstants.SPH.cohesion,
            totalParticles: chemistry.totalParticles,
            particleCount: 0
        )
        foamEntity.components[SPHComponent.self] = sph
        return (chemistry, sph)
    }

    /// Step 3 — spawn into SPHSystem from FoamComponent.elapsedTime.
    @discardableResult
    func emit(
        foamEntity: Entity,
        volcanoState: VolcanoState,
        into sphSystem: SPHSystem
    ) -> Int {
        guard volcanoState == .reacting,
              let foam = foamEntity.components[FoamComponent.self],
              var sph = foamEntity.components[SPHComponent.self],
              let chemistry = foam.chemistry,
              foam.isRunning
        else { return sphSystem.particleCount }

        let progress = min(1.0, foam.elapsedTime / max(sph.emissionDuration, 0.001))
        let target = Int(Double(sph.totalParticles) * progress)
        guard target > sph.particleCount else { return sph.particleCount }

        let aboveRim = Float(chemistry.peakHeightCm / 100.0) - geometry.height
        let launchH = max(ExplosionSandboxConstants.Emitter.minLaunchHeight, aboveRim)
        let gravity = abs(ExplosionSandboxConstants.SPH.gravity.y)
        let launch = (2 * gravity * launchH).squareRoot()
            * ExplosionSandboxConstants.Emitter.launchVelocityScale

        var spawned: [Particle] = []
        spawned.reserveCapacity(target - sph.particleCount)
        for _ in sph.particleCount..<target {
            let spawn = makeSpawn(launchSpeed: launch)
            spawned.append(
                Particle(
                    position: spawn.position,
                    velocity: spawn.velocity,
                    mass: ExplosionSandboxConstants.SPH.particleMass
                )
            )
        }

        sphSystem.addParticles(spawned)
        sph.particleCount = target
        foamEntity.components[SPHComponent.self] = sph
        return sph.particleCount
    }

    func clear(foamEntity: Entity) {
        foamEntity.components.remove(FoamComponent.self)
        foamEntity.components.remove(SPHComponent.self)
    }

    private struct ParticleSpawn {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
    }

    private func makeSpawn(launchSpeed: Float) -> ParticleSpawn {
        let angle = Float.random(in: 0..<(2 * .pi))
        let rr = geometry.radius
            * ExplosionSandboxConstants.Emitter.spawnRadiusFactor
            * sqrt(Float.random(in: 0...1))
        let y = geometry.height
            - Float.random(in: 0...ExplosionSandboxConstants.Emitter.spawnBelowRimMax)
        let position = SIMD3<Float>(rr * cos(angle), y, rr * sin(angle))
        let spread = ExplosionSandboxConstants.Emitter.velocitySpread
        let velocity = SIMD3<Float>(
            Float.random(in: -spread...spread) * launchSpeed,
            launchSpeed,
            Float.random(in: -spread...spread) * launchSpeed
        )
        return ParticleSpawn(position: position, velocity: velocity)
    }
}
