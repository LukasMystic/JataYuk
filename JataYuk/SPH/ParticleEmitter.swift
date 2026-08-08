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

    /// The recipe's peak plume height (cm), used to pick the emission rate.
    private let peakHeightCm: Double

    /// Extra gain on the √(2gH) launch speed. The formula uses g = 9.81 but the
    /// sim's gravity is much weaker, so raw launches overshoot — mostly for WEAK
    /// recipes, whose launch speed is below maxSpeed and so isn't clipped. ~0.5
    /// tames those sparse-and-too-high plumes; strong recipes are maxSpeed-capped
    /// anyway, so they're unaffected.
    var launchVelocityScale: Float = 0.5

    /// Emission speed (× the chemistry's real pace) for SHORT plumes.
    /// 2.0 = twice the particles/sec, eruption finishes in ~half the time.
    var emissionRateScale: Double = 2.0
    /// Emission speed for TALL plumes. Kept slow (1.0 = real pace) so foam is
    /// still erupting later, once the lift ceiling has grown tall enough to lift
    /// it — otherwise a tall recipe emits everything early (while the ceiling is
    /// still low) and stays short. The rate blends between the two by peak height.
    var tallEmissionRateScale: Double = 1.0

    private let gravity: Float = 9.81

    init(model: FoamModel,
         geometry: ContainerGeometry,
         particleMass: Float,
         maxParticles: Int) {
        self.model = model
        self.geometry = geometry
        self.particleMass = particleMass
        self.maxParticles = maxParticles

        // Absolute volume per particle (10 mL): the recipe's foam volume now
        // controls HOW MANY particles are emitted (up to maxParticles), so
        // stronger recipes visibly produce more foam. Mid/strong recipes cap out
        // at maxParticles; weaker recipes come out proportionally smaller.
        litresPerParticle = 0.01
        peakHeightCm = model.peakHeightCm
    }

    /// Particles to emit this frame, given how many already exist. Emission
    /// follows the *rise* of the volume curve; during collapse the target falls
    /// below the current count, so nothing new is emitted.
    func newParticles(at elapsed: Double, currentCount: Int) -> [Particle] {
        // Pick emission speed by how TALL this recipe's plume is: short plumes
        // emit fast (emissionRateScale); tall plumes emit slower (toward
        // tallEmissionRateScale) so foam is still erupting once the lift ceiling
        // has grown tall — which is why tall recipes previously stayed short.
        let tallness = min(1.0, max(0.0, (peakHeightCm - 20.0) / (80.0 - 20.0)))
        let scale = emissionRateScale + (tallEmissionRateScale - emissionRateScale) * tallness
        let t = elapsed * scale
        let gasNow = max(0, model.volume(at: t) - model.liquidL)
        let target = min(maxParticles, Int(gasNow / litresPerParticle))
        guard target > currentCount else { return [] }

        // Height → launch speed: the speed needed to ballistically reach the
        // predicted foam height. Height is in cm; convert to metres.
        let heightM = Float(model.height(at: t) / 100.0)
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
