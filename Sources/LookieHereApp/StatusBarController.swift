import AppKit
import Carbon.HIToolbox
import LookieHereCore

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let pipeline: Pipeline
    private var hotKeyRef: EventHotKeyRef?

    private var dwellSlider: NSSlider!
    private var dwellLabel: NSMenuItem!
    private var fpsSlider: NSSlider!
    private var fpsLabel: NSMenuItem!

    init(pipeline: Pipeline) {
        self.pipeline = pipeline
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupMenu()
        updateIcon()
        registerGlobalHotKey()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status line
        let statusLabel = NSMenuItem(title: "Status: \(pipeline.state == .running ? "Tracking" : "Paused")", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        menu.addItem(statusLabel)

        menu.addItem(NSMenuItem.separator())

        // Toggle
        let toggleTitle = pipeline.state == .running ? "Pause Tracking" : "Start Tracking"
        let toggleItem = NSMenuItem(title: "\(toggleTitle)  (⌘;)", action: #selector(toggleTracking), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Dwell time slider
        let config = pipeline.config
        dwellLabel = NSMenuItem(title: "Dwell Time: \(config.dwellTimeMs)ms", action: nil, keyEquivalent: "")
        dwellLabel.isEnabled = false
        menu.addItem(dwellLabel)
        menu.addItem(makeSliderItem(
            value: Double(config.dwellTimeMs), min: 100, max: 2000,
            action: #selector(dwellSliderChanged(_:)), slider: &dwellSlider
        ))

        menu.addItem(NSMenuItem.separator())

        // FPS slider
        fpsLabel = NSMenuItem(title: "Camera FPS: \(config.cameraFps)", action: nil, keyEquivalent: "")
        fpsLabel.isEnabled = false
        menu.addItem(fpsLabel)
        let fpsItem = makeSliderItem(
            value: Double(config.cameraFps), min: 15, max: 30,
            action: #selector(fpsSliderChanged(_:)), slider: &fpsSlider
        )
        fpsSlider.numberOfTickMarks = 4
        fpsSlider.allowsTickMarkValuesOnly = true
        menu.addItem(fpsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    private func makeSliderItem(value: Double, min: Double, max: Double, action: Selector, slider: inout NSSlider!) -> NSMenuItem {
        slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.frame = NSRect(x: 20, y: 0, width: 200, height: 24)
        slider.isContinuous = true
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 30))
        slider.frame.origin = NSPoint(x: 20, y: 3)
        view.addSubview(slider)
        item.view = view
        return item
    }

    private func updateIcon() {
        if let button = statusItem.button {
            let symbolName = pipeline.state == .running ? "eye.fill" : "eye.slash"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Lookie Here")
        }
    }

    @objc private func toggleTracking() {
        if pipeline.state == .running {
            pipeline.pause()
        } else if pipeline.state == .paused {
            pipeline.resume()
        } else {
            try? pipeline.start()
        }
        setupMenu()
        updateIcon()
    }

    @objc private func dwellSliderChanged(_ sender: NSSlider) {
        let value = Int(sender.doubleValue / 50) * 50 // snap to 50ms increments
        var config = pipeline.config
        config.dwellTimeMs = max(100, value)
        dwellLabel.title = "Dwell Time: \(config.dwellTimeMs)ms"
        pipeline.updateConfig(config)
        try? config.save()
    }

    @objc private func fpsSliderChanged(_ sender: NSSlider) {
        var config = pipeline.config
        config.cameraFps = Int(sender.doubleValue)
        fpsLabel.title = "Camera FPS: \(config.cameraFps)"
        pipeline.updateConfig(config)
        try? config.save()
    }

    @objc private func quit() {
        pipeline.stop()
        NSApp.terminate(nil)
    }

    // MARK: - Global Hotkey (⌘;)

    private func registerGlobalHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C4B4845), id: 1)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_Semicolon),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            self.hotKeyRef = hotKeyRef
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<StatusBarController>.fromOpaque(userData).takeUnretainedValue()
            controller.toggleTracking()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}
