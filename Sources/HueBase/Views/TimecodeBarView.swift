import SwiftUI

struct TimecodeBarView: View {
    @Environment(AppState.self) private var appState
    private var tc: TimecodeEngine { appState.timecodeEngine }

    var body: some View {
        HStack(spacing: 0) {
            // Source indicator
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(tc.isRunning ? HueBaseTheme.active : Color(white: 0.22))
                    .frame(width: 8, height: 8)
                Text(tc.source.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tc.isRunning ? HueBaseTheme.active : Color(white: 0.38))
            }
            .padding(.horizontal, 10)

            divider

            // Timecode display
            Text(tc.current.description)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(tc.isRunning
                    ? AnyShapeStyle(HueBaseTheme.accentGradient)
                    : AnyShapeStyle(Color(white: 0.50)))
                .padding(.horizontal, 12)

            Text(tc.frameRate.label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.32))
                .padding(.trailing, 10)

            divider

            // Transport controls
            HStack(spacing: 2) {
                transportButton(icon: "backward.end.fill") { tc.locate(to: .zero) }
                transportButton(icon: tc.isRunning ? "pause.fill" : "play.fill") {
                    tc.isRunning ? tc.pause() : tc.play()
                }
                transportButton(icon: "stop.fill") { tc.stop(); tc.locate(to: .zero) }
            }
            .padding(.horizontal, 6)
            .disabled(!isInternal)
            .opacity(isInternal ? 1.0 : 0.30)

            divider

            Spacer()

            if isInternal {
                Picker("", selection: Binding(
                    get: { tc.frameRate },
                    set: { tc.frameRate = $0 }
                )) {
                    ForEach(TimecodeFrameRate.allCases) { rate in
                        Text(rate.label).tag(rate)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                .padding(.horizontal, 8)
            }
        }
        .frame(height: 28)
        .background(HueBaseTheme.surfaceHigh)
        .overlay(alignment: .top) {
            GradientBar(height: 1)
        }
    }

    private var divider: some View {
        HueBaseTheme.border.frame(width: 1).padding(.vertical, 4)
    }

    private func transportButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 22, height: 20)
                .foregroundStyle(isInternal ? HueBaseTheme.purple : Color(white: 0.38))
                .background(HueBaseTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(HueBaseTheme.border, lineWidth: 1)
                )
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
    }

    private var isInternal: Bool { tc.source == .internal_ }
}
