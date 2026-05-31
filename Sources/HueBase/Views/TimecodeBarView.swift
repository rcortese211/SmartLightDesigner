import SwiftUI

/// Compact timecode transport bar shown at the bottom of the main window.
struct TimecodeBarView: View {
    @Environment(AppState.self) private var appState
    private var tc: TimecodeEngine { appState.timecodeEngine }

    var body: some View {
        HStack(spacing: 16) {
            // Source indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(tc.isRunning ? HueBaseTheme.purple : Color.secondary)
                    .frame(width: 7, height: 7)
                Text(tc.source.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 14)

            // Timecode display
            Text(tc.current.description)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(tc.isRunning
                    ? AnyShapeStyle(HueBaseTheme.accentGradient)
                    : AnyShapeStyle(Color.secondary))

            Text(tc.frameRate.label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Divider().frame(height: 14)

            // Transport controls (only active in internal mode)
            HStack(spacing: 8) {
                Button(action: { tc.locate(to: .zero) }) {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isInternal ? HueBaseTheme.purple : .secondary)
                .disabled(!isInternal)

                Button(action: {
                    tc.isRunning ? tc.pause() : tc.play()
                }) {
                    Image(systemName: tc.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isInternal ? HueBaseTheme.purple : .secondary)
                .disabled(!isInternal)

                Button(action: { tc.stop(); tc.locate(to: .zero) }) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isInternal ? HueBaseTheme.purple : .secondary)
                .disabled(!isInternal)
            }

            Spacer()

            // Frame rate picker (internal only)
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
                .frame(width: 160)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(HueBaseTheme.surface)
        .overlay(alignment: .top) { GradientBar(height: 1) }
    }

    private var isInternal: Bool { tc.source == .internal_ }
}
