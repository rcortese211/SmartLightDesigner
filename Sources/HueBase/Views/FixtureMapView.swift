import SwiftUI
import AppKit

struct FixtureMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.undoManager) private var undoManager
    @State private var selectedFixtureIDs: Set<UUID> = []
    @State private var snapEnabled = false
    @State private var snapDivisions: Double = 8
    @State private var highlightEnabled = false
    @State private var highlightColor: Color = Color(red: 1.0, green: 0.88, blue: 0.0)
    @State private var lowlightColor: Color = Color(white: 0.14)
    @State private var showHighlightPicker = false
    @State private var customGridSpacing: Double = 0.55
    @State private var showCustomGrid = false
    // Marquee drag state
    @State private var marqueeStart: CGPoint? = nil
    @State private var marqueeEnd: CGPoint? = nil
    // Live group-drag state
    @State private var activeDragFixtureID: UUID? = nil
    @State private var liveGroupDragOffset: CGSize = .zero

    var body: some View {
        HSplitView {
            mapCanvas
            if selectedFixtureIDs.count == 1,
               let id = selectedFixtureIDs.first,
               appState.show.fixtures.contains(where: { $0.id == id }) {
                inspectorPanel(id: id)
                    .frame(minWidth: 220, maxWidth: 260)
            }
        }
        .navigationTitle("Fixture Map")
        .toolbar {
            ToolbarItemGroup {
                Toggle("Snap", isOn: $snapEnabled)
                    .help("Snap to grid")
                if snapEnabled {
                    Picker("Grid", selection: $snapDivisions) {
                        Text("4").tag(4.0)
                        Text("8").tag(8.0)
                        Text("16").tag(16.0)
                    }
                    .frame(width: 60)
                }
                Divider()
                Button(action: { arrangeFixtures(mode: .row) }) {
                    Label("Row", systemImage: "line.horizontal.3")
                }
                .help("Arrange all fixtures in a horizontal row")
                Button(action: { arrangeFixtures(mode: .column) }) {
                    Label("Column", systemImage: "line.3.horizontal")
                }
                .help("Arrange all fixtures in a vertical column")
                Menu {
                    Button("Spread (Full)") { customGridSpacing = 1.0;  arrangeFixtures(mode: .grid, spacing: 1.0) }
                    Button("Wide")          { customGridSpacing = 0.75; arrangeFixtures(mode: .grid, spacing: 0.75) }
                    Button("Normal")        { customGridSpacing = 0.55; arrangeFixtures(mode: .grid, spacing: 0.55) }
                    Button("Compact")       { customGridSpacing = 0.35; arrangeFixtures(mode: .grid, spacing: 0.35) }
                    Divider()
                    Button("Custom…") { showCustomGrid = true }
                } label: {
                    Label("Grid", systemImage: "grid")
                }
                .help("Arrange all fixtures in a grid")
                .popover(isPresented: $showCustomGrid, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GRID SPACING")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .kerning(1)
                        HStack(spacing: 8) {
                            Slider(value: $customGridSpacing, in: 0.1...1.0)
                                .onChange(of: customGridSpacing) { _, v in
                                    arrangeFixtures(mode: .grid, spacing: v)
                                }
                            Text("\(Int(customGridSpacing * 100))%")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 34, alignment: .trailing)
                        }
                        Text("Drag to rearrange live")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .frame(width: 240)
                }
                Divider()
                Button(action: { highlightEnabled.toggle() }) {
                    Label("Highlight", systemImage: highlightEnabled ? "lightbulb.fill" : "lightbulb")
                        .foregroundStyle(highlightEnabled ? highlightColor : Color.primary)
                }
                .help(highlightEnabled ? "Highlight on — click to disable" : "Highlight selected fixture")
                if highlightEnabled {
                    Button(action: { showHighlightPicker.toggle() }) {
                        Image(systemName: "paintpalette")
                    }
                    .help("Customize highlight and lowlight colors")
                    .popover(isPresented: $showHighlightPicker, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HIGHLIGHT COLORS")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .kerning(1)
                            ColorPicker("Highlight (selected)", selection: $highlightColor,
                                        supportsOpacity: false)
                            ColorPicker("Lowlight (others)",    selection: $lowlightColor,
                                        supportsOpacity: false)
                        }
                        .padding(16)
                        .frame(width: 240)
                    }
                }
            }
        }
        .onChange(of: highlightEnabled)    { _, _ in syncHighlight() }
        .onChange(of: selectedFixtureIDs)  { _, _ in syncHighlight() }
        .onChange(of: highlightColor)      { _, _ in syncHighlight() }
        .onChange(of: lowlightColor)       { _, _ in syncHighlight() }
        .onDisappear { appState.engine.highlightOverride = nil }
    }

    // MARK: - Map canvas

    private var mapCanvas: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    drawBackground(ctx: &ctx, size: size)
                }
                .allowsHitTesting(false)

                // Background — handles tap-to-deselect and marquee drag
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { val in
                                marqueeStart = val.startLocation
                                marqueeEnd   = val.location
                            }
                            .onEnded { val in
                                let start = val.startLocation
                                let end   = val.location
                                let rect  = CGRect(
                                    x: min(start.x, end.x), y: min(start.y, end.y),
                                    width: abs(end.x - start.x), height: abs(end.y - start.y)
                                )
                                if rect.width < 4 && rect.height < 4 {
                                    selectedFixtureIDs = []
                                } else {
                                    let hit = Set(appState.show.fixtures.filter { f in
                                        rect.contains(CGPoint(x: f.positionX * geo.size.width,
                                                              y: f.positionY * geo.size.height))
                                    }.map { $0.id })
                                    if NSEvent.modifierFlags.contains(.shift) {
                                        selectedFixtureIDs.formUnion(hit)
                                    } else {
                                        selectedFixtureIDs = hit
                                    }
                                }
                                marqueeStart = nil
                                marqueeEnd   = nil
                            }
                    )

                ForEach(appState.show.fixtures) { fixture in
                    let isSel = selectedFixtureIDs.contains(fixture.id)
                    FixtureMapNode(
                        fixture: fixture,
                        isSelected: isSel,
                        highlightEnabled: highlightEnabled,
                        isHighlighted: highlightEnabled && isSel,
                        highlightColor: highlightColor,
                        lowlightColor: lowlightColor,
                        externalOffset: isSel && fixture.id != activeDragFixtureID
                            ? liveGroupDragOffset : .zero,
                        onTap: { shiftHeld in
                            if shiftHeld {
                                if selectedFixtureIDs.contains(fixture.id) {
                                    selectedFixtureIDs.remove(fixture.id)
                                } else {
                                    selectedFixtureIDs.insert(fixture.id)
                                }
                            } else {
                                selectedFixtureIDs = [fixture.id]
                            }
                        },
                        onDragChanged: { delta in
                            if isSel {
                                activeDragFixtureID  = fixture.id
                                liveGroupDragOffset  = delta
                            }
                        },
                        onDragEnd: { delta in
                            activeDragFixtureID = nil
                            liveGroupDragOffset = .zero
                            if isSel {
                                moveSelectedFixtures(by: delta, in: geo.size)
                            } else {
                                selectedFixtureIDs = [fixture.id]
                                moveFixture(id: fixture.id, by: delta, in: geo.size)
                            }
                        }
                    )
                    .position(
                        x: fixture.positionX * geo.size.width,
                        y: fixture.positionY * geo.size.height
                    )
                }

                // Marquee rectangle
                if let start = marqueeStart, let end = marqueeEnd {
                    let rect = CGRect(
                        x: min(start.x, end.x), y: min(start.y, end.y),
                        width: abs(end.x - start.x), height: abs(end.y - start.y)
                    )
                    Rectangle()
                        .stroke(SmartLightTheme.active.opacity(0.7), lineWidth: 1)
                        .background(SmartLightTheme.active.opacity(0.07))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color(red: 0.03, green: 0.02, blue: 0.07))
        .clipped()
        .focusable()
        .onKeyPress(.delete) {
            guard !selectedFixtureIDs.isEmpty else { return .ignored }
            deleteSelectedFixtures()
            return .handled
        }
    }

    // MARK: - Inspector

    // Takes UUID so bindings always re-resolve — avoids index-out-of-range if
    // fixtures are removed while the inspector is open on a different tab.
    @ViewBuilder
    private func inspectorPanel(id: UUID) -> some View {
        if let fixture = appState.show.fixtures.first(where: { $0.id == id }) {
            VStack(spacing: 0) {
                PanelHeader(title: "FIXTURE")
                Form {
                    Section("Identity") {
                        TextField("Name", text: Binding(
                            get: {
                                appState.show.fixtures.first(where: { $0.id == id })?.name ?? ""
                            },
                            set: { v in
                                if let i = appState.show.fixtures.firstIndex(where: { $0.id == id }) {
                                    appState.show.fixtures[i].name = v
                                }
                            }
                        ))
                    }
                    Section("Position") {
                        sliderRow(
                            label: "X (left→right)",
                            value: Binding(
                                get: {
                                    appState.show.fixtures.first(where: { $0.id == id })?.positionX ?? 0
                                },
                                set: { v in
                                    if let i = appState.show.fixtures.firstIndex(where: { $0.id == id }) {
                                        appState.show.fixtures[i].positionX = v
                                    }
                                }
                            )
                        )
                        sliderRow(
                            label: "Y (top→bottom)",
                            value: Binding(
                                get: {
                                    appState.show.fixtures.first(where: { $0.id == id })?.positionY ?? 0
                                },
                                set: { v in
                                    if let i = appState.show.fixtures.firstIndex(where: { $0.id == id }) {
                                        appState.show.fixtures[i].positionY = v
                                    }
                                }
                            )
                        )
                    }
                    Section("DMX") {
                        LabeledContent("Universe", value: "\(fixture.universe + 1)")
                        LabeledContent("Address",  value: "\(fixture.startAddress)")
                        LabeledContent("Profile",  value: appState.show.profile(for: fixture)?.name ?? "–")
                    }
                }
                .formStyle(.grouped)
            }
            .background(SmartLightTheme.surface)
        }
    }

    private func sliderRow(label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Slider(value: value, in: 0...1)
                    .tint(SmartLightTheme.purple)
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 34)
            }
        }
    }

    // MARK: - Mutations

    private func moveFixture(id: UUID, by delta: CGSize, in size: CGSize) {
        guard let idx = appState.show.fixtures.firstIndex(where: { $0.id == id }) else { return }
        applyDelta(delta, to: idx, in: size)
    }

    private func moveSelectedFixtures(by delta: CGSize, in size: CGSize) {
        for idx in appState.show.fixtures.indices {
            guard selectedFixtureIDs.contains(appState.show.fixtures[idx].id) else { continue }
            applyDelta(delta, to: idx, in: size)
        }
    }

    private func applyDelta(_ delta: CGSize, to idx: Int, in size: CGSize) {
        var newX = appState.show.fixtures[idx].positionX + delta.width  / size.width
        var newY = appState.show.fixtures[idx].positionY + delta.height / size.height
        if snapEnabled {
            let d = snapDivisions
            newX = round(newX * d) / d
            newY = round(newY * d) / d
        }
        appState.show.fixtures[idx].positionX = max(0, min(1, newX))
        appState.show.fixtures[idx].positionY = max(0, min(1, newY))
    }

    private enum ArrangeMode { case row, column, grid }

    private func arrangeFixtures(mode: ArrangeMode, spacing: Double = 1.0) {
        let count = appState.show.fixtures.count
        guard count > 0 else { return }
        switch mode {
        case .row:
            for i in 0..<count {
                appState.show.fixtures[i].positionX = count > 1 ? Double(i) / Double(count - 1) : 0.5
                appState.show.fixtures[i].positionY = 0.5
            }
        case .column:
            for i in 0..<count {
                appState.show.fixtures[i].positionX = 0.5
                appState.show.fixtures[i].positionY = count > 1 ? Double(i) / Double(count - 1) : 0.5
            }
        case .grid:
            let cols = max(1, Int(ceil(sqrt(Double(count)))))
            let rows = max(1, Int(ceil(Double(count) / Double(cols))))
            let pad  = (1.0 - spacing) / 2.0
            for i in 0..<count {
                let col = i % cols, row = i / cols
                appState.show.fixtures[i].positionX = cols > 1
                    ? pad + Double(col) / Double(cols - 1) * spacing : 0.5
                appState.show.fixtures[i].positionY = rows > 1
                    ? pad + Double(row) / Double(rows - 1) * spacing : 0.5
            }
        }
    }

    // MARK: - Delete with undo

    private func deleteSelectedFixtures() {
        // Capture ordered (index, fixture) pairs before removal
        let snapshot = appState.show.fixtures.enumerated()
            .filter { selectedFixtureIDs.contains($0.element.id) }
            .map { (index: $0.offset, fixture: $0.element) }
        guard !snapshot.isEmpty else { return }

        appState.show.fixtures.removeAll { selectedFixtureIDs.contains($0.id) }
        selectedFixtureIDs = []

        let count = snapshot.count
        undoManager?.registerUndo(withTarget: appState) { state in
            // Re-insert in reverse order so earlier indices stay valid
            for item in snapshot.reversed() {
                let idx = min(item.index, state.show.fixtures.count)
                state.show.fixtures.insert(item.fixture, at: idx)
            }
        }
        undoManager?.setActionName("Delete \(count) Fixture\(count == 1 ? "" : "s")")
    }

    // MARK: - Highlight sync

    private func syncHighlight() {
        guard highlightEnabled else {
            appState.engine.highlightOverride = nil
            return
        }
        appState.engine.highlightOverride = .init(
            selectedIDs:   selectedFixtureIDs,
            highlightRGB:  highlightColor.asRGB,
            lowlightRGB:   lowlightColor.asRGB
        )
    }

    // MARK: - Background drawing

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize) {
        let step: CGFloat = 48
        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            y += step
        }
        ctx.stroke(path, with: .color(Color(red: 0.12, green: 0.09, blue: 0.22)), lineWidth: 0.5)

        if snapEnabled {
            let d = CGFloat(snapDivisions)
            var snapPath = Path()
            for i in 0...Int(d) {
                let sx = CGFloat(i) * size.width / d, sy = CGFloat(i) * size.height / d
                snapPath.move(to: CGPoint(x: sx, y: 0));         snapPath.addLine(to: CGPoint(x: sx, y: size.height))
                snapPath.move(to: CGPoint(x: 0,  y: sy));        snapPath.addLine(to: CGPoint(x: size.width, y: sy))
            }
            ctx.stroke(snapPath, with: .color(Color(red: 0.42, green: 0.18, blue: 0.92).opacity(0.18)), lineWidth: 1)
        }

        let cx = size.width / 2, cy = size.height / 2
        var cross = Path()
        cross.move(to: CGPoint(x: cx - 12, y: cy)); cross.addLine(to: CGPoint(x: cx + 12, y: cy))
        cross.move(to: CGPoint(x: cx, y: cy - 12)); cross.addLine(to: CGPoint(x: cx, y: cy + 12))
        ctx.stroke(cross, with: .color(Color(red: 0.42, green: 0.18, blue: 0.92).opacity(0.28)), lineWidth: 1)

        let margin: CGFloat = 24
        let stageRect = CGRect(x: margin, y: margin,
                               width: size.width - margin * 2, height: size.height - margin * 2)
        ctx.stroke(Path(stageRect), with: .color(Color(red: 0.22, green: 0.16, blue: 0.36)), lineWidth: 1)
        ctx.draw(Text("STAGE").font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.45)),
                 at: CGPoint(x: size.width / 2, y: margin - 8))
        ctx.draw(Text("AUDIENCE").font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.36)),
                 at: CGPoint(x: size.width / 2, y: size.height - margin + 10))
    }
}

