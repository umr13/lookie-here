import AppKit
import AVFoundation
import LookieHereCore

/// A floating debug window showing the camera feed and face tracking overlay.
final class DebugPreview: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let overlayView: DebugOverlayView
    private let pipeline: Pipeline

    init(pipeline: Pipeline) {
        self.pipeline = pipeline

        // Create window
        let frame = NSRect(x: 100, y: 100, width: 480, height: 360)
        window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Lookie Debug — Camera Preview"
        window.level = .floating
        window.isReleasedWhenClosed = false

        // Camera preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: pipeline.camera.session)
        previewLayer.videoGravity = .resizeAspectFill

        // Overlay for face tracking info
        overlayView = DebugOverlayView(frame: frame)
        overlayView.wantsLayer = true
        overlayView.layer?.addSublayer(previewLayer)

        super.init()

        window.contentView = overlayView
        window.delegate = self

        // Wire up debug updates from pipeline
        pipeline.onDebugUpdate = { [weak self] direction, targetDisplay, currentFocused in
            DispatchQueue.main.async {
                self?.overlayView.update(
                    direction: direction,
                    targetDisplay: targetDisplay,
                    currentFocused: currentFocused,
                    zones: pipeline.monitorMapper.displayAngles
                )
            }
        }
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        // Resize the preview layer to match
        previewLayer.frame = overlayView.bounds
    }

    func windowDidResize(_ notification: Notification) {
        previewLayer.frame = overlayView.bounds
    }
}

/// Custom view that draws face tracking info on top of the camera preview.
final class DebugOverlayView: NSView {
    private var direction: FaceDirection?
    private var targetDisplay: CGDirectDisplayID?
    private var currentFocused: CGDirectDisplayID = 0
    private var zones: [(id: CGDirectDisplayID, centerYaw: Double)] = []
    private var lastUpdateTime = Date()
    private var fps: Double = 0
    private var frameCount = 0

    func update(direction: FaceDirection?, targetDisplay: CGDirectDisplayID?, currentFocused: CGDirectDisplayID, zones: [(id: CGDirectDisplayID, centerYaw: Double)]) {
        self.direction = direction
        self.targetDisplay = targetDisplay
        self.currentFocused = currentFocused
        self.zones = zones

        // Calculate FPS
        frameCount += 1
        let now = Date()
        let elapsed = now.timeIntervalSince(lastUpdateTime)
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastUpdateTime = now
        }

        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let boxHeight: CGFloat = direction != nil ? 120 : 60
        let boxRect = CGRect(x: 8, y: bounds.height - boxHeight - 8, width: 280, height: boxHeight)

        // Semi-transparent background
        context.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(boxRect)

        let textColor = NSColor.white
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: textColor, .font: font]
        let greenAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.green, .font: font]
        let redAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.red, .font: font]

        var y = bounds.height - 24.0

        // FPS
        let fpsStr = NSAttributedString(string: String(format: "FPS: %.0f", fps), attributes: attrs)
        fpsStr.draw(at: NSPoint(x: 14, y: y))
        y -= 18

        if let dir = direction {
            let yawDeg = dir.yaw * 180.0 / .pi
            let pitchDeg = dir.pitch * 180.0 / .pi

            let faceStr = NSAttributedString(
                string: String(format: "Yaw: %+.1f°  Pitch: %+.1f°", yawDeg, pitchDeg),
                attributes: greenAttrs
            )
            faceStr.draw(at: NSPoint(x: 14, y: y))
            y -= 18

            if let target = targetDisplay {
                let targetStr = NSAttributedString(
                    string: "Target: Display \(target)",
                    attributes: attrs
                )
                targetStr.draw(at: NSPoint(x: 14, y: y))
                y -= 18
            }

            let focusStr = NSAttributedString(
                string: "Focused: Display \(currentFocused)",
                attributes: attrs
            )
            focusStr.draw(at: NSPoint(x: 14, y: y))
            y -= 18

            // Draw zone info
            for zone in zones {
                let deg = zone.centerYaw * 180.0 / .pi
                let isTarget = zone.id == targetDisplay
                let marker = isTarget ? " ◀" : ""
                let zoneStr = NSAttributedString(
                    string: String(format: "  Zone %d: %+.1f°%@", zone.id, deg, marker),
                    attributes: isTarget ? greenAttrs : attrs
                )
                zoneStr.draw(at: NSPoint(x: 14, y: y))
                y -= 16
            }
        } else {
            let noFaceStr = NSAttributedString(string: "No face detected", attributes: redAttrs)
            noFaceStr.draw(at: NSPoint(x: 14, y: y))
        }
    }
}
