//
//  SloshSettings.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import Foundation

@Observable
final class SloshSettings {
    var viscosity: Float = 0.5
    var dynamicVertices: Float = 0.5
    var defaultHeight: Float = 0.55
    var canDecrement = false
    var decrementValue: Float = 0.05
    private(set) var decrementCount = 0

    func decrement() {
        guard canDecrement else { return }
        decrementCount += 1
    }
}
