//
//  ReactionViewModel.swift
//  JataYuk
//
//  ViewModel — single source of truth for the experiment state.
//  Drives motion detection (tilt for H₂O₂/Soap, shake for Yeast) and
//  publishes state changes consumed by both SwiftUI views and ARViewCoordinator.
//

import Foundation
import CoreMotion
import Combine

final class ReactionViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isPlaced: Bool = false
    @Published var selectedBeaker: BeakerType? = nil
    @Published var pouredIngredients: Set<BeakerType> = []
    @Published var reactionState: ReactionState = .idle
    @Published var isPouring: Bool = false

    /// Set in confirmPour() before isPouring flips true so the AR coordinator
    /// knows which entity to animate.
    @Published private(set) var lastPouredBeaker: BeakerType? = nil

    /// Volume of each liquid (0.1–1.0). Scales the eruption magnitude.
    @Published var h2o2Amount: Double = 0.5
    @Published var soapAmount: Double = 0.5

    /// Signals the AR scene to reset all entities.
    let resetPublisher = PassthroughSubject<Void, Never>()

    // Yeast is locked until both H₂O₂ and Soap have been poured.
    var isYeastLocked: Bool {
        !pouredIngredients.contains(.h2o2) || !pouredIngredients.contains(.soap)
    }

    var foamSegments: Int { Int(10 + (h2o2Amount + soapAmount) * 13) }

    // MARK: - Beaker Interaction

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
        baselineGravityX = nil
        resetPublisher.send()
    }

    // MARK: - CoreMotion

    private let motionManager = CMMotionManager()
    private var lastGestureDate: Date = .distantPast
    private var selectionDate: Date = .distantPast
    private var baselineGravityX: Double? = nil
    private let tiltDelta: Double = 0.38           // required delta from baseline (~22°)
    private let shakeThreshold: Double = 1.60      // g-force units
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

    func stopMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
    }

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
            let delta = motion.gravity.x - (baselineGravityX ?? 0)
            triggered = abs(delta) > tiltDelta
        }

        if triggered {
            lastGestureDate = now
            confirmPour()
        }
    }

    // MARK: - Private

    private func updateReactionState() {
        let p = pouredIngredients
        if p.contains(.yeast) {
            if p.contains(.h2o2) && p.contains(.soap) {
                reactionState = .success
            } else if p.contains(.h2o2) {
                reactionState = .failed
            }
        } else if !p.isEmpty {
            reactionState = .mixing
        }
    }
}
