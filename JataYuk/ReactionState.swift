//
//  ReactionState.swift
//  JataYuk
//
//  Model — tracks which phase the experiment is currently in.
//

import Foundation

enum ReactionState: Equatable {
    case idle       // no ingredients poured yet
    case mixing     // at least one ingredient poured; reaction not yet triggered
    case failed     // H₂O₂ + Yeast without Dish Soap → fizzle
    case success    // all three ingredients in correct order → eruption
}
