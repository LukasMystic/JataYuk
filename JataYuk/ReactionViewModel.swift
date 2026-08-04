//
//  ReactionViewModel.swift
//  JataYuk
//

import Foundation
import CoreMotion
import Combine

// MARK: - Beaker Type

enum BeakerType: String, CaseIterable, Equatable, Hashable {
    case h2o2, soap, yeast

    var displayName: String {
        switch self {
        case .h2o2:  return "H₂O₂"
        case .soap:  return "Dish Soap"
        case .yeast: return "Yeast"
        }
    }

    var sfSymbol: String {
        switch self {
        case .h2o2:  return "drop.fill"
        case .soap:  return "bubbles.and.sparkles.fill"
        case .yeast: return "microbe"
        }
    }

    /// Yeast is poured by shaking; the other two by tilting.
    var useShake: Bool { self == .yeast }

    var gestureDescription: String {
        useShake ? "Shake your iPad!" : "Tilt Left or Right to Pour"
    }
}

// MARK: - Reaction State

enum ReactionState: Equatable {
    case idle
    case mixing     // at least one ingredient poured; reaction not yet triggered
    case failed     // H₂O₂ + Yeast without Soap → fizzle
    case success    // all three → eruption
}

// MARK: - ViewModel

final class ReactionViewModel: ObservableObject {

    // MARK: Published State

    @Published var isPlaced: Bool = false
    @Published var selectedBeaker: BeakerType? = nil
    @Published var pouredIngredients: Set<BeakerType> = []
    @Published var reactionState: ReactionState = .idle
    @Published var isPouring: Bool = false

    /// Tracks the most recently poured beaker so the AR coordinator knows which
    /// entity to animate. Set in confirmPour() before isPouring turns true.
    @Published private(set) var lastPouredBeaker: BeakerType? = nil

    /// Volume of each liquid ingredient (0.1–1.0). Scales the eruption magnitude.
    @Published var h2o2Amount: Double = 0.5
    @Published var soapAmount: Double = 0.5

    /// Signals the AR scene to reset all entities.
    let resetPublisher = PassthroughSubject<Void, Never>()

    // Yeast is locked until both H₂O₂ and Dish Soap have been poured,
    // enforcing the correct reaction order for the success outcome.
    var isYeastLocked: Bool {
        !pouredIngredients.contains(.h2o2) || !pouredIngredients.contains(.soap)
    }

    var foamSegments: Int { Int(10 + (h2o2Amount + soapAmount) * 13) }  // 10–36

    // MARK: - Beaker Interaction

    /// Selects (picks up) a beaker, or deselects it if it was already selected.
    func selectBeaker(_ type: BeakerType) {
        guard !isPouring, !pouredIngredients.contains(type) else { return }
        guard !(type == .yeast && isYeastLocked) else { return }
        selectedBeaker = (selectedBeaker == type) ? nil : type
        if selectedBeaker != nil {
            // Snapshot the resting gravity baseline and block gesture detection
            // for a grace period so the tap motion doesn't immediately pour.
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

    /// Called by motion detection when the correct pour gesture is confirmed.
    /// Marks the beaker as poured, then evaluates the reaction after the
    /// pour animation completes.
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
        resetPublisher.send()
    }

    // MARK: - CoreMotion

    private let motionManager = CMMotionManager()
    private var lastGestureDate: Date = .distantPast
    private var selectionDate: Date = .distantPast
    private var baselineGravityX: Double? = nil   // gravity.x at the moment of pick-up
    private let tiltDelta: Double = 0.38           // required delta from baseline (~22°)
    private let shakeThreshold: Double = 1.60      // g-force units (user acceleration)
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

    /// Runs at 20 Hz. Checks for tilt (H₂O₂ / Soap) or shake (Yeast) when a
    /// beaker is selected, and calls confirmPour() on detection.
    private func processMotion(_ motion: CMDeviceMotion) {
        guard let selected = selectedBeaker, !isPouring else { return }
        let now = Date()

        // On the very first update after pick-up, record the resting gravity so
        // we measure a *change* from that angle rather than an absolute tilt.
        if baselineGravityX == nil {
            baselineGravityX = motion.gravity.x
            return
        }

        // Grace period: ignore gestures immediately after picking up a beaker.
        guard now.timeIntervalSince(selectionDate) >= pickupGracePeriod else { return }
        guard now.timeIntervalSince(lastGestureDate) >= gestureDebounce else { return }

        let triggered: Bool
        if selected.useShake {
            let a = motion.userAcceleration
            triggered = (a.x*a.x + a.y*a.y + a.z*a.z) > shakeThreshold * shakeThreshold
        } else {
            // Pour fires when the user tilts far enough from their resting angle.
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
                reactionState = .failed     // yeast + H₂O₂, no soap → fizzle
            }
        } else if !p.isEmpty {
            reactionState = .mixing
        }
    }
}
