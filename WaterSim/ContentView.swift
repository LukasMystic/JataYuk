//
//  ContentView.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import SwiftUI

struct ContentView: View {
    @State private var motion = MotionSource()
    @State private var settings = SloshSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            BottleSceneView(motion: motion, settings: settings)
                .ignoresSafeArea()

            SloshControls(settings: settings)
        }
        .persistentSystemOverlays(.hidden)
        .onAppear { motion.start() }
        .onDisappear { motion.stop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                motion.start()
            case .inactive, .background:
                motion.stop()
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
