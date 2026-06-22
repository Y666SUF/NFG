import SwiftUI

// MARK: - Flying rocket

/// Procedural rocket with metallic depth, panel lines, and thrust glow.
struct CrashRocketView: View {
    var angle: Angle
    var scale: CGFloat = 1
    var thrust: Bool
    /// 1.2 at round start (1×), shrinks as multiplier rises.
    var exhaustIntensity: CGFloat = 1
    var crashed: Bool
    var impactFlash: Bool

    private let baseW: CGFloat = 58
    private let baseH: CGFloat = 108

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                if thrust && !crashed {
                    RocketEngineGlow(scale: scale, phase: phase)
                        .offset(y: 46 * scale)
                }

                if thrust && !crashed {
                    RocketHullBloom(scale: scale, phase: phase)
                }

                Canvas { ctx, size in
                    RocketRenderer.draw(
                        ctx: &ctx,
                        size: size,
                        scorched: crashed,
                        thrust: thrust && !crashed
                    )
                }
                .frame(width: baseW * scale, height: baseH * scale)
                .drawingGroup(opaque: false)

                if impactFlash {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, NFGTheme.danger.opacity(0.75), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 42 * scale
                            )
                        )
                        .frame(width: 84 * scale, height: 84 * scale)
                        .offset(y: 14 * scale)
                        .blendMode(.plusLighter)
                }
            }
            .rotationEffect(crashed ? .degrees(95) : angle)
            .offset(y: crashed ? 0 : sin(phase * 2.4) * 1.2 * scale)
            .rotationEffect(
                crashed ? .zero : .degrees(sin(phase * 3.1) * (thrust ? 1.4 : 0.5)),
                anchor: .center
            )
        }
        .shadow(
            color: thrust && !crashed
                ? Color.orange.opacity(0.55)
                : Color.black.opacity(0.55),
            radius: thrust ? 18 : 14,
            y: 6
        )
        .shadow(
            color: thrust && !crashed ? NFGTheme.accent.opacity(0.25) : .clear,
            radius: 22,
            y: 0
        )
        .animation(.easeIn(duration: 0.35), value: crashed)
    }
}

// MARK: - Flight motion (chart)

struct RocketFlightMotionModifier: ViewModifier {
    var active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? (pulse ? 1.04 : 1.02) : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onChange(of: active) { _, on in
                if on {
                    withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                } else {
                    pulse = false
                }
            }
    }
}

// MARK: - Canvas renderer

private enum RocketPalette {
    static let hullLight = Color(red: 0.92, green: 0.94, blue: 0.98)
    static let hullMid = Color(red: 0.62, green: 0.66, blue: 0.76)
    static let hullDark = Color(red: 0.28, green: 0.32, blue: 0.42)
    static let finLight = Color(red: 0.48, green: 0.52, blue: 0.62)
    static let finDark = Color(red: 0.14, green: 0.16, blue: 0.22)
    static let noseHot = Color(red: 1, green: 0.72, blue: 0.38)
    static let noseDeep = Color(red: 0.62, green: 0.18, blue: 0.12)
    static let scorch = Color(red: 0.12, green: 0.1, blue: 0.1)
    static let ember = Color(red: 1, green: 0.42, blue: 0.12)
}

private enum RocketRenderer {
    static func draw(
        ctx: inout GraphicsContext,
        size: CGSize,
        scorched: Bool,
        thrust: Bool
    ) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5

