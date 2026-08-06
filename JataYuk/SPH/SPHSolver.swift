//
//  SPHSolver.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import simd

/// Geometry of the reaction vessel, shared by the emitter and the collision
/// code. Metres, with the floor at y == 0. Defaults match the reaction vessel
/// built in ARViewCoordinator (body cylinder: radius 0.041, spanning y≈0…0.146).
struct ContainerGeometry {
    var radius: Float = 0.041   // 4.1 cm
    var height: Float = 0.146   // rim height (foam overflows above this)

    /// Interior volume in litres — used to keep FoamModel's container fields
    /// consistent with the vessel the user actually sees.
    var volumeLitres: Double {
        Double(Float.pi * radius * radius * height) * 1000.0
    }
}

/// Real-time 3D SPH solver (Müller et al. 2003) tuned for thick, oozing foam.
///
/// The chemistry model never touches this class — it only *adds* particles with
/// a chosen initial velocity. Once a particle exists, SPH alone governs it via
/// pressure, viscosity, cohesion, gravity, and wall/floor collisions.
///
/// Units are centimetre-scale (the vessel is a few cm), so the constants below
/// differ from a "water in a bucket" demo. They are fitted for stability and
/// look, not measured — retune against real footage.
final class SPHSolver {

    /// FOAM preset: high viscosity + high cohesion + strong damping so the
    /// material heaps and piles on itself instead of self-levelling like water.
    struct Config {
        var smoothingRadius: Float = 0.022
        var particleMass: Float    = 0.0016
        var restDensity: Float     = 1000
        var stiffness: Float       = 30    // LOWER → less explosive side-repulsion (was 80)
        var viscosity: Float       = 15    // thick → stacks & oozes, doesn't run like water
        var cohesion: Float        = 4.0   // HIGHER → holds together as one piece (was 0.7)
        var xsph: Float            = 0.3   // XSPH velocity smoothing → laminar, coherent flow (0 = off)
        var gravity: SIMD3<Float>  = [0, -2.0, 0]  // enough to keep foam settling as a mass (was -0.5 → floated apart)
        var linearDamping: Float   = 2.0    // STRONG → stops in place, stacks (was 0.4)
        var restitution: Float     = 0.03   // no bounce
        var friction: Float        = 0.8    // grippy, doesn't slide apart
        var maxSpeed: Float        = 1.6   // calmer → less splashy, more laminar
        var collisionRadius: Float = 0.006
        var substeps: Int          = 4      // +1 for stability under the stronger forces
        var maxParticles: Int      = 500
    }

    private(set) var particles: [Particle] = []
    let config: Config
    private let geometry: ContainerGeometry
    private let hash: SpatialHash

    // Precomputed kernel coefficients (depend only on h).
    private let h: Float
    private let h2: Float
    private let poly6Coeff: Float
    private let spikyGradCoeff: Float
    private let viscLapCoeff: Float

    var count: Int { particles.count }
    /// Upward acceleration from gas generation (m/s²), applied only to particles
    /// still inside the vessel (below the rim). Set each frame by the driver;
    /// 0 once the reaction stops producing gas. This is the volumetric lift that
    /// makes the whole column erupt, rather than only the newest particles.
    var gasLift: Float = 0
    /// Top of the lift column (world y). Particles below this and inside the
    /// cylinder radius get pushed up; above it, gravity takes over.
    var liftCeiling: Float = 0

    init(config: Config, geometry: ContainerGeometry) {
        self.config = config
        self.geometry = geometry
        self.hash = SpatialHash(cellSize: config.smoothingRadius)

        h = config.smoothingRadius
        h2 = h * h
        poly6Coeff     = 315.0 / (64.0 * .pi * pow(h, 9))
        spikyGradCoeff = -45.0 / (.pi * pow(h, 6))
        viscLapCoeff   =  45.0 / (.pi * pow(h, 6))
    }

