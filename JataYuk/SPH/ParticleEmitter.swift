//
//  ParticleEmitter.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 06/08/26.
//

import simd

// The ONLY place the chemistry model influences the fluid, and it only ever affects *new* particles:
//   • `volume(at:)` → how many particles to create (fixed litres per particle).
//   • `height(at:)` → their initial upward speed.
final class ParticleEmitter {

    private let model: FoamModel
    private let geometry: ContainerGeometry
    private let particleMass: Float
    private let maxParticles: Int

    // Litres of foam represented by one particle.
    //   • Fixed at start so particle count tracks the volume curve linearly.
    private let litresPerParticle: Double

    // The recipe's peak plume height (cm), used for the launch speed.
    private let peakHeightCm: Double

    // Total particles this recipe emits — set by the AMOUNT of foam (peroxide
    // volume/concentration), capped at maxParticles. Emitted over emissionDuration.
    private let totalParticles: Int

    // Gain on the √(2·g·H) launch speed.
    var launchVelocityScale: Float = 1.0

    // Reaction length (seconds) at the reference catalyst.
    //  • The actual duration scales with the CATALYST only (see `emissionDuration`),
    //  • NOT the amount of peroxide — so more peroxide means more particles at a higher rate over the same time.
    var baseEmissionSeconds: Double = 10.0
    private let referenceRate = 0.5   // ~default catalyst (yeast 1, ~30 °C)

    // How long particles are emitted, in seconds.
    //  • Set ONLY by the catalyst (model.rate = yeast × temperature); independent of volume/concentration.
    //  • Clamped so a very weak catalyst doesn't drag on forever.
    var emissionDuration: Double {
        min(15, max(2, baseEmissionSeconds * referenceRate / max(model.rate, 0.02)))
    }

    // Gravity magnitude used for the launch mapping — set to the SIM's gravity
    //  • so √(2·g·H) reaches ~H under the sim's physics (not Earth's 9.81).
    private let gravity: Float

    init(model: FoamModel,
         geometry: ContainerGeometry,
         particleMass: Float,
         maxParticles: Int,
         gravity: Float) {
        self.model = model
        self.geometry = geometry
        self.particleMass = particleMass
        self.maxParticles = maxParticles
        self.gravity = gravity

        // Absolute volume per particle (10 mL): the recipe's foam volume now
        // controls HOW MANY particles are emitted (up to maxParticles), so
        // stronger recipes visibly produce more foam. Mid/strong recipes cap out
        // at maxParticles; weaker recipes come out proportionally smaller.
        litresPerParticle = 0.005   // 5 mL/particle → ~2× the particle density (more, smaller foam)
        peakHeightCm = model.peakHeightCm
        let peakGas = max(0, model.peakVolumeL - model.liquidL)
        totalParticles = min(maxParticles, Int(peakGas / litresPerParticle))
    }

    // Particles to emit this frame, given how many already exist.
    //  • Emission follows the *rise* of the volume curve;
    //  • during collapse the target falls below the current count, so nothing new is emitted.
    func newParticles(at elapsed: Double, currentCount: Int) -> [Particle] {
        // Linear emission: all `totalParticles` spread evenly over `emissionDuration`.
        //  • Amount (totalParticles) comes from the peroxide;
        //  • duration comes from the catalyst — so the RATE = totalParticles / emissionDuration.
        //  • Two recipes with the same catalyst but different peroxide finish in the same time;
        //  • the bigger one just emits faster.
        let progress = min(1.0, elapsed / emissionDuration)
        let target = Int(Double(totalParticles) * progress)
        guard target > currentCount else { return [] }

        // Launch only high enough to rise to the plume top ABOVE the mouth (particles spawn at the rim).
        //  • Weak recipes whose foam sits below the rim get a small floor → gentle overflow instead of a shot upward.
        let aboveRim = Float(peakHeightCm / 100.0) - geometry.height
        let launchH = max(0.02, aboveRim)
        let launch = (2 * gravity * launchH).squareRoot() * launchVelocityScale

        var emitted: [Particle] = []
        emitted.reserveCapacity(target - currentCount)
        for _ in currentCount..<target { emitted.append(makeParticle(launchSpeed: launch)) }
        return emitted
    }

    // Spawn a particle low inside the vessel,
    //  • moving mostly straight up with a little random spread so the column isn't a rigid pillar.
    private func makeParticle(launchSpeed: Float) -> Particle {
        let angle = Float.random(in: 0..<(2 * .pi))
        // Spread across most of the mouth and just BELOW the rim,
        //  • so a dense high-concentration burst fills the vessel and the wall directs it UP as a column
        //  • instead of over-packing one spot at the open mouth and venting sideways ("exploding everywhere").
        let rr = geometry.radius * 0.85 * sqrt(Float.random(in: 0...1))
        let y = geometry.height - Float.random(in: 0.0...0.04)   // 0–4 cm below the rim
        let position = SIMD3<Float>(rr * cos(angle), y, rr * sin(angle))

        let spread: Float = 0.04   // low → smooth laminar column (was 0.12 = scattered)
        let velocity = SIMD3<Float>(Float.random(in: -spread...spread) * launchSpeed,
                                    launchSpeed,
                                    Float.random(in: -spread...spread) * launchSpeed)
        return Particle(position: position, velocity: velocity, mass: particleMass)
    }
}
