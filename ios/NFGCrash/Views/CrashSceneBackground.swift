import SwiftUI

/// Galaxy + starfield for the crash chart box only.
struct CrashSceneBackground: View {
    var phase: GamePhase

    private let space = Color(red: 0.05, green: 0.04, blue: 0.22)

    var body: some View {
        ZStack {
            Rectangle().fill(space)

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.58, green: 0.32, blue: 1).opacity(0.78),
                            Color(red: 0.22, green: 0.42, blue: 0.95).opacity(0.42),
                            .clear
                        ],
                        center: UnitPoint(x: 0.22, y: 0.28),
                        startRadius: 0,
                        endRadius: 260
                    )
                )

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.82, green: 0.28, blue: 0.78).opacity(0.62),
                            Color(red: 0.12, green: 0.5, blue: 0.98).opacity(0.3),
                            .clear
                        ],
                        center: UnitPoint(x: 0.78, y: 0.42),
                        startRadius: 0,
                        endRadius: 230
                    )
                )

            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [phaseAccent.opacity(0.35), .clear],
                        center: UnitPoint(x: 0.5, y: 0.9),
                        startRadius: 0,
                        endRadius: 180
                    )
                )

            ChartStarfieldCanvas()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var phaseAccent: Color {
        switch phase {
        case .running: return NFGTheme.accent
        case .ended: return NFGTheme.danger
        case .betting: return NFGTheme.accent2
        case .idle: return NFGTheme.muted
        }
    }
}

private struct ChartStarfieldCanvas: View {
    var body: some View {
        Canvas { context, size in
            let starScale: CGFloat = min(size.width, size.height) < 200 ? 2.3 : 1.7
            for i in 0..<300 {
                let seed = Double(i * 97 + 13)
                let x = CGFloat((sin(seed) * 0.5 + 0.5)) * size.width
                let y = CGFloat((cos(seed * 1.31) * 0.5 + 0.5)) * size.height
                let tier = i % 11
                let r: CGFloat = (tier == 0 ? 2.6 : (tier < 4 ? 1.7 : 1.0)) * starScale
                let alpha = tier == 0 ? 1.0 : (0.55 + Double(i % 7) * 0.06)
                let tint: Color = i % 19 == 0
                    ? Color(red: 0.92, green: 0.86, blue: 1)
                    : .white
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)),
                    with: .color(tint.opacity(alpha))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

#if DEBUG
struct ChartGalaxyPreviewHost: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CrashChartView(
                history: [1, 1.4, 2.1, 2.8],
                phase: .running,
                multiplier: 2.85,
                crashPoint: nil,
                bettingEndsAt: 0,
                openBets: [],
                queuedBets: [],
                entriesActionMessage: nil
            )
            .frame(width: 360, height: 148)
        }
    }
}
#endif
