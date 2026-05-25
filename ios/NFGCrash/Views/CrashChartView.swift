import SwiftUI

struct CrashChartView: View {
    let history: [Double]
    let phase: GamePhase
    let multiplier: Double
    var crashPoint: Double?
    var bettingEndsAt: Int64 = 0
    var onCrashAnimationFinished: (() -> Void)?

    @State private var pulseGlow = false
    @State private var crashPhase: CrashAnimPhase = .none
    @State private var crashProgress: CGFloat = 0
    @State private var frozenMult: Double = 1
    @State private var crashAnimToken = UUID()
    @State private var impactBurstToken = 0
    @State private var impactPoint: CGPoint = .zero

    private enum CrashAnimPhase {
        case none, falling, exploded, wreckage
    }

    var body: some View {
        GeometryReader { geo in
            let liveMult = displayMultiplier
            let yMax = yAxisMax(for: liveMult)
            let layout = FlightLayout(
                width: geo.size.width,
                height: geo.size.height,
                yMax: yMax
            )
            let launch = layout.point(for: 1)
            let rocketPos = rocketScreenPosition(layout: layout, mult: liveMult)
            let rocketAngle = crashPhase == .falling
                ? Angle.degrees(98)
                : layout.flightAngle(for: liveMult)
            let exhaustAngle = rocketAngle.radians + .pi
            let showExhaust = phase == .running && crashPhase == .none

            ZStack {
                chartBackground(phase: visualPhase)

                gridLayer(layout: layout)

                launchPad(at: launch)

                RocketExhaustParticlesView(
                    rocketPosition: rocketPos,
                    exhaustAngleRadians: exhaustAngle,
                    isActive: showExhaust
                )

                if crashPhase == .exploded {
                    RocketImpactParticlesView(
                        position: impactPoint,
                        burstToken: impactBurstToken
                    )
                    CrashExplosionView(intensity: min(1, crashProgress * 1.15), size: 130)
                        .position(impactPoint)
                }

                if crashPhase == .wreckage {
                    CrashRocketWreckageView()
                        .position(impactPoint)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if crashPhase == .none || crashPhase == .falling {
                    CrashRocketView(
                        angle: rocketAngle,
                        scale: phase == .running ? 1.05 : 0.92,
                        thrust: showExhaust,
                        crashed: crashPhase == .falling,
                        impactFlash: crashPhase == .falling && crashProgress > 0.9
                    )
                    .position(rocketPos)
                }

                chartChromeOverlay(width: geo.size.width, height: geo.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: phase == .running ? 1.5 : 2)
            )
            .offset(x: shakeX, y: shakeY)
            .scaleEffect(crashPhase == .exploded && crashProgress > 0.4 ? 1.02 : 1)
            .onChange(of: phase) { old, new in
                handlePhaseChange(old: old, new: new, layout: layout)
            }
            .onAppear {
                pulseGlow = true
                if phase == .ended, crashPhase == .none {
                    handlePhaseChange(old: .running, new: .ended, layout: layout)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: pulseGlow)
    }

    // MARK: - Rocket position

    private var displayMultiplier: Double {
        switch crashPhase {
        case .falling, .exploded, .wreckage:
            return frozenMult
        case .none:
            if phase == .running { return max(multiplier, 1) }
            if phase == .ended { return max(crashPoint ?? multiplier, 1) }
            return 1
        }
    }

    private func rocketScreenPosition(layout: FlightLayout, mult: Double) -> CGPoint {
        let peak = layout.point(for: frozenMult)
        let impact = layout.verticalImpactPoint(for: frozenMult)

        switch crashPhase {
        case .falling:
            let t = easeInQuad(crashProgress)
            return CGPoint(x: peak.x, y: peak.y + (impact.y - peak.y) * t)
        case .exploded, .wreckage:
            return impact
        case .none:
            return layout.point(for: mult)
        }
    }

    private func easeInQuad(_ t: CGFloat) -> CGFloat {
        t * t
    }

    // MARK: - Crash sequence

    private var visualPhase: GamePhase {
        crashPhase == .none ? phase : .running
    }

    private var shakeX: CGFloat {
        guard crashPhase == .exploded else { return 0 }
        return sin(crashProgress * .pi * 12) * 8 * (1 - crashProgress * 0.55)
    }

    private var shakeY: CGFloat {
        guard crashPhase == .exploded else { return 0 }
        return cos(crashProgress * .pi * 10) * 5 * (1 - crashProgress * 0.55)
    }

    private var borderColor: Color {
        if crashPhase == .exploded || crashPhase == .wreckage { return NFGTheme.danger }
        if crashPhase == .falling { return NFGTheme.danger.opacity(0.6) }
        switch phase {
        case .running: return NFGTheme.accent.opacity(0.45)
        case .ended: return NFGTheme.danger.opacity(0.45)
        default: return NFGTheme.border
        }
    }

    private func handlePhaseChange(old: GamePhase, new: GamePhase, layout: FlightLayout) {
        if new == .betting || new == .idle {
            resetCrash()
            return
        }
        guard new == .ended, old == .running || old == .ended, crashPhase == .none else { return }
        beginCrash(layout: layout)
    }

    private func beginCrash(layout: FlightLayout) {
        let token = UUID()
        crashAnimToken = token
        frozenMult = max(crashPoint ?? multiplier, multiplier, 1)
        impactPoint = layout.verticalImpactPoint(for: frozenMult)
        crashProgress = 0
        crashPhase = .falling

        Task { @MainActor in
            withAnimation(.easeIn(duration: 0.85)) {
                crashProgress = 1
            }
            try? await Task.sleep(nanoseconds: 880_000_000)
            guard crashAnimToken == token else { return }

            crashPhase = .exploded
            impactBurstToken += 1
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                crashProgress = 1
            }
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard crashAnimToken == token else { return }

            withAnimation(.easeOut(duration: 0.2)) {
                crashPhase = .wreckage
            }
            crashProgress = 0
            onCrashAnimationFinished?()
        }
    }

    private func resetCrash() {
        crashAnimToken = UUID()
        crashPhase = .none
        crashProgress = 0
        frozenMult = 1
        impactBurstToken = 0
    }

    // MARK: - Chart chrome (status + compact multiplier — never blocks center)

    @ViewBuilder
    private func chartChromeOverlay(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if phase == .betting || phase == .idle {
                chartStatusChip
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
            }

            if showCompactMultiplier {
                compactMultiplierBadge
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
            }
        }
        .allowsHitTesting(false)
    }

    private var chartStatusChip: some View {
        VStack(spacing: 5) {
            Image(systemName: phase == .betting ? "hourglass" : "clock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NFGTheme.accent.opacity(0.7))
            Text(phase == .betting ? "Waiting for round…" : "Standing by")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
            if phase == .betting {
                Text("ENTRY WINDOW")
                    .font(NFGFont.eyebrow(8))
                    .tracking(1.1)
                    .foregroundStyle(NFGTheme.muted.opacity(0.85))
                    .padding(.top, 2)
                bettingCountdownLabel
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NFGTheme.panel.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: NFGRadius.sm, style: .continuous))
    }

    private var bettingCountdownLabel: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let sec = bettingSecondsRemaining(at: timeline.date)
            Text("\(sec)s")
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
                .contentTransition(.numericText())
        }
    }

