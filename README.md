# Agent On

A macOS menu bar utility that keeps your Mac awake when the lid is closed and it's connected to AC power — without needing a separate monitor or keyboard.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Free](https://img.shields.io/badge/license-free-brightgreen)

## What it does

When you close your MacBook lid with an external display connected, macOS normally puts it to sleep. Agent On prevents that by disabling clamshell sleep while AC power is detected, and restoring normal sleep behavior the moment you unplug.

**Features**

- One-click Enable / Disable from the menu bar
- Auto-enables when AC power is connected (optional)
- Auto-disable schedule: 30 min / 1 h / 2 h / 4 h / 8 h / custom time
- Live session timer in the menu bar panel
- Cleans up on quit — no leftover system state

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac

## Installation

1. Download `AgentOn-1.0.dmg` from [Releases](../../releases)
2. Open the DMG, drag **Agent On** to Applications
3. Launch Agent On from Applications
4. On first use, macOS will ask you to approve the privileged helper in **System Settings → Privacy & Security** — this is required for the sleep-prevention to work

> The app is notarized by Apple. If Gatekeeper still warns you, right-click the app and choose Open.

## How it works

Agent On installs a small privileged LaunchDaemon helper (`AgentOnHelper`) that runs `pmset -a disablesleep 1` to prevent clamshell sleep. The helper communicates with the main app via XPC. When Agent On is disabled or quit, it sends `pmset -a disablesleep 0` to restore normal behavior.

## Building from source

Requires Xcode 15+ and macOS 14 SDK.

```bash
git clone https://github.com/sshipanoo/agenton.git
cd agenton
open agenton.xcodeproj
```

Build the `agenton` scheme in Xcode. Note: the privileged helper requires a Developer ID certificate to run correctly outside of development.

## License

MIT
