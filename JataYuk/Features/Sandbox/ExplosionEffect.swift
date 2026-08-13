//
//  ExplosionEffect.swift
//  JataYuk
//
//  Minimal Effects surface for the hybrid driver.
//  Setup + per-frame SPH run synchronously in ExplosionStore (intentional — Metal).
//

import Foundation

/// Result of one ECS simulation frame (for TCA phase transitions only).
struct SimulationFrameResult: Equatable {
    var emissionComplete: Bool
    var settled: Bool
}

/// Side-effect boundary for ECS systems (EmissionSystem + SPHSystem).
struct ExplosionSimulationClient {
    var setup: (FoamModel) throws -> FoamChemistryResult
    var step: (_ deltaTime: Float, _ volcanoState: VolcanoState) -> SimulationFrameResult
    var reset: () -> Void
}

struct ExplosionEnvironment {
    var simulation: ExplosionSimulationClient
    var effects: ExplosionEffects
}

struct ExplosionEffects {
    var resetSimulation: Effect
}

extension ExplosionEffects {
    static func live(simulation: ExplosionSimulationClient) -> ExplosionEffects {
        ExplosionEffects(
            resetSimulation: Effect { _ in
                simulation.reset()
            }
        )
    }
}
