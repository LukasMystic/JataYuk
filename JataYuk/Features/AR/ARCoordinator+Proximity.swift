//
//  ARCoordinator+Proximity.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 10/08/26.
//

import ARKit
import RealityKit
import UIKit
import Combine

extension ARCoordinator {

    static let inHandDistanceM: Float      = 0.15
    static let highlightedDistanceM: Float = 0.35

    func subscribeToProximityUpdates() {
        guard let arView else { return }
        var frameCount = 0
        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            frameCount += 1
            guard frameCount % 10 == 0 else { return }  // ~6 Hz
            Task { @MainActor [weak self] in self?.updateProximity() }
        }
        .store(in: &cancellables)
    }

    func updateProximity() {
        guard let arView else { return }

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
            if let model = cand.entity as? ModelEntity {
                applyIngredientVisual(model, state: .far, type: ingredient.type, isGrayedOut: true)
            }
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

        if let model = cand.entity as? ModelEntity {
            applyIngredientVisual(model, state: newState, type: ingredient.type, isGrayedOut: false)
        }

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

        if let model = entity as? ModelEntity {
            let isReadyToMix = beakerState.mixtureState == .prepared && allIngredientsPoured(side: comp.side)
            applyBeakerVisual(model, proximity: newState, mixtureState: beakerState.mixtureState, isReadyToMix: isReadyToMix)
        }

        guard newState != current else { return }
        store.send(.ar(.mixingBeakerProximityChanged(comp.side, newState)))
    }

    // MARK: - Visual helpers

    func applyIngredientVisual(_ entity: ModelEntity, state: ARProximityState, type: BeakerType, isGrayedOut: Bool) {
        if isGrayedOut {
            entity.model?.materials = [SimpleMaterial(color: UIColor.systemGray.withAlphaComponent(0.4), isMetallic: false)]
            entity.scale = .one
            return
        }
        let base = ingredientColor(type)
        switch state {
        case .far:
            entity.model?.materials = [SimpleMaterial(color: base, isMetallic: false)]
            entity.scale = .one
        case .highlighted:
            entity.model?.materials = [SimpleMaterial(color: lightened(base), isMetallic: false)]
            entity.scale = SIMD3(repeating: 1.18)
        case .inHand:
            entity.model?.materials = [UnlitMaterial(color: base)]
            entity.scale = .one
        }
    }

    func applyBeakerVisual(_ model: ModelEntity, proximity: ARProximityState, mixtureState: MixtureState, isReadyToMix: Bool) {
        switch mixtureState {
        case .mixed:
            model.model?.materials = [SimpleMaterial(color: UIColor.systemGreen.withAlphaComponent(0.85), isMetallic: false)]
            model.scale = .one
        case .idle:
            model.model?.materials = [SimpleMaterial(color: UIColor.systemGray.withAlphaComponent(0.5), isMetallic: false)]
            model.scale = .one
        case .prepared:
            switch proximity {
            case .far:
                let color: UIColor = isReadyToMix
                    ? UIColor.systemGreen.withAlphaComponent(0.45)
                    : UIColor.white.withAlphaComponent(0.6)
                model.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
                model.scale = .one
            case .highlighted:
                if isReadyToMix {
                    model.model?.materials = [UnlitMaterial(color: .systemGreen)]
                    model.scale = SIMD3(repeating: 1.18)
                } else {
                    model.model?.materials = [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.9), isMetallic: false)]
                    model.scale = SIMD3(repeating: 1.1)
                }
            case .inHand:
                model.model?.materials = [UnlitMaterial(color: isReadyToMix ? .systemGreen : .white)]
                model.scale = .one
            }
        }
    }

    func syncVolcanoVisual() {
        guard let entity = volcanoEntity else { return }
        switch store.state.experiment.volcanoState {
        case .locked:
            entity.model?.materials = [SimpleMaterial(color: UIColor.systemGray.withAlphaComponent(0.4), isMetallic: false)]
            entity.scale = .one
        case .highlighted:
            entity.model?.materials = [UnlitMaterial(color: .systemOrange)]
            entity.scale = SIMD3(repeating: 1.06)
        case .reacting, .done:
            entity.model?.materials = [SimpleMaterial(color: UIColor.systemOrange.withAlphaComponent(0.9), isMetallic: false)]
            entity.scale = .one
        }
    }

    func syncAllIngredientVisuals() {
        for anchor in [stationAAnchor, stationBAnchor].compactMap({ $0 }) {
            for child in anchor.children {
                guard let comp = child.components[IngredientComponent.self],
                      let model = child as? ModelEntity else { continue }
                let ingredient = store.state.experiment[comp.side].ingredients[comp.ingredientIndex]
                applyIngredientVisual(model, state: ingredient.proximityState, type: ingredient.type, isGrayedOut: !ingredient.isInteractive)
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

    // Blends a color 40% toward white for highlighted entities.
    func lightened(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * 0.6 + 0.4, green: g * 0.6 + 0.4, blue: b * 0.6 + 0.4, alpha: a)
    }
}
