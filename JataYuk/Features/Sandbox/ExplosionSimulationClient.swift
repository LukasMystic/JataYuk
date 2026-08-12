//
//  ExplosionSimulationClient.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import RealityKit
extension ExplosionSimulationClient {
    static func live(
        foamEntity: Entity,
        volcanoEntity: Entity,
        emissionSystem: EmissionSystem,
        sphSystem: SPHSystem
    ) -> ExplosionSimulationClient {
        ExplosionSimulationClient(
            setup: { model in
                let (chemistry, sph) = emissionSystem.setup(foamEntity: foamEntity, model: model)
                sphSystem.applyForces(from: sph)
                return chemistry
            },
            step: { dt, forces, elapsed, emissionDuration in
                // Write forces into ECS component
                if var sph = foamEntity.components[SPHComponent.self] {
                    sph.gasLift = forces.gasLift
                    sph.liftCeiling = forces.liftCeiling
                    sph.runtimeViscosity = forces.viscosity
                    sph.runtimeCohesion = forces.cohesion
                    sph.emissionDuration = emissionDuration
                    foamEntity.components[SPHComponent.self] = sph
                    sphSystem.applyForces(from: sph)
                }
                // EmissionSystem only emits when volcano is reacting
                // (pass a no-op spawn if you manage particles purely in GPU buffer)
                // emissionSystem.update(...)
                // Collect particles from physics bodies → GPU
                let particles = foamEntity.children.compactMap { child -> Particle? in
                    guard let body = child.components[FoamParticlePhysicsComponent.self] else { return nil }
                    return Particle(
                        position: body.position,
                        velocity: body.velocity,
                        mass: body.mass
                    )
                }
                sphSystem.updatePhysics(deltaTime: dt, particles: particles)
                sphSystem.syncSurface(from: sphSystem.particles)
                // Write GPU results back to native components
                for (child, particle) in zip(foamEntity.children, sphSystem.particles) {
                    guard var body = child.components[FoamParticlePhysicsComponent.self] else { continue }
                    body.position = particle.position
                    body.velocity = particle.velocity
                    body.density = particle.density
                    body.pressure = particle.pressure
                    child.components[FoamParticlePhysicsComponent.self] = body
                    child.transform.translation = particle.position
                }
                return sphSystem.particles.count
            },
            reset: {
                sphSystem.reset()
                foamEntity.components.remove(FoamComponent.self)
                foamEntity.components.remove(SPHComponent.self)
            }
        )
    }
}
