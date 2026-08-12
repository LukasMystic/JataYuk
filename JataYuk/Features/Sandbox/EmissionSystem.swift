//
//  EmissionSystem.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import RealityKit
import simd
// ERD: queries VolcanoComponent + FoamComponent.
// Setup: build FoamModel → chemistry → ParticleEmitter config.
// Update: only when volcanoState == .reacting → spawn particles.
final class EmissionSystem {
    private let geometry = ContainerGeometry(
        radius: ExplosionSandboxConstants.Container.radius,
        height: ExplosionSandboxConstants.Container.height
    )
    // One-time setup when pipeline starts
    func setup(
        foamEntity: Entity,
        model: FoamModel
    ) -> (chemistry: FoamChemistryResult, sph: SPHComponent) {
        let chemistry = FoamChemistry.calculate(from: model)
        var foam = FoamComponent(
            foamModel: model,
            foamResult: FoamResult(
                peakVolumeL: chemistry.peakVolumeL,
                peakHeightCm: chemistry.peakHeightCm,
                oxygenL: chemistry.oxygenL,
                reactionDuration: chemistry.reactionDuration,
                totalParticles: Double(chemistry.totalParticles)
            ),
            chemistry: chemistry,
            stopTime: chemistry.stopTime,
            isRunning: true
        )
        foamEntity.components[FoamComponent.self] = foam
        let sph = SPHComponent(
            emissionDuration: chemistry.emissionDuration,
            runtimeViscosity: ExplosionSandboxConstants.SPH.viscosity,
            runtimeCohesion: ExplosionSandboxConstants.SPH.cohesion,
            totalParticles: chemistry.totalParticles
        )
        foamEntity.components[SPHComponent.self] = sph
        return (chemistry, sph)
    }
    // Step 3 from your diagram — called each frame while reacting
    func update(
        context: SceneUpdateContext,
        foamEntity: Entity,
        volcanoEntity: Entity,
        spawnParticle: (ParticleSpawn) -> Entity
    ) {
        guard
            let volcano = volcanoEntity.components[VolcanoComponent.self],
            volcano.state == .reacting,
            var foam = foamEntity.components[FoamComponent.self],
            var sph = foamEntity.components[SPHComponent.self],
            let chemistry = foam.chemistry,
            foam.isRunning
        else { return }
        let dt = Float(context.deltaTime)
        foam.elapsedTime += Double(dt)
        foamEntity.components[FoamComponent.self] = foam
        // Target count rises linearly over emissionDuration
        let progress = min(1.0, foam.elapsedTime / sph.emissionDuration)
        let target = Int(Double(sph.totalParticles) * progress)
        guard target > sph.particleCount else { return }
        let container = geometry
        let aboveRim = Float(chemistry.peakHeightCm / 100.0) - container.height
        let launchH = max(ExplosionSandboxConstants.Emitter.minLaunchHeight, aboveRim)
        let gravity = abs(ExplosionSandboxConstants.SPH.gravity.y)
        let launch = (2 * gravity * launchH).squareRoot()
            * ExplosionSandboxConstants.Emitter.launchVelocityScale
        for _ in sph.particleCount..<target {
            let spawn = makeSpawn(launchSpeed: launch, geometry: container)
            let entity = spawnParticle(spawn)
            entity.components[FoamParticlePhysicsComponent.self] = FoamParticlePhysicsComponent(
                position: spawn.position,
                velocity: spawn.velocity,
                mass: ExplosionSandboxConstants.SPH.particleMass
            )
        }
        sph.particleCount = target
        foamEntity.components[SPHComponent.self] = sph
    }
    // MARK: - Spawn helpers
    struct ParticleSpawn {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
    }
    private func makeSpawn(launchSpeed: Float, geometry: ContainerGeometry) -> ParticleSpawn {
        let angle = Float.random(in: 0..<(2 * .pi))
        let rr = geometry.radius
            * ExplosionSandboxConstants.Emitter.spawnRadiusFactor
            * sqrt(Float.random(in: 0...1))
        let y = geometry.height - Float.random(in: 0...ExplosionSandboxConstants.Emitter.spawnBelowRimMax)
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
