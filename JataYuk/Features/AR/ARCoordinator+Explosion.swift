//
//  ARCoordinator+Explosion.swift
//  JataYuk
//
//  Wires the ECS/TCA hybrid explosion pipeline to the volcano AR anchor.
//  RootReducer is unchanged — observes experiment.volcanoState / foam from root store.
//

import RealityKit
import UIKit

extension ARCoordinator {

    func setupExplosionSystem() {
        guard let volcanoAnchor else { return }

        tearDownExplosionSystem()

        let foam = Entity()
        foam.name = "FoamEntity"
        volcanoAnchor.addChild(foam)
        foamEntity = foam

        if let volcanoEntity {
            volcanoEntity.components[VolcanoComponent.self] = VolcanoComponent(
                state: store.state.experiment.volcanoState
            )
        }

        let emission = EmissionSystem()
        let sph = SPHSystem(container: foam, geometry: ContainerGeometry())
        emissionSystem = emission
        sphSystem = sph

        let simulation = ExplosionSimulationClient.live(
            foamEntity: foam,
            emissionSystem: emission,
            sphSystem: sph
        )
        let environment = ExplosionEnvironment(
            simulation: simulation,
            effects: .live(simulation: simulation)
        )
        explosionStore = ExplosionStore(environment: environment)
    }

    func tearDownExplosionSystem() {
        explosionStore?.send(.reset)
        explosionStore = nil
        emissionSystem = nil
        sphSystem = nil
        foamEntity?.removeFromParent()
        foamEntity = nil
    }

    func startExplosionPipeline() {
        guard let explosionStore else { return }
        guard explosionStore.state.phase == .idle else { return }

        if let volcanoEntity {
            volcanoEntity.components[VolcanoComponent.self] = VolcanoComponent(state: .reacting)
        }

        // Blend foam color from all poured food colorings using additive RGB mixing.
        // Normalising by the max channel keeps colors vivid (e.g. R+G = bright yellow).
        let pours = store.state.experiment.foam.foodColorPours
        if !pours.isEmpty {
            let r = CGFloat(pours[0, default: 0])
            let g = CGFloat(pours[1, default: 0])
            let b = CGFloat(pours[2, default: 0])
            let maxChannel = max(r, g, b)
            if maxChannel > 0 {
                let color = UIColor(red: r / maxChannel, green: g / maxChannel, blue: b / maxChannel, alpha: 1.0)
                sphSystem?.setFoamColor(color)
            }
        }

        explosionStore.send(.pipelineStarted(store.state.experiment.foam))
    }

    func syncExplosionVolcanoState(_ volcanoState: VolcanoState) {
        if let volcanoEntity {
            volcanoEntity.components[VolcanoComponent.self] = VolcanoComponent(state: volcanoState)
        }
        explosionStore?.send(.volcanoStateChanged(volcanoState))
    }
}