// MARK: - Color → RGB helper

private extension Color {
    var asRGB: (r: Double, g: Double, b: Double) {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return (ns.redComponent, ns.greenComponent, ns.blueComponent)
    }
}

// MARK: - Fixture node

struct FixtureMapNode: View {
    let fixture: Fixture
    let isSelected: Bool
    let highlightEnabled: Bool
    let isHighlighted: Bool
    let highlightColor: Color
    let lowlightColor: Color
    let externalOffset: CGSize      // applied to non-dragged selected fixtures during group drag
    let onTap: (Bool) -> Void       // Bool = shift held
    let onDragChanged: (CGSize) -> Void
    let onDragEnd: (CGSize) -> Void

    @GestureState private var dragOffset: CGSize = .zero

    private let r: CGFloat = 13

    private var fillColor: Color {
        if highlightEnabled {
            return isHighlighted ? highlightColor.opacity(0.9) : lowlightColor
        }
        return isSelected ? SmartLightTheme.active.opacity(0.85) : SmartLightTheme.purple.opacity(0.55)
    }

    private var strokeColor: Color {
        if highlightEnabled {
            return isHighlighted ? highlightColor : lowlightColor.opacity(0.55)
        }
        return isSelected ? SmartLightTheme.active : SmartLightTheme.purple
    }

