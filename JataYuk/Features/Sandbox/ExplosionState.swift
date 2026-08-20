//
//  ExplosionState.swift
//  JataYuk
//
//  TCA orchestration state only.
//  Live sim fields (elapsed, forces, particle counts) live on ECS components.
//

import Foundation

enum ExplosionPhase: Equatable {
    case idle
    case settingUp
    case emitting
    case simulating
    case settled
}

struct ExplosionState: Equatable {
    var phase: ExplosionPhase = .idle
    /// Mirror of the volcano gate (also on VolcanoComponent).
    var volcanoState: VolcanoState = .locked
    /// Recipe inputs from the experiment.
    var foamModel: FoamModel = FoamModel()
    /// Summary after chemistry setup (UI / tests).
    var foamResult: FoamResult = FoamResult()
    var chemistry: FoamChemistryResult?
}
