//
//  BeakerType.swift
//  JataYuk
//
//  Model — represents one of the three source ingredients.
//

import Foundation

enum BeakerType: String, CaseIterable, Equatable, Hashable {

    case h2o2, soap, yeast

    var displayName: String {
        switch self {
        case .h2o2:  return "H₂O₂"
        case .soap:  return "Dish Soap"
        case .yeast: return "Yeast"
        }
    }

    var sfSymbol: String {
        switch self {
        case .h2o2:  return "drop.fill"
        case .soap:  return "bubbles.and.sparkles.fill"
        case .yeast: return "microbe"
        }
    }

    /// Yeast is poured by shaking the iPad; the other two by tilting.
    var useShake: Bool { self == .yeast }

    var gestureDescription: String {
        useShake ? "Shake your iPad!" : "Tilt Left or Right to Pour"
    }
}
