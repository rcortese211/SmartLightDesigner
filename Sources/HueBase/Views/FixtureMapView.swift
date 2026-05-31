import SwiftUI

struct FixtureMapView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedFixtureID: UUID?
    @State private var snapEnabled = false
    @State private var snapDivisions: Double = 8

    var body: some View {
        HSplitView {
            mapCanvas
            if let id = selectedFixtureID,
               let idx = appState.show.fixtures.firstIndex(where: { $0.id == id }) {
                inspectorPanel(idx: idx)
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
                Button(action: { arrangeFixtures(mode: .grid) }) {
                    Label("Grid", systemImage: "grid")
                }
                .help("Arrange all fixtures in a grid")
            }
        }
    }

    // MARK: - Map canvas

    private var mapCanvas: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    drawBackground(ctx: &ctx, size: size)
                }
                .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selectedFixtureID = nil }

                ForEach(appState.show.fixtures) { fixture in
                    FixtureMapNode(
                        fixture: fixture,
                        isSelected: fixture.id == selectedFixtureID,
                        onTap: { selectedFixtureID = fixture.id },
                        onDragEnd: { delta in
                            moveFixture(id: fixture.id, by: delta, in: geo.size)
                        }
                    )
                    .position(
                        x: fixture.positionX * geo.size.width,
                        y: fixture.positionY * geo.size.height
                    )
                }
            }
        }
        .background(Color(red: 0.03, green: 0.02, blue: 0.07))
        .clipped()
    }

    // MARK: - Inspector

    @ViewBuilder
    private func inspectorPanel(idx: Int) -> some View {
        let fixture = appState.show.fixtures[idx]
        VStack(spacing: 0) {
            PanelHeader(title: "FIXTURE")
            Form {
                Section("Identity") {
                    TextField("Name", text: Binding(
                        get: { appState.show.fixtures[idx].name },
                        set: { appState.show.fixtures[idx].name = $0 }
                    ))
                }
                Section("Position") {
                    sliderRow(
                        label: "X (left→right)",
                        value: Binding(
                            get: { appState.show.fixtures[idx].positionX },
                            set: { appState.show.fixtures[idx].positionX = $0 }
                        )
                    )
                    sliderRow(
                        label: "Y (top→bottom)",
                        value: Binding(
                            get: { appState.show.fixtures[idx].positionY },
                            set: { appState.show.fixtures[idx].positionY = $0 }
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
        .background(HueBaseTheme.surface)
    }

    private func sliderRow(label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Slider(value: value, in: 0...1)
                    .tint(HueBaseTheme.purple)
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

    private func arrangeFixtures(mode: ArrangeMode) {
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
            for i in 0..<count {
                let col = i % cols
                let row = i / cols
                appState.show.fixtures[i].positionX = cols > 1 ? Double(col) / Double(cols - 1) : 0.5
                appState.show.fixtures[i].positionY = rows > 1 ? Double(row) / Double(rows - 1) : 0.5
            }
        }
    }

    // MARK: - Background drawing

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize) {
        // Base fine grid
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

        // Snap grid overlay
        if snapEnabled {
            let d = CGFloat(snapDivisions)
            var snapPath = Path()
            for i in 0...Int(d) {
                let sx = CGFloat(i) * size.width  / d
                let sy = CGFloat(i) * size.height / d
                snapPath.move(to: CGPoint(x: sx, y: 0));          snapPath.addLine(to: CGPoint(x: sx, y: size.height))
                snapPath.move(to: CGPoint(x: 0,  y: sy));         snapPath.addLine(to: CGPoint(x: size.width, y: sy))
            }
            ctx.stroke(snapPath, with: .color(Color(red: 0.42, green: 0.18, blue: 0.92).opacity(0.18)), lineWidth: 1)
        }

        // Center crosshair
        let cx = size.width / 2, cy = size.height / 2
        var cross = Path()
        cross.move(to: CGPoint(x: cx - 12, y: cy)); cross.addLine(to: CGPoint(x: cx + 12, y: cy))
        cross.move(to: CGPoint(x: cx, y: cy - 12)); cross.addLine(to: CGPoint(x: cx, y: cy + 12))
        ctx.stroke(cross, with: .color(Color(red: 0.42, green: 0.18, blue: 0.92).opacity(0.28)), lineWidth: 1)

        // Stage border
        let margin: CGFloat = 24
        let stageRect = CGRect(x: margin, y: margin,
                               width: size.width - margin * 2,
                               height: size.height - margin * 2)
        ctx.stroke(Path(stageRect), with: .color(Color(red: 0.22, green: 0.16, blue: 0.36)), lineWidth: 1)
        ctx.draw(Text("STAGE")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 0.28, green: 0.20, blue: 0.45)),
                 at: CGPoint(x: size.width / 2, y: margin - 8))
        ctx.draw(Text("AUDIENCE")
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(red: 0.22, green: 0.16, blue: 0.36)),
                 at: CGPoint(x: size.width / 2, y: size.height - margin + 10))
    }
}

// MARK: - Fixture node

struct FixtureMapNode: View {
    let fixture: Fixture
    let isSelected: Bool
    let onTap: () -> Void
    let onDragEnd: (CGSize) -> Void

    @GestureState private var dragOffset: CGSize = .zero

    private let r: CGFloat = 13

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected
                    ? HueBaseTheme.active.opacity(0.85)
                    : HueBaseTheme.purple.opacity(0.55))
                .frame(width: r * 2, height: r * 2)
            Circle()
                .strokeBorder(isSelected ? HueBaseTheme.active : HueBaseTheme.purple,
                              lineWidth: isSelected ? 2 : 1)
                .frame(width: r * 2, height: r * 2)
            Text(String(fixture.name.prefix(4)).uppercased())
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1)
        }
        .overlay(alignment: .bottom) {
            Text(fixture.name)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(isSelected
                    ? HueBaseTheme.active.opacity(0.9)
                    : HueBaseTheme.purple.opacity(0.65))
                .lineLimit(1)
                .fixedSize()
                .offset(y: r + 7)
        }
        .offset(dragOffset)
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($dragOffset) { val, state, _ in state = val.translation }
                .onEnded { val in onDragEnd(val.translation) }
        )
        .onTapGesture { onTap() }
        .animation(.none, value: dragOffset)
    }
}
