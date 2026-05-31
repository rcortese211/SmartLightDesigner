import SwiftUI

struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var pixelsPerSecond: Double = 60.0
    @State private var scrollOffset: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            transportBar
            Divider()
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    timeRuler
                    cueBlocks
                        .padding(.top, 32)
                }
                .frame(minWidth: totalWidth, minHeight: 200)
            }
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItemGroup {
                Button(action: { cueEngine.back() }) {
                    Label("Back", systemImage: "backward.fill")
                }
                Button(action: { cueEngine.go() }) {
                    Label("Go", systemImage: "forward.fill")
                }
                .buttonStyle(.borderedProminent)
                Slider(value: $pixelsPerSecond, in: 20...200, label: { Text("Zoom") })
                    .frame(width: 120)
            }
        }
    }

    var cueEngine: CueEngine { appState.engine.cueEngine }

    private var totalDuration: Double {
        let lastEnd = appState.show.cues.reduce(0.0) { $0 + $1.fadeInTime + 2.0 }
        return max(60, lastEnd + 10)
    }

    private var totalWidth: Double {
        totalDuration * pixelsPerSecond
    }

    private var transportBar: some View {
        HStack {
            Image(systemName: "backward.fill").onTapGesture { cueEngine.back() }
            Image(systemName: "forward.fill").onTapGesture { cueEngine.go() }
            Spacer()
            if let cue = cueEngine.currentCue {
                Text("Cue \(String(format: "%.1f", cue.number)): \(cue.name)")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Freerun").font(.callout).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var timeRuler: some View {
        Canvas { ctx, size in
            let step = pixelsPerSecond
            var t: Double = 0
            while t * step < size.width {
                let x = t * step
                let isMinute = t.truncatingRemainder(dividingBy: 60) == 0
                ctx.stroke(
                    Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: isMinute ? 24 : 12)) },
                    with: .color(.secondary),
                    lineWidth: isMinute ? 1.5 : 0.5
                )
                if t.truncatingRemainder(dividingBy: max(1, 30 / pixelsPerSecond * 10).rounded()) == 0 {
                    ctx.draw(Text(formatTime(t)).font(.caption2).foregroundStyle(.secondary),
                             at: CGPoint(x: x + 3, y: 2))
                }
                t += 1
            }
        }
        .frame(height: 32)
    }

    private var cueBlocks: some View {
        Canvas { ctx, size in
            var xOffset = 0.0
            let rowH: Double = 44
            let colors: [Color] = [.blue, .purple, .teal, .orange, .pink]
            for (i, cue) in appState.show.cues.enumerated() {
                let blockW = max(40, cue.fadeInTime * pixelsPerSecond)
                let color = colors[i % colors.count]
                let rect = CGRect(x: xOffset, y: 0, width: blockW, height: rowH)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(color.opacity(0.7)))
                ctx.draw(
                    Text(cue.name.isEmpty ? String(format: "%.1f", cue.number) : cue.name)
                        .font(.caption).bold().foregroundStyle(.white),
                    at: CGPoint(x: xOffset + 6, y: rowH / 2),
                    anchor: .leading
                )
                xOffset += blockW + 4
            }
        }
        .frame(height: 56)
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m\(s)s" : "\(s)s"
    }
}
