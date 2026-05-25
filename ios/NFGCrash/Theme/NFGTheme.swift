import SwiftUI

enum NFGTheme {
    // MARK: - Base palette
    static let background = Color(red: 7 / 255, green: 11 / 255, blue: 18 / 255)
    static let panel = Color(red: 15 / 255, green: 27 / 255, blue: 42 / 255)
    static let panel2 = Color(red: 11 / 255, green: 22 / 255, blue: 35 / 255)
    static let text = Color(red: 238 / 255, green: 247 / 255, blue: 255 / 255)
    static let muted = Color(red: 159 / 255, green: 179 / 255, blue: 201 / 255)
    static let mutedSoft = Color(red: 159 / 255, green: 179 / 255, blue: 201 / 255).opacity(0.7)
    static let accent = Color(red: 79 / 255, green: 209 / 255, blue: 255 / 255)
    static let accent2 = Color(red: 126 / 255, green: 231 / 255, blue: 196 / 255)
    static let danger = Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)
    static let border = Color.white.opacity(0.14)
    static let gold = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)

    // MARK: - Semantic tokens (new)
    static let chipBackground = Color.white.opacity(0.06)
    static let chipBorder = Color.white.opacity(0.12)
    static let betDockBackground = Color(red: 9 / 255, green: 16 / 255, blue: 26 / 255)
    static let cardBorder = Color.white.opacity(0.10)
    static let cardBorderStrong = Color.white.opacity(0.18)
    static let mutedText = Color(red: 159 / 255, green: 179 / 255, blue: 201 / 255)
    static let inputBackground = Color(red: 13 / 255, green: 23 / 255, blue: 36 / 255)
    static let glow = Color(red: 94 / 255, green: 234 / 255, blue: 212 / 255)

    // MARK: - Gradients
    static let logoGradient = LinearGradient(
        colors: [
            Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
            Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let lineGradient = LinearGradient(
        colors: [
            Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
            Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let chartFill = LinearGradient(
        colors: [
            Color(red: 94 / 255, green: 234 / 255, blue: 212 / 255).opacity(0.45),
            Color(red: 94 / 255, green: 234 / 255, blue: 212 / 255).opacity(0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Smooth accent gradient — used on primary buttons and the running multiplier badge.
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 79 / 255, green: 209 / 255, blue: 255 / 255),
            Color(red: 126 / 255, green: 231 / 255, blue: 196 / 255),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Coral → magenta — used on the crashed state.
    static let crashGradient = LinearGradient(
        colors: [
            Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255),
            Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Gold gradient used on Super Fan / tax / rewarded ad accents.
    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255),
            Color(red: 245 / 255, green: 158 / 255, blue: 11 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle navy panel gradient for cards.
    static let panelGradient = LinearGradient(
        colors: [
            Color(red: 18 / 255, green: 30 / 255, blue: 46 / 255),
            Color(red: 11 / 255, green: 20 / 255, blue: 32 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Hairline gradient stroke for cards — gives premium edge lighting without heavy borders.
    static let hairlineBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.18),
            Color.white.opacity(0.04),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Top-of-screen ambient glow.
    static let backgroundGlow = RadialGradient(
        colors: [
            Color(red: 76 / 255, green: 29 / 255, blue: 149 / 255).opacity(0.55),
            .clear,
        ],
        center: .top,
        startRadius: 0,
        endRadius: 420
    )
}

// MARK: - Spacing scale (8pt grid)
enum NFGSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
}

// MARK: - Corner radii
enum NFGRadius {
    static let chip: CGFloat = 999
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
}

// MARK: - Typography helpers
enum NFGFont {
    /// Monospaced big multiplier (e.g. `2.45×`)
    static func multiplier(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// SF Rounded label for headers and chips
    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// All-caps micro labels for section eyebrows.
    static func eyebrow(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Monospaced numeric body for bet amounts / timers.
    static func numeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Gold Super Fan badge — matches wallet / leaderboard / live game.
struct SuperFanBadgeView: View {
    var badge: SuperFanBadgeDisplay
    var compact: Bool = false

    var body: some View {
        if badge.superFan {
            HStack(spacing: 3) {
                Text("★")
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                if !compact {
                    Text("SUPER FAN")
                        .font(.system(size: 9, weight: .black))
                } else if badge.level > 1 {
                    Text("\(badge.level)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(NFGTheme.gold)
            .padding(.horizontal, compact ? 5 : 6)
            .padding(.vertical, compact ? 2 : 3)
            .background(NFGTheme.gold.opacity(0.22))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(NFGTheme.gold.opacity(0.45)))
            .accessibilityLabel(badge.level > 1 ? "Super Fan level \(badge.level)" : "Super Fan")
        }
    }
}
