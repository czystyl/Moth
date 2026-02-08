# Moth

**You're the moth. YouTube is the flame. This app breaks the trance.**

A macOS menubar app that watches your YouTube habit, earns your screen time through work, and snaps you out of the binge before it starts.

## What it does

Moth lives in your menubar and quietly tracks how you spend your screen time:

- **Detects YouTube viewing** (including Shorts) in Arc Browser
- **Tracks work time** and converts it into a YouTube budget (10 min earned per hour of work)
- **Sends escalating break reminders** — gentle at first, persistent if you keep watching
- **Shows real-time stats** — today's breakdown, a visual timeline, and weekly trends
- **Stores everything locally** in SQLite — your data stays on your machine

## Requirements

- macOS 14+
- Swift 5.9+
- Arc Browser (for YouTube detection)

## Development

```bash
# Build and run (debug)
make dev

# Build release
make build

# Run release build
make run

# Stop the app
make stop

# Clean build artifacts
make clean

# Regenerate app icon
make icon
```

## Permissions

Moth will ask for:

- **Screen Recording** — to detect Picture-in-Picture windows
- **Automation** — to read the current browser tab URL
