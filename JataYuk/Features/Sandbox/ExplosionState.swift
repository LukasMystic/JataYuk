//
//  ExplosionState.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import Foundation
enum ExplosionPhase: Equatable {
    case idle
    case settingUp      // chemistry + emitter being built
    case emitting       // volcano reacting, particles spawning
    case simulating     // emission ended, SPH still settling foam
    case settled        // puddle visible, loop stopped
}
struct ExplosionState: Equatable {
    var phase: ExplosionPhase = .idle
    var volcanoState: VolcanoState = .locked
    // Mirrors FoamComponent (TCA owns orchestration; ECS owns runtime entities)
    var foamModel: FoamModel = FoamModel()
    var foamResult: FoamResult = FoamResult()
    var chemistry: FoamChemistryResult?
    var elapsedTime: Double = 0
    var stopTime: Double = .greatestFiniteMagnitude
    var isRunning: Bool = false
    // Mirrors SPHComponent (visible in tests / debug UI)
    var emissionDuration: Double = 0
    var gasLift: Float = 0
    var liftCeiling: Float = 0
    var runtimeViscosity: Float = ExplosionSandboxConstants.SPH.viscosity
    var runtimeCohesion: Float = ExplosionSandboxConstants.SPH.cohesion
    var particleCount: Int = 0
    var totalParticles: Int = 0
}
