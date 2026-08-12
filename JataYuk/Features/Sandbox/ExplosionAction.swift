//
//  ExplosionAction.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import Foundation
enum ExplosionAction: Equatable {
    // Called by RootReducer when experiment.volcanoState changes
    case volcanoStateChanged(VolcanoState)
    // Pipeline entry — fetch FoamModel when volcano becomes .reacting
    case pipelineStarted(FoamModel)
    // Effect callbacks
    case setupCompleted(FoamChemistryResult)
    case setupFailed
    // Frame loop (from ExplosionEffect tick)
    case tick(deltaTime: Float)
    case particlesUpdated(count: Int)
    case reset
}
