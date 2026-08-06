//
//  ReactionViewModel.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 04/08/26.
//

import Foundation
import CoreMotion
import Combine

final class ReactionViewModel: ObservableObject {

    @Published var isPlaced = false
    @Published var selectedBeaker: BeakerType? = nil
    @Published var pouredIngredients: Set<BeakerType> = []
    @Published var reactionState: ReactionState = .idle
    @Published var isPouring = false
    @Published private(set) var lastPouredBeaker: BeakerType? = nil
    @Published var h2o2Amount: Double = 0.5
    @Published var soapAmount: Double = 0.5

    // MARK: - Chemistry inputs (drive FoamModel; set via the sliders panel)
    @Published var concentration: Int = 6    // % w/v   (3, 6, 9)
    @Published var volumeML: Int      = 100  // mL      (100…500)
    @Published var soapTbsp: Int      = 1    // tbsp    (1…5)
    @Published var yeastTbsp: Int     = 1    // tbsp    (1…5)
    @Published var temperatureC: Int  = 30   // °C      (20…50)

    let resetPublisher = PassthroughSubject<Void, Never>()

    var isYeastLocked: Bool {
        !pouredIngredients.contains(.h2o2) || !pouredIngredients.contains(.soap)
    }

    var foamSegments: Int { Int(10 + (h2o2Amount + soapAmount) * 13) }

    func selectBeaker(_ type: BeakerType) {
        guard !isPouring, !pouredIngredients.contains(type) else { return }
        guard !(type == .yeast && isYeastLocked) else { return }
        selectedBeaker = (selectedBeaker == type) ? nil : type
        if selectedBeaker != nil {
            baselineGravityX = nil
            selectionDate = Date()
            lastGestureDate = Date()
        }
    }

    func deselectBeaker() {
        guard !isPouring else { return }
        selectedBeaker = nil
        baselineGravityX = nil
    }

    func confirmPour() {
        guard let beaker = selectedBeaker, !isPouring else { return }
        isPouring = true
        lastPouredBeaker = beaker
        pouredIngredients.insert(beaker)
        selectedBeaker = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.isPouring = false
            self?.updateReactionState()
        }
    }

    func reset() {
        selectedBeaker = nil
        pouredIngredients = []
        lastPouredBeaker = nil
        reactionState = .idle
        isPouring = false
        h2o2Amount = 0.5
        soapAmount = 0.5
        // Chemistry sliders keep their values across a reset so the user can
        // rerun the same recipe; comment these back in to reset them too:
        // concentration = 6; volumeML = 100; soapTbsp = 1; yeastTbsp = 1; temperatureC = 30
        baselineGravityX = nil
        resetPublisher.send()
    }

    // MARK: - Motion

    private let motionManager = CMMotionManager()
    private var lastGestureDate: Date = .distantPast
    private var selectionDate: Date = .distantPast
    private var baselineGravityX: Double? = nil
    private let tiltDelta = 0.38
    private let shakeThreshold = 1.60
    private let gestureDebounce: TimeInterval = 0.7
    private let pickupGracePeriod: TimeInterval = 0.9

    func startMotionDetection() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.processMotion(motion)
        }
    }

    func stopMotionDetection() { motionManager.stopDeviceMotionUpdates() }

    private func processMotion(_ motion: CMDeviceMotion) {
        guard let selected = selectedBeaker, !isPouring else { return }
        let now = Date()

        if baselineGravityX == nil {
            baselineGravityX = motion.gravity.x
            return
        }

        guard now.timeIntervalSince(selectionDate) >= pickupGracePeriod else { return }
        guard now.timeIntervalSince(lastGestureDate) >= gestureDebounce else { return }

        let triggered: Bool
        if selected.useShake {
            let a = motion.userAcceleration
            triggered = (a.x*a.x + a.y*a.y + a.z*a.z) > shakeThreshold * shakeThreshold
        } else {
            triggered = abs(motion.gravity.x - (baselineGravityX ?? 0)) > tiltDelta
        }

        if triggered { lastGestureDate = now; confirmPour() }
    }

    private func updateReactionState() {
        let p = pouredIngredients
        guard p.contains(.yeast) else { if !p.isEmpty { reactionState = .mixing }; return }
        reactionState = (p.contains(.h2o2) && p.contains(.soap)) ? .success : .failed
    }
}
