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
            // TODO: trigger PoC pour animation here before detaching.
            store.send(.ar(.releaseIngredient(side, index)))
            detachCarriedEntity()
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

    // True when every selectable ingredient has at least one pour. Unselected h2o2 variants
    // (.depleted with pourCount == 0) are skipped — they were never interactable.
    func allIngredientsPoured(side: StationSide) -> Bool {
        !store.state.experiment[side].ingredients.contains {
            $0.pourCount == 0 && $0.grayOutReason != .depleted
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
