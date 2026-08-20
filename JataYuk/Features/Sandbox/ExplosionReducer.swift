//
//  ExplosionReducer.swift
//  JataYuk
//
//  Pure phase / recipe transitions. No per-frame SPH fields.
//

import Foundation

func explosionReducer(
    state: inout ExplosionState,
    action: ExplosionAction,
    environment: ExplosionEnvironment
) -> [Effect] {
    switch action {

    case .volcanoStateChanged(let volcanoState):
        state.volcanoState = volcanoState
        return []

    case .pipelineStarted(let foamModel):
        guard state.phase == .idle else { return [] }
        state.volcanoState = .reacting
        state.phase = .settingUp
        state.foamModel = foamModel
        state.chemistry = nil
        state.foamResult = FoamResult()
        // Sync ECS setup runs in ExplosionStore.send (hybrid driver).
        return []

    case .setupCompleted(let chemistry):
        state.chemistry = chemistry
        state.foamResult = FoamResult(
            peakVolumeL: chemistry.peakVolumeL,
            peakHeightCm: chemistry.peakHeightCm,
            oxygenL: chemistry.oxygenL,
            reactionDuration: chemistry.reactionDuration,
            totalParticles: Double(chemistry.totalParticles)
        )
        state.phase = .emitting
        return []

    case .setupFailed:
        state.phase = .idle
        return []

    case .frameAdvanced(let emissionComplete, let settled):
        if settled {
            state.phase = .settled
        } else if emissionComplete, state.phase == .emitting {
            state.phase = .simulating
        }
        return []

    case .reset:
        state = ExplosionState()
        return [environment.effects.resetSimulation]
    }
}
