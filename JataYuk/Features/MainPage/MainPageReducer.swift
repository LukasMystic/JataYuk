//
//  MainPageReducer.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import Foundation

enum MainPageAction {
    case tabSelected(MainPageTab)
    case playButtonTapped(ExperimentCard)
    case settingsButtonTapped
}

struct MainPageReducer {

    static func reduce(
        state: inout MainPageState,
        action: MainPageAction,
        environment: RootEnvironment
    ) -> [Effect] {

        switch action {

        case let .tabSelected(tab):
            state.selectedTab = tab
            return []

        case let .playButtonTapped(experiment):
            print("Start Experiment: \(experiment.title)")
            return []

        case .settingsButtonTapped:
            print("Settings tapped")
            return []
        }
    }
}

