import SwiftUI

struct CrashChartView: View {
    let history: [Double]
    let phase: GamePhase
    let multiplier: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = monotonicRisePoints(width: w, height: h)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
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
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border, lineWidth: 1))

                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(
                        NFGTheme.lineGradient,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: NFGTheme.accent.opacity(0.35), radius: 4)

                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        for p in points { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(NFGTheme.chartFill)

                    if let last = points.last {
                        Circle()
                            .fill(Color(red: 94 / 255, green: 234 / 255, blue: 212 / 255))
                            .frame(width: 10, height: 10)
                            .position(last)
                            .shadow(color: NFGTheme.accent2, radius: 6)
                    }
                } else {
                    // Waiting / betting: flat baseline at 1×
                    Path { path in
                        let y = h - 16
                        path.move(to: CGPoint(x: 24, y: y))
                        path.addLine(to: CGPoint(x: w - 24, y: y))
                    }
                    .stroke(NFGTheme.border, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
        .aspectRatio(2, contentMode: .fit)
    }

    /// Crash-game chart: each point uses the max multiplier seen *so far* for scale so the line never dips when the axis rescales.
    private func monotonicRisePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let vals = seriesValues
        guard !vals.isEmpty else { return [] }

        let padX: CGFloat = 24
        let padY: CGFloat = 16
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

        // Enforce screen-space rise only (smaller y = higher on screen).
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
