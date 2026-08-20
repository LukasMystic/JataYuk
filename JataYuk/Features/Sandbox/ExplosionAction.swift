//
//  ExplosionAction.swift
//  JataYuk
//

import Foundation

enum ExplosionAction: Equatable {
    /// Sync volcano gate with root experiment / VolcanoComponent.
    case volcanoStateChanged(VolcanoState)
    /// Start pipeline with recipe inputs when volcano becomes reacting.
    case pipelineStarted(FoamModel)
    case setupCompleted(FoamChemistryResult)
    case setupFailed
    /// Phase-only update after a sync ECS frame (hybrid driver).
    case frameAdvanced(emissionComplete: Bool, settled: Bool)
    case reset
}
