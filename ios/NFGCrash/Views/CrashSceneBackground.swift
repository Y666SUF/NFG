import SwiftUI

/// Subtle starfield + horizon glow behind the crash game.
struct CrashSceneBackground: View {
    var phase: GamePhase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 12 / 255, green: 16 / 255, blue: 28 / 255),
                    Color(red: 6 / 255, green: 8 / 255, blue: 14 / 255),
                    Color(red: 4 / 255, green: 5 / 255, blue: 10 / 255),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [phaseGlow.opacity(0.22), .clear],
                center: UnitPoint(x: 0.72, y: 0.88),
                startRadius: 0,
                endRadius: 280
            )

            RadialGradient(
                colors: [Color(red: 76 / 255, green: 29 / 255, blue: 149 / 255).opacity(0.2), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )

            StarfieldLayer()
        }
    }

    private var phaseGlow: Color {
        switch phase {
        case .running: return NFGTheme.accent
        case .ended: return NFGTheme.danger
        case .betting: return NFGTheme.accent2
        case .idle: return NFGTheme.muted
        }
    }
}

private struct StarfieldLayer: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<48 {
                let seed = Double(i * 97 + 13)
                let x = CGFloat((sin(seed) * 0.5 + 0.5)) * size.width
                let y = CGFloat((cos(seed * 1.3) * 0.5 + 0.5)) * size.height * 0.65
                let r: CGFloat = i % 5 == 0 ? 1.4 : 0.9
                let a = 0.15 + Double(i % 7) * 0.04
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
