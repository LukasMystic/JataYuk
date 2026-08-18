//
//  MotionSource.swift
//  WaterSim
//
//  Created by jatayumuw on 15/08/26.
//

import CoreMotion
import Foundation
import simd

@Observable
final class MotionSource: SloshMotionProviding {
    private(set) var gravity = SIMD3<Float>(0, -1, 0)
    private(set) var rotationRate = SIMD3<Float>(0, 0, 0)
    private(set) var userAcceleration = SIMD3<Float>(0, 0, 0)
    private(set) var sampleCount = 0
    private(set) var isActive = false
    private(set) var inputSource = "none"
    private(set) var lastError: String?

    private let manager = CMMotionManager()
    private var dragOverride: SIMD3<Float>?
    private var lastDragGravity = SIMD3<Float>(0, -1, 0)
    private var lastDragTime: TimeInterval = 0
    private var didFallbackWithoutReferenceFrame = false

    var isDeviceMotionAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    var rollDegrees: Float {
        atan2(gravity.x, -gravity.y) * 180 / .pi
    }

    var pitchDegrees: Float {
        atan2(gravity.z, -gravity.y) * 180 / .pi
    }

    func start() {
        didFallbackWithoutReferenceFrame = false
        lastError = nil
        guard manager.isDeviceMotionAvailable else {
            isActive = false
            inputSource = "none"
            return
        }
        beginUpdates(useReferenceFrame: true)
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isActive = false
    }

    func applyDrag(normalizedOffset: SIMD2<Float>) {
        let tilt = SIMD3<Float>(normalizedOffset.x, -1, normalizedOffset.y)
        let next = simd_normalize(tilt)
        let now = ProcessInfo.processInfo.systemUptime
        let dt = max(Float(now - lastDragTime), 1.0 / 120.0)
        rotationRate = (next - lastDragGravity) / dt
        userAcceleration = next - lastDragGravity
        lastDragGravity = next
        lastDragTime = now
        dragOverride = next
        gravity = next
        inputSource = "drag"
        sampleCount += 1
    }

    func endDrag() {
        dragOverride = nil
        rotationRate = .zero
        userAcceleration = .zero
        if !manager.isDeviceMotionAvailable {
            gravity = SIMD3<Float>(0, -1, 0)
            lastDragGravity = gravity
            inputSource = "drag"
        }
    }

    private func beginUpdates(useReferenceFrame: Bool) {
        manager.stopDeviceMotionUpdates()
        manager.deviceMotionUpdateInterval = 1.0 / 60.0

        let handler: CMDeviceMotionHandler = { [weak self] motion, error in
            self?.handleDeviceMotion(motion, error: error)
        }

        if useReferenceFrame {
            manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main, withHandler: handler)
        } else {
            manager.startDeviceMotionUpdates(to: .main, withHandler: handler)
        }
        isActive = manager.isDeviceMotionActive
    }

    private func handleDeviceMotion(_ motion: CMDeviceMotion?, error: Error?) {
        if let error {
            if !didFallbackWithoutReferenceFrame {
                didFallbackWithoutReferenceFrame = true
                beginUpdates(useReferenceFrame: false)
                return
            }
            lastError = error.localizedDescription
            isActive = false
            return
        }

        guard let motion, dragOverride == nil else { return }
        let g = motion.gravity
        let r = motion.rotationRate
        gravity = SIMD3(Float(g.x), Float(g.y), Float(g.z))
        rotationRate = SIMD3(Float(r.x), Float(r.y), Float(r.z))
        let a = motion.userAcceleration
        userAcceleration = SIMD3(Float(a.x), Float(a.y), Float(a.z))
        sampleCount += 1
        isActive = true
        inputSource = "gyro"
        lastError = nil
    }
}