        drawGroundShadow(ctx: &ctx, cx: cx, w: w, h: h)
        drawFins(ctx: &ctx, cx: cx, w: w, h: h, scorched: scorched)
        drawBoosters(ctx: &ctx, cx: cx, w: w, h: h)
        drawMainBody(ctx: &ctx, cx: cx, w: w, h: h, scorched: scorched)
        drawNose(ctx: &ctx, cx: cx, w: w, h: h, scorched: scorched)
        drawEngineBell(ctx: &ctx, cx: cx, w: w, h: h, thrust: thrust, scorched: scorched)
        if scorched {
            drawScorchOverlay(ctx: &ctx, cx: cx, w: w, h: h)
        }
    }

    private static func drawGroundShadow(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat) {
        var shadow = Path(ellipseIn: CGRect(x: cx - w * 0.32, y: h - 12, width: w * 0.64, height: 14))
        ctx.fill(shadow, with: .color(.black.opacity(0.42)))
        var inner = Path(ellipseIn: CGRect(x: cx - w * 0.2, y: h - 10, width: w * 0.4, height: 8))
        ctx.fill(inner, with: .color(.black.opacity(0.22)))
    }

    private static func drawFins(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat, scorched: Bool) {
        for side in [-1.0, 1.0] {
            var fin = Path()
            fin.move(to: CGPoint(x: cx + side * 5, y: h * 0.58))
            fin.addQuadCurve(
                to: CGPoint(x: cx + side * 26, y: h * 0.82),
                control: CGPoint(x: cx + side * 22, y: h * 0.66)
            )
            fin.addLine(to: CGPoint(x: cx + side * 12, y: h * 0.74))
            fin.closeSubpath()
            ctx.fill(
                fin,
                with: .linearGradient(
                    Gradient(colors: scorched
                        ? [RocketPalette.scorch, RocketPalette.finDark]
                        : [RocketPalette.finLight, RocketPalette.finDark]),
                    startPoint: CGPoint(x: cx, y: h * 0.58),
                    endPoint: CGPoint(x: cx + side * 28, y: h * 0.84)
                )
            )
            ctx.stroke(fin, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
        }
    }

    private static func drawBoosters(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat) {
        for side in [-1.0, 1.0] {
            let r = CGRect(x: cx + side * 14 - 5, y: h * 0.42, width: 10, height: h * 0.28)
            let path = Path(roundedRect: r, cornerRadius: 3)
            ctx.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [RocketPalette.hullLight, RocketPalette.hullDark]),
                    startPoint: CGPoint(x: r.minX, y: r.midY),
                    endPoint: CGPoint(x: r.maxX, y: r.midY)
                )
            )
            ctx.stroke(path, with: .color(.black.opacity(0.25)), lineWidth: 0.6)
        }
    }

    private static func drawMainBody(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat, scorched: Bool) {
        let bodyRect = CGRect(x: cx - w * 0.22, y: h * 0.26, width: w * 0.44, height: h * 0.5)
        let bodyPath = Path(roundedRect: bodyRect, cornerRadius: w * 0.09)

        ctx.fill(
            bodyPath,
            with: .linearGradient(
                Gradient(colors: scorched
                    ? [Color(red: 0.35, green: 0.34, blue: 0.38), RocketPalette.hullDark, RocketPalette.scorch]
                    : [RocketPalette.hullLight, RocketPalette.hullMid, RocketPalette.hullDark]),
                startPoint: CGPoint(x: bodyRect.minX - 4, y: bodyRect.minY),
                endPoint: CGPoint(x: bodyRect.maxX + 6, y: bodyRect.maxY)
            )
        )

        // Cylindrical highlight (specular band)
        let spec = CGRect(x: cx - w * 0.05, y: h * 0.28, width: w * 0.07, height: h * 0.46)
        ctx.fill(
            Path(roundedRect: spec, cornerRadius: 2),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.55), .white.opacity(0.08), .clear]),
                startPoint: CGPoint(x: spec.minX, y: spec.minY),
                endPoint: CGPoint(x: spec.maxX, y: spec.maxY)
            )
        )

        // Panel seam lines
        for yFrac in [0.38, 0.52, 0.66] as [CGFloat] {
            var seam = Path()
            seam.move(to: CGPoint(x: bodyRect.minX + 2, y: h * yFrac))
            seam.addLine(to: CGPoint(x: bodyRect.maxX - 2, y: h * yFrac))
            ctx.stroke(seam, with: .color(.black.opacity(0.22)), lineWidth: 0.7)
        }

        // NFG stripe + glow
        let stripe = CGRect(x: bodyRect.minX, y: h * 0.5, width: bodyRect.width, height: h * 0.055)
        ctx.fill(Path(stripe), with: .color(NFGTheme.accent.opacity(0.95)))
        ctx.fill(
            Path(stripe).offsetBy(dx: 0, dy: -1),
            with: .color(NFGTheme.glow.opacity(0.35))
        )

        // Rivets
        for ry in stride(from: h * 0.32, through: h * 0.7, by: h * 0.075) {
            for xOff: CGFloat in [-0.15, 0.12] {
                let rivet = CGRect(x: cx + w * xOff, y: ry, width: 3.5, height: 3.5)
                ctx.fill(Path(ellipseIn: rivet), with: .color(.white.opacity(xOff < 0 ? 0.35 : 0.12)))
                ctx.stroke(Path(ellipseIn: rivet), with: .color(.black.opacity(0.2)), lineWidth: 0.4)
            }
        }

        drawWindow(ctx: &ctx, cx: cx, w: w, h: h, scorched: scorched)
    }

    private static func drawWindow(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat, scorched: Bool) {
        let window = CGRect(x: cx - w * 0.1, y: h * 0.34, width: w * 0.2, height: w * 0.2)
        let ring = Path(ellipseIn: window.insetBy(dx: -1.5, dy: -1.5))
        ctx.fill(ring, with: .color(.white.opacity(0.2)))
        ctx.fill(
            Path(ellipseIn: window),
            with: .radialGradient(
                Gradient(colors: scorched
                    ? [Color(red: 0.25, green: 0.2, blue: 0.18), RocketPalette.scorch]
                    : [
                        Color(red: 0.75, green: 0.92, blue: 1),
                        Color(red: 0.2, green: 0.55, blue: 0.88),
                        Color(red: 0.05, green: 0.2, blue: 0.45),
                    ]),
                center: CGPoint(x: window.midX - 3, y: window.midY - 4),
                startRadius: 0,
                endRadius: w * 0.14
            )
        )
        // Glass glint
        var glint = Path()
        glint.addArc(
            center: CGPoint(x: window.midX - 4, y: window.midY - 5),
            radius: w * 0.05,
            startAngle: .degrees(-40),
            endAngle: .degrees(80),
            clockwise: false
        )
        ctx.stroke(glint, with: .color(.white.opacity(scorched ? 0.15 : 0.7)), lineWidth: 2)
        ctx.stroke(Path(ellipseIn: window), with: .color(.white.opacity(0.5)), lineWidth: 1.4)
    }

    private static func drawNose(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat, scorched: Bool) {
        var nose = Path()
        nose.move(to: CGPoint(x: cx, y: h * 0.04))
        nose.addQuadCurve(
            to: CGPoint(x: cx + w * 0.22, y: h * 0.28),
            control: CGPoint(x: cx + w * 0.18, y: h * 0.1)
        )
        nose.addLine(to: CGPoint(x: cx - w * 0.22, y: h * 0.28))
        nose.addQuadCurve(
            to: CGPoint(x: cx, y: h * 0.04),
            control: CGPoint(x: cx - w * 0.18, y: h * 0.1)
        )
        nose.closeSubpath()

        ctx.fill(
            nose,
            with: .linearGradient(
                Gradient(colors: scorched
                    ? [RocketPalette.ember.opacity(0.6), RocketPalette.scorch]
                    : [RocketPalette.noseHot, RocketPalette.noseDeep, Color(red: 0.4, green: 0.1, blue: 0.08)]),
                startPoint: CGPoint(x: cx, y: h * 0.02),
                endPoint: CGPoint(x: cx, y: h * 0.3)
            )
        )

        // Specular cap
        var cap = Path()
        cap.addEllipse(in: CGRect(x: cx - w * 0.06, y: h * 0.06, width: w * 0.12, height: h * 0.05))
        ctx.fill(cap, with: .color(.white.opacity(scorched ? 0.12 : 0.45)))
        ctx.stroke(nose, with: .color(.black.opacity(0.28)), lineWidth: 0.8)
    }

    private static func drawEngineBell(
        ctx: inout GraphicsContext,
        cx: CGFloat,
        w: CGFloat,
        h: CGFloat,
        thrust: Bool,
        scorched: Bool
    ) {
        let bellOuter = CGRect(x: cx - w * 0.16, y: h * 0.72, width: w * 0.32, height: h * 0.1)
        ctx.fill(
            Path(ellipseIn: bellOuter),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.42, green: 0.45, blue: 0.52), RocketPalette.finDark]),
                startPoint: CGPoint(x: bellOuter.minX, y: bellOuter.midY),
                endPoint: CGPoint(x: bellOuter.maxX, y: bellOuter.midY)
            )
        )
        let bellInner = CGRect(x: cx - w * 0.11, y: h * 0.735, width: w * 0.22, height: h * 0.06)
        ctx.fill(
            Path(ellipseIn: bellInner),
            with: .radialGradient(
                Gradient(colors: thrust && !scorched
                    ? [Color(red: 1, green: 0.85, blue: 0.5), Color(red: 1, green: 0.4, blue: 0.1), Color(red: 0.15, green: 0.08, blue: 0.05)]
                    : [Color(red: 0.2, green: 0.18, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.08)]),
                center: CGPoint(x: cx, y: bellInner.midY),
                startRadius: 0,
                endRadius: w * 0.14
            )
        )
        // Nozzle lip
        ctx.stroke(Path(ellipseIn: bellOuter), with: .color(.white.opacity(0.15)), lineWidth: 0.8)
    }

    private static func drawScorchOverlay(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat) {
        var streak = Path()
        streak.move(to: CGPoint(x: cx - w * 0.12, y: h * 0.35))
        streak.addQuadCurve(
            to: CGPoint(x: cx + w * 0.18, y: h * 0.78),
            control: CGPoint(x: cx + w * 0.05, y: h * 0.55)
        )
        ctx.stroke(streak, with: .color(RocketPalette.ember.opacity(0.5)), lineWidth: 6)
        ctx.stroke(streak, with: .color(.black.opacity(0.35)), lineWidth: 10)

        let sparks: [(CGFloat, CGFloat)] = [(-10, 0.52), (6, 0.58), (12, 0.68), (-4, 0.72)]
        for (dx, yFrac) in sparks {
            let spark = CGRect(x: cx + dx, y: h * yFrac, width: 3, height: 3)
            ctx.fill(Path(ellipseIn: spark), with: .color(RocketPalette.ember.opacity(0.8)))
        }
    }
}

