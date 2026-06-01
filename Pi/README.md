# SmartLight Pi

Raspberry Pi server for SmartLight Designer. Requires Swift 5.9+ on Linux.

## Modes

**Player mode** (default) — performance-focused, no web visualization:
- Runs the DMX engine and outputs Art-Net/sACN
- Minimal status web UI at `http://<pi>:8080`
- Accepts Mac "session" connections via WebSocket
- Multiple Macs can connect with Primary / Control / Editor roles

**Designer mode** — full web-based designer:
- Complete show editor in the browser at `http://<pi>:8080`
- No session support (Pi is the authority; connect directly via browser)

## Setup

```bash
# Install Swift on Raspberry Pi OS (arm64)
curl -s https://swiftlang.github.io/swifty-pi/install.sh | bash

# Build (release for best performance)
cd Pi
swift build -c release

# Run in player mode (default)
.build/release/SmartLightPi

# Run in designer mode
.build/release/SmartLightPi --designer

# Custom port
.build/release/SmartLightPi --port 9090

# Run as systemd service (recommended)
sudo cp scripts/smartlight-pi.service /etc/systemd/system/
sudo systemctl enable --now smartlight-pi
```

## Session Roles (Player mode only)

| Role | Priority | Description |
|------|----------|-------------|
| Primary | 3 | Full authority — Pi outputs your show state; overrides all |
| Control | 2 | Run the show via Pi; yields to Primary if present |
| Editor | 1 | Design at lower priority; yields to Primary & Control |

Only **one Pi** per session. **Multiple Macs** can join.  
Sessions require the Pi to be in **Player mode** (not Designer mode).

## Enable on Mac

Settings → Sessions tab → toggle **Enable Pi Sessions & Remote Control**.
