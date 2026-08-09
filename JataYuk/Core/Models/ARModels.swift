//
//  ARModels.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

// MARK: - AR Availability

enum ARAvailability: Equatable {
    case available
    case unavailable
    case permissionDenied
}

// MARK: - Placement Phase

enum ARStationPlacement: Equatable {
    case placingVolcano
    case placingSideA
    case placingSideB
    case allPlaced
}

// MARK: - Proximity

enum ARProximityState: Equatable {
    case far
    case highlighted
    case inHand
}

// MARK: - Station

enum StationSide: Equatable {
    case sideA
    case sideB
}

// MARK: - Gray Out

enum GrayOutReason: Equatable {
    case anotherInHand
    case depleted
    case stationLocked
}

// MARK: - AR State

struct ARState: Equatable {
    var availability: ARAvailability = .available
    var placement: ARStationPlacement = .placingVolcano
    var activeStation: StationSide? = nil
}
