import Foundation
import CoreGraphics

public final class DwellTimer {
    public typealias SwitchHandler = (CGDirectDisplayID) -> Void

    private var thresholdMs: Int
    private let onSwitch: SwitchHandler
    private var pendingTarget: CGDirectDisplayID?
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.lookie-here.dwell-timer")

    public init(thresholdMs: Int, onSwitch: @escaping SwitchHandler) {
        self.thresholdMs = thresholdMs
        self.onSwitch = onSwitch
    }

    public func report(target: CGDirectDisplayID?, currentFocused: CGDirectDisplayID) {
        queue.async { [weak self] in
            self?.handleReport(target: target, currentFocused: currentFocused)
        }
    }

    public func updateThreshold(ms: Int) {
        queue.async { [weak self] in
            self?.thresholdMs = ms
        }
    }

    public func cancel() {
        queue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
            self?.pendingTarget = nil
        }
    }

    private func handleReport(target: CGDirectDisplayID?, currentFocused: CGDirectDisplayID) {
        // No face detected or already focused — cancel any pending timer
        guard let target = target, target != currentFocused else {
            timer?.cancel()
            timer = nil
            pendingTarget = nil
            return
        }

        // Same pending target — let existing timer continue
        if target == pendingTarget {
            return
        }

        // New target — reset timer
        timer?.cancel()
        pendingTarget = target

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + .milliseconds(thresholdMs))
        t.setEventHandler { [weak self] in
            guard let self = self, self.pendingTarget == target else { return }
            self.pendingTarget = nil
            self.timer = nil
            DispatchQueue.main.async {
                self.onSwitch(target)
            }
        }
        timer = t
        t.resume()
    }
}
