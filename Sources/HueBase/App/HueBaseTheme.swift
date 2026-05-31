import SwiftUI

enum HueBaseTheme {
    // Core palette — black/purple/blue, professional DMX console layout
    static let purple      = Color(red: 0.42, green: 0.18, blue: 0.92)
    static let blue        = Color(red: 0.17, green: 0.38, blue: 0.95)
    static let deepPurple  = Color(red: 0.22, green: 0.08, blue: 0.45)
    static let active      = Color(red: 0.95, green: 0.73, blue: 0.00)   // amber — live/hot state
    static let danger      = Color(red: 0.90, green: 0.20, blue: 0.20)
    static let background  = Color(red: 0.05, green: 0.04, blue: 0.10)   // near-black, purple tinted
    static let surface     = Color(red: 0.10, green: 0.08, blue: 0.18)   // panel
    static let surfaceHigh = Color(red: 0.14, green: 0.11, blue: 0.24)   // raised panel
    static let border      = Color(red: 0.22, green: 0.18, blue: 0.35)   // panel divider
    static let borderBright = Color(red: 0.38, green: 0.28, blue: 0.60)   // active border

    // Primary accent — used across all call sites
    static var accent: Color { purple }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [purple, blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var subtleGradient: LinearGradient {
        LinearGradient(colors: [background, surface], startPoint: .top, endPoint: .bottom)
    }

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [deepPurple.opacity(0.9), Color(red: 0.08, green: 0.12, blue: 0.30).opacity(0.9)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

extension View {
    func hueBaseTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(HueBaseTheme.purple)
    }
}

// Teal accent line used in section headers
struct GradientBar: View {
    var height: CGFloat = 2
    var body: some View {
        HueBaseTheme.accentGradient
            .frame(height: height)
    }
}

struct ThemeLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(HueBaseTheme.accentGradient)
            .textCase(nil)
    }
}

// Compact panel header — dense DMX console-style header strip
struct PanelHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HueBaseTheme.accentGradient)
                .kerning(1.0)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(HueBaseTheme.surfaceHigh)
        .overlay(alignment: .bottom) {
            HueBaseTheme.purple.opacity(0.5).frame(height: 1)
        }
    }
}

// Inline value display — monospaced, used for DMX channel values
struct DMXValueLabel: View {
    let value: Int
    var body: some View {
        Text(String(format: "%3d", value))
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundStyle(value > 0 ? HueBaseTheme.active : Color.secondary)
    }
}
