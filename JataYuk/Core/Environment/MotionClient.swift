//
//  MotionClient.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import Foundation
import CoreMotion

struct MotionClient {
    // Private class so struct copies in RootEnvironment share the same CMMotionManager instance.
    private let handle = Handle()

    private final class Handle {
        let manager = CMMotionManager()
        var isRunning = false
        // Tilt state
        var tiltFired = false
        var onPour: (() -> Void)?
        // Shake state
        var shakeCooldown = false
        var onShake: (() -> Void)?
    }

    // Tilt thresholds (iPad-calibrated: fires at 30°, resets at 20°)
    private static let pourThresholdRad  = 30.0 * .pi / 180.0
    private static let resetThresholdRad = 20.0 * .pi / 180.0
    // Shake threshold: userAcceleration magnitude in g (gravity already removed by device motion)
    private static let shakeThresholdG   = 1.0
    private static let shakeCooldownNs   = UInt64(1_000_000_000)   // 1 second

    // MARK: - Tilt / Pour

    func startTiltMonitoring(onPour: @MainActor @escaping () -> Void) {
        handle.onPour = { Task { @MainActor in onPour() } }
        startLoopIfNeeded()
    }

    func stopTiltMonitoring() {
        handle.onPour = nil
        handle.tiltFired = false
        stopLoopIfIdle()
    }

    // MARK: - Shake

    func startShakeMonitoring(onShake: @MainActor @escaping () -> Void) {
        handle.onShake = { Task { @MainActor in onShake() } }
        startLoopIfNeeded()
    }

    func stopShakeMonitoring() {
        handle.onShake = nil
        handle.shakeCooldown = false
        stopLoopIfIdle()
    }

    // MARK: - Shared 30 Hz device motion loop

    private func startLoopIfNeeded() {
        guard !handle.isRunning, handle.manager.isDeviceMotionAvailable else { return }
        handle.isRunning = true
        handle.manager.deviceMotionUpdateInterval = 1.0 / 30.0
        let pourThreshold  = Self.pourThresholdRad
        let resetThreshold = Self.resetThresholdRad
        let shakeThreshold = Self.shakeThresholdG
        let cooldownNs     = Self.shakeCooldownNs
        handle.manager.startDeviceMotionUpdates(to: .main) { [handle] motion, _ in
            guard let motion else { return }

            // Tilt: pitch > 30° fires pour once; gate resets below 20°
            let pitch = abs(motion.attitude.pitch)
            let isTilted = pitch > pourThreshold
            if isTilted, !handle.tiltFired {
                handle.tiltFired = true
                handle.onPour?()
            } else if pitch < resetThreshold {
                handle.tiltFired = false
            }

            // Shake: suppressed while device is tilted — tilt motion inherently spikes
            // userAcceleration above the shake threshold, causing false positives on every pour.
            guard !isTilted, !handle.shakeCooldown else { return }
            let a = motion.userAcceleration
            let mag = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            if mag > shakeThreshold {
                handle.shakeCooldown = true
                handle.onShake?()
                Task {
                    try? await Task.sleep(nanoseconds: cooldownNs)
                    handle.shakeCooldown = false
                }
            }
        }
    }

    private func stopLoopIfIdle() {
        guard handle.onPour == nil, handle.onShake == nil else { return }
        handle.manager.stopDeviceMotionUpdates()
        handle.isRunning = false
    }
}
