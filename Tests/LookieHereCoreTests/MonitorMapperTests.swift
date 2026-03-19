import XCTest
@testable import LookieHereCore

final class MonitorMapperTests: XCTestCase {

    // Helper: create a display info struct for testing
    func makeDisplay(id: CGDirectDisplayID, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, widthMm: CGFloat, isBuiltin: Bool) -> DisplayInfo {
        DisplayInfo(
            id: id,
            bounds: CGRect(x: x, y: y, width: width, height: height),
            physicalSizeMm: CGSize(width: widthMm, height: 0),
            isBuiltin: isBuiltin
        )
    }

    func testSingleMonitorAlwaysMaps() {
        // Only laptop screen
        let laptop = makeDisplay(id: 1, x: 0, y: 0, width: 1440, height: 900, widthMm: 330, isBuiltin: true)
        let mapper = MonitorMapper(displays: [laptop])

        // Looking straight ahead
        XCTAssertEqual(mapper.displayForYaw(0.0), 1)
        // Looking slightly left
        XCTAssertEqual(mapper.displayForYaw(-0.3), 1)
        // Looking slightly right
        XCTAssertEqual(mapper.displayForYaw(0.3), 1)
    }

    func testExternalMonitorToTheLeft() {
        // External to the left of laptop in display arrangement
        let external = makeDisplay(id: 2, x: -1920, y: 0, width: 1920, height: 1080, widthMm: 600, isBuiltin: false)
        let laptop = makeDisplay(id: 1, x: 0, y: 0, width: 1440, height: 900, widthMm: 330, isBuiltin: true)
        let mapper = MonitorMapper(displays: [laptop, external])

        // Looking straight — should be laptop
        XCTAssertEqual(mapper.displayForYaw(0.0), 1)

        // Looking left (negative yaw) — should be external
        XCTAssertEqual(mapper.displayForYaw(-0.5), 2)
    }

    func testExternalMonitorToTheRight() {
        let laptop = makeDisplay(id: 1, x: 0, y: 0, width: 1440, height: 900, widthMm: 330, isBuiltin: true)
        let external = makeDisplay(id: 2, x: 1440, y: 0, width: 1920, height: 1080, widthMm: 600, isBuiltin: false)
        let mapper = MonitorMapper(displays: [laptop, external])

        // Looking straight — laptop
        XCTAssertEqual(mapper.displayForYaw(0.0), 1)

        // Looking right (positive yaw) — external
        XCTAssertEqual(mapper.displayForYaw(0.5), 2)
    }

    func testThreeMonitors() {
        let left = makeDisplay(id: 3, x: -1920, y: 0, width: 1920, height: 1080, widthMm: 600, isBuiltin: false)
        let laptop = makeDisplay(id: 1, x: 0, y: 0, width: 1440, height: 900, widthMm: 330, isBuiltin: true)
        let right = makeDisplay(id: 2, x: 1440, y: 0, width: 1920, height: 1080, widthMm: 600, isBuiltin: false)
        let mapper = MonitorMapper(displays: [laptop, left, right])

        XCTAssertEqual(mapper.displayForYaw(0.0), 1)   // center → laptop
        XCTAssertEqual(mapper.displayForYaw(-0.5), 3)   // left → left monitor
        XCTAssertEqual(mapper.displayForYaw(0.5), 2)    // right → right monitor
    }

    func testNearestCenterWins() {
        // Two monitors close together on the right
        let laptop = makeDisplay(id: 1, x: 0, y: 0, width: 1440, height: 900, widthMm: 330, isBuiltin: true)
        let near = makeDisplay(id: 2, x: 1440, y: 0, width: 1920, height: 1080, widthMm: 600, isBuiltin: false)
        let far = makeDisplay(id: 3, x: 3360, y: 0, width: 1920, height: 1080, widthMm: 600, isBuiltin: false)
        let mapper = MonitorMapper(displays: [laptop, near, far])

        // Moderate right — should pick near monitor (closer center)
        let result = mapper.displayForYaw(0.4)
        XCTAssertEqual(result, 2)
    }
}
