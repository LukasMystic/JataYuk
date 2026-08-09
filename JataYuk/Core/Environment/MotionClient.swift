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
        var tiltFired = false
    }

    private static let pourThresholdRad = 45.0 * .pi / 180.0
    private static let resetThresholdRad = 20.0 * .pi / 180.0

    // Monitors device pitch at 30 Hz. Calls onPour once per pour gesture (tilt > 70°).
    // Resets the gate when the device returns to within 30° of upright so repeated pours work.
    func startTiltMonitoring(onPour: @MainActor @escaping () -> Void) {
        guard handle.manager.isDeviceMotionAvailable else { return }
        handle.manager.deviceMotionUpdateInterval = 1.0 / 30.0
        let pourThreshold = Self.pourThresholdRad
        let resetThreshold = Self.resetThresholdRad
        handle.manager.startDeviceMotionUpdates(to: .main) { [handle] motion, _ in
            guard let motion else { return }
            let pitch = abs(motion.attitude.pitch)
            if pitch > pourThreshold, !handle.tiltFired {
                handle.tiltFired = true
                Task { @MainActor in onPour() }
            } else if pitch < resetThreshold {
                handle.tiltFired = false
            }
        }
    }

    func stopTiltMonitoring() {
        handle.manager.stopDeviceMotionUpdates()
        handle.tiltFired = false
    }
}
