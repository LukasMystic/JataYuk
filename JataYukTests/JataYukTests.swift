//
//  JataYukTests.swift
//  JataYukTests
//
//  Created by Stanley Pratama Teguh on 09/08/26.
//

@testable import JataYuk
import Testing

// MARK: - Helpers

private func apply(_ action: RootAction, to state: inout RootState) {
    _ = rootReducer(state: &state, action: action, environment: RootEnvironment())
}

// MARK: - Navigation

@Suite("Navigation")
struct NavigationTests {

    @Test func navigateToARChangesRoute() {
        var state = RootState()
        apply(.navigate(to: .ar), to: &state)
        #expect(state.currentRoute == .ar)
    }

    @Test func navigateToEndChangesRoute() {
        var state = RootState()
        apply(.navigate(to: .end), to: &state)
        #expect(state.currentRoute == .end)
    }
}

// MARK: - Placement

@Suite("Placement")
struct PlacementTests {

    @Test func firstAdvanceMovesToSideA() {
        var state = RootState()
        apply(.ar(.placementAdvanced), to: &state)
        #expect(state.ar.placement == .placingSideA)
    }

    @Test func fullSequenceReachesAllPlaced() {
        var state = RootState()
        apply(.ar(.placementAdvanced), to: &state)
        apply(.ar(.placementAdvanced), to: &state)
        apply(.ar(.placementAdvanced), to: &state)
        #expect(state.ar.placement == .allPlaced)
    }

    @Test func extraAdvanceAfterAllPlacedIsIgnored() {
        var state = RootState()
        for _ in 0..<4 { apply(.ar(.placementAdvanced), to: &state) }
        #expect(state.ar.placement == .allPlaced)
    }
}

// MARK: - Pour Ingredient

@Suite("Pour Ingredient")
struct PourIngredientTests {
    // Side A layout: [0] h2o2 3%, [1] h2o2 5%, [2] h2o2 7%, [3] soap, [4] foodColoring
    // Side B layout: [0] water, [1] yeast

    @Test func pourIncrementsPourCount() {
        var state = RootState()
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        #expect(state.experiment.stationA.ingredients[3].pourCount == 1)
    }

    @Test func pourAppendsToMixingBeakerContents() {
        var state = RootState()
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        #expect(state.experiment.stationA.mixingBeaker.contents == [.soap])
    }

    @Test func firstPourSetsMixtureStateToPrepared() {
        var state = RootState()
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        #expect(state.experiment.stationA.mixingBeaker.mixtureState == .prepared)
    }

    @Test func subsequentPoursKeepMixtureStatePrepared() {
        var state = RootState()
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        #expect(state.experiment.stationA.mixingBeaker.mixtureState == .prepared)
    }

    @Test func pourAccumulatesSoapTbsp() {
        var state = RootState()
        // soap amountPerPour = 1 tbsp
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        apply(.ar(.pourIngredient(.sideA, 3)), to: &state)
        #expect(state.experiment.foam.soapTbsp == 2.0)
    }

    @Test func pourAccumulatesH2O2VolumeL() {
        var state = RootState()
        // h2o2 amountPerPour = 50 mL → 0.05 L per pour
        apply(.ar(.pourIngredient(.sideA, 0)), to: &state)
        apply(.ar(.pourIngredient(.sideA, 0)), to: &state)
        #expect(abs(state.experiment.foam.volumeL - 0.10) < 1e-9)
    }

    @Test func pourAccumulatesYeastTbsp() {
        var state = RootState()
        // yeast amountPerPour = 1 tbsp
        apply(.ar(.pourIngredient(.sideB, 1)), to: &state)
        #expect(state.experiment.foam.yeastTbsp == 1.0)
    }

    @Test func foodColoringDoesNotAffectFoamModel() {
        var state = RootState()
        apply(.ar(.pourIngredient(.sideA, 4)), to: &state)
        #expect(state.experiment.foam.volumeL == 0)
        #expect(state.experiment.foam.soapTbsp == 0)
        #expect(state.experiment.foam.yeastTbsp == 0)
    }

    @Test func waterDoesNotAffectFoamModel() {
        var state = RootState()
        apply(.ar(.pourIngredient(.sideB, 0)), to: &state)
        #expect(state.experiment.foam.volumeL == 0)
    }

    @Test func fifthPourDepletesIngredient() {
        var state = RootState()
        for _ in 0..<5 { apply(.ar(.pourIngredient(.sideA, 3)), to: &state) }
        #expect(state.experiment.stationA.ingredients[3].isDepleted)
        #expect(state.experiment.stationA.ingredients[3].grayOutReason == .depleted)
    }

