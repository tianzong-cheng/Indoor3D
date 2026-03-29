// Indoor3D/Features/Recording/MotionAnalyzer.swift

import CoreMotion
import Foundation

enum MotionState {
    case good
    case tooFast
    case tooSlow
    case shaky
}

struct MotionFeedback {
    let state: MotionState
    let message: String?
}

@MainActor
final class MotionAnalyzer: ObservableObject {
    private let motionManager = CMMotionManager()

    @Published var currentFeedback: MotionFeedback?

    private var lastUpdateTime: Date = Date()
    private var lastAcceleration: CMAcceleration?

    // Thresholds (tunable)
    let maxVelocity: Double = 1.5  // m/s
    let minVelocity: Double = 0.1
    let maxRotationRate: Double = 2.0  // rad/s
    let stopThreshold: TimeInterval = 3.0

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            currentFeedback = MotionFeedback(state: .good, message: nil)
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            Task { @MainActor in
                self.analyze(motion: motion)
            }
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        currentFeedback = nil
    }

    private func analyze(motion: CMDeviceMotion) {
        let now = Date()
        let acceleration = motion.userAcceleration
        let rotationRate = motion.rotationRate

        // Calculate velocity magnitude
        let velocityMagnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )

        // Calculate rotation magnitude
        let rotationMagnitude = sqrt(
            rotationRate.x * rotationRate.x +
            rotationRate.y * rotationRate.y +
            rotationRate.z * rotationRate.z
        )

        // Determine state
        var state: MotionState = .good
        var message: String?

        if velocityMagnitude > maxVelocity {
            state = .tooFast
            message = "Move slower"
        } else if rotationMagnitude > maxRotationRate {
            state = .shaky
            message = "Hold steadier"
        } else if velocityMagnitude < minVelocity {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateTime)
            if timeSinceLastUpdate > stopThreshold {
                state = .tooSlow
                message = "Keep moving"
            }
        }

        lastUpdateTime = now
        lastAcceleration = acceleration
        currentFeedback = MotionFeedback(state: state, message: message)
    }
}