//
//  ExplosionReducer.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import Foundation
func explosionReducer(
    state: inout ExplosionState,
    action: ExplosionAction,
    environment: ExplosionEnvironment
) -> [Effect] {
    switch action {
    // MARK: - Volcano gate (EmissionSystem only runs when reacting)
    case .volcanoStateChanged(let volcanoState):
        state.volcanoState = volcanoState
        switch volcanoState {
        case .reacting where state.phase == .idle:
            // Fetch FoamModel from experiment and kick off pipeline
            return [environment.effects.startPipeline(state.foamModel)]
        case .done where state.isRunning:
            return [environment.effects.stopFrameLoop]
        default:
            return []
        }
    case .pipelineStarted(let foamModel):
        guard state.volcanoState == .reacting else { return [] }
        state.phase = .settingUp
        state.foamModel = foamModel
        state.elapsedTime = 0
        state.isRunning = false
        state.particleCount = 0
        // Effect runs chemistry + builds ParticleEmitter in ECS world
        return [environment.effects.runSetup(foamModel)]
    case .setupCompleted(let chemistry):
        state.chemistry = chemistry
        state.emissionDuration = chemistry.emissionDuration
        state.totalParticles = chemistry.totalParticles
        state.stopTime = chemistry.stopTime
        state.foamResult = FoamResult(
            peakVolumeL: chemistry.peakVolumeL,
            peakHeightCm: chemistry.peakHeightCm,
            oxygenL: chemistry.oxygenL,
            reactionDuration: chemistry.reactionDuration,
            totalParticles: Double(chemistry.totalParticles)
        )
        state.phase = .emitting
        state.isRunning = true
        return [environment.effects.startFrameLoop]
    case .setupFailed:
        state.phase = .idle
        state.isRunning = false
        return []
    // MARK: - Loop (steps 1–7 from your diagram)
    case .tick(let dt):
        guard state.isRunning, state.volcanoState == .reacting || state.phase == .simulating else {
            return []
        }
        let newElapsed = state.elapsedTime + Double(dt)
        var effects: [Effect] = []
        // 1. Advance clock
        state.elapsedTime = newElapsed
        // 2. Chemistry sets forces for this frame
        if let chemistry = state.chemistry {
            let forces = FoamChemistry.frameForces(
                elapsed: newElapsed,
                emissionDuration: state.emissionDuration,
                peakHeightCm: chemistry.peakHeightCm,
                rate: chemistry.rate,
                baseViscosity: ExplosionSandboxConstants.SPH.viscosity,
                baseCohesion: ExplosionSandboxConstants.SPH.cohesion
            )
            state.gasLift = forces.gasLift
            state.liftCeiling = forces.liftCeiling
            state.runtimeViscosity = forces.viscosity
            state.runtimeCohesion = forces.cohesion
        }
        // 3–7 delegated to ECS via effect (emit → SPH → mesh → RealityKit)
        effects.append(environment.effects.runSimulationStep(
            dt,
            SimulationForces(
                gasLift: state.gasLift,
                liftCeiling: state.liftCeiling,
                viscosity: state.runtimeViscosity,
                cohesion: state.runtimeCohesion
            ),
            newElapsed,
            state.emissionDuration
        ))
        // Phase transition: emission window closed, still simulating
        if newElapsed >= state.emissionDuration, state.phase == .emitting {
            state.phase = .simulating
        }
        // 4. Stop when foam has decayed + settle padding
        if newElapsed >= state.stopTime {
            state.isRunning = false
            state.phase = .settled
            effects.append(environment.effects.stopFrameLoop)
        }
        return effects
    case .particlesUpdated(let count):
        state.particleCount = count
        return []
    case .reset:
        state = ExplosionState()
        return [environment.effects.resetSimulation]
    }
}
