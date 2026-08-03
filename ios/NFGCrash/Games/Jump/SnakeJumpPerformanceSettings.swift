import UIKit

/// Runtime graphics tuning for NFG Jump — reduces load on devices that struggle with 120Hz full-frame CG draws.
enum SnakeJumpPerformanceSettings {
    struct Profile {
        let minFPS: Int
        let maxFPS: Int
        let preferredFPS: Int
        let liteVisualEffects: Bool
    }

    static var current: Profile {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return Profile(minFPS: 30, maxFPS: 60, preferredFPS: 60, liteVisualEffects: true)
        }
        if UIAccessibility.isReduceMotionEnabled {
            return Profile(minFPS: 30, maxFPS: 60, preferredFPS: 60, liteVisualEffects: true)
        }
        // ProMotion devices were targeting 120fps with a full CoreGraphics redraw each frame — too heavy for some users.
        return Profile(minFPS: 60, maxFPS: 60, preferredFPS: 60, liteVisualEffects: false)
    }
}
