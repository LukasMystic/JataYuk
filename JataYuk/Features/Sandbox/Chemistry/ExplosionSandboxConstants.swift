//
//  ExplosionSandboxConstants.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import Foundation
import simd
enum ExplosionSandboxConstants {
    // MARK: - Chemistry calibration (BoomPoC fitted values)
    enum Chemistry {
        static let rateRef: Double = 0.345
        static let pileAspect: Double = 2.34
        static let soapCeiling: Double = 0.85
        static let soapHalf: Double = 0.21
        static let yeastHalf: Double = 0.8
        static let yeastCeiling: Double = 1.8
        static let halfLifeRef: Double = 40.0
        static let halfLifeExp: Double = 0.45
        static let baseDuration: Double = 6.9
        static let tempFloorFactor: Double = 0.05
        static let stoichiometryFactor: Double = 3.59   // O₂ litres per % × L H₂O₂
        static let liquidSoapCoeff: Double = 0.015
        static let liquidBaseL: Double = 0.045
    }
    // MARK: - Vessel geometry (metres, floor at y = 0)
    enum Container {
        static let radius: Float = 0.041
        static let height: Float = 0.146
        static var volumeLitres: Double {
            Double(Float.pi * radius * radius * height) * 1000.0
        }
    }
    // MARK: - Particle emitter
    enum Emitter {
        static let litresPerParticle: Double = 0.005
        static let baseEmissionSeconds: Double = 10.0
        static let referenceRate: Double = 0.5
        static let launchVelocityScale: Float = 1.0
        static let minEmissionDuration: Double = 2.0
        static let maxEmissionDuration: Double = 15.0
        static let velocitySpread: Float = 0.04
        static let spawnRadiusFactor: Float = 0.85
        static let spawnBelowRimMax: Float = 0.04
        static let minLaunchHeight: Float = 0.02
    }
    // MARK: - SPH solver (GPU + CPU mirror)
    enum SPH {
        static let smoothingRadius: Float = 0.022
        static let particleMass: Float = 0.0016
        static let restDensity: Float = 1000
        static let stiffness: Float = 30
        static let viscosity: Float = 12
        static let cohesion: Float = 6.0
        static let xsph: Float = 0.3
        static let gravity = SIMD3<Float>(0, -0.8, 0)
        static let linearDamping: Float = 2.0
        static let restitution: Float = 0
        static let friction: Float = 0.8
        static let yieldSpeed: Float = 0.16
        static let restFriction: Float = 0.18
        static let stackRadius: Float = 0.12
        static let topSpread: Float = 2.0
        static let apexSpeed: Float = 0.6
        static let floorContactBand: Float = 0.1
        static let floorContactDamping: Float = 0.35
        static let maxSpeed: Float = 1.6
        static let collisionRadius: Float = 0.006
        static let substeps: Int = 3
        static let maxParticles: Int = 1000
        // Per-frame lift drivers (set by chemistry each frame)
        static let gasLiftBase: Float = 3
        static let gasLiftScale: Float = 10
        static let vigorCap: Float = 2.0
        static let referenceModelRate: Double = 0.345
        static let rimOverflowPadding: Float = 0.02
        static let rheologyRelaxSpan: Double = 12.0
        static let rheologyCohesionFade: Float = 0.20
        static let rheologyViscosityFade: Float = 0.20
    }
    // MARK: - Surface builder (marching cubes)
    enum Surface {
        static let cellSize: Float = 0.01
        static let influenceRadius: Float = 0.085
        static let isoLevel: Float = 0.3
        static let maxGridDim: Int = 48
        static let smoothingIterations: Int = 4
        static let smoothingFactor: Float = 0.5
        static let rebuildEvery: Int = 1
        static let minParticlesForMesh: Int = 4
        static let settlePaddingSeconds: Double = 6.0
        static let decayFraction: Double = 0.15
    }
    // MARK: - Simulation loop
    enum Loop {
        static let maxDeltaTime: Float = 1.0 / 30.0
        static let tickIntervalSeconds: Double = 1.0 / 60.0
    }
}