    /// Append newly emitted particles, respecting the hard cap.
    func add(_ newParticles: [Particle]) {
        let room = config.maxParticles - particles.count
        guard room > 0 else { return }
        particles.append(contentsOf: newParticles.prefix(room))
    }

    /// Remove all particles (Reset).
    func clear() { particles.removeAll(keepingCapacity: true) }

    /// Advance the whole simulation by `dt`, split into substeps for stability.
    /// `dt` is clamped so a dropped frame can't blow the sim up.
    func update(dt: Float) {
        guard !particles.isEmpty else { return }
        let clamped = min(dt, 1.0 / 30.0)
        let sub = clamped / Float(config.substeps)
        for _ in 0..<config.substeps { substep(sub) }
    }

    // MARK: - Core step

    private func substep(_ dt: Float) {
        hash.build(particles)
        computeDensityAndPressure()
        computeForces()
        applyXSPH(config.xsph)
        integrate(dt)
    }

    /// XSPH velocity smoothing (Monaghan). Blends each particle's velocity a
    /// little toward the mass-weighted average of its neighbours, so the fluid
    /// moves in coherent sheets — laminar — instead of each particle jittering
    /// on its own. It barely changes momentum, so it smooths without freezing.
    private func applyXSPH(_ epsilon: Float) {
        guard epsilon > 0, !particles.isEmpty else { return }
        let m = config.particleMass
        var deltas = [SIMD3<Float>](repeating: .zero, count: particles.count)
        for i in particles.indices {
            let pi = particles[i].position
            let vi = particles[i].velocity
            var acc = SIMD3<Float>.zero
            hash.forEachNeighbour(of: pi) { j in
                if j == i { return }
                let r2 = simd_length_squared(pi - particles[j].position)
                if r2 >= self.h2 { return }
                let densJ = particles[j].density
                if densJ <= 0 { return }
                let x = self.h2 - r2
                let w = self.poly6Coeff * x * x * x
                acc += (m / densJ) * (particles[j].velocity - vi) * w
            }
            deltas[i] = epsilon * acc
        }
        for i in particles.indices { particles[i].velocity += deltas[i] }
    }

    /// Poly6 density (includes self-contribution), then pressure from a simple
    /// equation of state. Negative pressure is clamped to zero so the pressure
    /// term never glues particles together — cohesion handles clumping.
    private func computeDensityAndPressure() {
        let selfDensity = config.particleMass * poly6Coeff * (h2 * h2 * h2) // (h²-0)³
        for i in particles.indices {
            var density = selfDensity
            let pi = particles[i].position
            hash.forEachNeighbour(of: pi) { j in
                if j == i { return }
                let d = pi - particles[j].position
                let r2 = simd_length_squared(d)
                if r2 < self.h2 {
                    let x = self.h2 - r2
                    density += self.config.particleMass * self.poly6Coeff * x * x * x
                }
            }
            particles[i].density = density
            particles[i].pressure = max(0, config.stiffness * (density - config.restDensity))
        }
    }

    /// Pressure (repulsion) + viscosity (velocity smoothing) + cohesion
    /// (attraction), summed into an acceleration. Gravity is added at integration.
    private func computeForces() {
        let m = config.particleMass
        for i in particles.indices {
            let pi = particles[i].position
            let vi = particles[i].velocity
            let pressI = particles[i].pressure

            var fPressure = SIMD3<Float>.zero
            var fViscosity = SIMD3<Float>.zero
            var fCohesion = SIMD3<Float>.zero

            hash.forEachNeighbour(of: pi) { j in
                if j == i { return }
                let rvec = pi - particles[j].position
                let r2 = simd_length_squared(rvec)
                if r2 >= self.h2 || r2 <= 1e-12 { return }

                let r = sqrt(r2)
                let densJ = particles[j].density
                if densJ <= 0 { return }

                // Pressure — Spiky gradient points from j toward i.
                let grad = self.spikyGradCoeff * (self.h - r) * (self.h - r) * (rvec / r)
                let shared = (pressI + particles[j].pressure) / (2 * densJ)
                fPressure += -m * shared * grad

                // Viscosity — Laplacian pulls velocities together.
                let lap = self.viscLapCoeff * (self.h - r)
                fViscosity += self.config.viscosity * m *
                              (particles[j].velocity - vi) / densJ * lap

                // Cohesion — Poly6-weighted pull toward neighbours.
                let x = self.h2 - r2
                let w = self.poly6Coeff * x * x * x
                fCohesion += -self.config.cohesion * m * rvec * w
            }

            let densI = max(particles[i].density, 1e-5)
            particles[i].acceleration =
                (fPressure + fViscosity + fCohesion) / densI + config.gravity
        }
    }