// MARK: - Wreckage (post-crash)

/// Dramatic crash debris with charred hull, embers, and smoke wisps.
struct CrashRocketWreckageView: View {
    var scale: CGFloat = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                scorchCrater
                smokeWisps(phase: t)
                Canvas { ctx, size in
                    WreckRenderer.draw(ctx: &ctx, size: size)
                }
                .frame(width: 128 * scale, height: 88 * scale)
                .drawingGroup(opaque: false)

                emberField(phase: t)
            }
            .frame(width: 128 * scale, height: 88 * scale)
        }
        .allowsHitTesting(false)
    }

    private var scorchCrater: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.7),
                            NFGTheme.danger.opacity(0.45),
                            Color(red: 0.2, green: 0.08, blue: 0.05).opacity(0.35),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 52 * scale
                    )
                )
                .frame(width: 104 * scale, height: 32 * scale)
                .offset(y: 18 * scale)
            Ellipse()
                .stroke(NFGTheme.danger.opacity(0.35), lineWidth: 1.5)
                .frame(width: 72 * scale, height: 20 * scale)
                .offset(y: 16 * scale)
        }
    }

    private func smokeWisps(phase: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(Color(white: 0.35, opacity: 0.22 + Double(i) * 0.04))
                    .frame(width: (28 + CGFloat(i) * 10) * scale, height: (18 + CGFloat(i) * 6) * scale)
                    .blur(radius: 10 + CGFloat(i) * 2)
                    .offset(
                        x: CGFloat([-20, 12, 28, -8, 0][i]) * scale,
                        y: CGFloat([-28, -34, -22, -40, -48][i]) * scale
                            + CGFloat(sin(phase * 0.9 + Double(i)) * 4) * scale
                    )
                    .opacity(0.35 + sin(phase * 1.2 + Double(i)) * 0.12)
            }
        }
    }

    private func emberField(phase: Double) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow, RocketPalette.ember, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 6
                        )
                    )
                    .frame(width: (4 + CGFloat(i % 3)) * scale, height: (4 + CGFloat(i % 3)) * scale)
                    .offset(
                        x: CGFloat([-24, -10, 6, 20, -18, 14, 26, -2][i]) * scale,
                        y: CGFloat([-6, -12, 4, 8, 10, 14, 2, -4][i]) * scale
                    )
                    .opacity(0.5 + sin(phase * 4 + Double(i) * 0.7) * 0.4)
                    .blur(radius: i % 2 == 0 ? 0 : 1)
            }
        }
    }
}

