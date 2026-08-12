//
//  RootReducer.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation

func rootReducer(state: inout RootState, action: RootAction, environment: RootEnvironment) -> [Effect] {
    switch action {
    case .navigate(let route):
        state.currentRoute = route
        return []
        
    case .overlay(let overlayAction):
        return overlayReducer(state: &state, action: overlayAction)
        
    case .ar(let arAction):
        return arReducer(state: &state, action: arAction)
        
    case .onboarding(let OnboardingAction):
        return OnboardingReducer(
            state: &state,
            action: OnboardingAction,
            environment: environment
        ) //added
    }

}

// MARK: - Overlay

private func overlayReducer(state: inout RootState, action: OverlayAction) -> [Effect] {
    switch action {
    case .showInstruction:
        state.isInstructionVisible = true
    case .hideInstruction:
        state.isInstructionVisible = false
    case .markInstructionsSeen:
        state.hasSeenInstructions = true
    case .showItemInfo(let type):
        state.activeInfoItem = type
        state.isItemInfoVisible = true
    case .hideItemInfo:
        state.activeInfoItem = nil
        state.isItemInfoVisible = false
    }
    return []
}

// MARK: - AR

private func arReducer(state: inout RootState, action: ARAction) -> [Effect] {
    switch action {

    case .placementAdvanced:
        switch state.ar.placement {
        case .placingVolcano: state.ar.placement = .placingSideA
        case .placingSideA:   state.ar.placement = .placingSideB
        case .placingSideB:   state.ar.placement = .allPlaced
        case .allPlaced:      break
        }

    case .ingredientProximityChanged(let side, let index, let proximity):
        guard index < state.experiment[side].ingredients.count else { break }
        state.experiment[side].ingredients[index].proximityState = proximity

    case .mixingBeakerProximityChanged(let side, let proximity):
        state.experiment[side].mixingBeaker.proximityState = proximity

    case .pickupIngredient(let side, let index):
        guard index < state.experiment[side].ingredients.count else { break }
        state.experiment[side].ingredients[index].proximityState = .inHand
        state.ar.activeStation = side
        // gray out all other ingredients on the same side
        for i in state.experiment[side].ingredients.indices where i != index {
            if state.experiment[side].ingredients[i].grayOutReason == nil {
                state.experiment[side].ingredients[i].grayOutReason = .anotherInHand
            }
        }
        // lock the opposite station entirely
        let opp = opposite(side)
        for i in state.experiment[opp].ingredients.indices {
            if state.experiment[opp].ingredients[i].grayOutReason == nil {
                state.experiment[opp].ingredients[i].grayOutReason = .stationLocked
            }
        }

    case .releaseIngredient(let side, let index):
        guard index < state.experiment[side].ingredients.count else { break }
        state.experiment[side].ingredients[index].proximityState = .far
        state.ar.activeStation = nil
        // clear transient reasons — depleted stays depleted
        for i in state.experiment[side].ingredients.indices {
            if state.experiment[side].ingredients[i].grayOutReason == .anotherInHand {
                state.experiment[side].ingredients[i].grayOutReason = nil
            }
        }
        let opp = opposite(side)
        for i in state.experiment[opp].ingredients.indices {
            if state.experiment[opp].ingredients[i].grayOutReason == .stationLocked {
                state.experiment[opp].ingredients[i].grayOutReason = nil
            }
        }

    case .pourIngredient(let side, let index):
        guard index < state.experiment[side].ingredients.count else { break }
        guard !state.experiment[side].ingredients[index].isDepleted else { break }
        let ingredient = state.experiment[side].ingredients[index]
        let type = ingredient.type
        state.experiment[side].ingredients[index].pourCount += 1
        state.experiment[side].mixingBeaker.contents.append(type)
        if state.experiment[side].ingredients[index].isDepleted {
            state.experiment[side].ingredients[index].grayOutReason = .depleted
        }
        if state.experiment[side].mixingBeaker.mixtureState == .idle {
            state.experiment[side].mixingBeaker.mixtureState = .prepared
            // Lock opposite side while this side is mixing; cleared when shake completes.
            // Override transient locks (.stationLocked) but never .depleted — if the
            // opposite side's beaker is already mixed its ingredients are permanently
            // depleted and must not be unlocked later when this shake clears .otherSideMixing.
            let opp = opposite(side)
            for i in state.experiment[opp].ingredients.indices
            where state.experiment[opp].ingredients[i].grayOutReason != .depleted {
                state.experiment[opp].ingredients[i].grayOutReason = .otherSideMixing
            }
        }
        switch type {
        case .h2o2:
            state.experiment.foam.volumeL += ingredient.amountPerPour / 1000
            if let variant = ingredient.h2o2Variant {
                state.experiment.foam.concentration = variant.concentration
            }
            // Deplete sibling h2o2 variants. Override .anotherInHand if needed —
            // at pour time the ingredient being poured is in-hand, making siblings .anotherInHand.
            for i in state.experiment[side].ingredients.indices {
                let ing = state.experiment[side].ingredients[i]
                if ing.type == .h2o2, i != index, ing.grayOutReason != .depleted {
                    state.experiment[side].ingredients[i].grayOutReason = .depleted
                }
            }
        case .soap:    state.experiment.foam.soapTbsp   += ingredient.amountPerPour
        case .yeast:   state.experiment.foam.yeastTbsp  += ingredient.amountPerPour
        case .water, .foodColoring: break
        }

    case .selectH2O2Variant(let variant):
        // permanently gray out the two unselected h2o2 variants
        for i in state.experiment.stationA.ingredients.indices {
            let ing = state.experiment.stationA.ingredients[i]
            if ing.type == .h2o2, ing.h2o2Variant != variant {
                state.experiment.stationA.ingredients[i].grayOutReason = .depleted
            }
        }
        state.experiment.foam.concentration = variant.concentration

    case .adjustWaterTemperature(let temp):
        if let i = state.experiment.stationB.ingredients.firstIndex(where: { $0.type == .water }) {
            state.experiment.stationB.ingredients[i].temperatureC = temp
            state.experiment.foam.tempC = temp
        }

    case .shakeMixingBeaker(let side):
        guard state.experiment[side].mixingBeaker.mixtureState == .prepared else { break }
        state.experiment[side].mixingBeaker.mixtureState = .mixed
        // Lock this side's ingredients permanently — beaker is done.
        for i in state.experiment[side].ingredients.indices {
            state.experiment[side].ingredients[i].grayOutReason = .depleted
        }
        // Unlock the opposite side so it can start mixing next.
        let opp = opposite(side)
        for i in state.experiment[opp].ingredients.indices
        where state.experiment[opp].ingredients[i].grayOutReason == .otherSideMixing {
            state.experiment[opp].ingredients[i].grayOutReason = nil
        }
        if state.experiment.stationA.mixingBeaker.mixtureState == .mixed &&
           state.experiment.stationB.mixingBeaker.mixtureState == .mixed {
            state.experiment.volcanoState = .highlighted
        }

    case .interactWithVolcano:
        guard state.experiment.volcanoState == .highlighted else { break }
        state.experiment.volcanoState = .reacting
        state.experiment.reactionState = .reacting
        state.experiment.reactionStartedAt = Date()

    case .reactionTick(let elapsed):
        guard state.experiment.reactionState == .reacting else { break }
        if elapsed >= 30 {
            state.experiment.volcanoState = .done
            state.experiment.reactionState = .done
        }

    case .resetSession:
        state.ar.placement = .placingVolcano
        state.ar.activeStation = nil
        state.ar.sessionResetToken += 1
        state.experiment = .initial()
    }
    return []
}

// MARK: - Helpers

private func opposite(_ side: StationSide) -> StationSide {
    side == .sideA ? .sideB : .sideA
}
