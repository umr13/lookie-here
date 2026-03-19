import Foundation
import CoreGraphics

/// Information about a single display, injectable for testing.
public struct DisplayInfo: Equatable {
    public let id: CGDirectDisplayID
    public let bounds: CGRect          // In global display coordinates (points)
    public let physicalSizeMm: CGSize  // Physical width/height in mm
    public let isBuiltin: Bool

    public init(id: CGDirectDisplayID, bounds: CGRect, physicalSizeMm: CGSize, isBuiltin: Bool) {
        self.id = id
        self.bounds = bounds
        self.physicalSizeMm = physicalSizeMm
        self.isBuiltin = isBuiltin
    }
}

/// Maps head yaw angles to display IDs based on physical monitor arrangement.
public final class MonitorMapper {
    /// Each display's center expressed as an estimated yaw angle (radians) from the laptop camera.
    public private(set) var displayAngles: [(id: CGDirectDisplayID, centerYaw: Double)] = []

    /// Initialize with an explicit list of displays (for testing).
    public init(displays: [DisplayInfo]) {
        computeZones(from: displays)
    }

    /// Initialize from the live macOS display configuration.
    public convenience init() {
        let displays = MonitorMapper.queryDisplays()
        self.init(displays: displays)
    }

    /// Returns the display ID closest to the given yaw angle (radians).
    /// Negative yaw = looking left, positive = looking right.
    public func displayForYaw(_ yaw: Double) -> CGDirectDisplayID? {
        guard !displayAngles.isEmpty else { return nil }
        return displayAngles.min(by: { abs($0.centerYaw - yaw) < abs($1.centerYaw - yaw) })?.id
    }

    /// Recompute zones from the current macOS display layout.
    public func refresh() {
        let displays = MonitorMapper.queryDisplays()
        computeZones(from: displays)
    }

    // MARK: - Private

    private func computeZones(from displays: [DisplayInfo]) {
        guard let builtin = displays.first(where: { $0.isBuiltin }) else {
            // No built-in display found — use first display as origin
            if let first = displays.first {
                displayAngles = [(id: first.id, centerYaw: 0.0)]
            }
            return
        }

        // Laptop center in display coordinates (points)
        let laptopCenterX = Double(builtin.bounds.midX)

        // Estimate pixels-per-mm from the laptop display to get a rough physical scale
        let laptopPpmm = Double(builtin.bounds.width) / Double(builtin.physicalSizeMm.width)

        // Assumed viewing distance in mm (typical laptop distance ~600mm)
        let viewingDistanceMm: Double = 600.0

        displayAngles = displays.map { display in
            let displayCenterX = Double(display.bounds.midX)
            let offsetPoints = displayCenterX - laptopCenterX
            let offsetMm = offsetPoints / laptopPpmm
            let yaw = atan2(offsetMm, viewingDistanceMm)
            return (id: display.id, centerYaw: yaw)
        }
    }

    /// Query macOS for the current display configuration.
    public static func queryDisplays() -> [DisplayInfo] {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(16, &displayIDs, &displayCount)

        return (0..<Int(displayCount)).map { i in
            let id = displayIDs[i]
            let bounds = CGDisplayBounds(id)
            let size = CGDisplayScreenSize(id) // mm
            let isBuiltin = CGDisplayIsBuiltin(id) != 0
            return DisplayInfo(id: id, bounds: bounds, physicalSizeMm: size, isBuiltin: isBuiltin)
        }
    }
}
