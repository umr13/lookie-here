import AppKit
import CoreGraphics

public final class FocusSwitcher {
    private var currentDisplayID: CGDirectDisplayID?

    public init() {}

    /// Focus the frontmost window on the given display. No-op if already focused on this display.
    public func focusDisplay(_ displayID: CGDirectDisplayID) {
        guard displayID != currentDisplayID else { return }
        currentDisplayID = displayID

        let displayBounds = CGDisplayBounds(displayID)

        // Move cursor to the center of the target display
        let center = CGPoint(x: displayBounds.midX, y: displayBounds.midY)
        CGWarpMouseCursorPosition(center)
        CGAssociateMouseAndMouseCursorPosition(1)

        // Get window list ordered front-to-back
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return
        }

        for windowInfo in windowList {
            guard let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let pid = windowInfo[kCGWindowOwnerPID as String] as? Int32,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 // Normal window layer
            else {
                continue
            }

            let windowBounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Check if this window's center is on the target display
            let windowCenter = CGPoint(x: windowBounds.midX, y: windowBounds.midY)
            guard displayBounds.contains(windowCenter) else {
                continue
            }

            // Found the frontmost window on target display — activate it
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: [])

                // Raise the specific window via Accessibility API
                let appElement = AXUIElementCreateApplication(pid)
                var windows: CFTypeRef?
                AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)

                if let axWindows = windows as? [AXUIElement] {
                    for axWindow in axWindows {
                        var axPosition: CFTypeRef?
                        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &axPosition)

                        if let axPos = axPosition, CFGetTypeID(axPos) == AXValueGetTypeID() {
                            var point = CGPoint.zero
                            AXValueGetValue(axPos as! AXValue, .cgPoint, &point)

                            // Match by position (close enough)
                            if abs(point.x - windowBounds.origin.x) < 5 &&
                               abs(point.y - windowBounds.origin.y) < 5 {
                                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                                break
                            }
                        }
                    }
                }
                return
            }
        }
    }

    /// Reset tracking so the next call to focusDisplay always acts.
    public func reset() {
        currentDisplayID = nil
    }
}
