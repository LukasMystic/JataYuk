//
//  ARCoordinator+Explosion.swift
//  JataYuk
//
//  Wires the ECS/TCA hybrid explosion pipeline to the volcano AR anchor.
//  RootReducer is unchanged — observes experiment.volcanoState / foam from root store.
//

import RealityKit

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

        explosionStore.send(.pipelineStarted(store.state.experiment.foam))
    }

    func syncExplosionVolcanoState(_ volcanoState: VolcanoState) {
        if let volcanoEntity {
            volcanoEntity.components[VolcanoComponent.self] = VolcanoComponent(state: volcanoState)
        }
        explosionStore?.send(.volcanoStateChanged(volcanoState))
    }
}
