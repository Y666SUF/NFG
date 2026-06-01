import SwiftUI

/// Dark NFG-style palette (pink/purple) shared across the caster UI.
enum Theme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.07)
    static let panel = Color(red: 0.10, green: 0.10, blue: 0.16)
    static let panelRaised = Color(red: 0.14, green: 0.14, blue: 0.21)
    static let border = Color.white.opacity(0.08)
    static let text = Color.white
    static let muted = Color.white.opacity(0.55)

    static let accent = Color(red: 0.925, green: 0.282, blue: 0.600)
    static let accent2 = Color(red: 0.49, green: 0.30, blue: 0.96)
    static let success = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let warning = Color(red: 0.98, green: 0.74, blue: 0.27)
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.40)

    static let logoGradient = LinearGradient(
        colors: [accent, accent2],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelGradient = LinearGradient(
        colors: [panelRaised, panel],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.panelGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func nfgCard(padding: CGFloat = 14) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
