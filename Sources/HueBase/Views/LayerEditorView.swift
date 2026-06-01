import SwiftUI

struct LayerEditorView: View {
    @Binding var layer: Layer
    @Environment(AppState.self) private var appState

    private var effectDefs: [EffectParameterDefinition] {
        EffectRegistry.shared.effect(for: layer.effectId)?.parameterDefinitions ?? []
    }

    var body: some View {
        Form {
            Section("Layer") {
                TextField("Name", text: $layer.name)
                Picker("Effect", selection: $layer.effectId) {
                    ForEach(EffectRegistry.shared.allEffects, id: \.id) { e in
                        Text(e.name).tag(e.id)
                    }
                }
                .onChange(of: layer.effectId) { _, newId in
                    layer.parameters = EffectRegistry.shared.defaultParameters(for: newId)
                }
            }

            Section("Compositing") {
                LabeledContent("Opacity") {
                    HStack {
                        Slider(value: $layer.opacity, in: 0...1)
                        Text("\(Int(layer.opacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 38)
                    }
                }
                Picker("Blend Mode", selection: $layer.blendMode) {
                    ForEach(DMXBlendMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                LabeledContent("Speed") {
                    HStack {
                        Slider(value: $layer.speed, in: 0.05...8.0)
                        Text(String(format: "%.2f×", layer.speed))
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }
                Toggle("Enabled", isOn: $layer.isEnabled)
            }

            Section("Parameters") {
                ForEach(effectDefs, id: \.key) { def in
                    parameterRow(for: def)
                }
            }

            Section("Fixture Scope") {
                if layer.fixtureIds.isEmpty {
                    Text("All fixtures").foregroundStyle(.secondary)
                } else {
                    Text("\(layer.fixtureIds.count) fixture(s) selected")
                        .foregroundStyle(.secondary)
                }
                Button("Assign Fixtures…") { assignFixtures() }
                    .buttonStyle(.bordered)
            }

            Section("Spatial Zone") {
                SpatialZoneEditor(zone: $layer.zone, fixtures: appState.show.fixtures)
                LabeledContent("X") {
                    HStack {
                        Slider(value: $layer.zone.x, in: 0...0.99)
                        Text(String(format: "%.2f", layer.zone.x))
                            .monospacedDigit().frame(width: 40)
                    }
                }
                LabeledContent("Y") {
                    HStack {
                        Slider(value: $layer.zone.y, in: 0...0.99)
                        Text(String(format: "%.2f", layer.zone.y))
                            .monospacedDigit().frame(width: 40)
                    }
                }
                LabeledContent("Width") {
                    HStack {
                        Slider(value: $layer.zone.width, in: 0.01...1)
                        Text(String(format: "%.2f", layer.zone.width))
                            .monospacedDigit().frame(width: 40)
                    }
                }
                LabeledContent("Height") {
                    HStack {
                        Slider(value: $layer.zone.height, in: 0.01...1)
                        Text(String(format: "%.2f", layer.zone.height))
                            .monospacedDigit().frame(width: 40)
                    }
                }
                Button("Reset to Full Canvas") {
                    layer.zone = SpatialZone()
                }
                .buttonStyle(.bordered)
                .disabled(layer.zone.isFullCanvas)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func parameterRow(for def: EffectParameterDefinition) -> some View {
        let binding = paramBinding(for: def)
        switch def.type {
        case .double(let min, let max):
            LabeledContent(def.name) {
                HStack {
                    Slider(value: doubleBinding(binding, fallback: def.defaultValue.doubleValue ?? 0), in: min...max)
                    Text(String(format: "%.2f", binding.wrappedValue.doubleValue ?? 0))
                        .monospacedDigit()
                        .frame(width: 48)
                }
            }
        case .color:
            LabeledContent(def.name) {
                ColorParamButton(
                    name: def.name,
                    paramValue: binding,
                    fallbackRGB: def.defaultValue.colorValue ?? (1, 1, 1)
                )
            }
        case .bool:
            Toggle(def.name, isOn: boolBinding(binding, fallback: def.defaultValue.boolValue ?? false))
        case .string:
            LabeledContent(def.name) {
                TextField("", text: stringBinding(binding))
                    .textFieldStyle(.roundedBorder)
            }
        case .select(let options):
            Picker(def.name, selection: stringBinding(binding)) {
                ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
            }
        case .colorList:
            ColorListParamRow(name: def.name, paramValue: binding,
                              fallback: def.defaultValue.colorListValue ?? [])
        }
    }

    private func paramBinding(for def: EffectParameterDefinition) -> Binding<ParameterValue> {
        Binding(
            get: { layer.parameters[def.key] ?? def.defaultValue },
            set: { layer.parameters[def.key] = $0 }
        )
    }

    private func doubleBinding(_ b: Binding<ParameterValue>, fallback: Double) -> Binding<Double> {
        Binding(
            get: { b.wrappedValue.doubleValue ?? fallback },
            set: { b.wrappedValue = .double($0) }
        )
    }

    private func boolBinding(_ b: Binding<ParameterValue>, fallback: Bool) -> Binding<Bool> {
        Binding(
            get: { b.wrappedValue.boolValue ?? fallback },
            set: { b.wrappedValue = .bool($0) }
        )
    }

    private func stringBinding(_ b: Binding<ParameterValue>) -> Binding<String> {
        Binding(
            get: { b.wrappedValue.stringValue ?? "" },
            set: { b.wrappedValue = .string($0) }
        )
    }

    private func assignFixtures() {
        // Opens fixture selection — simple: toggle current show fixtures into layer.fixtureIds
        // A real implementation would show a picker sheet; wiring left for the full UI pass.
        layer.fixtureIds = []   // reset to "all" for now
    }
}

// MARK: - Spatial Zone Canvas Editor

struct SpatialZoneEditor: View {
    @Binding var zone: SpatialZone
    let fixtures: [Fixture]

    @State private var dragStart: CGPoint? = nil
    @State private var dragStartZone: SpatialZone? = nil
    @State private var dragType: ZoneDragType = .none

    private enum ZoneDragType { case none, move, resizeSE }

    var body: some View {
        Canvas { ctx, size in
            let rect = zoneRect(in: size)

            // Background grid
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(white: 0.08)))
            drawGrid(ctx: ctx, size: size)

            // Zone fill
            ctx.fill(Path(rect),
                     with: .color(HueBaseTheme.active.opacity(0.15)))

            // Zone border
            var strokePath = Path(rect)
            ctx.stroke(strokePath, with: .color(HueBaseTheme.active.opacity(0.8)), lineWidth: 1.5)

            // Resize handle (SE corner)
            let handleR: CGFloat = 5
            let hx = rect.maxX - handleR
            let hy = rect.maxY - handleR
            ctx.fill(Path(ellipseIn: CGRect(x: hx - handleR, y: hy - handleR,
                                            width: handleR * 2, height: handleR * 2)),
                     with: .color(HueBaseTheme.active))

            // Fixture dots
            for f in fixtures {
                let fx = CGFloat(f.positionX) * size.width
                let fy = CGFloat(f.positionY) * size.height
                let inZone = f.positionX >= zone.x && f.positionX < zone.x + zone.width &&
                             f.positionY >= zone.y && f.positionY < zone.y + zone.height
                let dotColor: Color = inZone ? .white : Color(white: 0.3)
                ctx.fill(Path(ellipseIn: CGRect(x: fx - 2.5, y: fy - 2.5, width: 5, height: 5)),
                         with: .color(dotColor))
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HueBaseTheme.border, lineWidth: 1))
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                        dragStartZone = zone
                        dragType = detectDragType(at: value.startLocation, size: CGSize(width: 200, height: 140))
                    }
                    guard let startZone = dragStartZone else { return }
                    let dx = Double(value.translation.width / 200)
                    let dy = Double(value.translation.height / 140)
                    switch dragType {
                    case .move:
                        zone.x = clamp01(startZone.x + dx)
                        zone.y = clamp01(startZone.y + dy)
                        zone.x = min(zone.x, 1 - zone.width)
                        zone.y = min(zone.y, 1 - zone.height)
                    case .resizeSE:
                        let newW = max(0.05, startZone.width + dx)
                        let newH = max(0.05, startZone.height + dy)
                        zone.width  = min(newW, 1 - zone.x)
                        zone.height = min(newH, 1 - zone.y)
                    case .none: break
                    }
                }
                .onEnded { _ in
                    dragStart = nil
                    dragStartZone = nil
                    dragType = .none
                }
        )
    }

    private func zoneRect(in size: CGSize) -> CGRect {
        CGRect(x: CGFloat(zone.x) * size.width,
               y: CGFloat(zone.y) * size.height,
               width: CGFloat(zone.width) * size.width,
               height: CGFloat(zone.height) * size.height)
    }

    private func detectDragType(at point: CGPoint, size: CGSize) -> ZoneDragType {
        let rect = zoneRect(in: size)
        let handleArea = CGRect(x: rect.maxX - 14, y: rect.maxY - 14, width: 14, height: 14)
        if handleArea.contains(point) { return .resizeSE }
        if rect.contains(point) { return .move }
        return .none
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let cols = 8; let rows = 6
        var path = Path()
        for i in 1..<cols {
            let x = CGFloat(i) / CGFloat(cols) * size.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for i in 1..<rows {
            let y = CGFloat(i) / CGFloat(rows) * size.height
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(path, with: .color(Color(white: 0.18)), lineWidth: 0.5)
    }

    private func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }
}
