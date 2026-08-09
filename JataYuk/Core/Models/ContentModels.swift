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

struct InstructionStep: Equatable {
    let stepNumber: Int
    let title: String
    let description: String
    let animationName: String
    let context: InstructionContext
}

struct ItemInfo: Equatable {
    let beakerType: BeakerType
    let title: String
    let description: String
    let scienceFact: String
    let imageName: String
}