    private func bettingSecondsRemaining(at date: Date) -> Int {
        let ends = Double(bettingEndsAt)
        guard ends > 0 else { return 0 }
        let msLeft = ends - date.timeIntervalSince1970 * 1000
        return max(0, Int(msLeft / 1000))
    }

    private var showCompactMultiplier: Bool {
        if phase == .betting || phase == .idle { return false }
        if phase == .running { return true }
        if phase == .ended || crashPhase == .falling || crashPhase == .exploded || crashPhase == .wreckage { return true }
        return false
    }

    private var compactMultiplierBadge: some View {
        let value = displayMultiplier
        let crashed = phase == .ended || crashPhase == .falling || crashPhase == .exploded || crashPhase == .wreckage
        return VStack(alignment: .trailing, spacing: 2) {
            if crashed {
                Text("CRASHED AT")
                    .font(NFGFont.eyebrow(8))
                    .foregroundStyle(NFGTheme.danger.opacity(0.85))
            }
            Text(String(format: "%.2f×", max(1, value)))
                .font(.system(size: crashed ? 22 : 20, weight: .black, design: .monospaced))
                .foregroundStyle(crashed ? NFGTheme.danger : NFGTheme.accent2)
                .shadow(color: (crashed ? NFGTheme.danger : NFGTheme.accent).opacity(0.45), radius: 6)
                .contentTransition(.numericText(value: value))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.sm, style: .continuous)
                .fill(NFGTheme.panel.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.sm, style: .continuous)
                .stroke((crashed ? NFGTheme.danger : NFGTheme.accent).opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Chrome

    private func launchPad(at point: CGPoint) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [NFGTheme.accent.opacity(0.45), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 36
                    )
                )
                .frame(width: 72, height: 24)
                .position(x: point.x, y: point.y + 10)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.12))
                .frame(width: 48, height: 8)
                .position(x: point.x, y: point.y + 8)
        }
    }

    @ViewBuilder
    private func gridLayer(layout: FlightLayout) -> some View {
        ForEach(layout.gridTicks, id: \.self) { tick in
            let y = layout.y(for: tick)
            Path { path in
                path.move(to: CGPoint(x: layout.padX, y: y))
                path.addLine(to: CGPoint(x: layout.width - layout.padX, y: y))
            }
            .stroke(NFGTheme.border.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

            Text("\(tickLabel(tick))×")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(NFGTheme.muted.opacity(0.75))
                .frame(width: 34, alignment: .trailing)
                .position(x: layout.width - 17, y: y)
        }
    }

    private func chartBackground(phase: GamePhase) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 16/255, green: 22/255, blue: 34/255),
                        Color(red: 8/255, green: 10/255, blue: 16/255),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                if phase == .running {
                    RadialGradient(
                        colors: [NFGTheme.accent.opacity(0.14), .clear],
                        center: .bottomLeading,
                        startRadius: 0,
                        endRadius: 260
                    )
                } else if crashPhase != .none {
                    RadialGradient(
                        colors: [NFGTheme.danger.opacity(0.4), .clear],
                        center: .bottomLeading,
                        startRadius: 0,
                        endRadius: 280
                    )
                }
            }
    }

    private func yAxisMax(for mult: Double) -> Double {
        max(mult * 1.22, 1.5)
    }

    private func tickLabel(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0f", value) }
        if value >= 2 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }
}