    @Test func sixthPourIsIgnoredAfterDepletion() {
        var state = RootState()
        for _ in 0..<6 { apply(.ar(.pourIngredient(.sideA, 3)), to: &state) }
        #expect(state.experiment.stationA.ingredients[3].pourCount == 5)
    }
}

// MARK: - Pickup and Release

@Suite("Pickup and Release")
struct PickupReleaseTests {

    @Test func pickupSetsIngredientInHand() {
        var state = RootState()
        apply(.ar(.pickupIngredient(.sideA, 3)), to: &state)
        #expect(state.experiment.stationA.ingredients[3].proximityState == .inHand)
        #expect(state.ar.activeStation == .sideA)
    }

    @Test func pickupGreysOutOtherIngredientsOnSameSide() {
        var state = RootState()
        apply(.ar(.pickupIngredient(.sideA, 3)), to: &state)
        for i in state.experiment.stationA.ingredients.indices where i != 3 {
            #expect(state.experiment.stationA.ingredients[i].grayOutReason == .anotherInHand)
        }
    }

    @Test func pickupLocksEntireOppositeStation() {
        var state = RootState()
        apply(.ar(.pickupIngredient(.sideA, 3)), to: &state)
        for ingredient in state.experiment.stationB.ingredients {
            #expect(ingredient.grayOutReason == .stationLocked)
        }
    }

    @Test func releaseClearsAnotherInHandGrayOut() {
        var state = RootState()
        apply(.ar(.pickupIngredient(.sideA, 3)), to: &state)
        apply(.ar(.releaseIngredient(.sideA, 3)), to: &state)
        for ingredient in state.experiment.stationA.ingredients {
            #expect(ingredient.grayOutReason != .anotherInHand)
        }
    }

    @Test func releaseClearsStationLockedOnOpposite() {
        var state = RootState()
        apply(.ar(.pickupIngredient(.sideA, 3)), to: &state)
        apply(.ar(.releaseIngredient(.sideA, 3)), to: &state)
        for ingredient in state.experiment.stationB.ingredients {
            #expect(ingredient.grayOutReason != .stationLocked)
        }
    }

    @Test func releasePreservesDepletedGrayOut() {
        var state = RootState()
        // Deplete soap (index 3), then pick up and release a different ingredient
        for _ in 0..<5 { apply(.ar(.pourIngredient(.sideA, 3)), to: &state) }
        apply(.ar(.pickupIngredient(.sideA, 0)), to: &state)
        apply(.ar(.releaseIngredient(.sideA, 0)), to: &state)
        #expect(state.experiment.stationA.ingredients[3].grayOutReason == .depleted)
    }

    @Test func releaseResetsActiveStation() {
        var state = RootState()
        apply(.ar(.pickupIngredient(.sideA, 3)), to: &state)
        apply(.ar(.releaseIngredient(.sideA, 3)), to: &state)
        #expect(state.ar.activeStation == nil)
    }
}

// MARK: - H2O2 Variant Selection

@Suite("H2O2 Variant Selection")
struct H2O2SelectionTests {

    @Test func selectVariantGreysOutUnselectedVariants() {
        var state = RootState()
        apply(.ar(.selectH2O2Variant(.fivePct)), to: &state)
        let ings = state.experiment.stationA.ingredients
        // [0] = threePct, [1] = fivePct, [2] = sevenPct
        #expect(ings[0].grayOutReason == .depleted)
        #expect(ings[1].grayOutReason == nil)
        #expect(ings[2].grayOutReason == .depleted)
    }

    @Test func selectVariantSetsFoamConcentration() {
        var state = RootState()
        apply(.ar(.selectH2O2Variant(.sevenPct)), to: &state)
        #expect(state.experiment.foam.concentration == 7.0)
    }

    @Test func selectThreePctSetsConcentrationToThree() {
        var state = RootState()
        apply(.ar(.selectH2O2Variant(.threePct)), to: &state)
        #expect(state.experiment.foam.concentration == 3.0)
    }
}

// MARK: - Water Temperature

@Suite("Water Temperature")
struct WaterTemperatureTests {

    @Test func adjustTemperatureUpdatesIngredientAndFoam() {
        var state = RootState()
        apply(.ar(.adjustWaterTemperature(37.0)), to: &state)
        let waterIndex = state.experiment.stationB.ingredients.firstIndex { $0.type == .water }!
        #expect(state.experiment.stationB.ingredients[waterIndex].temperatureC == 37.0)
        #expect(state.experiment.foam.tempC == 37.0)
    }

