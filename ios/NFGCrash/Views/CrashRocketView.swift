import SwiftUI

/// Detailed rocket with metallic shading (ascent, fall, impact).
struct CrashRocketView: View {
    var angle: Angle
    var scale: CGFloat = 1
    var thrust: Bool
    var crashed: Bool
    var impactFlash: Bool

    private let baseW: CGFloat = 52
    private let baseH: CGFloat = 96

    var body: some View {
        ZStack {
            if thrust && !crashed {
                RocketEngineGlow(scale: scale)
                    .offset(y: 42 * scale)
            }

            Canvas { ctx, size in
                drawRocket(ctx: &ctx, size: size)
            }
            .frame(width: baseW * scale, height: baseH * scale)

            if impactFlash {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, NFGTheme.danger.opacity(0.6), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 36 * scale
                        )
                    )
                    .frame(width: 72 * scale, height: 72 * scale)
                    .offset(y: 12 * scale)
                    .blendMode(.plusLighter)
            }
        }
        .rotationEffect(crashed ? .degrees(95) : angle)
        .shadow(color: thrust ? Color.orange.opacity(0.5) : Color.black.opacity(0.45), radius: 12, y: 4)
        .animation(.easeIn(duration: 0.35), value: crashed)
    }

    private func drawRocket(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5

        // Shadow on pad
        var shadow = Path(ellipseIn: CGRect(x: cx - w * 0.28, y: h - 10, width: w * 0.56, height: 10))
        ctx.fill(shadow, with: .color(.black.opacity(0.35)))

        // Fins (back)
        for side in [-1.0, 1.0] {
            var fin = Path()
            fin.move(to: CGPoint(x: cx + side * 6, y: h * 0.62))
            fin.addLine(to: CGPoint(x: cx + side * 22, y: h * 0.78))
            fin.addLine(to: CGPoint(x: cx + side * 10, y: h * 0.72))
            fin.closeSubpath()
            ctx.fill(
                fin,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.32, green: 0.34, blue: 0.42),
                        Color(red: 0.18, green: 0.2, blue: 0.26),
                    ]),
                    startPoint: CGPoint(x: cx, y: h * 0.6),
                    endPoint: CGPoint(x: cx + side * 24, y: h * 0.8)
                )
            )
        }

        // Main body cylinder
        let bodyRect = CGRect(x: cx - w * 0.2, y: h * 0.28, width: w * 0.4, height: h * 0.48)
        let bodyPath = Path(roundedRect: bodyRect, cornerRadius: w * 0.08)
        ctx.fill(
            bodyPath,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.78, green: 0.8, blue: 0.88),
                    Color(red: 0.55, green: 0.58, blue: 0.68),
                    Color(red: 0.38, green: 0.4, blue: 0.5),
                ]),
                startPoint: CGPoint(x: bodyRect.minX, y: bodyRect.midY),
                endPoint: CGPoint(x: bodyRect.maxX, y: bodyRect.midY)
            )
        )
        // Highlight strip (3D)
        let highlight = CGRect(x: cx - w * 0.06, y: h * 0.3, width: w * 0.05, height: h * 0.44)
        ctx.fill(Path(roundedRect: highlight, cornerRadius: 2), with: .color(.white.opacity(0.35)))

        // NFG stripe
        let stripe = CGRect(x: bodyRect.minX, y: h * 0.48, width: bodyRect.width, height: h * 0.06)
        ctx.fill(Path(stripe), with: .color(NFGTheme.accent.opacity(0.9)))

        // Rivets
        for ry in stride(from: h * 0.34, through: h * 0.68, by: h * 0.08) {
            let rivet = CGRect(x: cx - w * 0.14, y: ry, width: 3, height: 3)
            ctx.fill(Path(ellipseIn: rivet), with: .color(.white.opacity(0.25)))
            let rivetR = CGRect(x: cx + w * 0.11, y: ry, width: 3, height: 3)
            ctx.fill(Path(ellipseIn: rivetR), with: .color(.black.opacity(0.2)))
        }

        // Window
        let window = CGRect(x: cx - w * 0.09, y: h * 0.36, width: w * 0.18, height: w * 0.18)
        ctx.fill(
            Path(ellipseIn: window),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.65, green: 0.88, blue: 1),
                    Color(red: 0.12, green: 0.35, blue: 0.62),
                ]),
                center: CGPoint(x: window.midX - 2, y: window.midY - 2),
                startRadius: 0,
                endRadius: w * 0.12
            )
        )
        ctx.stroke(Path(ellipseIn: window), with: .color(.white.opacity(0.55)), lineWidth: 1.2)

        // Nose cone
        var nose = Path()
        nose.move(to: CGPoint(x: cx, y: h * 0.06))
        nose.addLine(to: CGPoint(x: cx + w * 0.2, y: h * 0.3))
        nose.addLine(to: CGPoint(x: cx - w * 0.2, y: h * 0.3))
        nose.closeSubpath()
        ctx.fill(
            nose,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.98, green: 0.55, blue: 0.28),
                    Color(red: 0.85, green: 0.28, blue: 0.14),
                    Color(red: 0.55, green: 0.15, blue: 0.1),
                ]),
                startPoint: CGPoint(x: cx, y: h * 0.05),
                endPoint: CGPoint(x: cx, y: h * 0.3)
            )
        )

        // Engine bell
        var bell = Path()
        bell.addEllipse(in: CGRect(x: cx - w * 0.14, y: h * 0.74, width: w * 0.28, height: h * 0.08))
        ctx.fill(bell, with: .color(Color(red: 0.25, green: 0.27, blue: 0.32)))
        var inner = Path()
        inner.addEllipse(in: CGRect(x: cx - w * 0.09, y: h * 0.755, width: w * 0.18, height: h * 0.05))
        ctx.fill(inner, with: .color(Color(red: 0.08, green: 0.09, blue: 0.12)))
    }
}

