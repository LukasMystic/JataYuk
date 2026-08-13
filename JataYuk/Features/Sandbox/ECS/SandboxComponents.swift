//
//  SandboxComponents.swift
//  JataYuk
//
//  ECS components for the explosion / foam pipeline.
//

import RealityKit
import simd

// Attached to the volcano entity. EmissionSystem gates on `.reacting`.
struct VolcanoComponent: Component {
    var state: VolcanoState = .locked
}

// Attached to the foam container entity — high-level sim bookkeeping.
struct FoamComponent: Component {
    var foamModel: FoamModel
    var foamResult: FoamResult = FoamResult()
    var chemistry: FoamChemistryResult?
    var elapsedTime: Double = 0
    var stopTime: Double = .greatestFiniteMagnitude
    var isRunning: Bool = false
}

// Per-frame SPH drivers written by chemistry / TCA, read by SPHSystem.
struct SPHComponent: Component {
    var emissionDuration: Double = 0
    var gasLift: Float = 0
    var liftCeiling: Float = 0
    var runtimeViscosity: Float = ExplosionSandboxConstants.SPH.viscosity
    var runtimeCohesion: Float = ExplosionSandboxConstants.SPH.cohesion
    var totalParticles: Int = 0
    var particleCount: Int = 0
}

struct Particle: Component, Equatable {
    // Foam container local space (metres, y-up, floor at y = 0).
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var acceleration: SIMD3<Float> = .zero

    // Estimated density (kg/m³), recomputed each SPH substep.
    var density: Float = 0
    // Pressure from the equation of state (Pa).
    var pressure: Float = 0
    // Constant particle mass (kg).
    var mass: Float

    init(position: SIMD3<Float>, velocity: SIMD3<Float>, mass: Float) {
        self.position = position
        self.velocity = velocity
        self.mass = mass
    }
}
