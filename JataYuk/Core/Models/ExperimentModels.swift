//
//  ExperimentModels.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

// MARK: - Beaker Types

enum BeakerType: Equatable {
    case soap
    case foodColoring
    case h2o2
    case water
    case yeast
}

enum H2O2Variant: Equatable {
    case threePct
    case fivePct
    case sevenPct

    var concentration: Double {
        switch self {
        case .threePct: return 3.0
        case .fivePct:  return 5.0
        case .sevenPct: return 7.0
        }
    }
}

enum FoamColor: Equatable {
    // placeholder — cases TBD
}

// MARK: - Experiment Phases

enum MixtureState: Equatable {
    case idle
    case prepared
    case mixed
}

enum VolcanoState: Equatable {
    case locked
    case highlighted
    case reacting
    case done
}

enum ReactionState: Equatable {
    case idle
    case reacting
    case done
}

// MARK: - Ingredient

struct Ingredient: Equatable {
    let type: BeakerType
    var h2o2Variant: H2O2Variant? = nil
    var pourCount: Int = 0
    var amountPerPour: Double
    var proximityState: ARProximityState = .far
    var grayOutReason: GrayOutReason? = nil
    var color: FoamColor? = nil
    var temperatureC: Double? = nil

    static let maxPours: Int = 5
    var isDepleted: Bool { pourCount >= Ingredient.maxPours }
    var isInteractive: Bool { grayOutReason == nil }
}

extension Ingredient {
    init(type: BeakerType, amountPerPour: Double, h2o2Variant: H2O2Variant? = nil, temperatureC: Double? = nil) {
        self.type = type
        self.amountPerPour = amountPerPour
        self.h2o2Variant = h2o2Variant
        self.pourCount = 0
        self.proximityState = .far
        self.grayOutReason = nil
        self.color = nil
        self.temperatureC = temperatureC
    }
}

// MARK: - Mixing Beaker

struct MixingBeaker: Equatable {
    let side: StationSide
    var proximityState: ARProximityState = .far
    var mixtureState: MixtureState = .idle
    var contents: [BeakerType] = []
}

// MARK: - Station State

struct StationState: Equatable {
    let side: StationSide
    var ingredients: [Ingredient]
    var mixingBeaker: MixingBeaker
}

// MARK: - Foam Physics Model

struct FoamModel: Equatable {
    var concentration: Double = 0
    var volumeL: Double = 0
    var soapTbsp: Double = 0
    var yeastTbsp: Double = 0
    var tempC: Double = 25
    var containerRadiusCm: Double = 5
    var containerVolumeL: Double = 1

    func volume(at t: Double) -> Double {
        // TODO: plug in real foam growth curve
        0
    }

    func height(at t: Double) -> Double {
        // TODO: derive from volume and container radius
        0
    }
}

// MARK: - Experiment State

struct ExperimentState: Equatable {
    var stationA: StationState
    var stationB: StationState
    var volcanoState: VolcanoState = .locked
    var reactionState: ReactionState = .idle
    var reactionStartedAt: Date? = nil
    var foam: FoamModel = FoamModel()
}

extension ExperimentState {
    static func initial() -> ExperimentState {
        ExperimentState(
            stationA: StationState(
                side: .sideA,
                ingredients: [
                    Ingredient(type: .h2o2, amountPerPour: 50, h2o2Variant: .threePct),
                    Ingredient(type: .h2o2, amountPerPour: 50, h2o2Variant: .fivePct),
                    Ingredient(type: .h2o2, amountPerPour: 50, h2o2Variant: .sevenPct),
                    Ingredient(type: .soap, amountPerPour: 1),
                    Ingredient(type: .foodColoring, amountPerPour: 1)
                ],
                mixingBeaker: MixingBeaker(side: .sideA)
            ),
            stationB: StationState(
                side: .sideB,
                ingredients: [
                    Ingredient(type: .water, amountPerPour: 50, temperatureC: 25),
                    Ingredient(type: .yeast, amountPerPour: 1)
                ],
                mixingBeaker: MixingBeaker(side: .sideB)
            )
        )
    }

    subscript(side: StationSide) -> StationState {
        get { side == .sideA ? stationA : stationB }
        set { if side == .sideA { stationA = newValue } else { stationB = newValue } }
    }
}
