//
//  GPUSPHSolver.swift
//  JataYuk
//
//  GPU-accelerated SPH solver used by SPHSystem.
//  Public API: config, particles, count, gasLift, liftCeiling, runtimeViscosity/Cohesion,
//  add/clear/update. Physics runs in Metal (SPHCompute.metal); positions are read back
//  each frame for CPU marching-cubes meshing.
//
//  Uses unified (shared) memory buffers, so on iOS/Apple Silicon there's no copy —
//  the CPU writes emitted particles straight into the buffers and reads results back.
//

import Metal
import simd

final class GPUSPHSolver {

    let config: SPHConfig
    private let geometry: ContainerGeometry

    private(set) var particles: [Particle] = []
    var count: Int { particles.count }

    // Per-frame drivers, set by SPHSystem (same names as the CPU solver).
    var gasLift: Float = 0
    var liftCeiling: Float = 0
    var runtimeViscosity: Float = 0
    var runtimeCohesion: Float = 0

    // Kernel coefficients (depend only on h).
    private let h: Float
    private let h2: Float
    private let poly6: Float
    private let spikyGrad: Float
    private let viscLap: Float

    // Metal objects (optional so a Metal-less environment fails gracefully).
    private let queue: MTLCommandQueue?
    private let densityPSO: MTLComputePipelineState?
    private let forcesPSO: MTLComputePipelineState?
    private let positionsBuf: MTLBuffer?
    private let velocitiesBuf: MTLBuffer?
    private let densityBuf: MTLBuffer?
    private let pressureBuf: MTLBuffer?
    private var frameSeed: UInt32 = 0x1234_5678

    /// Mirrors the Metal `Uniforms` struct exactly (all 4-byte scalars, same order).
    private struct Uniforms {
        var count: UInt32 = 0
        var dt: Float = 0
        var h: Float = 0
        var h2: Float = 0
        var poly6: Float = 0
        var spikyGrad: Float = 0
        var viscLap: Float = 0
        var mass: Float = 0
        var restDensity: Float = 0
        var stiffness: Float = 0
        var viscosity: Float = 0
        var cohesion: Float = 0
        var xsph: Float = 0
        var gravityY: Float = 0
        var damping: Float = 0
        var restitution: Float = 0
        var friction: Float = 0
        var maxSpeed: Float = 0
        var collisionRadius: Float = 0
        var yieldSpeed: Float = 0
        var restFriction: Float = 0
        var restAccel: Float = 0
        var stackRadius: Float = 0
        var gasLift: Float = 0
        var liftCeiling: Float = 0
        var topSpread: Float = 0
        var apexSpeed: Float = 0
        var rimHeight: Float = 0
        var cylRadius: Float = 0
        var floorContactBand: Float = 0
        var floorContactDamping: Float = 0
        var seed: UInt32 = 0
    }

    init(config: SPHConfig, geometry: ContainerGeometry) {
        self.config = config
        self.geometry = geometry
        runtimeViscosity = config.viscosity
        runtimeCohesion = config.cohesion

        h = config.smoothingRadius
        h2 = h * h
        poly6     = 315.0 / (64.0 * .pi * pow(h, 9))
        spikyGrad = -45.0 / (.pi * pow(h, 6))
        viscLap   =  45.0 / (.pi * pow(h, 6))

        let device = MTLCreateSystemDefaultDevice()
        queue = device?.makeCommandQueue()

        var dPSO: MTLComputePipelineState?
        var fPSO: MTLComputePipelineState?
        if let device, let lib = device.makeDefaultLibrary() {
            if let fn = lib.makeFunction(name: "sphDensity") {
                dPSO = try? device.makeComputePipelineState(function: fn)
            }
            if let fn = lib.makeFunction(name: "sphForcesIntegrate") {
                fPSO = try? device.makeComputePipelineState(function: fn)
            }
        }
        densityPSO = dPSO
        forcesPSO = fPSO

        let cap = config.maxParticles
        let vecLen = cap * MemoryLayout<SIMD3<Float>>.stride
        let fLen = cap * MemoryLayout<Float>.stride
        positionsBuf  = device?.makeBuffer(length: vecLen, options: .storageModeShared)
        velocitiesBuf = device?.makeBuffer(length: vecLen, options: .storageModeShared)
        densityBuf    = device?.makeBuffer(length: fLen, options: .storageModeShared)
        pressureBuf   = device?.makeBuffer(length: fLen, options: .storageModeShared)

        if dPSO == nil || fPSO == nil || queue == nil {
            print("[GPUSPHSolver] Metal setup failed — make sure SPHCompute.metal is added to the app target. Simulation will be inert.")
        }
    }

