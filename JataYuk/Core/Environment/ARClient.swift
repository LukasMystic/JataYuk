//
//  ARClient.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

// Stub for the AR dependency client.
// Implement in Features/AR once RealityKit scene is wired up.
//
// Responsibilities:
//   - Anchor placement (volcano → bench A → bench B)
//   - ProximitySystem callbacks → .ar(.ingredientProximityChanged) / .ar(.mixingBeakerProximityChanged)
//   - FoamSystem per-frame tick → .ar(.reactionTick)
//   - FlyBackSystem trigger on release
struct ARClient {
}
