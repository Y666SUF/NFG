import SwiftUI

/// Proposed visual direction — **preview only**. Does not replace `NFGTheme` until approved.
enum NFGThemeVaultTerminal {
    // MARK: - Base palette (warm charcoal + amber casino)
    static let background = Color(red: 12 / 255, green: 12 / 255, blue: 14 / 255)
    static let panel = Color(red: 22 / 255, green: 22 / 255, blue: 26 / 255)
    static let panel2 = Color(red: 18 / 255, green: 18 / 255, blue: 21 / 255)
    static let text = Color(red: 245 / 255, green: 243 / 255, blue: 238 / 255)
    static let muted = Color(red: 148 / 255, green: 144 / 255, blue: 136 / 255)
    static let mutedSoft = muted.opacity(0.72)
    static let accent = Color(red: 232 / 255, green: 168 / 255, blue: 56 / 255)
    static let accent2 = Color(red: 110 / 255, green: 196 / 255, blue: 232 / 255)
    static let danger = Color(red: 220 / 255, green: 74 / 255, blue: 88 / 255)
    static let border = Color.white.opacity(0.10)
    static let gold = Color(red: 240 / 255, green: 180 / 255, blue: 41 / 255)

    static let chipBackground = Color.white.opacity(0.05)
    static let chipBorder = Color.white.opacity(0.10)
    static let betDockBackground = Color(red: 10 / 255, green: 10 / 255, blue: 12 / 255)
    static let cardBorder = Color.white.opacity(0.08)
    static let inputBackground = Color(red: 16 / 255, green: 16 / 255, blue: 19 / 255)
    static let glow = accent.opacity(0.55)

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 240 / 255, green: 180 / 255, blue: 41 / 255),
            Color(red: 232 / 255, green: 148 / 255, blue: 36 / 255),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let crashGradient = LinearGradient(
        colors: [
            Color(red: 220 / 255, green: 74 / 255, blue: 88 / 255),
            Color(red: 180 / 255, green: 48 / 255, blue: 62 / 255),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let lineGradient = LinearGradient(
        colors: [accent, accent.opacity(0.65)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let chartFill = LinearGradient(
        colors: [accent.opacity(0.28), accent.opacity(0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let panelGradient = LinearGradient(
        colors: [panel, panel2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hairlineBorder = LinearGradient(
        colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGlow = RadialGradient(
        colors: [accent.opacity(0.22), .clear],
        center: .top,
        startRadius: 0,
        endRadius: 380
    )
}

enum NFGVaultTerminalRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
}
