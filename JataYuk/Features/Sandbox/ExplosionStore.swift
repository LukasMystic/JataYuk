//
//  ExplosionStore.swift
//  JataYuk
//
//  Intentional hybrid driver (not textbook pure-TCA Effects for every frame):
//  • TCA: phase, recipe (FoamModel), chemistry summary
//  • Sync ECS: setup + per-frame emit / SPH / mesh (required for Metal correctness)
//

import Foundation
import Combine

@MainActor
final class ExplosionStore: ObservableObject {
    @Published private(set) var state: ExplosionState

    private let reducer: (inout ExplosionState, ExplosionAction, ExplosionEnvironment) -> [Effect]
    private let environment: ExplosionEnvironment

    init(
        initialState: ExplosionState = ExplosionState(),
        environment: ExplosionEnvironment,
        reducer: @escaping (inout ExplosionState, ExplosionAction, ExplosionEnvironment) -> [Effect] = explosionReducer
    ) {
        self.state = initialState
        self.environment = environment
        self.reducer = reducer
    }

    func send(_ action: ExplosionAction) {
        let effects = reducer(&state, action, environment)

        // Hybrid: ECS setup is synchronous so the first tick sees a ready solver.
        if case .pipelineStarted(let model) = action, state.phase == .settingUp {
            do {
                let result = try environment.simulation.setup(model)
                send(.setupCompleted(result))
            } catch {
                send(.setupFailed)
            }
            return
        }

        for effect in effects {
            Task {
                await effect.run { [weak self] action in
                    guard let action = action as? ExplosionAction else { return }
                    self?.send(action)
                }
            }
        }
    }

    /// RealityKit frame entry. Runs one ECS step synchronously, then updates TCA phase.
    func tick(deltaTime: Float) {
        guard state.phase == .emitting || state.phase == .simulating else { return }

        let result = environment.simulation.step(deltaTime, state.volcanoState)
        send(.frameAdvanced(
            emissionComplete: result.emissionComplete,
            settled: result.settled
        ))
    }
}
