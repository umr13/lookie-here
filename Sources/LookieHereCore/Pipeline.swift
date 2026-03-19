import Foundation
import CoreGraphics

public final class Pipeline {
    public enum State: Equatable {
        case stopped
        case running
        case paused
    }

    public let camera: CameraCapture
    private let faceTracker: FaceTracker
    public let monitorMapper: MonitorMapper
    private var dwellTimer: DwellTimer
    private let focusSwitcher: FocusSwitcher
    public private(set) var config: LookieConfig
    public var verbose: Bool = false {
        didSet { faceTracker.verbose = verbose }
    }

    /// Called on every face tracker result when verbose/debug is on.
    /// Provides: (yaw, pitch, targetDisplayID?, currentFocusedID)
    public var onDebugUpdate: ((FaceDirection?, CGDirectDisplayID?, CGDirectDisplayID) -> Void)?

    public private(set) var state: State = .stopped
    public private(set) var currentTargetDisplay: CGDirectDisplayID?

    public init(config: LookieConfig = .defaults) {
        self.config = config
        self.camera = CameraCapture(fps: config.cameraFps)
        self.faceTracker = FaceTracker()
        self.monitorMapper = MonitorMapper()
        self.focusSwitcher = FocusSwitcher()

        // Initialize with no-op first to satisfy Swift's definite initialization,
        // then rewire with the real callback that captures [weak self].
        self.dwellTimer = DwellTimer(thresholdMs: config.dwellTimeMs) { _ in }
        self.dwellTimer = DwellTimer(thresholdMs: config.dwellTimeMs) { [weak self] displayID in
            guard let self = self else { return }
            if self.verbose {
                print("[FOCUS] Switching to display \(displayID)")
            }
            self.focusSwitcher.focusDisplay(displayID)
            self.currentTargetDisplay = displayID
        }
    }

    public func start() throws {
        guard state == .stopped else { return }

        if verbose {
            print("[PIPELINE] Starting camera...")
            print("[PIPELINE] Monitor zones:")
            for zone in monitorMapper.displayAngles {
                let degrees = zone.centerYaw * 180.0 / .pi
                print("[PIPELINE]   Display \(zone.id): center yaw = \(String(format: "%.1f", degrees))°")
            }
        }

        var frameCount = 0
        var faceCount = 0
        var noFaceCount = 0

        try camera.start { [weak self] sampleBuffer in
            guard let self = self, self.state == .running else { return }

            frameCount += 1
            if self.verbose && frameCount % 30 == 1 {
                print("[CAMERA] Frame #\(frameCount) received")
            }

            self.faceTracker.process(sampleBuffer: sampleBuffer) { [weak self] direction in
                guard let self = self else { return }

                let currentFocused = self.currentTargetDisplay ?? CGMainDisplayID()

                if let direction = direction {
                    faceCount += 1
                    let targetDisplay = self.monitorMapper.displayForYaw(direction.yaw)

                    if self.verbose && faceCount % 15 == 1 {
                        let yawDeg = direction.yaw * 180.0 / .pi
                        let pitchDeg = direction.pitch * 180.0 / .pi
                        print("[FACE] yaw=\(String(format: "%+.1f", yawDeg))° pitch=\(String(format: "%+.1f", pitchDeg))° → display \(targetDisplay ?? 0) (focused: \(currentFocused))")
                    }

                    self.dwellTimer.report(target: targetDisplay, currentFocused: currentFocused)
                    self.onDebugUpdate?(direction, targetDisplay, currentFocused)
                } else {
                    noFaceCount += 1
                    if self.verbose && noFaceCount % 30 == 1 {
                        print("[FACE] No face detected (count: \(noFaceCount))")
                    }
                    self.onDebugUpdate?(nil, nil, currentFocused)
                }
            }
        }

        // Listen for display reconfiguration (monitor plug/unplug/rearrange)
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())

        state = .running
        if verbose {
            print("[PIPELINE] Running. Waiting for face detection...")
        }
    }

    public func stop() {
        camera.stop()
        dwellTimer.cancel()
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        state = .stopped
    }

    public func pause() {
        guard state == .running else { return }
        camera.stop()
        dwellTimer.cancel()
        state = .paused
    }

    public func resume() {
        guard state == .paused else { return }
        state = .running
        try? camera.restart()
    }

    public func updateConfig(_ newConfig: LookieConfig) {
        config = newConfig
        dwellTimer.updateThreshold(ms: newConfig.dwellTimeMs)
        camera.updateFps(newConfig.cameraFps)
    }

    public func refreshMonitors() {
        monitorMapper.refresh()
    }
}

/// Stored top-level function for CGDisplayReconfigurationCallback (must be a C-compatible function pointer).
private func displayReconfigurationCallback(_ display: CGDirectDisplayID, _ flags: CGDisplayChangeSummaryFlags, _ userInfo: UnsafeMutableRawPointer?) {
    guard !flags.contains(.beginConfigurationFlag), let userInfo = userInfo else { return }
    let pipeline = Unmanaged<Pipeline>.fromOpaque(userInfo).takeUnretainedValue()
    pipeline.refreshMonitors()
}
