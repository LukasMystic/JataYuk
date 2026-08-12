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

    private let geometry: ContainerGeometry
    private let particleMass: Float

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
    let emissionDuration: Double

    // Gravity magnitude used for the launch mapping — set to the SIM's gravity
    //  • so √(2·g·H) reaches ~H under the sim's physics (not Earth's 9.81).
    private let gravity: Float

    init(model: FoamModel,
         geometry: ContainerGeometry,
         particleMass: Float,
         maxParticles: Int,
         gravity: Float) {
        self.geometry = geometry
        self.particleMass = particleMass
        self.gravity = gravity
        let chemistry = FoamChemistry.calculate(from: model)
        emissionDuration = chemistry.emissionDuration
        peakHeightCm = chemistry.peakHeightCm
        totalParticles = min(maxParticles, chemistry.totalParticles)
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
        let launchH = max(ExplosionSandboxConstants.Emitter.minLaunchHeight, aboveRim)
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
        let rr = geometry.radius
            * ExplosionSandboxConstants.Emitter.spawnRadiusFactor
            * sqrt(Float.random(in: 0...1))
        let y = geometry.height
            - Float.random(in: 0.0...ExplosionSandboxConstants.Emitter.spawnBelowRimMax)   // below rim
        let position = SIMD3<Float>(rr * cos(angle), y, rr * sin(angle))

        let spread = ExplosionSandboxConstants.Emitter.velocitySpread
        let velocity = SIMD3<Float>(Float.random(in: -spread...spread) * launchSpeed,
                                    launchSpeed,
                                    Float.random(in: -spread...spread) * launchSpeed)
        return Particle(position: position, velocity: velocity, mass: particleMass)
    }
}
