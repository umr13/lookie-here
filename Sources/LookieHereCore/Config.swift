import Foundation

public struct LookieConfig: Codable, Equatable {
    public var dwellTimeMs: Int
    public var cameraFps: Int
    public var enabled: Bool
    public var launchAtLogin: Bool

    public static let defaults = LookieConfig(
        dwellTimeMs: 500,
        cameraFps: 30,
        enabled: true,
        launchAtLogin: false
    )

    public static let defaultPath: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/lookie/config.json")
    }()

    public static func load(from url: URL = defaultPath) throws -> LookieConfig {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(LookieConfig.self, from: data)
    }

    public static func loadOrDefaults(from url: URL = defaultPath) -> LookieConfig {
        (try? load(from: url)) ?? .defaults
    }

    public func save(to url: URL = defaultPath) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    public init(dwellTimeMs: Int = 500, cameraFps: Int = 30, enabled: Bool = true, launchAtLogin: Bool = false) {
        self.dwellTimeMs = dwellTimeMs
        self.cameraFps = cameraFps
        self.enabled = enabled
        self.launchAtLogin = launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = LookieConfig.defaults
        self.dwellTimeMs = try container.decodeIfPresent(Int.self, forKey: .dwellTimeMs) ?? d.dwellTimeMs
        self.cameraFps = try container.decodeIfPresent(Int.self, forKey: .cameraFps) ?? d.cameraFps
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
    }
}
