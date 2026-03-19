import Foundation
import AppKit
import LookieHereCore

func printUsage() {
    print("""
    Usage: lookie <command> [options]

    Commands:
      start       Start tracking (foreground)
      status      Show current configuration
      config      Show/set config values (e.g., lookie config dwellTimeMs 750)
      monitors    List detected monitors and their yaw zones
      help        Show this help message

    Options for 'start':
      --verbose   Print detailed tracking logs
      --debug     Open camera preview window with face detection overlay
    """)
}

func loadConfig() -> LookieConfig {
    LookieConfig.loadOrDefaults()
}

let args = CommandLine.arguments.dropFirst()
guard let command = args.first else {
    printUsage()
    exit(0)
}

switch command {
case "start":
    let config = loadConfig()
    let startArgs = Set(args.dropFirst())
    let verbose = startArgs.contains("--verbose") || startArgs.contains("--debug")
    let debug = startArgs.contains("--debug")

    let pipeline = Pipeline(config: config)
    pipeline.verbose = verbose

    // Handle SIGINT for clean shutdown via DispatchSource (allows capturing pipeline)
    signal(SIGINT, SIG_IGN)
    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler {
        print("\nStopping...")
        pipeline.stop()
        exit(0)
    }
    sigintSource.resume()

    // Debug mode: start NSApplication for the preview window
    var debugPreview: DebugPreview?
    if debug {
        // Need an NSApplication to show windows from a CLI process
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
    }

    do {
        try pipeline.start()
        print("Lookie Here started (dwell: \(config.dwellTimeMs)ms, fps: \(config.cameraFps))")
        if verbose { print("[PIPELINE] Verbose logging enabled") }

        if debug {
            debugPreview = DebugPreview(pipeline: pipeline)
            debugPreview?.show()
            print("[DEBUG] Camera preview window opened")
            _ = debugPreview // keep alive
        }

        print("Press Ctrl+C to stop")
        RunLoop.current.run()
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }

case "status":
    let config = loadConfig()
    print("Lookie Here")
    print("  Dwell time:     \(config.dwellTimeMs)ms")
    print("  Camera FPS:     \(config.cameraFps)")
    print("  Enabled:        \(config.enabled)")
    print("  Launch at login: \(config.launchAtLogin)")

case "config":
    var config = loadConfig()
    let configArgs = Array(args.dropFirst())

    if configArgs.isEmpty {
        // Show current config
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    } else if configArgs.count == 2 {
        let key = configArgs[0]
        let value = configArgs[1]

        switch key {
        case "dwellTimeMs":
            guard let v = Int(value), v > 0 else { print("Error: dwellTimeMs must be a positive integer"); exit(1) }
            config.dwellTimeMs = v
        case "cameraFps":
            guard let v = Int(value), v > 0, v <= 60 else { print("Error: cameraFps must be between 1 and 60"); exit(1) }
            config.cameraFps = v
        case "enabled":
            config.enabled = (value == "true")
        case "launchAtLogin":
            config.launchAtLogin = (value == "true")
        default:
            print("Unknown config key: \(key)")
            exit(1)
        }

        do {
            try config.save()
            print("Saved: \(key) = \(value)")
        } catch {
            print("Error saving config: \(error.localizedDescription)")
            exit(1)
        }
    } else {
        print("Usage: lookie config [key value]")
        exit(1)
    }

case "monitors":
    let displays = MonitorMapper.queryDisplays()

    if displays.isEmpty {
        print("No displays detected")
    } else {
        print("Detected monitors:")
        for display in displays {
            let tag = display.isBuiltin ? " (built-in, camera)" : ""
            print("  Display \(display.id)\(tag)")
            print("    Bounds: \(Int(display.bounds.origin.x)),\(Int(display.bounds.origin.y)) \(Int(display.bounds.width))x\(Int(display.bounds.height))")
            print("    Physical: \(Int(display.physicalSizeMm.width))mm x \(Int(display.physicalSizeMm.height))mm")
        }
    }

case "help", "--help", "-h":
    printUsage()

default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}
