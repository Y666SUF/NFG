import SwiftUI

enum NFGTheme {
    static let background = Color(red: 7 / 255, green: 11 / 255, blue: 18 / 255)
    static let panel = Color(red: 15 / 255, green: 27 / 255, blue: 42 / 255)
    static let panel2 = Color(red: 11 / 255, green: 22 / 255, blue: 35 / 255)
    static let text = Color(red: 238 / 255, green: 247 / 255, blue: 255 / 255)
    static let muted = Color(red: 159 / 255, green: 179 / 255, blue: 201 / 255)
    static let accent = Color(red: 79 / 255, green: 209 / 255, blue: 255 / 255)
    static let accent2 = Color(red: 126 / 255, green: 231 / 255, blue: 196 / 255)
    static let danger = Color(red: 255 / 255, green: 107 / 255, blue: 107 / 255)
    static let border = Color.white.opacity(0.14)
    static let gold = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)

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
