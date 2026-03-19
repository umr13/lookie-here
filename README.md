# Lookie Here

A macOS menu bar app and CLI that automatically focuses the monitor you're looking at. Uses your built-in camera and Apple's Vision framework to track head direction, then moves focus to the corresponding display after a configurable dwell time.

## Requirements

- macOS 12+
- Xcode 14+ (to build)
- Camera access permission

## Install

### Homebrew

```bash
brew install lookie-here
```

### From source

```bash
swift build -c release --product lookie
cp .build/release/lookie /usr/local/bin/
```

## Usage

```
lookie start              # Start tracking (foreground)
lookie start --verbose    # With detailed logs
lookie start --debug      # With camera preview window
lookie status             # Show current configuration
lookie config             # Print config as JSON
lookie config dwellTimeMs 750   # Set dwell time to 750ms
lookie monitors           # List detected monitors and yaw zones
```

## Configuration

Config is stored at `~/.config/lookie/config.json`.

| Key | Default | Description |
|-----|---------|-------------|
| `dwellTimeMs` | 500 | Time looking at a monitor before switching focus |
| `cameraFps` | 30 | Camera capture frame rate |
| `enabled` | true | Enable/disable tracking |
| `launchAtLogin` | false | Start automatically at login |

## License

MIT

---

Built by [Umar](https://umarswork.com)