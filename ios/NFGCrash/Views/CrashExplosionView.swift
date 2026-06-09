import SwiftUI

struct CrashExplosionView: View {
    var intensity: CGFloat
    var size: CGFloat = 140

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .yellow, .orange, NFGTheme.danger.opacity(0.6), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.7 * intensity
                    )
                )
                .frame(width: size * 1.4 * intensity, height: size * 1.4 * intensity)
                .blur(radius: 4)

            ForEach(0..<16, id: \.self) { i in
                Capsule()
                    .fill(i % 2 == 0 ? Color.orange : NFGTheme.danger)
                    .frame(width: 5, height: 14 + CGFloat(i % 5) * 10)
                    .offset(y: -(size * 0.15 + CGFloat(i) * 7) * intensity)
                    .rotationEffect(.degrees(Double(i) * 22.5))
                    .opacity(Double(intensity) * 0.9)
            }

            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(particleColor(i))
                    .frame(width: particleSize(i), height: particleSize(i))
                    .offset(particleOffset(i))
                    .opacity(Double(intensity) * (0.4 + Double(i % 4) * 0.12))
                    .blur(radius: i % 3 == 0 ? 1 : 0)
            }

            ForEach(0..<6, id: \.self) { i in
                Ellipse()
                    .fill(Color(white: 0.35, opacity: 0.5))
                    .frame(width: 40 + CGFloat(i) * 18, height: 16 + CGFloat(i) * 6)
                    .offset(x: CGFloat(i - 3) * 12, y: CGFloat(i) * 4)
                    .scaleEffect(0.6 + intensity * 0.5)
                    .opacity(Double(intensity) * 0.35)
                    .blur(radius: 6)
            }
        }
        .allowsHitTesting(false)
    }

    private func particleColor(_ i: Int) -> Color {
        [Color.orange, NFGTheme.danger, .yellow, .white, Color(white: 0.7)][i % 5]
    }

    private func particleSize(_ i: Int) -> CGFloat {
        (5 + CGFloat(i % 5) * 4) * intensity
    }

    private func particleOffset(_ i: Int) -> CGSize {
        let angle = Double(i) / 20 * .pi * 2
        let dist = size * 0.42 * intensity
        return CGSize(width: cos(angle) * dist, height: sin(angle) * dist)
    }
}
