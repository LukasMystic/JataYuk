//
//  SandboxComponents.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import RealityKit
import simd

// ERD: attached to the volcano anchor entity.
// EmissionSystem queries this to gate on `.reacting`.
struct VolcanoComponent: Component {
    var state: VolcanoState = .locked
}

// ERD: FoamEntity — high-level simulation bookkeeping.
struct FoamComponent: Component {
    var foamModel: FoamModel
    var foamResult: FoamResult = FoamResult()
    var chemistry: FoamChemistryResult?
    var elapsedTime: Double = 0
    var stopTime: Double = .greatestFiniteMagnitude
    var isRunning: Bool = false
}

// ERD: per-frame force drivers written by chemistry, read by SPHSystem.
struct SPHComponent: Component {
    var emissionDuration: Double = 0
    var gasLift: Float = 0
    var liftCeiling: Float = 0
    var runtimeViscosity: Float = ExplosionSandboxConstants.SPH.viscosity
    var runtimeCohesion: Float = ExplosionSandboxConstants.SPH.cohesion
    var totalParticles: Int = 0
    var particleCount: Int = 0
}

// ERD name: PhysicsBodyComponent
// Stores native-friendly kinematic state per particle entity.
// SPHSystem writes these; you sync `position` → ModelEntity.transform each frame.
struct FoamParticlePhysicsComponent: Component {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var acceleration: SIMD3<Float> = .zero
    var density: Float = 0
    var pressure: Float = 0
    var mass: Float
    init(position: SIMD3<Float>, velocity: SIMD3<Float>, mass: Float) {
        self.position = position
        self.velocity = velocity
        self.mass = mass
    }
}
