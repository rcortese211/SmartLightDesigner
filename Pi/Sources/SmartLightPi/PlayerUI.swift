import Foundation

enum PlayerUI {
    static func html(port: Int) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>SmartLight Pi — Player</title>
        <style>
          :root { --bg:#0b0a10; --surf:#13111c; --surf2:#1c1928; --border:#2a2640;
                  --active:#3de87a; --purple:#8b5cf6; --blue:#4ab4ff; --text:#e8e6f0;
                  --dim:#888; --red:#f87171; --amber:#fbbf24; }
          *{box-sizing:border-box;margin:0;padding:0}
          body{background:var(--bg);color:var(--text);font-family:'SF Mono',Consolas,monospace;
               font-size:13px;min-height:100vh;display:flex;flex-direction:column}
          header{background:var(--surf2);border-bottom:1px solid var(--border);
                 padding:10px 20px;display:flex;align-items:center;gap:16px}
          .logo{font-size:15px;font-weight:800;letter-spacing:1px;
                background:linear-gradient(90deg,var(--active),var(--purple));
                -webkit-background-clip:text;-webkit-text-fill-color:transparent}
          .mode-badge{background:var(--purple);color:#fff;font-size:9px;font-weight:700;
                      letter-spacing:1px;padding:2px 7px;border-radius:3px}
          .status-dot{width:8px;height:8px;border-radius:50%;background:var(--dim);margin-left:auto}
          .status-dot.on{background:var(--active);box-shadow:0 0 6px var(--active)}
          main{flex:1;padding:20px;display:grid;grid-template-columns:1fr 1fr;
               grid-template-rows:auto auto 1fr;gap:16px;max-width:900px}
          .card{background:var(--surf);border:1px solid var(--border);border-radius:8px;padding:16px}
          .card-title{font-size:9px;font-weight:700;letter-spacing:1.5px;color:var(--dim);
                      text-transform:uppercase;margin-bottom:12px}
          .stat-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
          .stat{display:flex;flex-direction:column;gap:3px}
          .stat-label{font-size:8px;font-weight:600;letter-spacing:1px;color:var(--dim)}
          .stat-value{font-size:18px;font-weight:700;color:var(--text)}
          .stat-value.on{color:var(--active)}
          .stat-value.off{color:var(--dim)}
          .stat-value.small{font-size:13px}
          .controls{display:flex;gap:8px;flex-wrap:wrap;margin-top:4px}
          button{background:var(--surf2);border:1px solid var(--border);color:var(--text);
                 padding:7px 14px;border-radius:5px;cursor:pointer;font:inherit;font-size:11px;
                 font-weight:600;letter-spacing:.5px;transition:all .15s}
          button:hover{border-color:var(--purple);color:var(--purple)}
          button.primary{background:var(--active);border-color:var(--active);color:#000}
          button.primary:hover{filter:brightness(1.1)}
          button.danger{border-color:var(--red);color:var(--red)}
          button.danger:hover{background:var(--red);color:#fff}
          .output-btn{padding:10px 24px;font-size:13px}
          .sessions{grid-column:1/-1}
          .session-roster{display:flex;flex-direction:column;gap:6px;margin-top:8px}
          .client-row{display:flex;align-items:center;gap:8px;padding:6px 10px;
                      background:var(--surf2);border-radius:5px}
          .dot{width:6px;height:6px;border-radius:50%;background:var(--active);flex-shrink:0}
          .role-badge{margin-left:auto;font-size:8px;font-weight:700;letter-spacing:.8px;
                      padding:2px 6px;border-radius:3px}
          .role-primary{background:rgba(61,232,122,.15);color:var(--active)}
          .role-control{background:rgba(74,180,255,.15);color:var(--blue)}
          .role-editor{background:rgba(139,92,246,.15);color:var(--purple)}
          .empty{color:var(--dim);font-style:italic;font-size:11px}
          .tc-select{background:var(--surf2);border:1px solid var(--border);color:var(--text);
                     padding:5px 10px;border-radius:5px;font:inherit;font-size:11px;width:160px}
          footer{padding:8px 20px;font-size:10px;color:var(--dim);
                 border-top:1px solid var(--border)}
        </style>
        </head>
        <body>
        <header>
          <span class="logo">SmartLight</span>
          <span class="mode-badge">PLAYER</span>
          <span id="conn-dot" class="status-dot"></span>
        </header>

        <main>
          <!-- Output card -->
          <div class="card">
            <div class="card-title">Output</div>
            <div class="stat-grid">
              <div class="stat">
                <div class="stat-label">Status</div>
                <div id="output-status" class="stat-value off">OFF</div>
              </div>
              <div class="stat">
                <div class="stat-label">DMX FPS</div>
                <div id="fps" class="stat-value">—</div>
              </div>
            </div>
            <div class="controls" style="margin-top:14px">
              <button class="output-btn primary" id="btn-output">Enable Output</button>
            </div>
          </div>

          <!-- Timeline card -->
          <div class="card">
            <div class="card-title">Timeline / Cues</div>
            <div class="stat-grid">
              <div class="stat">
                <div class="stat-label">Position</div>
                <div id="tl-pos" class="stat-value small">—</div>
              </div>
              <div class="stat">
                <div class="stat-label">Active Cue</div>
                <div id="active-cue" class="stat-value small">—</div>
              </div>
            </div>
            <div class="controls" style="margin-top:14px">
              <button id="btn-play">▶ Play</button>
              <button id="btn-pause">⏸ Pause</button>
              <button id="btn-stop">⏹ Stop</button>
              <button id="btn-cue-go">CUE GO</button>
              <button id="btn-cue-back">◀ Back</button>
            </div>
          </div>

          <!-- Timecode card -->
          <div class="card">
            <div class="card-title">Timecode Source</div>
            <select id="tc-select" class="tc-select">
              <option value="internal">Internal</option>
              <option value="artnet">Art-Net LTC</option>
              <option value="mtc">MIDI TC</option>
              <option value="network">Network Sync</option>
            </select>
            <div class="controls" style="margin-top:10px">
              <button id="btn-tc-set">Apply</button>
            </div>
          </div>

          <!-- Uptime card -->
          <div class="card">
            <div class="card-title">System</div>
            <div class="stat-grid">
              <div class="stat">
                <div class="stat-label">Uptime</div>
                <div id="uptime" class="stat-value small">—</div>
              </div>
              <div class="stat">
                <div class="stat-label">TC Source</div>
                <div id="tc-current" class="stat-value small">—</div>
              </div>
            </div>
          </div>

          <!-- Sessions card -->
          <div class="card sessions">
            <div class="card-title">Connected Clients</div>
            <div id="roster" class="session-roster">
              <span class="empty">No active sessions</span>
            </div>
          </div>
        </main>

        <footer id="footer">Connecting…</footer>

        <script>
        const port = \(port);
        const wsUrl = `ws://${location.hostname}:${port}/session`;
        let ws, clientId, outputEnabled = false;

        function connect() {
          ws = new WebSocket(wsUrl);
          ws.binaryType = 'arraybuffer';

          ws.onopen = () => {
            document.getElementById('conn-dot').classList.add('on');
            document.getElementById('footer').textContent = 'Connected';
            poll();
          };
          ws.onclose = () => {
            document.getElementById('conn-dot').classList.remove('on');
            document.getElementById('footer').textContent = 'Disconnected — reconnecting…';
            setTimeout(connect, 2000);
          };
          ws.onmessage = (e) => {
            const data = e.data instanceof ArrayBuffer
              ? JSON.parse(new TextDecoder().decode(e.data))
              : JSON.parse(e.data);
            handleMessage(data);
          };
        }

        function send(type, payload) {
          if (!ws || ws.readyState !== 1) return;
          ws.send(JSON.stringify({ t: type, id: clientId, d: payload ? btoa(JSON.stringify(payload)) : null }));
        }

        function handleMessage(env) {
          try {
            const p = env.d ? JSON.parse(atob(env.d)) : null;
            switch (env.t) {
              case 'welcome':
                clientId = p.clientId;
                break;
              case 'statusUpdate':
                applyStatus(p);
                break;
              case 'sessionState':
                renderRoster(p.clients || []);
                break;
            }
          } catch(e) {}
        }

        function applyStatus(s) {
          outputEnabled = s.outputEnabled;
          document.getElementById('output-status').textContent = s.outputEnabled ? 'ON' : 'OFF';
          document.getElementById('output-status').className = 'stat-value ' + (s.outputEnabled ? 'on' : 'off');
          document.getElementById('btn-output').textContent = s.outputEnabled ? 'Disable Output' : 'Enable Output';
          document.getElementById('btn-output').className = 'output-btn ' + (s.outputEnabled ? 'danger' : 'primary');
          document.getElementById('fps').textContent = s.fps.toFixed(0);
          document.getElementById('tl-pos').textContent = s.timelinePosition != null ? formatTime(s.timelinePosition) : '—';
          document.getElementById('active-cue').textContent = s.activeCueName || '—';
          document.getElementById('uptime').textContent = formatUptime(s.uptime);
          document.getElementById('tc-current').textContent = s.timecodeSource;
          document.getElementById('footer').textContent = 'Connected · ' + new Date().toLocaleTimeString();
        }

        function renderRoster(clients) {
          const r = document.getElementById('roster');
          if (!clients.length) { r.innerHTML = '<span class="empty">No active sessions</span>'; return; }
          r.innerHTML = clients.map(c => `
            <div class="client-row">
              <div class="dot"></div>
              <span>${c.name}</span>
              <span class="role-badge role-${c.role}">${c.role.toUpperCase()}</span>
            </div>`).join('');
        }

        function cmd(command, arg) {
          send('command', { cmd: command, arg: arg || null });
        }

        function formatTime(s) {
          const h = Math.floor(s/3600), m = Math.floor((s%3600)/60), sec = Math.floor(s%60);
          return [h,m,sec].map(n=>String(n).padStart(2,'0')).join(':');
        }
        function formatUptime(s) {
          const d=Math.floor(s/86400), h=Math.floor((s%86400)/3600), m=Math.floor((s%3600)/60);
          return d>0 ? `${d}d ${h}h` : h>0 ? `${h}h ${m}m` : `${m}m`;
        }

        async function poll() {
          try {
            const r = await fetch('/api/status');
            if (r.ok) applyStatus(await r.json());
          } catch(e) {}
          setTimeout(poll, 2000);
        }

        document.getElementById('btn-output').onclick = () => cmd(outputEnabled ? 'output.off' : 'output.on');
        document.getElementById('btn-play').onclick   = () => cmd('tl.play');
        document.getElementById('btn-pause').onclick  = () => cmd('tl.pause');
        document.getElementById('btn-stop').onclick   = () => cmd('tl.stop');
        document.getElementById('btn-cue-go').onclick = () => cmd('cue.go');
        document.getElementById('btn-cue-back').onclick = () => cmd('cue.back');
        document.getElementById('btn-tc-set').onclick = () =>
          cmd('tc.source', document.getElementById('tc-select').value);

        connect();
        </script>
        </body>
        </html>
        """
    }
}
