//
//  OnboardingReducer.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import Foundation

// MARK: - OnboardingPageAction

enum OnboardingAction {
    case letsExploreTapped
    case animationFinished
    case didFinishOnboarding

}

// MARK: - OnboardingPageReducer

func OnboardingReducer(state: inout RootState, action: OnboardingAction, environment: RootEnvironment) -> [Effect] {
    
    switch action {

    case .letsExploreTapped:
        state.onboarding.isButtonPressed = true
        return [Effect { send in try? await Task.sleep(for: .milliseconds(180))
            send(RootAction.onboarding(.animationFinished))}
        ]

    case .animationFinished:
        state.onboarding.isButtonPressed = false
        state.currentRoute = .ar
        return []
        
    case .didFinishOnboarding:
        return []
    }
}
