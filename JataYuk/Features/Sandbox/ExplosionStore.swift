//
//  ExplosionStore.swift
//  JataYuk
//
//  Created by Teresa Tendeas on 12/08/26.
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
        for effect in effects {
            Task {
                await effect.run { [weak self] action in
                    guard let action = action as? ExplosionAction else { return }
                    self?.send(action)
                }
            }
        }
    }
    // Called from ARCoordinator.update (RealityKit render loop)
    func tick(deltaTime: Float) {
        send(.tick(deltaTime: deltaTime))
    }
}
