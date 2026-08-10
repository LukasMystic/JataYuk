//
//  ARComponents.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import RealityKit

// Tags an entity as an interactive ingredient and links it back to the store index.
struct IngredientComponent: Component {
    let side: StationSide
    let ingredientIndex: Int
}

// Tags an entity as an interactive mixing beaker.
struct MixingBeakerComponent: Component {
    let side: StationSide
}