    @Test func adjustTemperatureDoesNotAffectSideA() {
        var state = RootState()
        apply(.ar(.adjustWaterTemperature(50.0)), to: &state)
        for ingredient in state.experiment.stationA.ingredients {
            #expect(ingredient.temperatureC == nil)
        }
    }
}

// MARK: - Shake and Volcano

@Suite("Shake and Volcano")
struct ShakeVolcanoTests {

    @Test func shakeOneSideSetsItMixed() {
        var state = RootState()
        apply(.ar(.shakeMixingBeaker(.sideA)), to: &state)
        #expect(state.experiment.stationA.mixingBeaker.mixtureState == .mixed)
    }

    @Test func shakeOneSideAloneDoesNotUnlockVolcano() {
        var state = RootState()
        apply(.ar(.shakeMixingBeaker(.sideA)), to: &state)
        #expect(state.experiment.volcanoState == .locked)
    }

    @Test func shakeBothSidesHighlightsVolcano() {
        var state = RootState()
        apply(.ar(.shakeMixingBeaker(.sideA)), to: &state)
        apply(.ar(.shakeMixingBeaker(.sideB)), to: &state)
        #expect(state.experiment.volcanoState == .highlighted)
    }

    @Test func interactWhenHighlightedStartsReaction() {
        var state = RootState()
        apply(.ar(.shakeMixingBeaker(.sideA)), to: &state)
        apply(.ar(.shakeMixingBeaker(.sideB)), to: &state)
        apply(.ar(.interactWithVolcano), to: &state)
        #expect(state.experiment.volcanoState == .reacting)
        #expect(state.experiment.reactionState == .reacting)
        #expect(state.experiment.reactionStartedAt != nil)
    }

    @Test func interactWhenLockedIsIgnored() {
        var state = RootState()
        apply(.ar(.interactWithVolcano), to: &state)
        #expect(state.experiment.volcanoState == .locked)
        #expect(state.experiment.reactionState == .idle)
    }

    @Test func reactionTickBefore30sKeepsReacting() {
        var state = RootState()
        apply(.ar(.shakeMixingBeaker(.sideA)), to: &state)
        apply(.ar(.shakeMixingBeaker(.sideB)), to: &state)
        apply(.ar(.interactWithVolcano), to: &state)
        apply(.ar(.reactionTick(29)), to: &state)
        #expect(state.experiment.reactionState == .reacting)
        #expect(state.experiment.volcanoState == .reacting)
    }

    @Test func reactionTickAt30sCompletesReaction() {
        var state = RootState()
        apply(.ar(.shakeMixingBeaker(.sideA)), to: &state)
        apply(.ar(.shakeMixingBeaker(.sideB)), to: &state)
        apply(.ar(.interactWithVolcano), to: &state)
        apply(.ar(.reactionTick(30)), to: &state)
        #expect(state.experiment.reactionState == .done)
        #expect(state.experiment.volcanoState == .done)
    }

    @Test func reactionTickWhenIdleIsIgnored() {
        var state = RootState()
        apply(.ar(.reactionTick(30)), to: &state)
        #expect(state.experiment.reactionState == .idle)
    }
}

// MARK: - Overlay

@Suite("Overlay")
struct OverlayTests {

    @Test func showInstructionSetsVisible() {
        var state = RootState()
        apply(.overlay(.showInstruction), to: &state)
        #expect(state.isInstructionVisible)
    }

    @Test func hideInstructionClearsVisible() {
        var state = RootState()
        apply(.overlay(.showInstruction), to: &state)
        apply(.overlay(.hideInstruction), to: &state)
        #expect(!state.isInstructionVisible)
    }

    @Test func markInstructionsSeenSetsFlag() {
        var state = RootState()
        apply(.overlay(.markInstructionsSeen), to: &state)
        #expect(state.hasSeenInstructions)
    }

    @Test func showItemInfoSetsTypeAndVisible() {
        var state = RootState()
        apply(.overlay(.showItemInfo(.soap)), to: &state)
        #expect(state.isItemInfoVisible)
        #expect(state.activeInfoItem == .soap)
    }

    @Test func hideItemInfoClearsTypeAndVisible() {
        var state = RootState()
        apply(.overlay(.showItemInfo(.soap)), to: &state)
        apply(.overlay(.hideItemInfo), to: &state)
        #expect(!state.isItemInfoVisible)
        #expect(state.activeInfoItem == nil)
    }
}
