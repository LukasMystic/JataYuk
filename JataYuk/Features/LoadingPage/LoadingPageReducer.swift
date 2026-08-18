//
//  LoadingPageReducer.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import Foundation

enum LoadingPageAction {
    case onAppear
    case onDisappear
    case guideTicked
    case loadingFinished
    case didFinishLoading
}

struct LoadingPageReducer {

    static func reduce(state: inout LoadingPageState, action: LoadingPageAction, environment: RootEnvironment) -> [Effect] {

        switch action {

        case .onAppear:
            return [
                guideTimerEffect(),
                loadingEffect()
            ]

        case .onDisappear:
            return []

        case .guideTicked:
            guard !state.guides.isEmpty else {
                return []
            }

            state.currentGuideIndex =
                (state.currentGuideIndex + 1)
                % state.guides.count

            return []

        case .loadingFinished:
            state.progress = 1.0
            state.isLoadingComplete = true

            return [
                .init { send in
                    try? await Task.sleep(
                        nanoseconds: 300_000_000
                    )

                    send(
                        LoadingPageAction.didFinishLoading
                    )
                }
            ]

        case .didFinishLoading:
            return []
        }
    }
}

// MARK: - Effects

private extension LoadingPageReducer {

    static func loadingEffect() -> Effect {
        Effect { send in

            // Fake loading time.
            try? await Task.sleep(
                nanoseconds: 2_500_000_000
            )

            send(
                LoadingPageAction.loadingFinished
            )
        }
    }

    static func guideTimerEffect() -> Effect {
        Effect { send in

            while true {
                try? await Task.sleep(
                    nanoseconds: 2_500_000_000
                )

                send(
                    LoadingPageAction.guideTicked
                )
            }
        }
    }
}