    private var labelColor: Color {
        if highlightEnabled {
            return isHighlighted ? highlightColor : lowlightColor.opacity(0.7)
        }
        return isSelected ? SmartLightTheme.active.opacity(0.9) : SmartLightTheme.purple.opacity(0.65)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: r * 2, height: r * 2)
            Circle()
                .strokeBorder(strokeColor, lineWidth: (isSelected || isHighlighted) ? 2 : 1)
                .frame(width: r * 2, height: r * 2)
            Text(String(fixture.name.prefix(4)).uppercased())
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(highlightEnabled && !isHighlighted ? 0.3 : 0.9))
                .lineLimit(1)
        }
        .overlay(alignment: .bottom) {
            Text(fixture.name)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .fixedSize()
                .offset(y: r + 7)
        }
        .offset(
            x: dragOffset.width  + externalOffset.width,
            y: dragOffset.height + externalOffset.height
        )
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragOffset) { val, state, _ in state = val.translation }
                .onChanged { val in onDragChanged(val.translation) }
                .onEnded   { val in onDragChanged(.zero); onDragEnd(val.translation) }
        )
        .onTapGesture {
            onTap(NSEvent.modifierFlags.contains(.shift))
        }
        .animation(.easeInOut(duration: 0.15), value: highlightEnabled)
        .animation(.none, value: dragOffset)
        .animation(.none, value: externalOffset)
    }
}
