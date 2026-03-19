import AppKit
import LookieHereCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let pipeline: Pipeline

    override init() {
        let config = LookieConfig.loadOrDefaults()
        self.pipeline = Pipeline(config: config)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        if pipeline.config.enabled {
            try? pipeline.start()
        }

        statusBarController = StatusBarController(pipeline: pipeline)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pipeline.stop()
    }
}

@main
enum LookieHereAppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
