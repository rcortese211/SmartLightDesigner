import Foundation
import Observation

// Provisions a fresh Raspberry Pi over SSH:
// installs Swift, clones the repo, builds the Pi server, installs a systemd service.

@Observable
final class PiProvisioner {

    // MARK: - Stage

    enum Stage: Equatable {
        case idle
        case connecting
        case installingDeps
        case installingSwift
        case fetchingCode
        case building
        case installingService
        case done
        case failed(String)

        var label: String {
            switch self {
            case .idle:              return "Ready"
            case .connecting:        return "Connecting…"
            case .installingDeps:    return "Installing system packages…"
            case .installingSwift:   return "Installing Swift (may take 10–20 min)…"
            case .fetchingCode:      return "Fetching SmartLight Pi…"
            case .building:          return "Building (a few minutes on Pi 4/5)…"
            case .installingService: return "Installing service…"
            case .done:              return "Setup complete ✓"
            case .failed(let msg):   return "Failed: \(msg)"
            }
        }

        var isTerminal: Bool {
            switch self { case .done, .failed: true; default: false }
        }
    }

    var stage: Stage = .idle
    var log = ""
    var isRunning = false

    // MARK: - Public

    func provision(ip: String, username: String, password: String,
                   mode: String, repoURL: String, port: Int) async {
        await set(stage: .connecting, running: true)
        addLog("▶ Starting SmartLight Pi setup on \(ip)\n")

        // Create a temporary SSH_ASKPASS helper that outputs the password
        let askPassPath = "/tmp/sld_ap_\(Int.random(in: 100000...999999)).sh"
        let escaped = password.replacingOccurrences(of: "'", with: "'\\''")
        let askPassBody = "#!/bin/bash\nprintf '%s' '\(escaped)'\n"
        guard (try? askPassBody.write(toFile: askPassPath, atomically: true, encoding: .utf8)) != nil else {
            await fail("Could not create askpass helper")
            return
        }
        try? FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o700)],
                                               ofItemAtPath: askPassPath)
        defer { try? FileManager.default.removeItem(atPath: askPassPath) }

        let script = buildScript(username: username, sudoPass: password,
                                 mode: mode, repoURL: repoURL, port: port)

        let (ok, _) = await sshRun(ip: ip, username: username, askPassPath: askPassPath,
                                   script: script)
        if !ok {
            await fail("SSH command failed — check the log above for details")
        } else if !log.contains("SETUP_DONE") {
            await fail("Setup script did not complete — scroll up for error details")
        } else {
            await set(stage: .done, running: false)
            addLog("\n✓ SmartLight Pi is live at http://\(ip):\(port)\n")
        }
    }

    func cancel() {
        runningProcess?.terminate()
        runningProcess = nil
        stage = .idle
        isRunning = false
    }

    // MARK: - Script generation

    private func buildScript(username: String, sudoPass: String,
                              mode: String, repoURL: String, port: Int) -> String {
        // We embed the sudo password using `sudo -S` with a pipe.
        // All sudo lines use:  echo "$SUDO_P" | sudo -S <command>
        let sp = sudoPass.replacingOccurrences(of: "'", with: "'\\''")
        return """
        #!/bin/bash
        set -euo pipefail
        export SUDO_P='\(sp)'
        S() { printf '%s\\n' "$SUDO_P" | sudo -S "$@" 2>/dev/null; }
        LOG() { echo "[SLD] $*"; }

        # ── 1 / 5  System packages ──────────────────────────────────────
        LOG "STAGE:deps"
        S apt-get update -qq
        S apt-get install -y -qq \\
            git curl clang libicu-dev libcurl4-openssl-dev libssl-dev \\
            libxml2-dev libc6-dev binutils libz-dev pkg-config \\
            libgcc-12-dev libstdc++-12-dev 2>&1 | tail -3

        # ── 2 / 5  Swift ────────────────────────────────────────────────
        LOG "STAGE:swift"
        SWIFT_VER="5.10.1"
        ARCH=$(uname -m)
        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
          SWIFT_TAG="swift-${SWIFT_VER}-RELEASE-ubuntu22.04-aarch64"
        else
          echo "ERROR: 32-bit Pi not supported. Please use a 64-bit Raspberry Pi OS."
          exit 1
        fi
        SWIFT_DIR="/opt/${SWIFT_TAG}"

        if [ -d "$SWIFT_DIR" ] && command -v swift &>/dev/null; then
          LOG "Swift already installed: $(swift --version 2>&1 | head -1)"
        else
          LOG "Downloading Swift ${SWIFT_VER} for aarch64 (≈280 MB)…"
          URL="https://download.swift.org/swift-${SWIFT_VER}-release/ubuntu2204-aarch64/${SWIFT_TAG}/${SWIFT_TAG}.tar.gz"
          curl -fL "$URL" -o /tmp/swift.tar.gz
          LOG "Extracting…"
          S tar -xzf /tmp/swift.tar.gz -C /opt
          rm /tmp/swift.tar.gz
          S tee /etc/profile.d/swift.sh >/dev/null <<'PROFEOF'
        export PATH="/opt/\\(sp)/usr/bin:$PATH"
        PROFEOF
          S sh -c "echo 'export PATH=/opt/${SWIFT_TAG}/usr/bin:\\$PATH' > /etc/profile.d/swift.sh"
        fi
        export PATH="${SWIFT_DIR}/usr/bin:$PATH"
        swift --version 2>&1 | head -1

        # ── 3 / 5  Code ──────────────────────────────────────────────────
        LOG "STAGE:fetch"
        DEST="$HOME/smartlight-pi"
        if [ -d "$DEST/.git" ]; then
          LOG "Updating existing checkout…"
          git -C "$DEST" pull --ff-only 2>&1 | tail -2
        else
          LOG "Cloning from \(repoURL)…"
          git clone --depth 1 "\(repoURL)" "$DEST" 2>&1 | tail -3
        fi

        # ── 4 / 5  Build ─────────────────────────────────────────────────
        LOG "STAGE:build"
        cd "$DEST/Pi"
        LOG "Running swift build -c release …"
        swift build -c release 2>&1

        # ── 5 / 5  Systemd service ───────────────────────────────────────
        LOG "STAGE:service"
        BINARY="$DEST/Pi/.build/release/SmartLightPi"
        S tee /etc/systemd/system/smartlight-pi.service >/dev/null <<SVCEOF
        [Unit]
        Description=SmartLight Pi Server
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        User=\(username)
        WorkingDirectory=$DEST/Pi
        Environment=HOME=/home/\(username)
        Environment=PATH=${SWIFT_DIR}/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        ExecStart=$BINARY --\(mode) --port \(port)
        Restart=always
        RestartSec=5

        [Install]
        WantedBy=multi-user.target
        SVCEOF

        S systemctl daemon-reload
        S systemctl enable smartlight-pi
        S systemctl restart smartlight-pi

        sleep 3
        if S systemctl is-active --quiet smartlight-pi; then
          LOG "Service is running ✓"
          LOCAL_IP=$(hostname -I | awk '{print $1}')
          echo "URL: http://${LOCAL_IP}:\(port)"
        else
          LOG "Service failed to start — last 20 log lines:"
          S journalctl -u smartlight-pi -n 20 --no-pager
        fi

        echo "SETUP_DONE"
        """
    }

    // MARK: - SSH execution

    @ObservationIgnored private var runningProcess: Process?

    private func sshRun(ip: String, username: String, askPassPath: String,
                        script: String) async -> (Bool, String) {
        await withCheckedContinuation { cont in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            proc.arguments = [
                "-o", "StrictHostKeyChecking=accept-new",
                "-o", "ConnectTimeout=15",
                "\(username)@\(ip)", "bash -s"
            ]

            var env = ProcessInfo.processInfo.environment
            env["SSH_ASKPASS"]         = askPassPath
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env.removeValue(forKey: "DISPLAY")
            proc.environment = env

            // Script fed via stdin
            let inPipe  = Pipe()
            let outPipe = Pipe()
            let errPipe = Pipe()
            proc.standardInput  = inPipe
            proc.standardOutput = outPipe
            proc.standardError  = errPipe

            // Stream stdout live
            outPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
                guard let self else { return }
                let data = h.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { self.handleLogChunk(str) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
                guard let self else { return }
                let data = h.availableData
                guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async { self.addLog("⚠ \(str)") }
            }

            proc.terminationHandler = { p in
                DispatchQueue.main.async { self.runningProcess = nil }
                cont.resume(returning: (p.terminationStatus == 0, ""))
            }

            runningProcess = proc
            do {
                try proc.run()
                if let data = script.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                }
                inPipe.fileHandleForWriting.closeFile()
            } catch {
                DispatchQueue.main.async { self.addLog("Process error: \(error.localizedDescription)\n") }
                cont.resume(returning: (false, error.localizedDescription))
            }
        }
    }

    // MARK: - Log + stage helpers

    private func handleLogChunk(_ text: String) {
        addLog(text)
        if text.contains("STAGE:deps")    { stage = .installingDeps }
        if text.contains("STAGE:swift")   { stage = .installingSwift }
        if text.contains("STAGE:fetch")   { stage = .fetchingCode }
        if text.contains("STAGE:build")   { stage = .building }
        if text.contains("STAGE:service") { stage = .installingService }
    }

    @MainActor
    private func set(stage newStage: Stage, running: Bool) {
        stage   = newStage
        isRunning = running
    }

    @MainActor
    private func fail(_ msg: String) {
        stage     = .failed(msg)
        isRunning = false
        addLog("\n✗ \(msg)\n")
    }

    func addLog(_ text: String) {
        log += text
    }
}
