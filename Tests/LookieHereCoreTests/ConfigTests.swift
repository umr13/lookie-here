import XCTest
@testable import LookieHereCore

final class ConfigTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultConfig() {
        let config = LookieConfig.defaults
        XCTAssertEqual(config.dwellTimeMs, 500)
        XCTAssertEqual(config.cameraFps, 30)
        XCTAssertTrue(config.enabled)
        XCTAssertFalse(config.launchAtLogin)
    }

    func testLoadFromFile() throws {
        let json = """
        {"dwellTimeMs": 750, "cameraFps": 15, "enabled": false, "launchAtLogin": true}
        """
        let file = tempDir.appendingPathComponent("config.json")
        try json.write(to: file, atomically: true, encoding: .utf8)

        let config = try LookieConfig.load(from: file)
        XCTAssertEqual(config.dwellTimeMs, 750)
        XCTAssertEqual(config.cameraFps, 15)
        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.launchAtLogin)
    }

    func testLoadMissingFileReturnsDefaults() {
        let file = tempDir.appendingPathComponent("nonexistent.json")
        let config = (try? LookieConfig.load(from: file)) ?? .defaults
        XCTAssertEqual(config.dwellTimeMs, 500)
    }

    func testSaveAndReload() throws {
        var config = LookieConfig.defaults
        config.dwellTimeMs = 1000
        let file = tempDir.appendingPathComponent("config.json")
        try config.save(to: file)

        let reloaded = try LookieConfig.load(from: file)
        XCTAssertEqual(reloaded.dwellTimeMs, 1000)
    }

    func testPartialJsonUsesDefaults() throws {
        let json = """
        {"dwellTimeMs": 300}
        """
        let file = tempDir.appendingPathComponent("config.json")
        try json.write(to: file, atomically: true, encoding: .utf8)

        let config = try LookieConfig.load(from: file)
        XCTAssertEqual(config.dwellTimeMs, 300)
        XCTAssertEqual(config.cameraFps, 30) // default
    }
}
