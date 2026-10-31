import Foundation

/// Decides when mouse-wheel input flips a launcher page.
///
/// A classic wheel sends one event per notch. A smooth-scrolling mouse (for
/// example a Logitech mouse with smooth scrolling on) sends each notch as a burst
/// of small precise events without trackpad gesture phases. A burst flips one
/// page at once and, while it continues, at most one more every
/// `burstFlipInterval`.
struct WheelPagingGate {
    static let defaultThreshold: Double = 2.0
    static let notchCooldown: TimeInterval = 0.15
    static let burstGap: TimeInterval = 0.25
    static let burstFlipInterval: TimeInterval = 0.5

    private var accumulated: Double = 0
    private var lastDirection = 0
    private var lastFlipAt: TimeInterval?
    private var lastSmoothEventAt: TimeInterval?

    /// Returns the direction to page (1 or -1, the sign of `delta`), or 0.
    mutating func register(delta: Double,
                           threshold: Double = WheelPagingGate.defaultThreshold,
                           isSmooth: Bool,
                           at time: TimeInterval) -> Int {
        guard delta != 0, delta.isFinite else { return 0 }
        var cooldown = Self.notchCooldown
        if isSmooth {
            if let last = lastSmoothEventAt, time - last < Self.burstGap {
                cooldown = Self.burstFlipInterval
            } else {
                accumulated = 0
            }
            lastSmoothEventAt = time
        }
        let direction = delta > 0 ? 1 : -1
        if direction != lastDirection { accumulated = 0 }
        lastDirection = direction
        accumulated += abs(delta)
        guard accumulated >= threshold else { return 0 }
        if let last = lastFlipAt, time - last < cooldown { return 0 }
        lastFlipAt = time
        accumulated = 0
        return direction
    }

    mutating func reset() {
        self = WheelPagingGate()
    }
}
