import SwiftUI

struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var pixelsPerSecond: Double = 60.0

    var body: some View {
        VStack(spacing: 0) {
            transportBar
            Divider().background(HueBaseTheme.border)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    timeRuler
                    cueBlocks.padding(.top, 32)
                }
                .frame(minWidth: totalWidth, minHeight: 200)
            }
            .background(HueBaseTheme.background)
        }
        .navigationTitle("Timeline")
        .background(HueBaseTheme.background)
        .toolbar {
            ToolbarItemGroup {
                Button(action: { cueEngine.back() }) {
                    Image(systemName: "backward.fill")
                }
                Button(action: { cueEngine.go() }) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(HueBaseTheme.purple)
                HStack(spacing: 6) {
                    Text("ZOOM")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.38))
                    Slider(value: $pixelsPerSecond, in: 20...200, label: { EmptyView() })
                        .frame(width: 100)
                        .tint(HueBaseTheme.purple)
                }
            }
        }
    }

    var cueEngine: CueEngine { appState.engine.cueEngine }

    private var totalDuration: Double {
        let lastEnd = appState.show.cues.reduce(0.0) { $0 + $1.fadeInTime + 2.0 }
        return max(60, lastEnd + 10)
    }

    private var totalWidth: Double { totalDuration * pixelsPerSecond }

    private var transportBar: some View {
        HStack(spacing: 0) {
            // Transport buttons
            HStack(spacing: 2) {
                transportBtn(icon: "backward.fill") { cueEngine.back() }
                transportBtn(icon: "forward.fill")  { cueEngine.go() }
            }
            .padding(.horizontal, 8)

            HueBaseTheme.border.frame(width: 1).padding(.vertical, 4)

            // Current cue indicator
            HStack(spacing: 6) {
                if let cue = cueEngine.currentCue {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(HueBaseTheme.active)
                        .frame(width: 8, height: 8)
                    Text("CUE \(String(format: "%.1f", cue.number))  \(cue.name)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(HueBaseTheme.active)
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(white: 0.22))
                        .frame(width: 8, height: 8)
                    Text("FREERUN")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.35))
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("\(appState.show.cues.count) CUES")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(white: 0.32))
                .padding(.trailing, 10)
        }
        .frame(height: 28)
        .background(HueBaseTheme.surfaceHigh)
    }

    private func transportBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 22, height: 20)
                .foregroundStyle(HueBaseTheme.purple)
                .background(HueBaseTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(HueBaseTheme.border, lineWidth: 1)
                )
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
    }

    private var timeRuler: some View {
        Canvas { ctx, size in
            let step = pixelsPerSecond
            var t: Double = 0
            while t * step < size.width {
                let x = t * step
                let isMinute = t.truncatingRemainder(dividingBy: 60) == 0
                let lineH: CGFloat = isMinute ? 24 : 12
                ctx.stroke(
                    Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: lineH)) },
                    with: .color(isMinute ? HueBaseTheme.purple.opacity(0.5) : HueBaseTheme.border),
                    lineWidth: isMinute ? 1.0 : 0.5
                )
                if t.truncatingRemainder(dividingBy: max(1, 30 / pixelsPerSecond * 10).rounded()) == 0 {
                    ctx.draw(
                        Text(formatTime(t))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color(white: 0.45)),
                        at: CGPoint(x: x + 3, y: 2)
                    )
                }
                t += 1
            }
        }
        .frame(height: 32)
        .background(HueBaseTheme.surfaceHigh)
    }

    private var cueBlocks: some View {
        Canvas { ctx, size in
            var xOffset = 0.0
            let rowH: Double = 44
            let blockColors: [Color] = [
                HueBaseTheme.purple,
                HueBaseTheme.blue,
                Color(red: 0.55, green: 0.1, blue: 0.80),
                Color(red: 0.20, green: 0.50, blue: 0.90),
                Color(red: 0.70, green: 0.12, blue: 0.60)
            ]
            for (i, cue) in appState.show.cues.enumerated() {
                let blockW = max(40, cue.fadeInTime * pixelsPerSecond)
                let color = blockColors[i % blockColors.count]
                let rect = CGRect(x: xOffset + 1, y: 1, width: blockW - 2, height: rowH - 2)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(color.opacity(0.35)))
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 3),
                           with: .color(color.opacity(0.7)), lineWidth: 1)
                ctx.draw(
                    Text(cue.name.isEmpty ? String(format: "%.1f", cue.number) : cue.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.85)),
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
