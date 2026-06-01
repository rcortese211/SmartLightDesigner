import SwiftUI

// MARK: - Splash View

struct SplashView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            SplashBackground()

            HStack(spacing: 0) {
                Spacer()
                actionCard
                    .padding(.trailing, 72)
                    .padding(.vertical, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HueBaseTheme.background)
    }

    // MARK: - Action card

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Logo
            VStack(alignment: .leading, spacing: 6) {
                Text("SMARTLIGHT")
                    .font(.system(size: 30, weight: .black, design: .monospaced))
                    .foregroundStyle(HueBaseTheme.accentGradient)
                    .kerning(3)
                Text("DESIGNER")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(HueBaseTheme.active)
                    .kerning(7)
                Rectangle()
                    .fill(HueBaseTheme.accentGradient)
                    .frame(height: 1.5)
                    .padding(.top, 6)
            }
            .padding(.bottom, 28)

            // Primary actions
            VStack(spacing: 10) {
                Button {
                    appState.newShow()
                    isPresented = false
                } label: {
                    Label("New Show", systemImage: "plus.square.fill")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .kerning(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(SplashPrimaryButtonStyle())

                Button {
                    if appState.openShow() { isPresented = false }
                } label: {
                    Label("Open Show…", systemImage: "folder")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .kerning(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(SplashSecondaryButtonStyle())
            }

            // Recent files
            let recent = appState.recentFiles
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RECENT FILES")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(HueBaseTheme.borderBright)
                        .kerning(2)
                        .padding(.top, 24)
                        .padding(.bottom, 2)

                    VStack(spacing: 3) {
                        ForEach(recent.prefix(6), id: \.self) { url in
                            Button {
                                appState.openShow(url: url)
                                isPresented = false
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(HueBaseTheme.purple.opacity(0.8))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                        Text(url.deletingLastPathComponent().abbreviatingWithTildeInPath)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.45))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                            }
                            .buttonStyle(.plain)
                            .background(HueBaseTheme.surface.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(HueBaseTheme.border.opacity(0.6), lineWidth: 1))
                        }
                    }
                }
            }

            // Continue link (when autosave has content)
            if appState.hasContinuableShow {
                HStack {
                    Spacer()
                    Button("Continue last show") { isPresented = false }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(HueBaseTheme.borderBright)
                }
                .padding(.top, 20)
            }
        }
        .frame(width: 310)
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(HueBaseTheme.background.opacity(0.88))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(HueBaseTheme.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Animated geometric background

struct SplashBackground: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                SplashGeometry.draw(ctx: ctx, size: size, time: t)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

// MARK: - Geometry renderer

enum SplashGeometry {
    // Stage-left focal point for all emanating elements
    private static func focal(size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.36, y: size.height * 0.50)
    }

    static func draw(ctx: GraphicsContext, size: CGSize, time: Double) {
        let c = focal(size: size)

        // 1 ── Deep background fill
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(Color(red: 0.04, green: 0.03, blue: 0.10)))

        // 2 ── Radial purple glow at focal point
        ctx.drawLayer { g in
            let r: CGFloat = min(size.width, size.height) * 0.65
            g.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .radialGradient(
                       Gradient(stops: [
                           .init(color: Color(red: 0.28, green: 0.10, blue: 0.62).opacity(0.72), location: 0),
                           .init(color: Color(red: 0.12, green: 0.05, blue: 0.30).opacity(0.30), location: 0.5),
                           .init(color: .clear, location: 1),
                       ]),
                       center: c, startRadius: 0, endRadius: r))
        }

        // 3 ── Dot grid (batched into one path for performance)
        let spacing: CGFloat = 38
        var gridPath = Path()
        for row in stride(from: 0.0, through: Double(size.height), by: Double(spacing)) {
            for col in stride(from: 0.0, through: Double(size.width) * 0.80, by: Double(spacing)) {
                let dist = hypot(col - Double(c.x), row - Double(c.y))
                let alpha = max(0.0, 1.0 - dist / 460.0)
                // only worth adding if visible
                if alpha > 0.02 {
                    gridPath.addEllipse(in: CGRect(x: col - 1.5, y: row - 1.5, width: 3, height: 3))
                }
            }
        }
        ctx.fill(gridPath, with: .color(Color(red: 0.38, green: 0.22, blue: 0.70).opacity(0.20)))

        // 4 ── Radiating beam lines from focal point
        let beamCount = 18
        for i in 0..<beamCount {
            let angle = Double(i) / Double(beamCount) * .pi * 2
            let isMajor = i % 3 == 0
            let len: CGFloat = isMajor ? min(size.width, size.height) * 1.1 : min(size.width, size.height) * 0.75
            let ex = c.x + cos(angle) * len
            let ey = c.y + sin(angle) * len
            var path = Path()
            path.move(to: c)
            path.addLine(to: CGPoint(x: ex, y: ey))
            let alpha: CGFloat = isMajor ? 0.22 : 0.10
            ctx.stroke(path,
                       with: .linearGradient(
                           Gradient(colors: [
                               Color(red: 0.42, green: 0.18, blue: 0.92).opacity(alpha),
                               Color.clear,
                           ]),
                           startPoint: c,
                           endPoint: CGPoint(x: ex, y: ey)),
                       lineWidth: isMajor ? 1.2 : 0.7)
        }

        // 5 ── Concentric hexagonal rings (slow counter-clockwise)
        let hexRadii: [CGFloat] = [70, 135, 200, 265, 330]
        for (ri, radius) in hexRadii.enumerated() {
            let rot = time * -0.018 + Double(ri) * 0.26
            let alpha = max(0.06, 0.38 - Double(ri) * 0.06)
            ctx.stroke(polygon(center: c, sides: 6, radius: radius, rotation: rot),
                       with: .color(Color(red: 0.42, green: 0.18, blue: 0.92).opacity(alpha)),
                       lineWidth: 1.0)
        }

        // 6 ── Concentric octagonal rings (slow clockwise, offset color)
        let octRadii: [CGFloat] = [100, 175, 250, 325]
        for (ri, radius) in octRadii.enumerated() {
            let rot = time * 0.012 + Double(ri) * 0.40
            let alpha = max(0.04, 0.28 - Double(ri) * 0.05)
            ctx.stroke(polygon(center: c, sides: 8, radius: radius, rotation: rot),
                       with: .color(Color(red: 0.17, green: 0.38, blue: 0.95).opacity(alpha)),
                       lineWidth: 0.8)
        }

        // 7 ── Outer 12-gon ring (very slow, amber)
        let outerRot = time * 0.007
        ctx.stroke(polygon(center: c, sides: 12, radius: 390, rotation: outerRot),
                   with: .color(Color(red: 0.95, green: 0.73, blue: 0.00).opacity(0.12)),
                   lineWidth: 1.2)

        // 8 ── Amber arc segments (pulsing)
        let arcCount = 3
        for i in 0..<arcCount {
            let baseRadius: CGFloat = 110 + CGFloat(i) * 72
            let startA = time * (i % 2 == 0 ? 0.14 : -0.10) + Double(i) * 2.09
            let sweep  = 0.55 + sin(time * 0.4 + Double(i)) * 0.15
            var arc = Path()
            arc.addArc(center: c,
                       radius: baseRadius,
                       startAngle: .radians(startA),
                       endAngle:   .radians(startA + sweep),
                       clockwise: false)
            let pulse = 0.55 + 0.25 * sin(time * 1.2 + Double(i) * 1.4)
            ctx.stroke(arc,
                       with: .color(Color(red: 0.95, green: 0.73, blue: 0.00).opacity(pulse * 0.70)),
                       style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
        }

        // 9 ── Inner connector spokes between hex vertices at small radius
        let spokeRadius: CGFloat = 70
        let spokeRot = time * 0.030
        let crossSpoke = polygon(center: c, sides: 3, radius: spokeRadius, rotation: spokeRot)
        ctx.stroke(crossSpoke,
                   with: .color(Color(red: 0.95, green: 0.73, blue: 0.00).opacity(0.35)),
                   lineWidth: 1.2)

        // 10 ── Bright center node
        ctx.drawLayer { g in
            g.fill(Path(ellipseIn: CGRect(x: c.x - 10, y: c.y - 10, width: 20, height: 20)),
                   with: .radialGradient(
                       Gradient(colors: [Color.white, Color(red: 0.95, green: 0.73, blue: 0.00)]),
                       center: c, startRadius: 0, endRadius: 10))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)),
                 with: .color(.white))

        // 11 ── Right-side fade so the action card is legible
        let fadeStartX = size.width * 0.48
        ctx.fill(
            Path(CGRect(x: fadeStartX, y: 0, width: size.width - fadeStartX, height: size.height)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color(red: 0.04, green: 0.03, blue: 0.10).opacity(0.92), location: 1),
                ]),
                startPoint: CGPoint(x: fadeStartX, y: 0),
                endPoint:   CGPoint(x: size.width, y: 0)))
    }

    // Builds a closed polygon Path
    private static func polygon(center: CGPoint, sides: Int, radius: CGFloat, rotation: Double) -> Path {
        var path = Path()
        for v in 0...sides {
            let a = Double(v) / Double(sides) * .pi * 2 + rotation
            let pt = CGPoint(x: center.x + cos(a) * radius,
                             y: center.y + sin(a) * radius)
            v == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        return path
    }
}

// MARK: - Button styles

struct SplashPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.18, blue: 0.92),
                        Color(red: 0.17, green: 0.38, blue: 0.95),
                    ],
                    startPoint: .leading, endPoint: .trailing)
                .opacity(configuration.isPressed ? 0.65 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SplashSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary)
            .background(
                HueBaseTheme.surfaceHigh
                    .opacity(configuration.isPressed ? 0.5 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(HueBaseTheme.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - URL helper

private extension URL {
    var abbreviatingWithTildeInPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
