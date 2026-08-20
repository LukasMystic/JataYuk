//
//  RootState.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

enum AppRoute: Equatable {
    case loading
    case onboarding
    case main
    case ar
    case end
}

struct RootState: Equatable {
    var currentRoute: AppRoute = .loading   // changed from .onboarding
    var loadingPage: LoadingPageState = LoadingPageState()   // added
    var mainPage: MainPageState = MainPageState()            // added
    var ar: ARState = ARState()
    var experiment: ExperimentState = .initial()
    var end: EndState = EndState()
    var onboarding = OnboardingState()
    var hasSeenInstructions: Bool = false
    var isInstructionVisible: Bool = false
    var isItemInfoVisible: Bool = false
    var activeInfoItem: BeakerType? = nil
}
