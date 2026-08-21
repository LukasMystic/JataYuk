//
//  InstructionDerivation.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 05/08/26.
//

import Foundation

enum InstructionDerivation {

    // MARK: - Current Instruction

    static func currentInstruction(for state: RootState) -> InstructionStep? {
        switch state.currentRoute {
        case .loading, .onboarding, .main, .end:
            return nil

        case .ar:
            return arInstruction(for: state)
        }
    }

    // MARK: - AR

    private static func arInstruction(for state: RootState) -> InstructionStep {
        if let placementStep = placementInstruction(for: state.ar.placement) {
            return placementStep
        }

        if let volcanoStep = volcanoInstruction(for: state.experiment) {
            return volcanoStep
        }

        guard let side = state.ar.activeStation else {
            return InstructionCopy.step(for: .introSolutions)
        }

        return stationInstruction(
            for: side,
            in: state.experiment
        )
    }

    // MARK: - Placement

    private static func placementInstruction(
        for placement: ARStationPlacement
    ) -> InstructionStep? {

        switch placement {
        case .placingVolcano:
            return InstructionCopy.step(for: .placeVolcano)

        case .placingSideA:
            return InstructionCopy.step(for: .placeSideA)

        case .placingSideB:
            return InstructionCopy.step(for: .placeSideB)

        case .allPlaced:
            return nil
        }
    }

    // MARK: - Ordered Ingredient Slots

    private struct Slot {
        let type: BeakerType
        let indices: [Int]
    }

    private static func slots(
        for side: StationSide,
        in experiment: ExperimentState
    ) -> [Slot] {

        let station = experiment[side]

        switch side {

        case .sideA:
            let h2o2 = station.ingredients.indices.filter {
                station.ingredients[$0].type == .h2o2
            }

            let soap = station.ingredients.indices.filter {
                station.ingredients[$0].type == .soap
            }

            let color = station.ingredients.indices.filter {
                station.ingredients[$0].type == .foodColoring
            }

            return [
                Slot(type: .h2o2, indices: h2o2),
                Slot(type: .soap, indices: soap),
                Slot(type: .foodColoring, indices: color)
            ]

        case .sideB:
            let yeast = station.ingredients.indices.filter {
                station.ingredients[$0].type == .yeast
            }

            let water = station.ingredients.indices.filter {
                station.ingredients[$0].type == .water
            }

            return [
                Slot(type: .yeast, indices: yeast),
                Slot(type: .water, indices: water)
            ]
        }
    }

    private static func heldIngredient(
        in slots: [Slot],
        station: StationState
    ) -> (Slot, Int)? {

        for slot in slots {
            if let idx = slot.indices.first(where: {
                station.ingredients[$0].proximityState == .inHand
            }) {
                return (slot, idx)
            }
        }

        return nil
    }

    private static func highlightedIngredient(
        in slots: [Slot],
        station: StationState
    ) -> (Slot, Int)? {

        for slot in slots {
            if let idx = slot.indices.first(where: {
                station.ingredients[$0].proximityState == .highlighted
            }) {
                return (slot, idx)
            }
        }

        return nil
    }

    // MARK: - Station Instructions

    private static func stationInstruction(
        for side: StationSide,
        in experiment: ExperimentState
    ) -> InstructionStep {

        let station = experiment[side]
        let beaker = station.mixingBeaker
        let slotList = slots(
            for: side,
            in: experiment
        )

        // 1. This side's beaker already mixed.
        if beaker.mixtureState == .mixed {
            return InstructionCopy.step(for: .sideComplete)
        }

        // 2. Holding the beaker, prepared — prompt to shake.
        if beaker.proximityState == .inHand,
           beaker.mixtureState == .prepared {

            return InstructionCopy.step(for: .shakeToMix)
        }

        // 3. Currently holding an ingredient.
        //
        if let (_, heldIdx) = heldIngredient(
            in: slotList,
            station: station
        ) {

            let ing = station.ingredients[heldIdx]

            // The ingredient has already been poured during
            // this pickup. Offer another pour or stop if depleted.
            if ing.hasPouredThisPickup {
                return InstructionCopy.step(
                    for: ing.isDepleted ? .maxPoursReached: .offerMore
                )
            }

            switch beaker.proximityState {

            case .far:
                return InstructionCopy.step(for: .bringToBeaker)

            case .highlighted, .inHand:
                return InstructionCopy.step(for: .pourIngredient)
            }
        }

        // 4. Near (highlighted) an ingredient, not held.
        //
        // This is checked before the beaker-ready state so the
        // user can choose another ingredient after the beaker
        // has already been prepared.
        if let (_, nearIdx) = highlightedIngredient(
            in: slotList,
            station: station
        ) {

            let ing = station.ingredients[nearIdx]

            if ing.pourCount == 0 {
                return nearIngredientInstruction(
                    for: ing.type
                )
            }

            return InstructionCopy.step(
                for: ing.isDepleted
                    ? .maxPoursReached
                    : .offerMore
            )
        }

        // 5. Beaker ready to pick up — every slot has at least one pour.
        if beaker.mixtureState == .prepared,
           beaker.proximityState == .highlighted {

            let allSlotsPoured = slotList.allSatisfy { slot in
                slot.indices.contains {
                    station.ingredients[$0].pourCount > 0
                }
            }

            if allSlotsPoured {
                return InstructionCopy.step(
                    for: side == .sideA
                        ? .readyToMixSideA
                        : .readyToMixSideB
                )
            }
        }

        // 6. Nothing held/highlighted — but a slot already has
        // progress: keep offering.
        if let lastProgressed = slotList.last(where: { slot in
            slot.indices.contains {
                station.ingredients[$0].pourCount > 0
            }
        }) {

            let anyDepleted = lastProgressed.indices.contains {
                station.ingredients[$0].isDepleted
            }

            return InstructionCopy.step(
                for: anyDepleted
                    ? .maxPoursReached
                    : .offerMore
            )
        }

        // 7. No progress anywhere on this side, nothing
        // currently held/highlighted.
        switch side {

        case .sideA:
            return InstructionCopy.step(
                for: experiment.hasSeenSideAIntro
                    ? .moveCloserToBench
                    : .sideAIntro
            )

        case .sideB:
            return InstructionCopy.step(
                for: experiment.hasSeenSideBIntro
                    ? .moveCloserToBench
                    : .sideBIntro
            )
        }
    }

    // MARK: - Near Ingredient

    private static func nearIngredientInstruction(
        for type: BeakerType
    ) -> InstructionStep {

        switch type {

        case .h2o2:
            return InstructionCopy.step(for: .h2o2Near)

        case .soap:
            return InstructionCopy.step(for: .soapNear)

        case .foodColoring:
            return InstructionCopy.step(for: .foodColoringNear)

        case .yeast:
            return InstructionCopy.step(for: .yeastNear)

        case .water:
            return InstructionCopy.step(for: .waterNear)
        }
    }

    // MARK: - Volcano

    private static func volcanoInstruction(
        for experiment: ExperimentState
    ) -> InstructionStep? {

        let bothMixed =
            experiment.stationA.mixingBeaker.mixtureState == .mixed &&
            experiment.stationB.mixingBeaker.mixtureState == .mixed

        guard bothMixed else {
            return nil
        }

        switch experiment.volcanoState {

        case .locked:
            return InstructionCopy.step(for: .noSolutionsYet)

        case .highlighted:
            return InstructionCopy.step(for: .interactVolcano)

        case .reacting:
            return InstructionCopy.step(for: .reacting)

        case .done:
            return InstructionCopy.step(for: .reactionDone)
        }
    }
}
