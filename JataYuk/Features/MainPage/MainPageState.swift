//
//  MainPageState.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import Foundation

enum MainPageTab: String, CaseIterable, Identifiable {
    case experiments = "Experiments"
    case achievements = "My Achievements"

    var id: String {
        rawValue
    }
}

struct MainPageState: Equatable {
    var selectedTab: MainPageTab = .experiments
    var experiments: [ExperimentCard] = ExperimentData.experiments
}
