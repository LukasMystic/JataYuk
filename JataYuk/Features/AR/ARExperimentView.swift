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

    @State private var waterTempC: Double = 25

    #if DEBUG
    @StateObject private var motionObserver = MotionDebugObserver()
    @State private var isDebugExpanded = false
    #endif

    var body: some View {
        ZStack {
            ARViewContainer(
                store: store,
                sessionResetToken: store.state.ar.sessionResetToken,
                isPaused: store.state.ar.isPaused
            )
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
            
            //Added - Instruction Bubble
            VStack {
                InstructionView(step: InstructionDerivation.currentInstruction(for: store.state))
                    .padding(.top, 150)
                Spacer()
            }
            .padding(.horizontal, 60)
            
            VStack{
                Spacer()
                
                HStack {
                    inHandInfoButton
                    Spacer()
                }
            }
            .padding(.leading, 24)
            .padding(.bottom, 24)

            // Interact button pinned to the right edge, vertically centered
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    interactButton
                    Spacer()
                }
            }
            .padding(.trailing, 20)

            // Pause button — top-right corner, only after all items placed
            if store.state.ar.placement == .allPlaced && !store.state.ar.isPaused {
                VStack {
                    HStack {
                        Spacer()
                        Button {store.send(.ar(.pauseSession))}
                        label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 20, weight: .semibold))
                                //.foregroundStyle(.black)
                                .frame(width: 57, height: 57)
                        }
                        .buttonStyle(.plain)
                        .background {Capsule()
                                .fill(Color(red: 0.949, green: 0.729, blue: 0.216).opacity(0.85)
                                ).glassEffect()
                        }
                        .contentShape(Capsule())
                    }
                    Spacer()
                }
                .padding()
            }

            // Pause overlay
            if store.state.ar.isPaused {
                PauseOverlayView(store: store)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: store.state.ar.isPaused)
            }
        }
        #if DEBUG
        .onDisappear { motionObserver.stop() }
        #endif
    }

    // MARK: - Placement status

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

    // MARK: - Interact button (Hold / Release / Tilt prompt / Beaker lock-in / Shake prompt)

    @ViewBuilder
    private var interactButton: some View {
        if store.state.ar.placement == .allPlaced {
            if let (side, index) = heldIngredientSideIndex {
                let ingredient = store.state.experiment[side].ingredients[index]
                // Holding an ingredient — Release + optional tilt prompt + thermostat for water.
                VStack(spacing: 10) {
                    // Thermostat — only when holding water.
                    if ingredient.type == .water {
                        waterThermostat(side: side, index: index)
                    }

                    if isNearMixingBeaker {
                        Text("Tilt to pour! ↕")
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.55))
                            .cornerRadius(6)
                    }
                    Button("Release") {
                        store.send(.ar(.releaseIngredient(side, index)))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: isNearMixingBeaker)

            } else if let side = heldBeakerSide {
                // Locked in to beaker — prompt player to physically shake the device.
                VStack(spacing: 6) {
                    Text("Shake to mix! 〜")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55))
                        .cornerRadius(6)
                    Button("Release") {
                        store.send(.ar(.mixingBeakerProximityChanged(side, .far)))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .transition(.scale.combined(with: .opacity))

            } else if let side = mixableBeakerSide {
                // Near a ready-to-mix beaker — Interact locks in; physical shake then mixes.
                Button("Interact") {
                    store.send(.ar(.mixingBeakerProximityChanged(side, .inHand)))
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .transition(.scale.combined(with: .opacity))

            } else if store.state.experiment.volcanoState == .highlighted {
                // Both beakers mixed — prompt player to interact with the volcano.
                Button("Interact") {
                    store.send(.ar(.interactWithVolcano))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .transition(.scale.combined(with: .opacity))

            } else {
                // Default — always show Hold, disabled (grey) when nothing is highlighted.
                let highlighted = highlightedIngredient
                Button("Hold") {
                    if let (side, index) = highlighted {
                        store.send(.ar(.pickupIngredient(side, index)))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(highlighted != nil ? .green : .gray)
                .disabled(highlighted == nil)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Water thermostat (vertical, right side, shown while water is in hand)

    @ViewBuilder
    private func waterThermostat(side: StationSide, index: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(waterTempC))°C")
                .font(.caption.bold())
                .foregroundColor(.cyan)
                .monospacedDigit()
            // Rotate a normal slider -90° to make it vertical.
            // frame(width:) before rotation sets the slider's natural length (= visual height).
            Slider(value: $waterTempC, in: 20...90, step: 1)
                .frame(width: 150)
                .rotationEffect(.degrees(-90))
                .frame(width: 44, height: 150)
                .tint(.cyan)
            Text("20°")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .onChange(of: waterTempC) { _, newVal in
            store.send(.ar(.adjustWaterTemperature(newVal)))
        }
        .onAppear {
            // Sync slider to any previously stored temperature.
            if let stored = store.state.experiment[side].ingredients[index].temperatureC {
                waterTempC = stored
            }
        }
    }

    // MARK: - Info button (shows ingredient info while holding)

    @ViewBuilder
    private var inHandInfoButton: some View {
        if let (side, index) = heldIngredientSideIndex {
            let ing = store.state.experiment[side].ingredients[index]
            Button {
                store.send(.overlay(.showItemInfo(ing.type)))
            }label:{
                Image(systemName: "info")
                    .font(.system(size: 20, weight: .semibold))
                    //.foregroundStyle(.black)
                    .frame(width: 57, height: 57)
                    }
                    .buttonStyle(.plain)
                    .background {
                        Capsule().fill(Color(red: 0.949,green: 0.729,blue: 0.216)
                                .opacity(0.85)
                            )
                            .glassEffect()
                    }
                    .contentShape(Capsule())
                    .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Computed helpers

    private var heldIngredientSideIndex: (StationSide, Int)? {
        for side in [StationSide.sideA, StationSide.sideB] {
            if let index = store.state.experiment[side].ingredients.firstIndex(where: { $0.proximityState == .inHand }) {
                return (side, index)
            }
        }
        return nil
    }

    private var highlightedIngredient: (StationSide, Int)? {
        for side in [StationSide.sideA, StationSide.sideB] {
            if let index = store.state.experiment[side].ingredients.firstIndex(where: { $0.proximityState == .highlighted }) {
                return (side, index)
            }
        }
        return nil
    }

    private var isNearMixingBeaker: Bool {
        for side in [StationSide.sideA, StationSide.sideB] {
            let station = store.state.experiment[side]
            guard station.ingredients.contains(where: { $0.proximityState == .inHand }) else { continue }
            let beaker = station.mixingBeaker.proximityState
            return beaker == .highlighted || beaker == .inHand
        }
        return false
    }

    // Returns the side whose beaker the player has locked into (Interact was tapped).
    private var heldBeakerSide: StationSide? {
        for side in [StationSide.sideA, StationSide.sideB] {
            if store.state.experiment[side].mixingBeaker.proximityState == .inHand { return side }
        }
        return nil
    }

    // Returns the side whose beaker is ready to mix and the player is near but not yet locked in.
    // Only matches .highlighted (not .inHand) — the inHand case is handled by heldBeakerSide above.
    private var mixableBeakerSide: StationSide? {
        for side in [StationSide.sideA, StationSide.sideB] {
            let station = store.state.experiment[side]
            let beaker = station.mixingBeaker
            guard beaker.mixtureState == .prepared else { continue }
            guard beaker.proximityState == .highlighted else { continue }
            let allPoured = !station.ingredients.contains { $0.pourCount == 0 && $0.grayOutReason != .depleted }
            if allPoured { return side }
        }
        return nil
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

//            Button("?") {
//                store.send(.overlay(.showInstruction))
//            }
//            .buttonStyle(.bordered)
//            .tint(.white)
        }
    }

    // MARK: - Debug Motion Overlay

    #if DEBUG
    @ViewBuilder
    private var debugMotionOverlay: some View {
        if store.state.ar.placement == .allPlaced {
            let beakerA = store.state.experiment.stationA.mixingBeaker
            let beakerB = store.state.experiment.stationB.mixingBeaker
            let holdingBeakerA = beakerA.proximityState == .inHand
            let holdingBeakerB = beakerB.proximityState == .inHand
            let holdingAnyBeaker = holdingBeakerA || holdingBeakerB

            VStack(alignment: .leading, spacing: 6) {
                // Header row with collapse toggle
                HStack {
                    Text("DEBUG — Motion Test")
                        .font(.caption.bold())
                    Spacer()
                    Button(isDebugExpanded ? "Hide ▲" : "Show ▼") {
                        isDebugExpanded.toggle()
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.7))
                }

                if isDebugExpanded {

                Divider().overlay(.white.opacity(0.4))

                // ── Tilt / Pour ──
                Text("TILT (pour)")
                    .font(.caption2.bold()).foregroundColor(.white.opacity(0.6))
                Text("Pitch: \(motionObserver.pitchDeg, specifier: "%.1f")°  (fires at >30°)")
                    .font(.caption.monospaced())
                    .foregroundColor(motionObserver.pitchDeg > 45 ? .yellow : .white)
                Text("Held: \(heldIngredientSideIndex.map { "\($0.0 == .sideA ? "A" : "B")[\($0.1)]" } ?? "none")  Near beaker: \(isNearMixingBeaker ? "yes" : "no")")
                    .font(.caption.monospaced())

                HStack(spacing: 10) {
                    if let (side, index) = highlightedIngredient {
                        let typeStr = String(describing: store.state.experiment[side].ingredients[index].type)
                        Button("Hold \(typeStr)") {
                            store.send(.ar(.pickupIngredient(side, index)))
                        }
                        .buttonStyle(.bordered).tint(.yellow)
                        .disabled(heldIngredientSideIndex != nil || holdingAnyBeaker)
                    } else {
                        Button("Hold (none highlighted)") { }
                            .buttonStyle(.bordered).disabled(true)
                    }

                    if let (side, index) = heldIngredientSideIndex {
                        Button("Release") {
                            store.send(.ar(.releaseIngredient(side, index)))
                        }
                        .buttonStyle(.bordered).tint(.orange)
                    }
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
                    .disabled(holdingAnyBeaker || heldIngredientSideIndex != nil)

                    Button(holdingBeakerB ? "Beaker B ✓" : "Hold B") {
                        store.send(.ar(.mixingBeakerProximityChanged(.sideB, .inHand)))
                    }
                    .buttonStyle(.bordered).tint(holdingBeakerB ? .green : .cyan)
                    .disabled(holdingAnyBeaker || heldIngredientSideIndex != nil)

                    Button("Release") {
                        store.send(.ar(.mixingBeakerProximityChanged(.sideA, .far)))
                        store.send(.ar(.mixingBeakerProximityChanged(.sideB, .far)))
                    }
                    .buttonStyle(.bordered).tint(.orange)
                    .disabled(!holdingAnyBeaker)
                }

                Divider().overlay(.white.opacity(0.4))

                // ── Proximity (live from ProximitySystem) ──
                Text("PROXIMITY (live)")
                    .font(.caption2.bold()).foregroundColor(.white.opacity(0.6))
                ForEach(Array(store.state.experiment.stationA.ingredients.enumerated()), id: \.offset) { i, ing in
                    let typeStr  = String(describing: ing.type)
                    let stateStr = String(describing: ing.proximityState)
                    Text("A[\(i)] \(typeStr): \(stateStr)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ing.proximityState == .inHand ? .green : ing.proximityState == .highlighted ? .yellow : .white)
                }
                ForEach(Array(store.state.experiment.stationB.ingredients.enumerated()), id: \.offset) { i, ing in
                    let typeStr  = String(describing: ing.type)
                    let stateStr = String(describing: ing.proximityState)
                    Text("B[\(i)] \(typeStr): \(stateStr)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(ing.proximityState == .inHand ? .green : ing.proximityState == .highlighted ? .yellow : .white)
                }
                let beakerAState = String(describing: beakerA.proximityState)
                let beakerBState = String(describing: beakerB.proximityState)
                Text("Beaker A: \(beakerAState)  |  Beaker B: \(beakerBState)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                } // end if isDebugExpanded
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
