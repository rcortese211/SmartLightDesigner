import Foundation

// Full web-based designer mode — a single-page app that mirrors the macOS
// panel layout (Effects / Cues / Patch / Output / Timeline).
// Communicates with the Pi via REST API at /api/show and /api/command.

enum DesignerUI {
    static func html(port: Int) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>SmartLight Designer (Pi)</title>
        <style>
          :root{--bg:#0b0a10;--surf:#13111c;--surf2:#1c1928;--surf3:#23203a;
               --border:#2a2640;--active:#3de87a;--purple:#8b5cf6;--blue:#4ab4ff;
               --text:#e8e6f0;--dim:#888;--red:#f87171;--amber:#fbbf24}
          *{box-sizing:border-box;margin:0;padding:0}
          html,body{height:100%}
          body{background:var(--bg);color:var(--text);font-family:'SF Mono',Consolas,monospace;
               font-size:12px;display:flex;flex-direction:column;overflow:hidden}
          /* Header */
          header{background:var(--surf2);border-bottom:1px solid var(--border);
                 padding:0 16px;height:40px;display:flex;align-items:center;gap:12px;flex-shrink:0}
          .logo{font-size:14px;font-weight:800;letter-spacing:1px;
                background:linear-gradient(90deg,var(--active),var(--purple));
                -webkit-background-clip:text;-webkit-text-fill-color:transparent}
          .mode-badge{background:var(--purple);color:#fff;font-size:9px;font-weight:700;
                      letter-spacing:1px;padding:2px 7px;border-radius:3px}
          nav{display:flex;gap:2px;margin-left:16px}
          nav button{background:none;border:none;color:var(--dim);padding:5px 12px;
                     border-radius:4px;cursor:pointer;font:inherit;font-size:11px;font-weight:600}
          nav button.active,nav button:hover{color:var(--text);background:var(--surf3)}
          .status-bar{margin-left:auto;display:flex;align-items:center;gap:8px;font-size:10px;color:var(--dim)}
          .status-dot{width:7px;height:7px;border-radius:50%;background:var(--dim)}
          .status-dot.on{background:var(--active)}
          /* Main layout */
          .app{display:flex;flex:1;overflow:hidden}
          /* Panels */
          .panel{background:var(--surf);border-right:1px solid var(--border);
                 display:flex;flex-direction:column;overflow:hidden}
          .panel-header{background:var(--surf2);border-bottom:1px solid var(--border);
                        padding:6px 10px;font-size:9px;font-weight:700;letter-spacing:1.5px;
                        color:var(--dim);text-transform:uppercase;flex-shrink:0}
          .panel-body{flex:1;overflow-y:auto}
          /* Page views */
          .page{display:none;flex:1;overflow:hidden}
          .page.active{display:flex}
          /* Shared components */
          .list-item{padding:8px 10px;cursor:pointer;border-bottom:1px solid var(--border)}
          .list-item:hover,.list-item.selected{background:var(--surf3)}
          .list-item-title{font-weight:600;margin-bottom:2px}
          .list-item-sub{font-size:10px;color:var(--dim)}
          btn{display:inline-flex;align-items:center;gap:4px;padding:5px 10px;
              background:var(--surf2);border:1px solid var(--border);border-radius:4px;
              color:var(--text);cursor:pointer;font:inherit;font-size:11px;font-weight:600;
              transition:all .12s}
          btn:hover{border-color:var(--purple);color:var(--purple)}
          btn.primary{background:var(--active);border-color:var(--active);color:#000}
          /* Bottom bar */
          .bottom-bar{height:36px;background:var(--surf2);border-top:1px solid var(--border);
                      display:flex;align-items:center;padding:0 14px;gap:12px;flex-shrink:0}
          /* Editor area */
          .editor{flex:1;background:var(--bg);padding:16px;overflow-y:auto}
          .editor h2{font-size:10px;font-weight:700;letter-spacing:1.5px;color:var(--dim);
                     text-transform:uppercase;margin-bottom:12px}
          .form-row{display:flex;align-items:center;gap:10px;margin-bottom:10px}
          .form-row label{font-size:10px;color:var(--dim);width:100px;flex-shrink:0}
          input,select{background:var(--surf2);border:1px solid var(--border);color:var(--text);
                       padding:5px 8px;border-radius:4px;font:inherit;font-size:11px;width:100%}
          input:focus,select:focus{outline:none;border-color:var(--purple)}
          .slider-row{display:flex;align-items:center;gap:8px}
          input[type=range]{flex:1;accent-color:var(--purple)}
          .range-val{width:36px;text-align:right;color:var(--dim);font-size:10px}
          /* Empty state */
          .empty-state{flex:1;display:flex;flex-direction:column;align-items:center;
                       justify-content:center;gap:8px;color:var(--dim);font-size:11px}
          /* Visualizer */
          #viz-canvas{background:#08060f;display:block}
        </style>
        </head>
        <body>

        <header>
          <span class="logo">SmartLight</span>
          <span class="mode-badge">DESIGNER</span>
          <nav>
            <button class="active" onclick="showPage('effects')">Effects</button>
            <button onclick="showPage('cues')">Cues</button>
            <button onclick="showPage('timeline')">Timeline</button>
            <button onclick="showPage('patch')">Patch</button>
            <button onclick="showPage('output')">Output</button>
            <button onclick="showPage('visualizer')">Visualizer</button>
          </nav>
          <div class="status-bar">
            <div id="out-dot" class="status-dot"></div>
            <span id="out-label">Output OFF</span>
            <btn onclick="toggleOutput()" id="out-btn">Enable</btn>
            <span id="save-status" style="color:var(--dim)">—</span>
          </div>
        </header>

        <div class="app">

          <!-- EFFECTS PAGE -->
          <div class="page active" id="page-effects">
            <div class="panel" style="width:180px">
              <div class="panel-header">Folders</div>
              <div class="panel-body" id="folders-list"></div>
              <div class="bottom-bar">
                <btn onclick="addFolder()">+ Folder</btn>
              </div>
            </div>
            <div class="panel" style="width:200px">
              <div class="panel-header">Palettes</div>
              <div class="panel-body" id="palettes-list"></div>
              <div class="bottom-bar">
                <btn onclick="addPalette()">+ Palette</btn>
                <btn onclick="recallA()" style="margin-left:auto">→ A</btn>
                <btn onclick="recallB()">→ B</btn>
              </div>
            </div>
            <div class="panel" style="width:160px">
              <div class="panel-header">Layers</div>
              <div class="panel-body" id="layers-list"></div>
              <div class="bottom-bar">
                <btn onclick="addLayer()">+</btn>
                <btn onclick="storePalette()" style="margin-left:auto">STORE</btn>
              </div>
            </div>
            <div class="editor">
              <div id="layer-editor-area" class="empty-state">Select a layer</div>
            </div>
          </div>

          <!-- CUES PAGE -->
          <div class="page" id="page-cues">
            <div class="panel" style="width:420px">
              <div class="panel-header">Cue List</div>
              <div class="panel-body" id="cue-list"></div>
              <div class="bottom-bar">
                <btn onclick="addCue()">+ Cue</btn>
                <btn onclick="cueGo()" class="primary" style="margin-left:auto">GO</btn>
                <btn onclick="cueBack()">◀ Back</btn>
              </div>
            </div>
            <div class="editor" id="cue-editor-area">
              <div class="empty-state">Select a cue to edit</div>
            </div>
          </div>

          <!-- TIMELINE PAGE -->
          <div class="page" id="page-timeline">
            <div style="flex:1;display:flex;flex-direction:column">
              <div style="background:var(--surf2);border-bottom:1px solid var(--border);
                          padding:6px 14px;display:flex;align-items:center;gap:10px">
                <span id="tl-time">0:00:00</span>
                <btn onclick="cmd('tl.play')">▶</btn>
                <btn onclick="cmd('tl.pause')">⏸</btn>
                <btn onclick="cmd('tl.stop')">⏹</btn>
              </div>
              <div id="timeline-area" style="flex:1;background:var(--bg);padding:16px">
                <div class="empty-state">Timeline tracks will appear here</div>
              </div>
            </div>
          </div>

          <!-- PATCH PAGE -->
          <div class="page" id="page-patch">
            <div class="panel" style="width:320px">
              <div class="panel-header">Fixtures</div>
              <div class="panel-body" id="fixture-list"></div>
              <div class="bottom-bar"><btn onclick="addFixture()">+ Add Fixture</btn></div>
            </div>
            <div class="editor" id="fixture-editor-area">
              <div class="empty-state">Select a fixture</div>
            </div>
          </div>

          <!-- OUTPUT PAGE -->
          <div class="page" id="page-output">
            <div class="editor">
              <h2>Output Settings</h2>
              <div class="form-row">
                <label>Art-Net</label>
                <input type="checkbox" id="artnet-en" style="width:auto">
                <input type="text" id="artnet-ip" placeholder="255.255.255.255" style="flex:1">
                <input type="number" id="artnet-uni" placeholder="Universe" style="width:70px">
              </div>
              <div class="form-row">
                <label>sACN</label>
                <input type="checkbox" id="sacn-en" style="width:auto">
                <input type="number" id="sacn-uni" placeholder="Universe" style="width:70px">
              </div>
              <div class="form-row" style="margin-top:16px">
                <btn class="primary" onclick="saveOutput()">Apply</btn>
              </div>
              <div id="output-status-block" style="margin-top:16px"></div>
            </div>
          </div>

          <!-- VISUALIZER PAGE -->
          <div class="page" id="page-visualizer">
            <div style="flex:1;display:flex;flex-direction:column;align-items:center;
                        justify-content:center;background:var(--bg)">
              <canvas id="viz-canvas"></canvas>
              <div style="font-size:10px;color:var(--dim);margin-top:8px">
                Fixture positions from patch — updates on status poll
              </div>
            </div>
          </div>

        </div><!-- .app -->

        <script>
        const port = \(port);
        let show = { effectFolders:[], fixtures:[], cues:[], layers:[] };
        let selectedFolder=null, selectedPalette=null, selectedCue=null, selectedFixture=null;
        let outputEnabled=false, pollTimer=null;

        // Page navigation
        function showPage(name) {
          document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
          document.getElementById('page-' + name).classList.add('active');
          document.querySelectorAll('nav button').forEach((b,i) => b.classList.remove('active'));
          const order = ['effects','cues','timeline','patch','output','visualizer'];
          const idx = order.indexOf(name);
          if (idx >= 0) document.querySelectorAll('nav button')[idx].classList.add('active');
          if (name === 'effects')   renderEffects();
          if (name === 'cues')      renderCues();
          if (name === 'patch')     renderPatch();
        }

        // API helpers
        async function loadShow() {
          try {
            const r = await fetch('/api/show');
            if (r.ok) { show = await r.json(); renderEffects(); }
          } catch(e) {}
        }

        async function saveShow() {
          try {
            const r = await fetch('/api/show', { method:'PUT',
              headers:{'Content-Type':'application/json'}, body: JSON.stringify(show) });
            document.getElementById('save-status').textContent = r.ok ? 'Saved ✓' : 'Save failed';
            setTimeout(() => document.getElementById('save-status').textContent = '—', 2000);
          } catch(e) {}
        }

        async function pollStatus() {
          try {
            const r = await fetch('/api/status');
            if (!r.ok) return;
            const s = await r.json();
            outputEnabled = s.outputEnabled;
            document.getElementById('out-dot').className = 'status-dot' + (s.outputEnabled?' on':'');
            document.getElementById('out-label').textContent = s.outputEnabled ? 'Output ON' : 'Output OFF';
            document.getElementById('out-btn').textContent = s.outputEnabled ? 'Disable' : 'Enable';
            if (s.timelinePosition != null) {
              const p = s.timelinePosition;
              const h=Math.floor(p/3600), m=Math.floor((p%3600)/60), sec=Math.floor(p%60);
              document.getElementById('tl-time').textContent = [h,m,sec].map(n=>String(n).padStart(2,'0')).join(':');
            }
          } catch(e) {}
        }

        async function cmd(command, arg) {
          try { await fetch('/api/command', { method:'POST',
            headers:{'Content-Type':'application/json'},
            body: JSON.stringify({ cmd: command, arg: arg||null }) }); }
          catch(e) {}
        }

        function toggleOutput() { cmd(outputEnabled ? 'output.off' : 'output.on').then(pollStatus); }
        function cueGo()  { cmd('cue.go'); }
        function cueBack(){ cmd('cue.back'); }

        // Effects rendering
        function renderEffects() {
          const fl = document.getElementById('folders-list');
          fl.innerHTML = (show.effectFolders || []).map((f,i) => `
            <div class="list-item${selectedFolder===i?' selected':''}" onclick="selectFolder(${i})">
              <div class="list-item-title">${f.name}</div>
              <div class="list-item-sub">${(f.palettes||[]).length} palettes</div>
            </div>`).join('');
          if (selectedFolder != null) renderPalettes();
        }

        function selectFolder(i) { selectedFolder=i; selectedPalette=null; renderEffects(); renderPalettes(); }

        function renderPalettes() {
          const f = (show.effectFolders||[])[selectedFolder];
          const pl = document.getElementById('palettes-list');
          if (!f) { pl.innerHTML=''; return; }
          pl.innerHTML = (f.palettes||[]).map((p,i) => `
            <div class="list-item${selectedPalette===i?' selected':''}" onclick="selectPalette(${i})">
              <div class="list-item-title">${p.name}</div>
              <div class="list-item-sub">${(p.layers||[]).length} layers</div>
            </div>`).join('');
          renderLayers();
        }

        function selectPalette(i) { selectedPalette=i; renderPalettes(); renderLayers(); }

        function renderLayers() {
          const f = (show.effectFolders||[])[selectedFolder];
          const p = f && (f.palettes||[])[selectedPalette];
          const ll = document.getElementById('layers-list');
          if (!p) { ll.innerHTML=''; return; }
          ll.innerHTML = (p.layers||[]).map((l,i) => `
            <div class="list-item" onclick="editLayer(${i})">
              <div class="list-item-title">${l.name||'Layer '+(i+1)}</div>
              <div class="list-item-sub">${l.effectId||''} · ${Math.round((l.opacity||1)*100)}%</div>
            </div>`).join('');
        }

        function editLayer(i) {
          const f = (show.effectFolders||[])[selectedFolder];
          const p = f && (f.palettes||[])[selectedPalette];
          const l = p && (p.layers||[])[i];
          if (!l) return;
          document.getElementById('layer-editor-area').innerHTML = `
            <h2>Layer Editor</h2>
            <div class="form-row"><label>Name</label>
              <input id="le-name" value="${l.name||''}"></div>
            <div class="form-row"><label>Opacity</label>
              <div class="slider-row">
                <input type="range" id="le-opacity" min="0" max="100" value="${Math.round((l.opacity||1)*100)}">
                <span class="range-val" id="le-opacity-val">${Math.round((l.opacity||1)*100)}%</span>
              </div></div>
            <div class="form-row"><label>Speed</label>
              <div class="slider-row">
                <input type="range" id="le-speed" min="10" max="500" value="${Math.round((l.speed||1)*100)}">
                <span class="range-val" id="le-speed-val">${(l.speed||1).toFixed(1)}×</span>
              </div></div>
            <div class="form-row" style="margin-top:14px">
              <btn class="primary" onclick="saveLayer(${i})">Save Layer</btn>
            </div>`;
          document.getElementById('le-opacity').oninput = e => {
            document.getElementById('le-opacity-val').textContent = e.target.value + '%'; };
          document.getElementById('le-speed').oninput = e => {
            document.getElementById('le-speed-val').textContent = (e.target.value/100).toFixed(1) + '×'; };
        }

        function saveLayer(i) {
          const f = show.effectFolders[selectedFolder];
          const p = f.palettes[selectedPalette];
          p.layers[i].name    = document.getElementById('le-name').value;
          p.layers[i].opacity = parseInt(document.getElementById('le-opacity').value)/100;
          p.layers[i].speed   = parseInt(document.getElementById('le-speed').value)/100;
          saveShow(); renderLayers();
        }

        // Cues rendering
        function renderCues() {
          const cl = document.getElementById('cue-list');
          cl.innerHTML = (show.cues||[]).map((c,i) => `
            <div class="list-item${selectedCue===i?' selected':''}" onclick="selectCue(${i})">
              <div class="list-item-title">Cue ${c.number} — ${c.name||'(unnamed)'}</div>
              <div class="list-item-sub">Fade ${c.fadeInTime||1}s in / ${c.fadeOutTime||1}s out${c.timecodeTime!=null?' · TC '+formatTC(c.timecodeTime):''}</div>
            </div>`).join('');
        }

        function selectCue(i) {
          selectedCue = i;
          const c = (show.cues||[])[i];
          if (!c) return;
          document.getElementById('cue-editor-area').innerHTML = `
            <h2>Cue ${c.number}</h2>
            <div class="form-row"><label>Name</label>
              <input id="ce-name" value="${c.name||''}"></div>
            <div class="form-row"><label>Fade In</label>
              <input id="ce-fi" type="number" step="0.1" value="${c.fadeInTime||1}" style="width:80px">s</div>
            <div class="form-row"><label>Fade Out</label>
              <input id="ce-fo" type="number" step="0.1" value="${c.fadeOutTime||1}" style="width:80px">s</div>
            <div class="form-row"><label>Timecode</label>
              <input id="ce-tc" value="${c.timecodeTime!=null?formatTC(c.timecodeTime):''}"
                     placeholder="HH:MM:SS;FF (optional)"></div>
            <div class="form-row"><label>Notes</label>
              <input id="ce-notes" value="${c.notes||''}"></div>
            <div class="form-row" style="margin-top:14px">
              <btn class="primary" onclick="saveCue(${i})">Save Cue</btn>
            </div>`;
          renderCues();
        }

        function saveCue(i) {
          const c = show.cues[i];
          c.name         = document.getElementById('ce-name').value;
          c.fadeInTime   = parseFloat(document.getElementById('ce-fi').value)||1;
          c.fadeOutTime  = parseFloat(document.getElementById('ce-fo').value)||1;
          c.notes        = document.getElementById('ce-notes').value;
          const tcStr    = document.getElementById('ce-tc').value.trim();
          c.timecodeTime = tcStr ? parseTC(tcStr) : null;
          saveShow(); renderCues();
        }

        function formatTC(s) {
          const h=Math.floor(s/3600),m=Math.floor((s%3600)/60),sec=Math.floor(s%60),f=Math.round((s%1)*30);
          return [h,m,sec].map(n=>String(n).padStart(2,'0')).join(':')+';'+String(f).padStart(2,'0');
        }
        function parseTC(str) {
          const m = str.replace(/[^\\d;:]/g,'').match(/(\\d{1,2})[:;](\\d{1,2})[:;](\\d{1,2})[:;](\\d{1,2})/);
          if (!m) return null;
          return parseInt(m[1])*3600 + parseInt(m[2])*60 + parseInt(m[3]) + parseInt(m[4])/30;
        }

        // Patch rendering
        function renderPatch() {
          const fl = document.getElementById('fixture-list');
          fl.innerHTML = (show.fixtures||[]).map((f,i) => `
            <div class="list-item${selectedFixture===i?' selected':''}" onclick="selectFixture(${i})">
              <div class="list-item-title">${f.name||'Fixture '+(i+1)}</div>
              <div class="list-item-sub">Uni ${f.universe} · Ch ${f.startAddress}</div>
            </div>`).join('');
        }

        function selectFixture(i) {
          selectedFixture = i;
          const f = (show.fixtures||[])[i];
          if (!f) return;
          document.getElementById('fixture-editor-area').innerHTML = `
            <h2>Fixture</h2>
            <div class="form-row"><label>Name</label><input id="fe-name" value="${f.name||''}"></div>
            <div class="form-row"><label>Universe</label>
              <input id="fe-uni" type="number" value="${f.universe}" style="width:80px"></div>
            <div class="form-row"><label>Start Address</label>
              <input id="fe-addr" type="number" value="${f.startAddress}" style="width:80px"></div>
            <div class="form-row" style="margin-top:14px">
              <btn class="primary" onclick="saveFixture(${i})">Save</btn>
            </div>`;
          renderPatch();
        }

        function saveFixture(i) {
          show.fixtures[i].name         = document.getElementById('fe-name').value;
          show.fixtures[i].universe      = parseInt(document.getElementById('fe-uni').value)||1;
          show.fixtures[i].startAddress  = parseInt(document.getElementById('fe-addr').value)||1;
          saveShow(); renderPatch();
        }

        // Stubs for add actions (full implementation would use modals)
        function addFolder()  { const n=prompt('Folder name'); if(n){show.effectFolders.push({name:n,palettes:[],id:crypto.randomUUID()});saveShow();renderEffects();} }
        function addPalette() { if(selectedFolder==null)return; const n=prompt('Palette name'); if(n){show.effectFolders[selectedFolder].palettes.push({name:n,layers:[],id:crypto.randomUUID()});saveShow();renderPalettes();} }
        function addLayer()   { /* stub */ alert('Add layer: choose effect from list (stub)'); }
        function addCue()     { const n=prompt('Cue name'); if(n){show.cues=show.cues||[];show.cues.push({number:(show.cues.length+1),name:n,fadeInTime:1,fadeOutTime:1,id:crypto.randomUUID()});saveShow();renderCues();} }
        function addFixture() { const n=prompt('Fixture name'); if(n){show.fixtures=show.fixtures||[];show.fixtures.push({name:n,universe:1,startAddress:1,id:crypto.randomUUID()});saveShow();renderPatch();} }
        function recallA()    { /* stub */ }
        function recallB()    { /* stub */ }
        function storePalette(){ /* stub */ }
        function saveOutput() { /* stub — would POST config changes */ }

        // Init
        loadShow();
        pollStatus();
        pollTimer = setInterval(pollStatus, 2000);
        </script>
        </body>
        </html>
        """
    }
}
