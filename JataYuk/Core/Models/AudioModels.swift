//
//  AudioModels.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

enum BGMTrack: Equatable {
    case onboarding
    case main
    case experiment
}

enum SoundEffect: Equatable {
    case buttonPress
    case placeDishSoapOrFoodColoring
    case placeGlass(StationSide)
    case pourSand
    case pourLiquid
    case scoopSand
    case mixOrShake
    case volcanoPlacement
    case volcanoReacting
    case volcanoOutcome
    case wrongPlacement
}
