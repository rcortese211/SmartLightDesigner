import SwiftUI

// ──────────────────────────────────────────────────────────────────────────────
// DMXColorPicker — console-style HSB color picker for effect parameters.
//
// Layout:
//   [HSB wheel] [Brightness bar]   [Preset swatches]
//   [R slider] [G slider] [B slider]
// ──────────────────────────────────────────────────────────────────────────────

struct DMXColorPicker: View {
    @Binding var rgb: (r: Double, g: Double, b: Double)
    @Environment(AppState.self) private var appState

    @State private var h: Double = 0
    @State private var s: Double = 1
    @State private var v: Double = 1
    @State private var showSaveRow = false
    @State private var saveName = ""
    @FocusState private var saveFieldFocused: Bool

    private let wheelSize: CGFloat = 164
    private let briBarWidth: CGFloat = 18

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                // HSB Wheel + brightness bar
                HStack(alignment: .top, spacing: 6) {
                    colorWheelView
                        .frame(width: wheelSize, height: wheelSize)

                    brightnessBar
                        .frame(width: briBarWidth, height: wheelSize)
                }

                // Preset swatches
                presetGrid
            }

            // RGB sliders
            rgbSliders

            // Preview swatch
            RoundedRectangle(cornerRadius: 4)
                .fill(currentColor)
                .frame(height: 18)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.25), lineWidth: 1))
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.08, blue: 0.13))
        .onAppear { syncFromRGB() }
    }

    // MARK: - Wheel

    private var colorWheelView: some View {
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius  = min(size.width, size.height) / 2 - 1
                let slices  = 180

                for i in 0..<slices {
                    let a0 = Double(i)     / Double(slices) * 2 * .pi - .pi / 2
                    let a1 = Double(i + 1) / Double(slices) * 2 * .pi - .pi / 2
                    let am = (a0 + a1) / 2
                    let hue = (am + .pi / 2) / (2 * .pi)
                    let (pr, pg, pb) = hsvToRGB(h: hue, s: 1, v: v)

                    var path = Path()
                    path.move(to: center)
                    path.addArc(center: center, radius: radius,
                                startAngle: .radians(a0), endAngle: .radians(a1),
                                clockwise: false)
                    path.closeSubpath()

                    ctx.fill(path, with: .radialGradient(
                        Gradient(colors: [
                            Color(white: v),
                            Color(red: pr, green: pg, blue: pb)
                        ]),
                        center: center, startRadius: 0, endRadius: radius
                    ))
                }

                // Rim
                let rim = CGRect(x: center.x - radius, y: center.y - radius,
                                 width: radius * 2, height: radius * 2)
                ctx.stroke(Path(ellipseIn: rim),
                           with: .color(Color(white: 0.22)), lineWidth: 1)
            }

            // Selection dot
            let wheelRadius = wheelSize / 2
            let dotX = wheelRadius + CGFloat(s) * (wheelRadius - 2) * CGFloat(cos(h * 2 * .pi - .pi / 2))
            let dotY = wheelRadius + CGFloat(s) * (wheelRadius - 2) * CGFloat(sin(h * 2 * .pi - .pi / 2))
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 10, height: 10)
                .position(x: dotX, y: dotY)
            Circle()
                .stroke(Color.black.opacity(0.6), lineWidth: 1)
                .frame(width: 12, height: 12)
                .position(x: dotX, y: dotY)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    let center = CGPoint(x: wheelSize / 2, y: wheelSize / 2)
                    let dx = Double(val.location.x - center.x)
                    let dy = Double(val.location.y - center.y)
                    let radius = Double(wheelSize / 2) - 1
                    let dist   = sqrt(dx*dx + dy*dy)
                    s = max(0, min(1, dist / radius))
                    h = ((atan2(dy, dx) + .pi / 2) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1)
                    pushToRGB()
                }
        )
    }

    // MARK: - Brightness bar

    private var brightnessBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Gradient from black (bottom) to current saturated hue (top)
                let (pr, pg, pb) = hsvToRGB(h: h, s: s, v: 1)
                LinearGradient(
                    colors: [.black, Color(red: pr, green: pg, blue: pb)],
                    startPoint: .bottom, endPoint: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Thumb
                let thumbY = geo.size.height * CGFloat(1 - v)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: briBarWidth, height: 4)
                    .shadow(radius: 2)
                    .offset(y: thumbY - geo.size.height)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .offset(y: thumbY)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        v = max(0, min(1, 1 - Double(val.location.y / geo.size.height)))
                        pushToRGB()
                    }
            )
        }
    }

    // MARK: - Swatches panel (global colors + standard presets)

    private var presetGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                globalColorsSection
                Divider().background(Color(white: 0.25)).padding(.vertical, 5)
                presetsSection
            }
        }
        .frame(width: 84)
    }

    @ViewBuilder
    private var globalColorsSection: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("GLOBAL")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.purple.opacity(0.8))
                Spacer()
                Button {
                    saveName = ""
                    showSaveRow.toggle()
                    if showSaveRow { saveFieldFocused = true }
                } label: {
                    Image(systemName: showSaveRow ? "xmark" : "plus")
                        .font(.system(size: 9))
                        .foregroundStyle(SmartLightTheme.purple)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            // Inline save row
            if showSaveRow {
                HStack(spacing: 4) {
                    TextField("Name", text: $saveName)
                        .font(.system(size: 9, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .focused($saveFieldFocused)
                        .onSubmit { commitSave() }
                    Button(action: commitSave) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(SmartLightTheme.active)
                    }
                    .buttonStyle(.plain)
                    .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.bottom, 4)
            }

            // Saved color list
            if appState.show.globalColors.isEmpty && !showSaveRow {
                Text("No saved colors")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color(white: 0.3))
                    .padding(.vertical, 4)
            } else {
                ForEach(appState.show.globalColors) { gc in
                    Button {
                        rgb = (gc.r, gc.g, gc.b)
                        syncFromRGB()
                    } label: {
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(red: gc.r, green: gc.g, blue: gc.b))
                                .frame(width: 14, height: 14)
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color(white: 0.3), lineWidth: 0.5))
                            Text(gc.name)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(white: 0.75))
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Update to Current Color") {
                            if let i = appState.show.globalColors.firstIndex(where: { $0.id == gc.id }) {
                                appState.show.globalColors[i].r = rgb.r
                                appState.show.globalColors[i].g = rgb.g
                                appState.show.globalColors[i].b = rgb.b
                            }
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            appState.show.globalColors.removeAll { $0.id == gc.id }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private var presetsSection: some View {
        let presets: [(String, Double, Double, Double)] = [
            ("Red",      1.00, 0.00, 0.00),
            ("Orange",   1.00, 0.40, 0.00),
            ("Yellow",   1.00, 0.90, 0.00),
            ("Lime",     0.30, 1.00, 0.00),
            ("Green",    0.00, 1.00, 0.00),
            ("Cyan",     0.00, 0.90, 1.00),
            ("Blue",     0.00, 0.20, 1.00),
            ("Violet",   0.40, 0.00, 1.00),
            ("Magenta",  1.00, 0.00, 0.80),
            ("Pink",     1.00, 0.30, 0.60),
            ("Warm W.",  1.00, 0.85, 0.60),
            ("White",    1.00, 1.00, 1.00),
            ("Dim",      0.30, 0.30, 0.30),
            ("Black",    0.00, 0.00, 0.00),
        ]
        return VStack(spacing: 0) {
            HStack {
                Text("PRESETS")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(presets, id: \.0) { (name, r, g, b) in
                Button {
                    rgb = (r, g, b)
                    syncFromRGB()
                } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: r, green: g, blue: b))
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(white: 0.3), lineWidth: 0.5))
                        Text(name)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(white: 0.6))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 1)
            }
        }
    }

    private func commitSave() {
        let name = saveName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let gc = GlobalColor(name: name, r: rgb.r, g: rgb.g, b: rgb.b)
        appState.show.globalColors.append(gc)
        saveName = ""
        showSaveRow = false
    }

    // MARK: - RGB Sliders

    private var rgbSliders: some View {
        VStack(spacing: 4) {
            channelSlider(label: "R", value: Binding(get: { rgb.r }, set: { rgb.r = $0; syncFromRGB() }), color: .red)
            channelSlider(label: "G", value: Binding(get: { rgb.g }, set: { rgb.g = $0; syncFromRGB() }), color: .green)
            channelSlider(label: "B", value: Binding(get: { rgb.b }, set: { rgb.b = $0; syncFromRGB() }), color: .blue)
        }
    }

    @ViewBuilder
    private func channelSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.9))
                .frame(width: 10)
            Slider(value: value, in: 0...1)
                .tint(color)
            Text(String(Int(value.wrappedValue * 255)))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(white: 0.55))
                .frame(width: 26, alignment: .trailing)
        }
    }

    // MARK: - Sync helpers

    private var currentColor: Color {
        Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private func syncFromRGB() {
        let (nh, ns, nv) = rgbToHSV(r: rgb.r, g: rgb.g, b: rgb.b)
        h = nh; s = ns; v = nv
    }

    private func pushToRGB() {
        let (r, g, b) = hsvToRGB(h: h, s: s, v: v)
        rgb = (r, g, b)
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Inline color swatch button that opens DMXColorPicker in a popover.
// Use this anywhere a color parameter appears in the layer editor.
// ──────────────────────────────────────────────────────────────────────────────

struct ColorParamButton: View {
    let name: String
    @Binding var paramValue: ParameterValue
    let fallbackRGB: (r: Double, g: Double, b: Double)

    @State private var showPicker = false

    private var rgbBinding: Binding<(r: Double, g: Double, b: Double)> {
        Binding(
            get: { paramValue.colorValue ?? fallbackRGB },
            set: { paramValue = .color(r: $0.r, g: $0.g, b: $0.b) }
        )
    }

    var body: some View {
        let (r, g, b) = paramValue.colorValue ?? fallbackRGB
        Button {
            showPicker.toggle()
        } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: r, green: g, blue: b))
                .frame(width: 44, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(white: 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .trailing) {
            DMXColorPicker(rgb: rgbBinding)
                .frame(width: 340)
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// HSV ↔ RGB helpers (shared; hsvToRGB is also in Effect.swift scope)
// ──────────────────────────────────────────────────────────────────────────────

private func rgbToHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
    let maxC = max(r, g, b)
    let minC = min(r, g, b)
    let delta = maxC - minC
    let vv = maxC
    let ss = maxC > 0 ? delta / maxC : 0
    var hh = 0.0
    if delta > 0 {
        if maxC == r      { hh = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == g { hh = (b - r) / delta + 2 }
        else              { hh = (r - g) / delta + 4 }
        hh = (hh / 6 + 1).truncatingRemainder(dividingBy: 1)
    }
    return (hh, ss, vv)
}
