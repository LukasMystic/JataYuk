//
//  ExplosionSimulationClient.swift
//  JataYuk
//

import RealityKit

extension ExplosionSimulationClient {

    static func live(
        foamEntity: Entity,
        emissionSystem: EmissionSystem,
        sphSystem: SPHSystem
    ) -> ExplosionSimulationClient {
        ExplosionSimulationClient(
            setup: { model in
                sphSystem.reset()
                let (chemistry, sph) = emissionSystem.setup(foamEntity: foamEntity, model: model)
                sphSystem.applyForces(from: sph)
                return chemistry
            },
            step: { dt, volcanoState in
                guard var foam = foamEntity.components[FoamComponent.self],
                      foam.isRunning,
                      var sph = foamEntity.components[SPHComponent.self],
                      let chemistry = foam.chemistry
                else {
                    return SimulationFrameResult(emissionComplete: true, settled: true)
                }

                // 1. Advance clock (ECS owns elapsed)
                foam.elapsedTime += Double(dt)

                // 2. Chemistry → SPHComponent forces
                let forces = FoamChemistry.frameForces(
                    elapsed: foam.elapsedTime,
                    emissionDuration: sph.emissionDuration,
                    peakHeightCm: chemistry.peakHeightCm,
                    rate: chemistry.rate,
                    baseViscosity: ExplosionSandboxConstants.SPH.viscosity,
                    baseCohesion: ExplosionSandboxConstants.SPH.cohesion
                )
                sph.gasLift = forces.gasLift
                sph.liftCeiling = forces.liftCeiling
                sph.runtimeViscosity = forces.viscosity
                sph.runtimeCohesion = forces.cohesion
                foamEntity.components[SPHComponent.self] = sph
                foamEntity.components[FoamComponent.self] = foam
                sphSystem.applyForces(from: sph)

                // 3. Emit
                _ = emissionSystem.emit(
                    foamEntity: foamEntity,
                    volcanoState: volcanoState,
                    into: sphSystem
                )

                // 4–7. Physics + mesh
                sphSystem.updatePhysics(deltaTime: dt)
                sphSystem.syncSurface()

                // Settle
                let elapsed = foamEntity.components[FoamComponent.self]?.elapsedTime ?? foam.elapsedTime
                let stopTime = foamEntity.components[FoamComponent.self]?.stopTime ?? foam.stopTime
                let emissionDuration = foamEntity.components[SPHComponent.self]?.emissionDuration
                    ?? sph.emissionDuration

                if elapsed >= stopTime, var foamEnd = foamEntity.components[FoamComponent.self] {
                    foamEnd.isRunning = false
                    foamEntity.components[FoamComponent.self] = foamEnd
                }

                return SimulationFrameResult(
                    emissionComplete: elapsed >= emissionDuration,
                    settled: elapsed >= stopTime
                )
            },
            reset: {
                sphSystem.reset()
                emissionSystem.clear(foamEntity: foamEntity)
            }
        )
    }
}