private enum WreckRenderer {
    static func draw(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let cx = w * 0.5

        drawTwistedFuselage(ctx: &ctx, cx: cx, w: w, h: h)
        drawDetachedNose(ctx: &ctx, w: w, h: h)
        drawBentFins(ctx: &ctx, w: w, h: h)
        drawShrapnel(ctx: &ctx, w: w, h: h)
    }

    private static func drawTwistedFuselage(ctx: inout GraphicsContext, cx: CGFloat, w: CGFloat, h: CGFloat) {
        var hull = Path()
        hull.addRoundedRect(
            in: CGRect(x: cx - 22, y: h * 0.38, width: 48, height: 16),
            cornerSize: CGSize(width: 6, height: 6)
        )
        ctx.fill(
            hull,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.22, green: 0.2, blue: 0.24),
                    Color(red: 0.38, green: 0.36, blue: 0.42),
                    Color(red: 0.15, green: 0.14, blue: 0.16),
                ]),
                startPoint: CGPoint(x: cx - 22, y: h * 0.38),
                endPoint: CGPoint(x: cx + 26, y: h * 0.54)
            )
        )
        ctx.stroke(hull, with: .color(RocketPalette.ember.opacity(0.45)), lineWidth: 2)

        let stripe = CGRect(x: cx - 18, y: h * 0.44, width: 36, height: 5)
        ctx.fill(Path(stripe), with: .color(NFGTheme.accent.opacity(0.35)))
    }

    private static func drawDetachedNose(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        var nose = Path()
        nose.move(to: CGPoint(x: w * 0.18, y: h * 0.22))
        nose.addLine(to: CGPoint(x: w * 0.32, y: h * 0.38))
        nose.addLine(to: CGPoint(x: w * 0.08, y: h * 0.36))
        nose.closeSubpath()
        ctx.fill(
            nose,
            with: .linearGradient(
                Gradient(colors: [RocketPalette.ember, RocketPalette.scorch]),
                startPoint: CGPoint(x: w * 0.18, y: h * 0.2),
                endPoint: CGPoint(x: w * 0.28, y: h * 0.38)
            )
        )
        ctx.stroke(nose, with: .color(.black.opacity(0.4)), lineWidth: 0.8)
    }

    private static func drawBentFins(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let cx = w * 0.5
        var left = Path()
        left.move(to: CGPoint(x: cx - 8, y: h * 0.52))
        left.addLine(to: CGPoint(x: cx - 36, y: h * 0.7))
        left.addLine(to: CGPoint(x: cx - 16, y: h * 0.6))
        left.closeSubpath()
        ctx.fill(left, with: .color(RocketPalette.finDark))
        ctx.stroke(left, with: .color(RocketPalette.ember.opacity(0.35)), lineWidth: 1)

        var right = Path()
        right.move(to: CGPoint(x: cx + 10, y: h * 0.5))
        right.addLine(to: CGPoint(x: cx + 32, y: h * 0.64))
        right.addLine(to: CGPoint(x: cx + 18, y: h * 0.58))
        right.closeSubpath()
        ctx.fill(right, with: .color(RocketPalette.finDark))
        ctx.stroke(right, with: .color(RocketPalette.ember.opacity(0.4)), lineWidth: 1)
    }

    private static func drawShrapnel(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let pieces: [(CGRect, CGFloat)] = [
            (CGRect(x: w * 0.62, y: h * 0.48, width: 18, height: 7), 24),
            (CGRect(x: w * 0.12, y: h * 0.55, width: 12, height: 9), -38),
            (CGRect(x: w * 0.72, y: h * 0.32, width: 8, height: 14), 12),
        ]
        for (rect, _) in pieces {
            let path = Path(roundedRect: rect, cornerRadius: 2, style: .continuous)
            ctx.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [RocketPalette.hullMid, RocketPalette.finDark]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            ctx.stroke(path, with: .color(.black.opacity(0.35)), lineWidth: 0.6)
        }
    }
}

