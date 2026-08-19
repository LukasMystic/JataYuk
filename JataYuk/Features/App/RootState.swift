//
//  RootState.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

enum AppRoute: Equatable {
    case onboarding
    case ar
    case end
}

struct RootState: Equatable {
    var currentRoute: AppRoute = .onboarding
    var ar: ARState = ARState()
    var experiment: ExperimentState = .initial()
    var end: EndState = EndState()
    var onboarding = OnboardingState() //added
    var hasSeenInstructions: Bool = false
    var isInstructionVisible: Bool = false
    var isItemInfoVisible: Bool = false
    var activeInfoItem: BeakerType? = nil
}
