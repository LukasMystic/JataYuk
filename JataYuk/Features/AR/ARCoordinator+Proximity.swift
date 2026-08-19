//
//  ARCoordinator+Proximity.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import ARKit
import RealityKit
import Combine

extension ARCoordinator {

    static let inHandDistanceM: Float      = 0.15
    static let highlightedDistanceM: Float = 0.20

    func subscribeToProximityUpdates() {
        guard let arView else { return }
        var frameCount = 0
        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            frameCount += 1
            let dt = Float(event.deltaTime)
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Drive the ECS/TCA foam pipeline every frame.
                explosionStore?.tick(deltaTime: dt)
                // Proximity checks run at ~6 Hz to avoid per-frame store churn.
                guard frameCount % 10 == 0 else { return }
                updateProximity()
            }
        }
        .store(in: &cancellables)
    }

    func updateProximity() {
        guard let arView else { return }

        // Detect volcano state changes and start / sync the explosion store.
        let volcanoState = store.state.experiment.volcanoState
        if volcanoState != lastSeenVolcanoState {
            if volcanoState == .reacting {
                startExplosionPipeline()
            } else {
                syncExplosionVolcanoState(volcanoState)
            }
            lastSeenVolcanoState = volcanoState
        }

        syncVolcanoVisual()

        // Detect external releases (e.g. debug button) — carried entity lives on cameraAnchor.
        if let carried = carriedEntity,
           let comp = carried.components[IngredientComponent.self] {
            let ingredient = store.state.experiment[comp.side].ingredients[comp.ingredientIndex]
            if ingredient.proximityState != .inHand { detachCarriedEntity() }
        }

        let cameraPos = arView.cameraTransform.translation
        var ingredientCandidates: [(entity: Entity, comp: IngredientComponent, distance: Float)] = []

        for anchor in [stationAAnchor, stationBAnchor].compactMap({ $0 }) {
            for child in anchor.children {
                if let comp = child.components[IngredientComponent.self] {
                    let dist = simd_distance(cameraPos, child.position(relativeTo: nil))
                    ingredientCandidates.append((child, comp, dist))
                } else if let comp = child.components[MixingBeakerComponent.self] {
                    updateBeakerProximity(entity: child, comp: comp, cameraPos: cameraPos)
                }
            }
        }

        // Only the single closest interactive entity gets highlighted.
        // Suppress all highlighting while locked into a beaker.
        let soloHighlight: Entity? = anythingInHand() ? nil : ingredientCandidates
            .filter { cand in
                let ing = store.state.experiment[cand.comp.side].ingredients[cand.comp.ingredientIndex]
                return ing.isInteractive && ing.proximityState != .inHand && cand.distance < Self.highlightedDistanceM
            }
            .min(by: { $0.distance < $1.distance })?.entity

        for cand in ingredientCandidates {
            updateIngredientProximity(cand: cand, soloHighlight: soloHighlight)
        }
    }

    func updateIngredientProximity(
        cand: (entity: Entity, comp: IngredientComponent, distance: Float),
        soloHighlight: Entity?
    ) {
        let ingredient = store.state.experiment[cand.comp.side].ingredients[cand.comp.ingredientIndex]

        guard ingredient.isInteractive else {
            applyIngredientVisual(cand.entity, state: .far, isGrayedOut: true)
            return
        }

        let newState: ARProximityState
        if ingredient.proximityState == .inHand {
            if cand.entity !== carriedEntity { attachEntityToCamera(cand.entity) }
            newState = .inHand
        } else if cand.entity === soloHighlight {
            newState = .highlighted
        } else {
            newState = .far
        }

        applyIngredientVisual(cand.entity, state: newState, isGrayedOut: false)

        guard newState != ingredient.proximityState else { return }
        store.send(.ar(.ingredientProximityChanged(cand.comp.side, cand.comp.ingredientIndex, newState)))
    }

    func updateBeakerProximity(entity: Entity, comp: MixingBeakerComponent, cameraPos: SIMD3<Float>) {
        let distance = simd_distance(cameraPos, entity.position(relativeTo: nil))
        let beakerState = store.state.experiment[comp.side].mixingBeaker
        let current = beakerState.proximityState

        let newState: ARProximityState
        if current == .inHand {
            newState = distance > Self.highlightedDistanceM ? .far : .inHand
        } else if distance < Self.highlightedDistanceM {
            newState = .highlighted
        } else {
            newState = .far
        }

        let isReadyToMix = beakerState.mixtureState == .prepared && allIngredientsPoured(side: comp.side)
        // Highlight this beaker whenever the user is holding an ingredient from the same side —
        // acts as a pour-target indicator even before they're physically close to it.
        let isHoldingIngredientForSide = store.state.experiment[comp.side].ingredients
            .contains { $0.proximityState == .inHand }
        applyBeakerVisual(entity, proximity: newState, mixtureState: beakerState.mixtureState,
                          isReadyToMix: isReadyToMix, isTargetBeaker: isHoldingIngredientForSide)

        guard newState != current else { return }
        store.send(.ar(.mixingBeakerProximityChanged(comp.side, newState)))
    }

    // MARK: - Visual helpers

    func applyIngredientVisual(_ entity: Entity, state: ARProximityState, isGrayedOut: Bool) {
        if isGrayedOut {
            entity.components.set(OpacityComponent(opacity: 0.35))
            entity.scale = .one
            return
        }
        entity.components.remove(OpacityComponent.self)
        switch state {
        case .far:
            entity.scale = .one
        case .highlighted:
            entity.scale = SIMD3(repeating: 1.18)
        case .inHand:
            entity.scale = .one
        }
    }

    func applyBeakerVisual(_ entity: Entity, proximity: ARProximityState, mixtureState: MixtureState,
                           isReadyToMix: Bool, isTargetBeaker: Bool = false) {
        // When the user is carrying an ingredient for this side, pulse the beaker as a pour target.
        if isTargetBeaker && mixtureState != .mixed {
            entity.components.remove(OpacityComponent.self)
            entity.scale = SIMD3(repeating: 1.1)
            return
        }
        switch mixtureState {
        case .mixed:
            entity.components.remove(OpacityComponent.self)
            entity.scale = .one
        case .idle:
            entity.components.set(OpacityComponent(opacity: 0.85))
            entity.scale = .one
        case .prepared:
            entity.components.remove(OpacityComponent.self)
            switch proximity {
            case .far:
                entity.scale = .one
            case .highlighted:
                entity.scale = SIMD3(repeating: isReadyToMix ? 1.18 : 1.1)
            case .inHand:
                entity.scale = .one
            }
        }
    }

    func syncVolcanoVisual() {
        guard let entity = volcanoEntity else { return }
        switch store.state.experiment.volcanoState {
        case .locked:
            entity.scale = .one
        case .highlighted:
            entity.scale = SIMD3(repeating: 1.06)
        case .reacting, .done:
            entity.scale = .one
        }
    }

    func syncAllIngredientVisuals() {
        for anchor in [stationAAnchor, stationBAnchor].compactMap({ $0 }) {
            for child in anchor.children {
                guard let comp = child.components[IngredientComponent.self] else { continue }
                let ingredient = store.state.experiment[comp.side].ingredients[comp.ingredientIndex]
                applyIngredientVisual(child, state: ingredient.proximityState, isGrayedOut: !ingredient.isInteractive)
            }
        }
    }

    // Returns true when any ingredient or beaker is held, preventing simultaneous holds.
    func anythingInHand() -> Bool {
        for side in [StationSide.sideA, StationSide.sideB] {
            if store.state.experiment[side].ingredients.contains(where: { $0.proximityState == .inHand }) { return true }
            if store.state.experiment[side].mixingBeaker.proximityState == .inHand { return true }
        }
        return false
    }
}
