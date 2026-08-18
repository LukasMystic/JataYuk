//
//  BottleSceneView.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import RealityKit
import SwiftUI
import simd

struct BottleSceneView: View {
    var motion: MotionSource
    var settings: SloshSettings

    var body: some View {
        GeometryReader { proxy in
            RealityView { content in
                #if targetEnvironment(simulator)
                content.camera = .virtual
                #endif
                if let scene = try? await BottleFactory.makeScene(
                    motion: motion,
                    settings: settings,
                    ar: !Self.isSimulator
                ) {
                    content.add(scene)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let size = proxy.size
                        guard size.width > 0, size.height > 0 else { return }
                        motion.applyDrag(
                            normalizedOffset: SIMD2(
                                Float((value.location.x / size.width) * 2 - 1),
                                Float((value.location.y / size.height) * 2 - 1)
                            )
                        )
                    }
                    .onEnded { _ in motion.endDrag() }
            )
        }
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}

#Preview {
    BottleSceneView(motion: MotionSource(), settings: SloshSettings())
        .ignoresSafeArea()
}
