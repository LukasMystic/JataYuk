//
//  ARCoordinator+Motion.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import RealityKit

extension ARCoordinator {

    func startTiltMonitoring() {
        motionClient.startTiltMonitoring { [weak self] in
            guard let self,
                  let (side, index) = activePourTarget() else { return }
            let type = store.state.experiment[side].ingredients[index].type   // added — capture before dispatch
            let pourEntity = carriedEntity                                     // added — capture before detach
            store.send(.ar(.pourIngredient(side, index)))
            playPourSFX(for: type, entity: pourEntity)                         // added
            store.send(.ar(.releaseIngredient(side, index)))
            placebackEntity()
            syncAllIngredientVisuals()
        }
    }

    func startShakeMonitoring() {
        motionClient.startShakeMonitoring { [weak self] in
            guard let self,
                  let side = activeShakerTarget() else { return }
            store.send(.ar(.shakeMixingBeaker(side)))
            if let beaker = beakerEntities[side] {
                animateBeakerMix(beaker)
                playSFX(.mixOrShake, on: beaker)   // added
            }
            store.send(.ar(.mixingBeakerProximityChanged(side, .far)))
            syncAllIngredientVisuals()
            syncVolcanoVisual()
        }
    }

    // Returns the held ingredient's side+index only when the same-side beaker is within reach.
    func activePourTarget() -> (StationSide, Int)? {
        for side in [StationSide.sideA, .sideB] {
            let station = store.state.experiment[side]
            let beaker = station.mixingBeaker.proximityState
            guard beaker == .highlighted || beaker == .inHand else { continue }
            for (i, ingredient) in station.ingredients.enumerated() where ingredient.proximityState == .inHand {
                return (side, i)
            }
        }
        return nil
    }

    // Returns the side whose beaker is locked in, only after all ingredients are poured and it's still prepared.
    func activeShakerTarget() -> StationSide? {
        for side in [StationSide.sideA, .sideB] {
            guard store.state.experiment[side].mixingBeaker.mixtureState == .prepared else { continue }
            guard allIngredientsPoured(side: side) else { continue }
            if store.state.experiment[side].mixingBeaker.proximityState == .inHand {
                return side
            }
        }
        return nil
    }

    // True when every selectable ingredient has at least one pour.
    // Food colorings are treated as a group: one pour from any bottle satisfies all three.
    // Unselected h2o2 variants (.depleted, pourCount == 0) are skipped — never interactable.
    func allIngredientsPoured(side: StationSide) -> Bool {
        let ingredients = store.state.experiment[side].ingredients
        let anyFoodColorPoured = ingredients.contains { $0.type == .foodColoring && $0.pourCount > 0 }
        return !ingredients.contains { ing in
            guard ing.grayOutReason != .depleted else { return false }
            guard ing.pourCount == 0 else { return false }
            // A food coloring bottle with 0 pours is OK as long as another was poured.
            if ing.type == .foodColoring { return !anyFoodColorPoured }
            return true
        }
    }

    // Quick left-right oscillation to visualise the mixing action.
    func animateBeakerMix(_ entity: Entity) {
        let origin = entity.position
        let d: Float = 0.012
        Task {
            for _ in 0..<4 {
                entity.move(
                    to: Transform(translation: origin + SIMD3(d, 0, 0)),
                    relativeTo: entity.parent,
                    duration: 0.05,
                    timingFunction: .easeInOut
                )
                try? await Task.sleep(nanoseconds: 60_000_000)
                entity.move(
                    to: Transform(translation: origin - SIMD3(d, 0, 0)),
                    relativeTo: entity.parent,
                    duration: 0.05,
                    timingFunction: .easeInOut
                )
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
            entity.move(
                to: Transform(translation: origin),
                relativeTo: entity.parent,
                duration: 0.05,
                timingFunction: .easeInOut
            )
        }
    }
}
