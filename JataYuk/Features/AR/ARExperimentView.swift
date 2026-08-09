//
//  ARExperimentView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import SwiftUI
import Combine
import CoreMotion

struct ARExperimentView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    #if DEBUG
    @StateObject private var pitchObserver = PitchObserver()
    #endif

    var body: some View {
        ZStack {
            ARViewContainer(store: store)
                .ignoresSafeArea()

            VStack {
                placementStatusView
                Spacer()
                #if DEBUG
                debugTiltOverlay
                #endif
                debugControlsView
            }
            .padding()
        }
        #if DEBUG
        .onDisappear { pitchObserver.stop() }
        #endif
    }

    // Temporary placement phase indicator
    @ViewBuilder
    private var placementStatusView: some View {
        let label: String = {
            switch store.state.ar.placement {
            case .placingVolcano: return "Place the volcano"
            case .placingSideA:   return "Place Side A bench"
            case .placingSideB:   return "Place Side B bench"
            case .allPlaced:      return "Experiment ready"
            }
        }()
        Text(label)
            .font(.headline)
            .foregroundColor(.white)
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
    }

    private var debugControlsView: some View {
        HStack(spacing: 16) {
            if store.state.ar.placement == .allPlaced {
                Button("End") {
                    store.send(.navigate(to: .end))
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            Button("?") {
                store.send(.overlay(.showInstruction))
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    // MARK: - Debug Tilt Overlay

    #if DEBUG
    @ViewBuilder
    private var debugTiltOverlay: some View {
        if store.state.ar.placement == .allPlaced {
            let soap = store.state.experiment.stationA.ingredients[3]
            let isHolding = soap.proximityState == .inHand

            VStack(alignment: .leading, spacing: 6) {
                Text("DEBUG — Tilt Test")
                    .font(.caption.bold())

                // Live pitch readout — confirm sensor is running
                Text("Pitch: \(pitchObserver.pitchDeg, specifier: "%.1f")°  (fires pour at >45°)")
                    .font(.caption.monospaced())
                    .foregroundColor(pitchObserver.pitchDeg > 45 ? .yellow : .white)

                // Pour progress for soap (index 3 on side A)
                Text("Soap pours: \(soap.pourCount) / \(Ingredient.maxPours)")
                    .font(.caption.monospaced())

                // Mixture state advances to .prepared on first pour, .mixed on shake
                Text("Mixture: \(String(describing: store.state.experiment.stationA.mixingBeaker.mixtureState))")
                    .font(.caption.monospaced())

                HStack(spacing: 12) {
                    Button(isHolding ? "Holding ✓" : "Hold Soap") {
                        store.send(.ar(.pickupIngredient(.sideA, 3)))
                    }
                    .buttonStyle(.bordered)
                    .tint(isHolding ? .green : .yellow)
                    .disabled(isHolding)

                    Button("Release") {
                        store.send(.ar(.releaseIngredient(.sideA, 3)))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(!isHolding)
                }
            }
            .foregroundColor(.white)
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
    }
    #endif
}

// MARK: - PitchObserver (debug only)

#if DEBUG
private final class PitchObserver: ObservableObject {
    @Published var pitchDeg: Double = 0
    private let manager = CMMotionManager()

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 10.0
        // Callback runs on .main queue, so @Published updates land on the right thread.
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.pitchDeg = abs(motion.attitude.pitch) * 180 / .pi
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
#endif
