//
//  ParticleEmitter.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import simd

/// The ONLY place the chemistry model influences the fluid, and it only ever
/// affects *new* particles:
///   • `volume(at:)` → how many particles to create (fixed litres per particle).
///   • `height(at:)` → their initial upward speed.
/// It never repositions or deletes existing particles.
final class ParticleEmitter {

    private let model: FoamModel
    private let geometry: ContainerGeometry
    private let particleMass: Float
    private let maxParticles: Int

    /// Litres of foam represented by one particle. Fixed at start so particle
    /// count tracks the volume curve linearly.
    private let litresPerParticle: Double

    /// Extra gain on the physical √(2gH) launch speed. Keep < 1 for a gentle,
    /// foamy eruption; 1.0 is the raw ballistic mapping.
    var launchVelocityScale: Float = 1.0

    private let gravity: Float = 9.81

    init(model: FoamModel,
         geometry: ContainerGeometry,
         particleMass: Float,
         maxParticles: Int) {
        self.model = model
        self.geometry = geometry
        self.particleMass = particleMass
        self.maxParticles = maxParticles

        // Base the budget on the gas portion of the peak (foam above the resting
        // liquid), so the full particle budget is spent right at peak height.
        let peakGas = max(model.peakVolumeL - model.liquidL, 1e-4)
        litresPerParticle = peakGas / Double(maxParticles)
    }

    /// Particles to emit this frame, given how many already exist. Emission
    /// follows the *rise* of the volume curve; during collapse the target falls
    /// below the current count, so nothing new is emitted.
    func newParticles(at elapsed: Double, currentCount: Int) -> [Particle] {
        let gasNow = max(0, model.volume(at: elapsed) - model.liquidL)
        let target = min(maxParticles, Int(gasNow / litresPerParticle))
        guard target > currentCount else { return [] }

        // Height → launch speed: the speed needed to ballistically reach the
        // predicted foam height. Height is in cm; convert to metres.
        let heightM = Float(model.height(at: elapsed) / 100.0)
        let launch = (2 * gravity * max(heightM, 0)).squareRoot() * launchVelocityScale

        var emitted: [Particle] = []
        emitted.reserveCapacity(target - currentCount)
        for _ in currentCount..<target { emitted.append(makeParticle(launchSpeed: launch)) }
        return emitted
    }

    /// Spawn a particle low inside the vessel, moving mostly straight up with a
    /// little random spread so the column isn't a rigid pillar.
    private func makeParticle(launchSpeed: Float) -> Particle {
        let angle = Float.random(in: 0..<(2 * .pi))
        // Near the centre of the opening so it forms a column, not a ring.
        let rr = geometry.radius * 0.5 * sqrt(Float.random(in: 0...1))
        let position = SIMD3<Float>(rr * cos(angle),
                                    geometry.height + Float.random(in: 0.0...0.01), // at/above the rim
                                    rr * sin(angle))

        let spread: Float = 0.04   // low → smooth laminar column (was 0.12 = scattered)
        let velocity = SIMD3<Float>(Float.random(in: -spread...spread) * launchSpeed,
                                    launchSpeed,
                                    Float.random(in: -spread...spread) * launchSpeed)
        return Particle(position: position, velocity: velocity, mass: particleMass)
    }
}