    /// Semi-implicit (symplectic) Euler: update velocity first, then use the new
    /// velocity for position. Damping + speed clamp keep the foam calm.
    private func integrate(_ dt: Float) {
        let damp = max(0, 1 - config.linearDamping * dt)
        for i in particles.indices {
            var a = particles[i].acceleration
            let p0 = particles[i].position
            // Gas lift acts on the column inside the vessel only.
            if gasLift != 0,
               p0.y < liftCeiling,
               (p0.x * p0.x + p0.z * p0.z) < geometry.radius * geometry.radius {
                // Taper the lift from full at the rim to zero at the ceiling, so
                // particles ease over the top and spill out — instead of piling
                // against an invisible lid (the "clump in the sky, then explode").
                let span = max(liftCeiling - geometry.height, 1e-4)
                let frac = min(1, (liftCeiling - p0.y) / span)
                a.y += gasLift * frac
            }

            // Semi-implicit Euler: new velocity, then move by it.
            var v = particles[i].velocity + a * dt
            v *= damp

            let speed = simd_length(v)
            if speed > config.maxSpeed { v *= config.maxSpeed / speed }

            var p = p0 + v * dt
            resolveCollisions(position: &p, velocity: &v)

            // Write the result back — WITHOUT this, particles never move.
            particles[i].velocity = v
            particles[i].position = p
        }
    }

    // MARK: - Boundaries

    /// Floor plane plus a zero-thickness cylinder wall. A particle keeps to
    /// whichever side of the wall it is currently on: emitted particles stay
    /// inside until they clear the rim, then fall and pool on the outside — so
    /// floor accumulation emerges from the physics, not from hand animation.
    private func resolveCollisions(position p: inout SIMD3<Float>,
                                   velocity v: inout SIMD3<Float>) {
        let r = config.collisionRadius

        // Floor.
        if p.y < r {
            p.y = r
            if v.y < 0 {
                v.y = -v.y * config.restitution
                v.x *= (1 - config.friction)
                v.z *= (1 - config.friction)
            }
        }

        // Cylinder wall, only where the wall physically exists (below the rim).
        if p.y < geometry.height {
            let radial = sqrt(p.x * p.x + p.z * p.z)
            guard radial > 1e-6 else { return }
            let dir = SIMD2<Float>(p.x, p.z) / radial

            if radial < geometry.radius {                 // inside the tube
                let maxR = geometry.radius - r
                if radial > maxR {
                    p.x = dir.x * maxR; p.z = dir.y * maxR
                    reflectRadial(&v, dir: dir)
                }
            } else {                                       // outside the tube
                let minR = geometry.radius + r
                if radial < minR {
                    p.x = dir.x * minR; p.z = dir.y * minR
                    reflectRadial(&v, dir: dir)
                }
            }
        }
    }

    /// Reflect the radial velocity off a vertical wall and shed some energy.
    private func reflectRadial(_ v: inout SIMD3<Float>, dir: SIMD2<Float>) {
        let vr = v.x * dir.x + v.z * dir.y
        v.x -= (1 + config.restitution) * vr * dir.x
        v.z -= (1 + config.restitution) * vr * dir.y
        v.y *= (1 - config.friction * 0.5)
    }
}
