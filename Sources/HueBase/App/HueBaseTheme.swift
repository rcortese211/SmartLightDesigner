import SwiftUI

enum HueBaseTheme {
    // Core palette
    static let purple      = Color(red: 0.42, green: 0.18, blue: 0.92)
    static let blue        = Color(red: 0.17, green: 0.38, blue: 0.95)
    static let deepPurple  = Color(red: 0.22, green: 0.08, blue: 0.45)
    static let background  = Color(red: 0.05, green: 0.04, blue: 0.10)
    static let surface     = Color(red: 0.10, green: 0.08, blue: 0.18)
    static let surfaceHigh = Color(red: 0.14, green: 0.11, blue: 0.24)

    // Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [purple, blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleGradient: LinearGradient {
        LinearGradient(
            colors: [background, surface],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [deepPurple.opacity(0.9), Color(red: 0.08, green: 0.12, blue: 0.30).opacity(0.9)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// Apply to any view to get the full HueBase dark + purple theme
extension View {
    func hueBaseTheme() -> some View {
        self
            .preferredColorScheme(.dark)
            .tint(HueBaseTheme.purple)
    }
}

// Gradient accent bar — used in section headers and toolbars
struct GradientBar: View {
    var height: CGFloat = 2
    var body: some View {
        HueBaseTheme.accentGradient
            .frame(height: height)
    }
}

// Styled section header
struct ThemeLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(HueBaseTheme.accentGradient)
            .textCase(nil)
    }
}
