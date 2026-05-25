import SwiftUI

struct CrashChartView: View {
    let history: [Double]
    let phase: GamePhase
    let multiplier: Double

    @State private var rocketWobble: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = monotonicRisePoints(width: w, height: h)
            let isCrashed = phase == .ended
            let isRunning = phase == .running

            ZStack {
                // Card background
                RoundedRectangle(cornerRadius: NFGRadius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 13 / 255, green: 18 / 255, blue: 25 / 255),
                                Color(red: 5 / 255, green: 7 / 255, blue: 11 / 255),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NFGRadius.lg, style: .continuous)
                            .strokeBorder(NFGTheme.hairlineBorder, lineWidth: 1)
                    )

                // Subtle grid lines
                gridLines(width: w, height: h)

                // Diagonal motion lines (parallax suggestion of speed)
                if isRunning {
                    motionLines(width: w, height: h)
                }

                // Idle / pre-flight hint
                if points.count < 2 {
                    waitingIndicator(width: w, height: h)
                }

                if points.count >= 2 {
                    chartArea(points: points, height: h, isCrashed: isCrashed)
                    chartStroke(points: points, isCrashed: isCrashed)
                    if let last = points.last {
                        rocketHead(at: last, isCrashed: isCrashed, isRunning: isRunning)
                    }
                }

                // Big in-chart multiplier overlay during running / ended phases
                if phase != .betting && phase != .idle {
                    multiplierOverlay
                        .padding(.bottom, h * 0.18)
                        .padding(.trailing, w * 0.06)
                        .frame(width: w, height: h, alignment: .bottomTrailing)
                        .allowsHitTesting(false)
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                rocketWobble = 1
            }
        }
    }

    // MARK: - Drawing

    private func chartArea(points: [CGPoint], height: CGFloat, isCrashed: Bool) -> some View {
        Path { path in
            path.move(to: CGPoint(x: points[0].x, y: height))
            for p in points { path.addLine(to: p) }
            path.addLine(to: CGPoint(x: points.last!.x, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: isCrashed
                    ? [NFGTheme.danger.opacity(0.45), NFGTheme.danger.opacity(0)]
                    : [NFGTheme.accent2.opacity(0.42), NFGTheme.accent2.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func chartStroke(points: [CGPoint], isCrashed: Bool) -> some View {
        Path { path in
            path.move(to: points[0])
            for p in points.dropFirst() { path.addLine(to: p) }
        }
        .stroke(
            isCrashed ? AnyShapeStyle(NFGTheme.crashGradient) : AnyShapeStyle(NFGTheme.accentGradient),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
        .shadow(color: (isCrashed ? NFGTheme.danger : NFGTheme.accent).opacity(0.55), radius: 8)
    }

    @ViewBuilder
    private func rocketHead(at point: CGPoint, isCrashed: Bool, isRunning: Bool) -> some View {
        ZStack {
            Circle()
                .fill((isCrashed ? NFGTheme.danger : NFGTheme.glow).opacity(0.35))
                .frame(width: 26, height: 26)
                .blur(radius: 4)

            if isCrashed {
                Text("💥")
                    .font(.system(size: 22))
                    .scaleEffect(1.05)
            } else {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-32))
                    .padding(6)
                    .background(
                        Circle().fill(NFGTheme.accentGradient)
                    )
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: NFGTheme.accent.opacity(0.7), radius: 8)
                    .scaleEffect(isRunning ? (1.0 + rocketWobble * 0.08) : 1.0)
            }
        }
        .position(point)
    }

    private var multiplierOverlay: some View {
        Text(String(format: "%.2f×", max(1, multiplier)))
            .font(.system(size: 56, weight: .black, design: .monospaced))
            .foregroundStyle(phase == .ended ? NFGTheme.danger : NFGTheme.text)
            .shadow(
                color: (phase == .ended ? NFGTheme.danger : NFGTheme.accent).opacity(0.6),
                radius: 16
            )
            .opacity(0.85)
            .contentTransition(.numericText(value: multiplier))
    }

    private func gridLines(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            ForEach(0..<4) { i in
                let y = h * CGFloat(i + 1) / 5
                Path { path in
                    path.move(to: CGPoint(x: 18, y: y))
                    path.addLine(to: CGPoint(x: w - 18, y: y))
                }
                .stroke(Color.white.opacity(0.04), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
            }
        }
    }

    private func motionLines(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            ForEach(0..<6) { i in
                let progress = (rocketWobble + CGFloat(i) * 0.18).truncatingRemainder(dividingBy: 1)
                let x = w * progress
                Path { path in
                    path.move(to: CGPoint(x: x, y: h * 0.85))
                    path.addLine(to: CGPoint(x: x + 22, y: h * 0.85 - 12))
                }
                .stroke(NFGTheme.accent.opacity(0.15), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    private func waitingIndicator(width w: CGFloat, height h: CGFloat) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "hourglass")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(NFGTheme.accent.opacity(0.65))
            Text(phase == .betting ? "Waiting for round to start…" : "Standing by")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(width: w, height: h)
        .overlay(
            Path { path in
                let y = h - 18
                path.move(to: CGPoint(x: 24, y: y))
                path.addLine(to: CGPoint(x: w - 24, y: y))
            }
            .stroke(NFGTheme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
        )
    }

    /// Crash-game chart: each point uses the max multiplier seen *so far* for scale so the line never dips when the axis rescales.
    private func monotonicRisePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let vals = seriesValues
        guard !vals.isEmpty else { return [] }

        let padX: CGFloat = 24
        let padY: CGFloat = 18
        let innerW = max(1, width - padX * 2)
        let innerH = max(1, height - padY * 2)
        let minMult: Double = 1

        var runningPeak = max(1.12, vals[0])
        var points: [CGPoint] = []

        for (i, v) in vals.enumerated() {
            let value = max(v, minMult)
            runningPeak = max(runningPeak, value)
            let x = padX + innerW * CGFloat(i) / CGFloat(max(vals.count - 1, 1))
            let t = (value - minMult) / (runningPeak - minMult)
            let y = height - padY - innerH * CGFloat(min(max(t, 0), 1))
            points.append(CGPoint(x: x, y: y))
        }

        for i in 1..<points.count {
            if points[i].y > points[i - 1].y {
                points[i].y = points[i - 1].y
            }
        }
        return points
    }

    private var seriesValues: [Double] {
        if phase == .betting || history.isEmpty {
            return [1]
        }
        var out: [Double] = []
        for v in history {
            let clamped = max(v, 1)
            if let last = out.last, clamped < last - 0.0001 { continue }
            out.append(clamped)
        }
        if out.isEmpty { out = [1] }
        return out
    }
}
