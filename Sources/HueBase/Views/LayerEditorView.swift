import SwiftUI

struct LayerEditorView: View {
    @Binding var layer: Layer
    @Environment(AppState.self) private var appState

    @State private var showZoneSave = false
    @State private var zoneSaveName = ""
    @State private var editingZoneID: UUID? = nil

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
                if let pts = layer.zone.points {
                    LabeledContent("Type") {
                        Text("polygon (\(pts.count) pts)")
                            .foregroundStyle(.secondary)
                    }
                } else {
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
                }

                HStack(spacing: 8) {
                    Button("Reset") { layer.zone = SpatialZone() }
                        .buttonStyle(.bordered)
                        .disabled(layer.zone.isFullCanvas)
                    Spacer()
                    if !appState.show.zoneLibrary.isEmpty {
                        Menu("Apply…") {
                            ForEach(appState.show.zoneLibrary) { named in
                                Button(named.name) { layer.zone = named.zone }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(showZoneSave ? "Cancel" : "Save…") {
                        showZoneSave.toggle()
                        if !showZoneSave { zoneSaveName = "" }
                    }
                    .buttonStyle(.bordered)
                }

                if showZoneSave {
                    HStack(spacing: 8) {
                        TextField("Zone name", text: $zoneSaveName)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            appState.show.zoneLibrary.append(
                                NamedSpatialZone(name: zoneSaveName, zone: layer.zone))
                            zoneSaveName = ""
                            showZoneSave = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(zoneSaveName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            if !appState.show.zoneLibrary.isEmpty {
                Section("Zone Library") {
                    ForEach(appState.show.zoneLibrary) { named in
                        HStack(spacing: 6) {
                            if editingZoneID == named.id {
                                TextField("Name", text: bindingForZoneName(named.id))
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { editingZoneID = nil }
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(named.name)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    Group {
                                        if let pts = named.zone.points {
                                            Text("polygon (\(pts.count) pts)")
                                        } else {
                                            Text("\(Int(named.zone.width * 100))%×\(Int(named.zone.height * 100))% @ (\(String(format: "%.2f", named.zone.x)), \(String(format: "%.2f", named.zone.y)))")
                                        }
                                    }
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                }
                                .onTapGesture(count: 2) { editingZoneID = named.id }
                            }
                            Spacer()
                            Button("Apply") { layer.zone = named.zone }
                                .buttonStyle(.bordered).controlSize(.small)
                            Button(role: .destructive) {
                                appState.show.zoneLibrary.removeAll { $0.id == named.id }
                                if editingZoneID == named.id { editingZoneID = nil }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.red.opacity(0.75))
                        }
                    }
                }
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

    private func bindingForZoneName(_ id: UUID) -> Binding<String> {
        Binding(
            get: { appState.show.zoneLibrary.first(where: { $0.id == id })?.name ?? "" },
            set: { v in
                if let i = appState.show.zoneLibrary.firstIndex(where: { $0.id == id }) {
                    appState.show.zoneLibrary[i].name = v
                }
            }
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

    @State private var dragStartZone: SpatialZone? = nil
    @State private var dragType: ZoneDragType = .none

    private enum ZoneDragType { case none, move, resizeSE }

    var body: some View {
        GeometryReader { geo in
            let sz = geo.size
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(white: 0.08)))
                drawGrid(ctx: ctx, size: size)

                if let pts = zone.points, pts.count >= 3 {
                    var path = Path()
                    path.move(to: CGPoint(x: CGFloat(pts[0].x) * size.width,
                                         y: CGFloat(pts[0].y) * size.height))
                    for pt in pts.dropFirst() {
                        path.addLine(to: CGPoint(x: CGFloat(pt.x) * size.width,
                                                 y: CGFloat(pt.y) * size.height))
                    }
                    path.closeSubpath()
                    ctx.fill(path, with: .color(SmartLightTheme.active.opacity(0.15)))
                    ctx.stroke(path, with: .color(SmartLightTheme.active.opacity(0.8)), lineWidth: 1.5)
                } else {
                    let rect = zoneRect(in: size)
                    ctx.fill(Path(rect), with: .color(SmartLightTheme.active.opacity(0.15)))
                    ctx.stroke(Path(rect), with: .color(SmartLightTheme.active.opacity(0.8)), lineWidth: 1.5)
                    let handleR: CGFloat = 5
                    ctx.fill(Path(ellipseIn: CGRect(x: rect.maxX - handleR * 2,
                                                    y: rect.maxY - handleR * 2,
                                                    width: handleR * 2, height: handleR * 2)),
                             with: .color(SmartLightTheme.active))
                }

                for f in fixtures {
                    let fx = CGFloat(f.positionX) * size.width
                    let fy = CGFloat(f.positionY) * size.height
                    let inZone = zone.contains(nx: f.positionX, ny: f.positionY)
                    ctx.fill(Path(ellipseIn: CGRect(x: fx - 2.5, y: fy - 2.5, width: 5, height: 5)),
                             with: .color(inZone ? .white : Color(white: 0.3)))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        guard zone.points == nil else { return }
                        if dragStartZone == nil {
                            dragStartZone = zone
                            dragType = detectDragType(at: value.startLocation, size: sz)
                        }
                        guard let startZone = dragStartZone else { return }
                        let dx = Double(value.translation.width / sz.width)
                        let dy = Double(value.translation.height / sz.height)
                        switch dragType {
                        case .move:
                            zone.x = min(clamp01(startZone.x + dx), 1 - zone.width)
                            zone.y = min(clamp01(startZone.y + dy), 1 - zone.height)
                        case .resizeSE:
                            zone.width  = min(max(0.05, startZone.width + dx),  1 - zone.x)
                            zone.height = min(max(0.05, startZone.height + dy), 1 - zone.y)
                        case .none: break
                        }
                    }
                    .onEnded { _ in dragStartZone = nil; dragType = .none }
            )
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(SmartLightTheme.border, lineWidth: 1))
    }

    private func zoneRect(in size: CGSize) -> CGRect {
        CGRect(x: CGFloat(zone.x) * size.width,
               y: CGFloat(zone.y) * size.height,
               width: CGFloat(zone.width) * size.width,
               height: CGFloat(zone.height) * size.height)
    }

    private func detectDragType(at point: CGPoint, size: CGSize) -> ZoneDragType {
        let rect = zoneRect(in: size)
        let handleArea = CGRect(x: rect.maxX - 16, y: rect.maxY - 16, width: 16, height: 16)
        if handleArea.contains(point) { return .resizeSE }
        if rect.contains(point) { return .move }
        return .none
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let cols = 8; let rows = 6
        var path = Path()
        for i in 1..<cols {
            let x = CGFloat(i) / CGFloat(cols) * size.width
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for i in 1..<rows {
            let y = CGFloat(i) / CGFloat(rows) * size.height
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
        }
        ctx.stroke(path, with: .color(Color(white: 0.18)), lineWidth: 0.5)
    }

    private func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }
}
