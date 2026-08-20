//
//  SPHTypes.swift
//  JataYuk
//
//  Shared vessel geometry + SPH config for the GPU solver.
//  (CPU SPHSolver / SpatialHash removed — ECS path uses GPUSPHSolver only.)
//

import simd

struct ContainerGeometry {
    var radius: Float = ExplosionSandboxConstants.Container.radius
    var height: Float = ExplosionSandboxConstants.Container.height

    var volumeLitres: Double {
        Double(Float.pi * radius * radius * height) * 1000.0
    }
}

struct SPHConfig {
    var smoothingRadius: Float = ExplosionSandboxConstants.SPH.smoothingRadius
    var particleMass: Float = ExplosionSandboxConstants.SPH.particleMass
    var restDensity: Float = ExplosionSandboxConstants.SPH.restDensity
    var stiffness: Float = ExplosionSandboxConstants.SPH.stiffness
    var viscosity: Float = ExplosionSandboxConstants.SPH.viscosity
    var cohesion: Float = ExplosionSandboxConstants.SPH.cohesion
    var xsph: Float = ExplosionSandboxConstants.SPH.xsph
    var gravity: SIMD3<Float> = ExplosionSandboxConstants.SPH.gravity
    var linearDamping: Float = ExplosionSandboxConstants.SPH.linearDamping
    var restitution: Float = ExplosionSandboxConstants.SPH.restitution
    var friction: Float = ExplosionSandboxConstants.SPH.friction
    var yieldSpeed: Float = ExplosionSandboxConstants.SPH.yieldSpeed
    var restFriction: Float = ExplosionSandboxConstants.SPH.restFriction
    var stackRadius: Float = ExplosionSandboxConstants.SPH.stackRadius
    var topSpread: Float = ExplosionSandboxConstants.SPH.topSpread
    var apexSpeed: Float = ExplosionSandboxConstants.SPH.apexSpeed
    var floorContactBand: Float = ExplosionSandboxConstants.SPH.floorContactBand
    var floorContactDamping: Float = ExplosionSandboxConstants.SPH.floorContactDamping
    var maxSpeed: Float = ExplosionSandboxConstants.SPH.maxSpeed
    var collisionRadius: Float = ExplosionSandboxConstants.SPH.collisionRadius
    var substeps: Int = ExplosionSandboxConstants.SPH.substeps
    var maxParticles: Int = ExplosionSandboxConstants.SPH.maxParticles
}
