import SwiftUI

struct VisualizerView: View {
    @Environment(AppState.self) private var appState
    @State private var fixtureSize: Double = 28
    @State private var showLabels: Bool = true
    @State private var showChannelValues: Bool = false
    @State private var displayUniverseIndex: Int = 0
    @State private var layoutMode: LayoutMode = .freeform

    enum LayoutMode: String, CaseIterable {
        case freeform = "Freeform"
        case grid     = "Grid"
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider().background(HueBaseTheme.border)
            GeometryReader { geo in
                ZStack {
                    Canvas { ctx, size in
                        drawGrid(ctx: &ctx, size: size)
                        if layoutMode == .freeform {
                            drawFixtures(ctx: &ctx, size: size)
                        } else {
                            drawGridFixtures(ctx: &ctx, size: size)
                        }
                    }
                    .allowsHitTesting(false)
                    .background(Color(red: 0.03, green: 0.02, blue: 0.07))

                    if showLabels && layoutMode == .freeform {
                        ForEach(appState.show.fixtures) { fixture in
                            let pos = fixturePosition(fixture, in: CGSize(width: geo.size.width, height: geo.size.height))
                            fixtureLabel(fixture, position: pos)
                        }
                    }
                }
            }

            // Status strip
            HStack(spacing: 12) {
                Text("\(appState.show.fixtures.count) FIXTURES")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HueBaseTheme.purple.opacity(0.8))
                Text("UNI \(displayUniverseIndex + 1)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.32))
                Spacer()
                let activeCount = appState.show.fixtures.filter { fixture in
                    guard let u = appState.engine.universeData[fixture.universe] else { return false }
                    let start = fixture.startAddress - 1
                    return (0..<3).contains { off in
                        let i = start + off
                        return i < u.count && u[i] > 0
                    }
                }.count
                if activeCount > 0 {
                    Text("\(activeCount) ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(HueBaseTheme.active)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(HueBaseTheme.surfaceHigh)
            .overlay(alignment: .top) { GradientBar(height: 1) }
        }
        .navigationTitle("Visualizer")
        .toolbar {
            ToolbarItemGroup {
                Picker("Layout", selection: $layoutMode) {
                    ForEach(LayoutMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Picker("Universe", selection: $displayUniverseIndex) {
                    let universes = Set(appState.show.fixtures.map { $0.universe }).sorted()
                    ForEach(universes, id: \.self) { u in
                        Text("Uni \(u + 1)").tag(u)
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                Toggle("Labels", isOn: $showLabels)
                Toggle("Values", isOn: $showChannelValues)
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Text("SIZE")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.38))
            Slider(value: $fixtureSize, in: 12...80)
                .tint(HueBaseTheme.purple)
                .frame(width: 120)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(HueBaseTheme.surfaceHigh)
    }

    // MARK: - Drawing

    private func drawGrid(ctx: inout GraphicsContext, size: CGSize) {
        let step: CGFloat = 48
        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        ctx.stroke(path, with: .color(Color(red: 0.12, green: 0.09, blue: 0.22)), lineWidth: 0.5)
    }

    private func drawFixtures(ctx: inout GraphicsContext, size: CGSize) {
        let universeValues = appState.engine.universeData
        for fixture in appState.show.fixtures {
            let pos = fixturePosition(fixture, in: size)
            drawFixtureAt(ctx: &ctx, pos: pos, fixture: fixture, universeValues: universeValues)
        }
    }

    private func drawGridFixtures(ctx: inout GraphicsContext, size: CGSize) {
        let universeValues = appState.engine.universeData
        let count = appState.show.fixtures.count
        guard count > 0 else { return }

        let cols = max(1, Int(ceil(sqrt(Double(count) * (size.width / max(1, size.height))))))
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(rows)
        let radius = min(cellW, cellH) * 0.3

        for (i, fixture) in appState.show.fixtures.enumerated() {
            let col = i % cols
            let row = i / cols
            let pos = CGPoint(
                x: cellW * CGFloat(col) + cellW / 2,
                y: cellH * CGFloat(row) + cellH / 2
            )
            drawFixtureAt(ctx: &ctx, pos: pos, fixture: fixture,
                          universeValues: universeValues, overrideRadius: radius)

            if showLabels {
                ctx.draw(
                    Text(fixture.name)
                        .font(.system(size: max(6, radius * 0.5), design: .monospaced))
                        .foregroundStyle(Color(red: 0.55, green: 0.38, blue: 0.90).opacity(0.7)),
                    at: CGPoint(x: pos.x, y: pos.y + radius + 8)
                )
            }
        }
    }

    private func drawFixtureAt(ctx: inout GraphicsContext,
                                pos: CGPoint,
                                fixture: Fixture,
                                universeValues: [Int: [UInt8]],
                                overrideRadius: CGFloat? = nil) {
        let radius = overrideRadius ?? (fixtureSize / 2)
        let color = fixtureColor(fixture, universeValues: universeValues)
        let rect = CGRect(x: pos.x - radius, y: pos.y - radius,
                          width: radius * 2, height: radius * 2)

        // Dark base
        ctx.fill(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)),
                 with: .color(Color(red: 0.06, green: 0.04, blue: 0.11)))

        // Colored fill
        ctx.fill(Path(ellipseIn: rect.insetBy(dx: 3, dy: 3)), with: .color(color))

        // Ring — bright purple border when active
        let brightness = color.resolve(in: EnvironmentValues())
        let glow = Double(brightness.red + brightness.green + brightness.blue) / 3.0
        let ringColor = glow > 0.05
            ? Color(red: 0.42, green: 0.18, blue: 0.92).opacity(0.7)
            : Color(red: 0.22, green: 0.16, blue: 0.32)
        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)),
                   with: .color(ringColor), lineWidth: 1)

        // Glow halo
        if glow > 0.15 {
            let glowRect = rect.insetBy(dx: -glow * 10, dy: -glow * 10)
            ctx.fill(Path(ellipseIn: glowRect),
                     with: .color(color.opacity(0.22 * glow)))
        }

        if showChannelValues, let profile = appState.show.profile(for: fixture),
           let universe = universeValues[fixture.universe] {
            let startIdx = fixture.startAddress - 1
            let channelStr = profile.channels.prefix(4).map { ch in
                let idx = startIdx + ch.offset
                let v = idx < universe.count ? universe[idx] : 0
                return "\(v)"
            }.joined(separator: " ")
            ctx.draw(
                Text(channelStr)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75)),
                at: CGPoint(x: pos.x, y: pos.y + radius + 10)
            )
        }
    }

    private func fixtureColor(_ fixture: Fixture, universeValues: [Int: [UInt8]]) -> Color {
        guard let profile = appState.show.profile(for: fixture),
              let universe = universeValues[fixture.universe] else {
            return Color(red: 0.07, green: 0.05, blue: 0.12)
        }

        let startIdx = fixture.startAddress - 1
        var r: Double = 0, g: Double = 0, b: Double = 0, dimmer: Double = 1

        for ch in profile.channels {
            let idx = startIdx + ch.offset
            guard idx < universe.count else { continue }
            let v = Double(universe[idx]) / 255.0
            switch ch.name.lowercased() {
            case "red",   "r": r = v
            case "green", "g": g = v
            case "blue",  "b": b = v
            case "white", "w": r = max(r, v); g = max(g, v); b = max(b, v)
            case "amber", "a": r = max(r, v * 0.9); g = max(g, v * 0.5)
            case "dimmer", "intensity", "master": dimmer = v
            default: break
            }
        }

        if r == 0 && g == 0 && b == 0 && dimmer < 1 {
            return Color(white: dimmer)
        }
        return Color(red: r * dimmer, green: g * dimmer, blue: b * dimmer)
    }

    private func fixturePosition(_ fixture: Fixture, in size: CGSize) -> CGPoint {
        let margin = fixtureSize
        return CGPoint(
            x: margin + fixture.positionX * (size.width - margin * 2),
            y: margin + fixture.positionY * (size.height - margin * 2)
        )
    }

    @ViewBuilder
    private func fixtureLabel(_ fixture: Fixture, position: CGPoint) -> some View {
        Text(fixture.name)
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(HueBaseTheme.purple.opacity(0.7))
            .position(x: position.x, y: position.y + fixtureSize / 2 + 8)
    }
}