/// Static debris at the crash impact point (replaces intact rocket until next round).
struct CrashRocketWreckageView: View {
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            NFGTheme.danger.opacity(0.35),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 44 * scale
                    )
                )
                .frame(width: 88 * scale, height: 26 * scale)
                .offset(y: 14 * scale)

            debrisPiece(width: 38, height: 10, rotation: -18, offset: CGSize(width: -22, height: 8))
            debrisPiece(width: 28, height: 8, rotation: 32, offset: CGSize(width: 24, height: 12))
            debrisPiece(width: 14, height: 22, rotation: -55, offset: CGSize(width: -8, height: -6))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.52, blue: 0.6),
                            Color(red: 0.28, green: 0.3, blue: 0.38),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 44 * scale, height: 14 * scale)
                .rotationEffect(.degrees(-12))
                .offset(y: 4 * scale)
                .overlay(
                    Capsule()
                        .fill(NFGTheme.accent.opacity(0.5))
                        .frame(width: 30 * scale, height: 4 * scale)
                        .rotationEffect(.degrees(-12))
                        .offset(y: 4 * scale)
                )

            wreckNose
                .offset(x: -26 * scale, y: -10 * scale)
                .rotationEffect(.degrees(-48))

            wreckFin
                .offset(x: 30 * scale, y: 2 * scale)
                .rotationEffect(.degrees(70))

            wreckFin
                .scaleEffect(x: -1, y: 1)
                .offset(x: -34 * scale, y: 6 * scale)
                .rotationEffect(.degrees(-95))

            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i % 2 == 0 ? Color.orange : NFGTheme.danger)
                    .frame(width: (3 + CGFloat(i % 2)) * scale, height: (3 + CGFloat(i % 2)) * scale)
                    .offset(
                        x: CGFloat([-18, 8, 22, -4, 14][i]) * scale,
                        y: CGFloat([-8, -14, -4, 6, 10][i]) * scale
                    )
                    .opacity(0.75)
            }
        }
        .frame(width: 110 * scale, height: 72 * scale)
        .allowsHitTesting(false)
    }

    private func debrisPiece(width: CGFloat, height: CGFloat, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(red: 0.32, green: 0.34, blue: 0.42))
            .frame(width: width * scale, height: height * scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }

    private var wreckNose: some View {
        Triangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.9, green: 0.45, blue: 0.2),
                        Color(red: 0.55, green: 0.18, blue: 0.1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 22 * scale, height: 20 * scale)
    }

    private var wreckFin: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 16, y: 18))
            path.addLine(to: CGPoint(x: 4, y: 14))
            path.closeSubpath()
        }
        .fill(Color(red: 0.28, green: 0.3, blue: 0.38))
        .frame(width: 18 * scale, height: 20 * scale)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct RocketEngineGlow: View {
    var scale: CGFloat
    @State private var flicker = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), .yellow, .orange, .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 28 * scale
                    )
                )
                .frame(width: 22 * scale, height: 38 * scale)
                .scaleEffect(y: flicker ? 1.15 : 0.9)
            Ellipse()
                .fill(Color.cyan.opacity(0.35))
                .frame(width: 14 * scale, height: 22 * scale)
                .blur(radius: 3)
                .offset(y: 4 * scale)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.08).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
    }
}