// MARK: - Flight layout

private struct FlightLayout {
    let width: CGFloat
    let height: CGFloat
    let yMax: Double
    let padX: CGFloat = 28
    let padY: CGFloat = 18
    var innerW: CGFloat { max(1, width - padX * 2) }
    var innerH: CGFloat { max(1, height - padY * 2) }
    let gridTicks: [Double]

    /// Straight-down crash: same X as the rocket at crash, Y at chart floor.
    func verticalImpactPoint(for multiplier: Double) -> CGPoint {
        let peak = point(for: multiplier)
        return CGPoint(x: peak.x, y: height - padY)
    }

    init(width: CGFloat, height: CGFloat, yMax: Double) {
        self.width = width
        self.height = height
        self.yMax = yMax
        self.gridTicks = Self.makeGridTicks(yMax: yMax)
    }

    func point(for multiplier: Double) -> CGPoint {
        let m = max(multiplier, 1)
        let denom = max(yMax - 1, 0.12)
        let t = min(max((m - 1) / denom, 0), 1)
        let eased = CGFloat(pow(t, 0.92))
        let x = padX + innerW * (0.08 + 0.84 * eased)
        let y = height - padY - innerH * CGFloat(t)
        return CGPoint(x: x, y: y)
    }

    func flightAngle(for multiplier: Double) -> Angle {
        let m = max(multiplier, 1.01)
        let p0 = point(for: max(1, m - 0.08))
        let p1 = point(for: m)
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        return .radians(atan2(dx, -dy))
    }

    func y(for value: Double) -> CGFloat {
        point(for: value).y
    }

    static func makeGridTicks(yMax: Double) -> [Double] {
        var ticks: [Double] = [1.0]
        let step: Double
        if yMax < 2 { step = 0.2 }
        else if yMax < 4 { step = 0.5 }
        else if yMax < 8 { step = 1.0 }
        else if yMax < 20 { step = 2.0 }
        else { step = 5.0 }
        var v = 1.0 + step
        while v < yMax * 0.92 {
            ticks.append((v * 100).rounded() / 100)
            v += step
        }
        return ticks
    }
}
