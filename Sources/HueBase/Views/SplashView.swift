import SwiftUI

// MARK: - Splash View

struct SplashView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    private static let panelW: CGFloat = 700
    private static let panelH: CGFloat = 440

    var body: some View {
        ZStack {
            SplashBackground()

            HStack(spacing: 0) {
                Spacer()
                actionCard
                    .padding(.trailing, 28)
                    .padding(.vertical, 28)
            }
        }
        .frame(width: Self.panelW, height: Self.panelH)
    }

    // MARK: - Action card

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Logo
            VStack(alignment: .leading, spacing: 5) {
                Text("SMARTLIGHT")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.accentGradient)
                    .kerning(3)
                Text("DESIGNER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.active)
                    .kerning(6)
                Rectangle()
                    .fill(SmartLightTheme.accentGradient)
                    .frame(height: 1.5)
                    .padding(.top, 5)
                Text(AppVersion.display)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(white: 0.38))
                    .kerning(0.5)
                    .padding(.top, 4)
            }
            .padding(.bottom, 20)

            // Primary actions
            VStack(spacing: 8) {
                Button {
                    appState.newShow()
                    isPresented = false
                } label: {
                    Label("New Show", systemImage: "plus.square.fill")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .kerning(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(SplashPrimaryButtonStyle())

                Button {
                    if appState.openShow() { isPresented = false }
                } label: {
                    Label("Open Show…", systemImage: "folder")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .kerning(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(SplashSecondaryButtonStyle())
            }

            // Recent files (capped at 4 to stay within panel height)
            let recent = appState.recentFiles
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RECENT")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(SmartLightTheme.borderBright)
                        .kerning(2)
                        .padding(.top, 16)
                        .padding(.bottom, 1)

                    VStack(spacing: 3) {
                        ForEach(recent.prefix(4), id: \.self) { url in
                            Button {
                                appState.openShow(url: url)
                                isPresented = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(SmartLightTheme.purple.opacity(0.8))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(url.deletingPathExtension().lastPathComponent)
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                        Text(url.deletingLastPathComponent().abbreviatingWithTildeInPath)
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundStyle(Color(white: 0.45))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(SmartLightTheme.surface.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(SmartLightTheme.border.opacity(0.6), lineWidth: 1))
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
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(SmartLightTheme.borderBright)
                }
                .padding(.top, 14)
            }
        }
        .frame(width: 260)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SmartLightTheme.background.opacity(0.88))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(SmartLightTheme.border, lineWidth: 1))
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
        // All hardcoded radii were tuned for a ~700px tall canvas; scale to actual size.
        let s = min(size.width, size.height) / 700.0

        // 1 ── Deep background fill
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .color(Color(red: 0.04, green: 0.03, blue: 0.10)))

        // 2 ── Radial purple glow at focal point
        ctx.drawLayer { g in
            let r = min(size.width, size.height) * 0.65
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
        let spacing = max(22.0, 38.0 * s)
        let falloff  = 460.0 * s
        var gridPath = Path()
        for row in stride(from: 0.0, through: Double(size.height), by: spacing) {
            for col in stride(from: 0.0, through: Double(size.width) * 0.80, by: spacing) {
                let dist = hypot(col - Double(c.x), row - Double(c.y))
                if dist / falloff < 0.98 {
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
            let len = (isMajor ? min(size.width, size.height) * 1.1
                                : min(size.width, size.height) * 0.75)
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
        let hexRadii: [CGFloat] = [70, 135, 200, 265, 330].map { $0 * s }
        for (ri, radius) in hexRadii.enumerated() {
            let rot = time * -0.018 + Double(ri) * 0.26
            let alpha = max(0.06, 0.38 - Double(ri) * 0.06)
            ctx.stroke(polygon(center: c, sides: 6, radius: radius, rotation: rot),
                       with: .color(Color(red: 0.42, green: 0.18, blue: 0.92).opacity(alpha)),
                       lineWidth: 1.0)
        }

        // 6 ── Concentric octagonal rings (slow clockwise, offset color)
        let octRadii: [CGFloat] = [100, 175, 250, 325].map { $0 * s }
        for (ri, radius) in octRadii.enumerated() {
            let rot = time * 0.012 + Double(ri) * 0.40
            let alpha = max(0.04, 0.28 - Double(ri) * 0.05)
            ctx.stroke(polygon(center: c, sides: 8, radius: radius, rotation: rot),
                       with: .color(Color(red: 0.17, green: 0.38, blue: 0.95).opacity(alpha)),
                       lineWidth: 0.8)
        }

        // 7 ── Outer 12-gon ring (very slow, amber)
        let outerRot = time * 0.007
        ctx.stroke(polygon(center: c, sides: 12, radius: 390 * s, rotation: outerRot),
                   with: .color(Color(red: 0.95, green: 0.73, blue: 0.00).opacity(0.12)),
                   lineWidth: 1.2)

        // 8 ── Amber arc segments (pulsing)
        for i in 0..<3 {
            let baseRadius = (110.0 + Double(i) * 72.0) * s
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

        // 9 ── Inner triangle spoke (amber)
        let spokeRot = time * 0.030
        ctx.stroke(polygon(center: c, sides: 3, radius: 70 * s, rotation: spokeRot),
                   with: .color(Color(red: 0.95, green: 0.73, blue: 0.00).opacity(0.35)),
                   lineWidth: 1.2)

        // 10 ── Bright center node
        let nr = max(5.0, 10.0 * s)
        ctx.drawLayer { g in
            g.fill(Path(ellipseIn: CGRect(x: c.x - nr, y: c.y - nr, width: nr * 2, height: nr * 2)),
                   with: .radialGradient(
                       Gradient(colors: [Color.white, Color(red: 0.95, green: 0.73, blue: 0.00)]),
                       center: c, startRadius: 0, endRadius: nr))
        }
        let dr = max(2.0, 3.5 * s)
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - dr, y: c.y - dr, width: dr * 2, height: dr * 2)),
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
                SmartLightTheme.surfaceHigh
                    .opacity(configuration.isPressed ? 0.5 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(SmartLightTheme.border, lineWidth: 1))
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
