//
//  ExplosionEffect.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
//

import Foundation
struct SimulationForces: Equatable {
    var gasLift: Float
    var liftCeiling: Float
    var viscosity: Float
    var cohesion: Float
}
// Dependency boundary — ARCoordinator / ECS systems live behind this.
struct ExplosionSimulationClient {
    var setup: (FoamModel) async throws -> FoamChemistryResult
    var step: (
        _ deltaTime: Float,
        _ forces: SimulationForces,
        _ elapsed: Double,
        _ emissionDuration: Double
    ) async -> Int  // returns current particle count
    var reset: () async -> Void
}
struct ExplosionEnvironment {
    var simulation: ExplosionSimulationClient
    var effects: ExplosionEffects
}
struct ExplosionEffects {
    var startPipeline: (FoamModel) -> Effect
    var runSetup: (FoamModel) -> Effect
    var startFrameLoop: Effect
    var stopFrameLoop: Effect
    var runSimulationStep: (
        _ deltaTime: Float,
        _ forces: SimulationForces,
        _ elapsed: Double,
        _ emissionDuration: Double
    ) -> Effect
    var resetSimulation: Effect
}
extension ExplosionEffects {
    static func live(
        simulation: ExplosionSimulationClient,
        send: @escaping (ExplosionAction) -> Void
    ) -> ExplosionEffects {
        ExplosionEffects(
            startPipeline: { foamModel in
                Effect { _ in send(.pipelineStarted(foamModel)) }
            },
            runSetup: { foamModel in
                Effect { _ in
                    do {
                        let result = try await simulation.setup(foamModel)
                        send(.setupCompleted(result))
                    } catch {
                        send(.setupFailed)
                    }
                }
            },
            startFrameLoop: Effect { _ in
                // ARCoordinator's update loop should call send(.tick(deltaTime:))
                // OR run a Task here — pick one place so you don't double-tick.
            },
            stopFrameLoop: .none(),
            runSimulationStep: { dt, forces, elapsed, emissionDuration in
                Effect { _ in
                    let count = await simulation.step(dt, forces, elapsed, emissionDuration)
                    send(.particlesUpdated(count: count))
                }
            },
            resetSimulation: Effect { _ in
                await simulation.reset()
            }
        )
    }
}
