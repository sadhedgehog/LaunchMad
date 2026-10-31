import XCTest

// The production source is also compiled into this test target.
final class WheelPagingGateTests: XCTestCase {
    func testClassicNotchesFlipOncePerNotchAfterCooldown() {
        var gate = WheelPagingGate()
        XCTAssertEqual(gate.register(delta: -4, isSmooth: false, at: 0), -1)
        XCTAssertEqual(gate.register(delta: -4, isSmooth: false, at: 0.05), 0)
        XCTAssertEqual(gate.register(delta: -4, isSmooth: false, at: 0.2), -1)
        XCTAssertEqual(gate.register(delta: 4, isSmooth: false, at: 0.4), 1)
    }

    func testSmallDeltasAccumulateToThreshold() {
        var gate = WheelPagingGate()
        XCTAssertEqual(gate.register(delta: 1, isSmooth: false, at: 0), 0)
        XCTAssertEqual(gate.register(delta: 1, isSmooth: false, at: 0.01), 1)
    }

    func testSmoothBurstFlipsOnceThenThrottles() {
        var gate = WheelPagingGate()
        var flips: [Int] = []
        // One notch from a smooth-scrolling mouse: 30 events over 0.3 s.
        for i in 0..<30 {
            let result = gate.register(delta: 6, isSmooth: true, at: Double(i) * 0.01)
            if result != 0 { flips.append(result) }
        }
        XCTAssertEqual(flips, [1])
    }

    func testContinuousSmoothScrollingKeepsPagingSlowly() {
        var gate = WheelPagingGate()
        var flipTimes: [Double] = []
        for i in 0..<120 {
            let time = Double(i) * 0.01
            if gate.register(delta: 6, isSmooth: true, at: time) != 0 { flipTimes.append(time) }
        }
        XCTAssertEqual(flipTimes.count, 3)
        XCTAssertEqual(flipTimes.first, 0)
    }

    func testNewSmoothBurstAfterPauseFlipsAgain() {
        var gate = WheelPagingGate()
        XCTAssertEqual(gate.register(delta: -6, isSmooth: true, at: 0), -1)
        XCTAssertEqual(gate.register(delta: -6, isSmooth: true, at: 0.1), 0)
        XCTAssertEqual(gate.register(delta: -6, isSmooth: true, at: 0.5), -1)
    }

    func testIgnoresZeroAndNonFiniteDeltas() {
        var gate = WheelPagingGate()
        XCTAssertEqual(gate.register(delta: 0, isSmooth: false, at: 0), 0)
        XCTAssertEqual(gate.register(delta: .nan, isSmooth: true, at: 0), 0)
    }

    func testWheelDownPagesForwardWithOrWithoutNaturalScrolling() {
        // Wheel down: negative deltaY normally, positive with natural scrolling on.
        XCTAssertGreaterThan(WheelPagingGate.forwardDelta(deltaX: 0, deltaY: -3, isDirectionInvertedFromDevice: false), 0)
        XCTAssertGreaterThan(WheelPagingGate.forwardDelta(deltaX: 0, deltaY: 3, isDirectionInvertedFromDevice: true), 0)
        // Wheel up pages back.
        XCTAssertLessThan(WheelPagingGate.forwardDelta(deltaX: 0, deltaY: 3, isDirectionInvertedFromDevice: false), 0)
        XCTAssertLessThan(WheelPagingGate.forwardDelta(deltaX: 0, deltaY: -3, isDirectionInvertedFromDevice: true), 0)
    }

    func testHorizontalWheelUsesDominantAxis() {
        XCTAssertEqual(WheelPagingGate.forwardDelta(deltaX: -5, deltaY: 1, isDirectionInvertedFromDevice: false), 5)
        XCTAssertEqual(WheelPagingGate.forwardDelta(deltaX: -5, deltaY: 1, isDirectionInvertedFromDevice: true), -5)
    }
}
