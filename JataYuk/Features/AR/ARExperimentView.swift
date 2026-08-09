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
    @StateObject private var motionObserver = MotionDebugObserver()
    #endif

    var body: some View {
        ZStack {
            ARViewContainer(store: store)
                .ignoresSafeArea()

            VStack {
                placementStatusView
                Spacer()
                #if DEBUG
                debugMotionOverlay
                #endif
                debugControlsView
            }
            .padding()
        }
        #if DEBUG
        .onDisappear { motionObserver.stop() }
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

    // MARK: - Debug Motion Overlay

    #if DEBUG
    @ViewBuilder
    private var debugMotionOverlay: some View {
        if store.state.ar.placement == .allPlaced {
            let soap    = store.state.experiment.stationA.ingredients[3]
            let beakerA = store.state.experiment.stationA.mixingBeaker
            let beakerB = store.state.experiment.stationB.mixingBeaker
            let holdingSoap    = soap.proximityState == .inHand
            let holdingBeakerA = beakerA.proximityState == .inHand
            let holdingBeakerB = beakerB.proximityState == .inHand
            let holdingAnyBeaker = holdingBeakerA || holdingBeakerB

            VStack(alignment: .leading, spacing: 6) {
                Text("DEBUG — Motion Test")
                    .font(.caption.bold())

                Divider().overlay(.white.opacity(0.4))

                // ── Tilt / Pour ──
                Text("TILT (pour)")
                    .font(.caption2.bold()).foregroundColor(.white.opacity(0.6))
                Text("Pitch: \(motionObserver.pitchDeg, specifier: "%.1f")°  (fires at >45°)")
                    .font(.caption.monospaced())
                    .foregroundColor(motionObserver.pitchDeg > 45 ? .yellow : .white)
                Text("Soap pours: \(soap.pourCount) / \(Ingredient.maxPours)")
                    .font(.caption.monospaced())
                Text("Side A mixture: \(String(describing: beakerA.mixtureState))")
                    .font(.caption.monospaced())

                HStack(spacing: 10) {
                    Button(holdingSoap ? "Holding Soap ✓" : "Hold Soap") {
                        store.send(.ar(.pickupIngredient(.sideA, 3)))
                    }
                    .buttonStyle(.bordered).tint(holdingSoap ? .green : .yellow)
                    .disabled(holdingSoap || holdingAnyBeaker)   // can't hold both

                    Button("Release Soap") {
                        store.send(.ar(.releaseIngredient(.sideA, 3)))
                    }
                    .buttonStyle(.bordered).tint(.orange)
                    .disabled(!holdingSoap)
                }

                Divider().overlay(.white.opacity(0.4))

                // ── Shake / Mix ──
                Text("SHAKE (mix)")
                    .font(.caption2.bold()).foregroundColor(.white.opacity(0.6))
                Text("Accel: \(motionObserver.accelMag, specifier: "%.2f")g  (fires at >1.0g)")
                    .font(.caption.monospaced())
                    .foregroundColor(motionObserver.accelMag > 1.0 ? .yellow : .white)
                Text("Side A mixture: \(String(describing: beakerA.mixtureState))")
                    .font(.caption.monospaced())
                Text("Side B mixture: \(String(describing: beakerB.mixtureState))")
                    .font(.caption.monospaced())

                HStack(spacing: 10) {
                    Button(holdingBeakerA ? "Beaker A ✓" : "Hold A") {
                        store.send(.ar(.mixingBeakerProximityChanged(.sideA, .inHand)))
                    }
                    .buttonStyle(.bordered).tint(holdingBeakerA ? .green : .cyan)
                    .disabled(holdingAnyBeaker || holdingSoap)   // can't hold both

                    Button(holdingBeakerB ? "Beaker B ✓" : "Hold B") {
                        store.send(.ar(.mixingBeakerProximityChanged(.sideB, .inHand)))
                    }
                    .buttonStyle(.bordered).tint(holdingBeakerB ? .green : .cyan)
                    .disabled(holdingAnyBeaker || holdingSoap)   // can't hold both

                    Button("Release") {
                        store.send(.ar(.mixingBeakerProximityChanged(.sideA, .far)))
                        store.send(.ar(.mixingBeakerProximityChanged(.sideB, .far)))
                    }
                    .buttonStyle(.bordered).tint(.orange)
                    .disabled(!holdingAnyBeaker)
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

// MARK: - MotionDebugObserver (debug only)

#if DEBUG
private final class MotionDebugObserver: ObservableObject {
    @Published var pitchDeg: Double = 0
    @Published var accelMag: Double = 0   // userAcceleration magnitude (gravity removed)
    private let manager = CMMotionManager()

    init() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 10.0
        // Both pitch and userAcceleration come from the same device motion frame.
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            self?.pitchDeg = abs(motion.attitude.pitch) * 180 / .pi
            let a = motion.userAcceleration
            self?.accelMag = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
#endif
