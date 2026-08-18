//
//  RootAction.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

enum RootAction {
    case navigate(to: AppRoute)
    case overlay(OverlayAction)
    case ar(ARAction)
    case onboarding(OnboardingAction) //added
}

// MARK: - Overlay Actions

enum OverlayAction {
    case showInstruction
    case hideInstruction
    case markInstructionsSeen
    case showItemInfo(BeakerType)
    case hideItemInfo
}

// MARK: - AR Actions
// Sent by SwiftUI gestures (tap, slider) and by client callbacks (proximity, tilt, shake).

enum ARAction {
    case placementAdvanced
    case ingredientProximityChanged(StationSide, Int, ARProximityState)
    case mixingBeakerProximityChanged(StationSide, ARProximityState)
    case pickupIngredient(StationSide, Int)
    case releaseIngredient(StationSide, Int)
    case pourIngredient(StationSide, Int)
    case selectH2O2Variant(H2O2Variant)
    case adjustWaterTemperature(Double)
    case shakeMixingBeaker(StationSide)
    case interactWithVolcano
    case reactionTick(Double)
    case pauseSession
    case resumeSession
    case resetSession
}
