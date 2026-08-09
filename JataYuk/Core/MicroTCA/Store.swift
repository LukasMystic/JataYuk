//
//  Store.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 05/08/26.

import Foundation
import Combine

@MainActor
final class Store<State, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reducer: (inout State, Action, RootEnvironment) -> [Effect]
    private let environment: RootEnvironment

    init(
        initialState: State,
        reducer: @escaping (inout State, Action, RootEnvironment) -> [Effect],
        environment: RootEnvironment
    ) {
        self.state = initialState
        self.reducer = reducer
        self.environment = environment
    }

    func send(_ action: Action) {
        let effects = reducer(&state, action, environment)
        for effect in effects {
            Task {
                await effect.run { [weak self] action in
                    guard let action = action as? Action else { return }
                    self?.send(action)
                }
            }
        }
    }
}
