import XCTest
@testable import LookieHereCore

final class DwellTimerTests: XCTestCase {
    func testNoSwitchBeforeDwellTime() {
        var switched: CGDirectDisplayID?
        let timer = DwellTimer(thresholdMs: 500) { displayID in
            switched = displayID
        }

        // Report a new target, but don't wait long enough
        timer.report(target: 2, currentFocused: 1)

        // Should not have switched yet
        XCTAssertNil(switched)
    }

    func testSwitchAfterDwellTime() {
        let expectation = expectation(description: "switch fires")
        var switched: CGDirectDisplayID?
        let timer = DwellTimer(thresholdMs: 100) { displayID in
            switched = displayID
            expectation.fulfill()
        }

        timer.report(target: 2, currentFocused: 1)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(switched, 2)
    }

    func testResetOnTargetChange() {
        var switched: CGDirectDisplayID?
        let timer = DwellTimer(thresholdMs: 200) { displayID in
            switched = displayID
        }

        timer.report(target: 2, currentFocused: 1)

        // Change target before dwell completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            timer.report(target: 3, currentFocused: 1)
        }

        // Wait past original dwell time — should NOT have switched to 2
        let expectation = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Should have switched to 3 (the reset target), not 2
        XCTAssertEqual(switched, 3)
    }

    func testNoTimerWhenTargetMatchesFocused() {
        var switched: CGDirectDisplayID?
        let timer = DwellTimer(thresholdMs: 50) { displayID in
            switched = displayID
        }

        timer.report(target: 1, currentFocused: 1)

        let expectation = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertNil(switched)
    }

    func testNilTargetDoesNotSwitch() {
        var switched: CGDirectDisplayID?
        let timer = DwellTimer(thresholdMs: 50) { displayID in
            switched = displayID
        }

        timer.report(target: nil, currentFocused: 1)

        let expectation = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertNil(switched)
    }

    func testUpdateThreshold() {
        let expectation = expectation(description: "switch fires")
        var switched: CGDirectDisplayID?
        let timer = DwellTimer(thresholdMs: 5000) { displayID in
            switched = displayID
            expectation.fulfill()
        }

        timer.updateThreshold(ms: 100)
        timer.report(target: 2, currentFocused: 1)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(switched, 2)
    }
}
