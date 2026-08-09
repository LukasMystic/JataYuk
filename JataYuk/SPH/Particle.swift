//
//  Particle.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import simd

// A single SPH fluid particle.
//  • SPH models a fluid as a cloud of particles carrying mass and velocity.
//  • Density and pressure are recomputed from neighbours every substep, so they are scratch fields rather than persistent state.
struct Particle {
    // The foam container's local space (metres, y-up, floor at y = 0).
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var acceleration: SIMD3<Float> = .zero
    
    // Estimated density (kg/m³), recomputed each substep.
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
