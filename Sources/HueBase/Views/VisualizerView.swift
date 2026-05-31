import SwiftUI

struct VisualizerView: View {
    @Environment(AppState.self) private var appState
    @State private var fixtureSize: Double = 28
    @State private var showLabels: Bool = true
    @State private var showChannelValues: Bool = false
    @State private var showOverlayEffect: Bool = true
    @State private var displayUniverseIndex: Int = 0
    @State private var layoutMode: LayoutMode = .freeform
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @GestureState private var liveZoomDelta: CGFloat = 1.0
    @GestureState private var livePanDelta: CGSize = .zero

    enum LayoutMode: String, CaseIterable {
        case freeform = "Map"
        case grid     = "Grid"
    }

    var body: some View {
        // Capture in body so @Observable tracks these → canvas redraws on change
        let fixtures = appState.show.fixtures
        let universeData = appState.engine.universeData

        let activeCount = fixtures.filter { fixture in
            guard let u = universeData[fixture.universe] else { return false }
            let start = fixture.startAddress - 1
            return (0..<3).contains { off in
                let i = start + off; return i < u.count && u[i] > 0
            }
        }.count

        return VStack(spacing: 0) {
            controlBar
            Divider().background(HueBaseTheme.border)

            if fixtures.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    let effectiveZoom = zoomScale * liveZoomDelta
                    let effectivePan  = CGSize(
                        width:  panOffset.width  + livePanDelta.width,
                        height: panOffset.height + livePanDelta.height
                    )

                    ZStack {
                        Canvas { ctx, size in
                            drawGrid(ctx: &ctx, size: size)
                            if showOverlayEffect {
                                drawOverlay(ctx: &ctx, size: size)
                            }
                            if layoutMode == .freeform {
                                drawFixtures(ctx: &ctx, size: size,
                                             fixtures: fixtures, universeData: universeData)
                            } else {
                                drawGridFixtures(ctx: &ctx, size: size,
                                                 fixtures: fixtures, universeData: universeData)
                            }
                        }
                        .allowsHitTesting(false)
                        .background(Color(red: 0.03, green: 0.02, blue: 0.07))

                        if showLabels && layoutMode == .freeform {
                            ForEach(fixtures) { fixture in
                                let pos = fixturePosition(fixture, in: geo.size)
                                fixtureLabel(fixture, position: pos)
                            }
                        }
                    }
                    .scaleEffect(effectiveZoom, anchor: .center)
                    .offset(effectivePan)
                    .gesture(
                        MagnificationGesture()
                            .updating($liveZoomDelta) { val, state, _ in state = val }
                            .onEnded { val in
                                zoomScale = max(0.25, min(8.0, zoomScale * val))
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .updating($livePanDelta) { val, state, _ in state = val.translation }
                            .onEnded { val in
                                panOffset = CGSize(
                                    width:  panOffset.width  + val.translation.width,
                                    height: panOffset.height + val.translation.height
                                )
                            }
                    )
                }
                .clipped()
            }

            // Status strip
            HStack(spacing: 12) {
                Text("\(fixtures.count) FIXTURES")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HueBaseTheme.purple.opacity(0.8))
                Text("UNI \(displayUniverseIndex + 1)")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.32))
                Spacer()
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
                if !fixtures.isEmpty {
                    Picker("Universe", selection: $displayUniverseIndex) {
                        let universes = Set(fixtures.map { $0.universe }).sorted()
                        ForEach(universes, id: \.self) { u in
                            Text("Uni \(u + 1)").tag(u)
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                Toggle("Labels", isOn: $showLabels)
                Toggle("Values", isOn: $showChannelValues)
                Toggle("Overlay", isOn: $showOverlayEffect)
                Button(action: resetZoom) {
                    Image(systemName: "arrow.up.left.and.arrow.bottom.right")
                        .help("Reset zoom & pan")
                }
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
                .frame(width: 100)

            Divider().frame(height: 14)

            Text("ZOOM")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.38))
            Button(action: { zoomScale = max(0.25, zoomScale / 1.25) }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(white: 0.55))
            Text(String(format: "%.0f%%", zoomScale * 100))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.45))
                .frame(width: 36)
                .onTapGesture { resetZoom() }
            Button(action: { zoomScale = min(8.0, zoomScale * 1.25) }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(white: 0.55))

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(HueBaseTheme.surfaceHigh)
    }

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoomScale = 1.0
            panOffset = .zero
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "eye.slash")
                .font(.system(size: 32))
                .foregroundStyle(HueBaseTheme.purple.opacity(0.25))
            Text("NO FIXTURES PATCHED")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.25))
                .kerning(1)
            Text("Add fixtures in Settings → Patch to see them here.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.2))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.03, green: 0.02, blue: 0.07))
    }

    // MARK: - Drawing

    private func drawGrid(ctx: inout GraphicsContext, size: CGSize) {
        let step: CGFloat = 48
        var path = Path()
        var x: CGFloat = 0
        while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
        var y: CGFloat = 0
        while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
        ctx.stroke(path, with: .color(Color(red: 0.12, green: 0.09, blue: 0.22)), lineWidth: 0.5)
    }

    // Reused across drawOverlay calls — fixed UUIDs so no heap churn per frame
    private static let overlayProfileID = UUID()
    private static let overlayProfile = FixtureProfile(
        id: overlayProfileID,
        name: "Overlay",
        manufacturer: "",
        channels: [
            FixtureChannel(id: UUID(), name: "Red",   offset: 0, defaultValue: 0),
            FixtureChannel(id: UUID(), name: "Green", offset: 1, defaultValue: 0),
            FixtureChannel(id: UUID(), name: "Blue",  offset: 2, defaultValue: 0)
        ]
    )
    private static let overlayFixtureID = UUID()

    private func drawOverlay(ctx: inout GraphicsContext, size: CGSize) {
        let fade   = appState.crossfade
        let aLayers = (fade < 0.999) ? appState.show.layers.filter { $0.isEnabled } : []
        let bLayers = (fade > 0.001) ? appState.programBLayers.filter { $0.isEnabled } : []
        guard !aLayers.isEmpty || !bLayers.isEmpty else { return }

        let registry = EffectRegistry.shared
        let profile  = Self.overlayProfile
        let overrides = appState.engine.parameterOverrides
        let time = Date().timeIntervalSinceReferenceDate

        let cellSize: CGFloat = 20
        let cols = Int(ceil(size.width  / cellSize))
        let rows = Int(ceil(size.height / cellSize))

        var vf = Fixture(id: Self.overlayFixtureID, name: "", profileId: profile.id,
                         universe: 0, startAddress: 1, positionX: 0, positionY: 0)

        for row in 0..<rows {
            for col in 0..<cols {
                vf.positionX = (Double(col) + 0.5) / Double(cols)
                vf.positionY = (Double(row) + 0.5) / Double(rows)

                // Render Program A
                var ar: Double = 0, ag: Double = 0, ab: Double = 0
                for layer in aLayers {
                    guard let effect = registry.effect(for: layer.effectId) else { continue }
                    var params = layer.parameters
                    if let ov = overrides[layer.id] { params.merge(ov) { _, new in new } }
                    let ch = effect.render(fixture: vf, profile: profile,
                                           parameters: params, time: time, speed: layer.speed)
                    let a = layer.opacity
                    ar += (Double(ch[0] ?? 0) / 255.0 - ar) * a
                    ag += (Double(ch[1] ?? 0) / 255.0 - ag) * a
                    ab += (Double(ch[2] ?? 0) / 255.0 - ab) * a
                }

                // Render Program B
                var br: Double = 0, bg: Double = 0, bb: Double = 0
                for layer in bLayers {
                    guard let effect = registry.effect(for: layer.effectId) else { continue }
                    var params = layer.parameters
                    if let ov = overrides[layer.id] { params.merge(ov) { _, new in new } }
                    let ch = effect.render(fixture: vf, profile: profile,
                                           parameters: params, time: time, speed: layer.speed)
                    let a = layer.opacity
                    br += (Double(ch[0] ?? 0) / 255.0 - br) * a
                    bg += (Double(ch[1] ?? 0) / 255.0 - bg) * a
                    bb += (Double(ch[2] ?? 0) / 255.0 - bb) * a
                }

                // Crossfade A → B
                let r = ar * (1 - fade) + br * fade
                let g = ag * (1 - fade) + bg * fade
                let b = ab * (1 - fade) + bb * fade
                guard r > 0.004 || g > 0.004 || b > 0.004 else { continue }

                let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize,
                                   width: cellSize, height: cellSize)
                ctx.fill(Path(rect),
                         with: .color(Color(red: r, green: g, blue: b).opacity(0.55)))
            }
        }
    }

    private func drawFixtures(ctx: inout GraphicsContext, size: CGSize,
                               fixtures: [Fixture], universeData: [Int: [UInt8]]) {
        for fixture in fixtures {
            let pos = fixturePosition(fixture, in: size)
            drawFixtureAt(ctx: &ctx, pos: pos, fixture: fixture, universeData: universeData)
        }
    }

    private func drawGridFixtures(ctx: inout GraphicsContext, size: CGSize,
                                   fixtures: [Fixture], universeData: [Int: [UInt8]]) {
        let count = fixtures.count
        guard count > 0 else { return }
        let cols = max(1, Int(ceil(sqrt(Double(count) * (size.width / max(1, size.height))))))
        let rows = max(1, Int(ceil(Double(count) / Double(cols))))
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(rows)
        let radius = min(cellW, cellH) * 0.3

        for (i, fixture) in fixtures.enumerated() {
            let col = i % cols
            let row = i / cols
            let pos = CGPoint(x: cellW * CGFloat(col) + cellW / 2,
                              y: cellH * CGFloat(row) + cellH / 2)
            drawFixtureAt(ctx: &ctx, pos: pos, fixture: fixture,
                          universeData: universeData, overrideRadius: radius)
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
                                universeData: [Int: [UInt8]],
                                overrideRadius: CGFloat? = nil) {
        let radius: CGFloat = overrideRadius ?? CGFloat(fixtureSize) / 2
        let color = fixtureColor(fixture, universeData: universeData)
        let rect = CGRect(x: pos.x - radius, y: pos.y - radius,
                          width: radius * 2, height: radius * 2)

        ctx.fill(Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)),
                 with: .color(Color(red: 0.06, green: 0.04, blue: 0.11)))
        ctx.fill(Path(ellipseIn: rect.insetBy(dx: 3, dy: 3)), with: .color(color))

        let brightness = color.resolve(in: EnvironmentValues())
        let glow = Double(brightness.red + brightness.green + brightness.blue) / 3.0
        let ringColor = glow > 0.05
            ? Color(red: 0.42, green: 0.18, blue: 0.92).opacity(0.7)
            : Color(red: 0.22, green: 0.16, blue: 0.32)
        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)),
                   with: .color(ringColor), lineWidth: 1)

        if glow > 0.15 {
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: -glow * 10, dy: -glow * 10)),
                     with: .color(color.opacity(0.22 * glow)))
        }

        if showChannelValues, let profile = appState.show.profile(for: fixture),
           let universe = universeData[fixture.universe] {
            let startIdx = fixture.startAddress - 1
            let channelStr = profile.channels.prefix(4).map { ch in
                let idx = startIdx + ch.offset
                return "\(idx < universe.count ? universe[idx] : 0)"
            }.joined(separator: " ")
            ctx.draw(
                Text(channelStr)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75)),
                at: CGPoint(x: pos.x, y: pos.y + radius + 10)
            )
        }
    }

    private func fixtureColor(_ fixture: Fixture, universeData: [Int: [UInt8]]) -> Color {
        guard let profile = appState.show.profile(for: fixture),
              let universe = universeData[fixture.universe] else {
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
        if r == 0 && g == 0 && b == 0 && dimmer < 1 { return Color(white: dimmer) }
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
