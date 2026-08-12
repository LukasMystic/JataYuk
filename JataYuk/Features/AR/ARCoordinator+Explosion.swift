//
//  ARCoordinator+Explosion.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 12/08/26.
//

import RealityKit

extension ARCoordinator {

    // Called once after allPlaced — creates the FoamSPHSystem anchored to the volcano.
    func setupExplosionSystem() {
        guard let volcanoAnchor else { return }
        foamSPHSystem = FoamSPHSystem(
            container: volcanoAnchor,
            geometry: ContainerGeometry()
        )
    }

    func tearDownExplosionSystem() {
        foamSPHSystem?.reset()
        foamSPHSystem = nil
    }
}
