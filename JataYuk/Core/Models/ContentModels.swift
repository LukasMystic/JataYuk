//
//  ContentModels.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

// MARK: - Instruction Context

enum InstructionContext: Equatable {
    case onboarding
    case arPlacement
    case arSideA
    case arSideB
    case arVolcano
    case end
}

// MARK: - Static Content Types
// These are immutable constants defined in code — no reducer manages them.

struct OnboardingPage: Equatable {
    let title: String
    let subtitle: String
    let imageName: String
    let isLast: Bool
}

struct InstructionStep: Equatable, Identifiable {
    var id: InstructionStepKey { key }
    let key: InstructionStepKey
    let stepNumber: Int
    let context: InstructionContext
    let title: String        // kept for ERD parity; DuAR copy doesn't currently use titles
    let description: String  // exact wording from Instructions Copy
    let animation: String?   // asset name placeholder; nil until Figma/animation spec exists - what for ya?
}

struct ItemInfo: Equatable {
    let beakerType: BeakerType
    let title: String
    let description: String
    let scienceFact: String
    let imageName: String
}
