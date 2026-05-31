import SwiftUI

struct VisualizerView: View {
    @Environment(AppState.self) private var appState
    @State private var fixtureSize: Double = 28
    @State private var showLabels: Bool = true
    @State private var showChannelValues: Bool = false
    @State private var displayUniverseIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            GeometryReader { geo in
                ZStack {
                    Color.black
                    Canvas { ctx, size in
                        drawFixtures(ctx: &ctx, size: size)
                    }
                    .allowsHitTesting(false)

                    // Overlay labels
                    if showLabels {
                        ForEach(appState.show.fixtures) { fixture in
                            let pos = fixturePosition(fixture, in: CGSize(width: geo.size.width, height: geo.size.height))
                            fixtureLabel(fixture, position: pos)
                        }
                    }
                }
            }
        }
        .navigationTitle("Visualizer")
        .toolbar {
            ToolbarItemGroup {
                Picker("Universe", selection: $displayUniverseIndex) {
                    let universes = Set(appState.show.fixtures.map { $0.universe }).sorted()
                    ForEach(universes, id: \.self) { u in
                        Text("Universe \(u + 1)").tag(u)
                    }
                }
                Toggle("Labels", isOn: $showLabels)
                Toggle("Values", isOn: $showChannelValues)
            }
        }
    }

    private var controlBar: some View {
        HStack {
            Text("Fixture Size")
            Slider(value: $fixtureSize, in: 12...80)
                .frame(width: 120)
            Spacer()
            Text("\(appState.show.fixtures.count) fixtures")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func drawFixtures(ctx: inout GraphicsContext, size: CGSize) {
        let universeValues = appState.engine.universeData

        for fixture in appState.show.fixtures {
            let pos = fixturePosition(fixture, in: size)
            let radius = fixtureSize / 2

            let color = fixtureColor(fixture, universeValues: universeValues)
            let rect = CGRect(x: pos.x - radius, y: pos.y - radius,
                              width: fixtureSize, height: fixtureSize)

            // Outer ring (always visible)
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)),
                       with: .color(.white.opacity(0.3)), lineWidth: 1)

            // Fill with fixture color
            ctx.fill(Path(ellipseIn: rect), with: .color(color))

            // Glow when bright
            let brightness = color.resolve(in: EnvironmentValues())
            let glow = Double(brightness.red + brightness.green + brightness.blue) / 3.0
            if glow > 0.1 {
                let glowRect = rect.insetBy(dx: -glow * 8, dy: -glow * 8)
                ctx.fill(Path(ellipseIn: glowRect),
                         with: .color(color.opacity(0.3 * glow)))
            }

            // Channel value overlay
            if showChannelValues, let profile = appState.show.profile(for: fixture),
               let universe = universeValues[fixture.universe] {
                let startIdx = fixture.startAddress - 1
                let channelStr = profile.channels.prefix(4).map { ch in
                    let idx = startIdx + ch.offset
                    let v = idx < universe.count ? universe[idx] : 0
                    return "\(v)"
                }.joined(separator: " ")
                ctx.draw(Text(channelStr).font(.system(size: 7)).foregroundStyle(.white),
                         at: CGPoint(x: pos.x, y: pos.y + radius + 10))
            }
        }
    }

    private func fixtureColor(_ fixture: Fixture, universeValues: [Int: [UInt8]]) -> Color {
        guard let profile = appState.show.profile(for: fixture),
              let universe = universeValues[fixture.universe] else {
            return Color(white: 0.1)
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

        // If only a dimmer channel exists, show white
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
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.7))
            .position(x: position.x, y: position.y + fixtureSize / 2 + 8)
    }
}