// MARK: - Engine visuals

private struct RocketHullBloom: View {
    var scale: CGFloat
    var exhaustIntensity: CGFloat = 1
    var phase: Double

    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        NFGTheme.accent.opacity(0.22),
                        Color.orange.opacity(0.12),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 8 * scale * exhaustIntensity,
                    endRadius: 38 * scale * exhaustIntensity
                )
            )
            .frame(width: 76 * scale * exhaustIntensity, height: 100 * scale * exhaustIntensity)
            .scaleEffect(1 + CGFloat(sin(phase * 2.8)) * 0.04)
            .blendMode(.plusLighter)
    }
}

private struct RocketEngineGlow: View {
    var scale: CGFloat
    var exhaustIntensity: CGFloat = 1
    var phase: Double

    private var flicker: CGFloat {
        0.88 + CGFloat(sin(phase * 18) * 0.08 + sin(phase * 31) * 0.05)
    }

    private var flame: CGFloat { max(0.42, exhaustIntensity) }

    var body: some View {
        ZStack {
            // Outer exhaust cone
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.5),
                            Color.red.opacity(0.25),
                            .clear,
                        ],
                        center: .top,
                        startRadius: 4 * scale * flame,
                        endRadius: 42 * scale * flame
                    )
                )
                .frame(width: 36 * scale * flame, height: 56 * scale * flame)
                .scaleEffect(x: 1.1, y: flicker * (0.95 + 0.35 * flame))
                .blur(radius: 2)

            // Core plasma
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            .white,
                            Color(red: 0.85, green: 0.95, blue: 1),
                            .yellow,
                            .orange,
                            .clear,
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: 24 * scale * flame
                    )
                )
                .frame(width: 20 * scale * flame, height: 40 * scale * flame)
                .scaleEffect(y: flicker)

            // Shock diamonds
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .stroke(
                        Color.cyan.opacity(0.35 - Double(i) * 0.08),
                        lineWidth: 1.2
                    )
                    .frame(width: (10 - CGFloat(i) * 2) * scale * flame, height: 4 * scale * flame)
                    .offset(y: (10 + CGFloat(i) * 9) * scale * flame)
                    .scaleEffect(x: flicker, y: 1)
            }

            Ellipse()
                .fill(Color.cyan.opacity(0.4))
                .frame(width: 10 * scale * flame, height: 16 * scale * flame)
                .blur(radius: 4)
                .offset(y: 6 * scale * flame)
        }
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