    /// Append emitted particles and write them straight into the GPU buffers.
    func add(_ newParticles: [Particle]) {
        let room = config.maxParticles - particles.count
        guard room > 0 else { return }
        let toAdd = Array(newParticles.prefix(room))
        guard !toAdd.isEmpty else { return }

        let start = particles.count
        if let pBuf = positionsBuf, let vBuf = velocitiesBuf {
            let pPtr = pBuf.contents().bindMemory(to: SIMD3<Float>.self, capacity: config.maxParticles)
            let vPtr = vBuf.contents().bindMemory(to: SIMD3<Float>.self, capacity: config.maxParticles)
            for (k, part) in toAdd.enumerated() {
                pPtr[start + k] = part.position
                vPtr[start + k] = part.velocity
            }
        }
        particles.append(contentsOf: toAdd)
    }

    func clear() { particles.removeAll(keepingCapacity: true) }

    /// Advance the sim on the GPU, then read positions/velocities back to CPU.
    func update(dt: Float) {
        let n = particles.count
        guard n > 0,
              let queue, let densityPSO, let forcesPSO,
              let pBuf = positionsBuf, let vBuf = velocitiesBuf,
              let dBuf = densityBuf, let prBuf = pressureBuf,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder()
        else { return }

        let clamped = min(dt, 1.0 / 30.0)
        let sub = clamped / Float(config.substeps)

        enc.setBuffer(pBuf,  offset: 0, index: 0)
        enc.setBuffer(vBuf,  offset: 0, index: 1)
        enc.setBuffer(dBuf,  offset: 0, index: 2)
        enc.setBuffer(prBuf, offset: 0, index: 3)

        let w = min(64, densityPSO.maxTotalThreadsPerThreadgroup)
        let tpt = MTLSize(width: w, height: 1, depth: 1)
        let grid = MTLSize(width: n, height: 1, depth: 1)

        // One command buffer for all substeps; setBytes captures per-substep uniforms.
        // Metal's automatic hazard tracking serialises density → forces (forces reads
        // the density buffer that density wrote), and each substep after the last.
        for s in 0..<config.substeps {
            var u = makeUniforms(dt: sub, count: n, seed: frameSeed &+ UInt32(s))
            enc.setComputePipelineState(densityPSO)
            enc.setBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 4)
            enc.dispatchThreads(grid, threadsPerThreadgroup: tpt)

            enc.setComputePipelineState(forcesPSO)
            enc.setBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 4)
            enc.dispatchThreads(grid, threadsPerThreadgroup: tpt)
        }
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        frameSeed = frameSeed &+ 0x9E37_79B9

        // Read back into the CPU mirror for the mesh builder.
        let pPtr = pBuf.contents().bindMemory(to: SIMD3<Float>.self, capacity: config.maxParticles)
        let vPtr = vBuf.contents().bindMemory(to: SIMD3<Float>.self, capacity: config.maxParticles)
        for i in 0..<n {
            particles[i].position = pPtr[i]
            particles[i].velocity = vPtr[i]
        }
    }

    private func makeUniforms(dt: Float, count: Int, seed: UInt32) -> Uniforms {
        var u = Uniforms()
        u.count = UInt32(count)
        u.dt = dt
        u.h = h; u.h2 = h2
        u.poly6 = poly6; u.spikyGrad = spikyGrad; u.viscLap = viscLap
        u.mass = config.particleMass
        u.restDensity = config.restDensity
        u.stiffness = config.stiffness
        u.viscosity = runtimeViscosity
        u.cohesion = runtimeCohesion
        u.xsph = config.xsph
        u.gravityY = config.gravity.y
        u.damping = config.linearDamping
        u.restitution = config.restitution
        u.friction = config.friction
        u.maxSpeed = config.maxSpeed
        u.collisionRadius = config.collisionRadius
        u.yieldSpeed = config.yieldSpeed
        u.restFriction = config.restFriction
        u.restAccel = abs(config.gravity.y) * 0.6
        u.stackRadius = config.stackRadius
        u.gasLift = gasLift
        u.liftCeiling = liftCeiling
        u.topSpread = config.topSpread
        u.apexSpeed = config.apexSpeed
        u.rimHeight = geometry.height
        u.cylRadius = geometry.radius
        u.floorContactBand = config.floorContactBand
        u.floorContactDamping = config.floorContactDamping
        u.seed = seed
        return u
    }
}
