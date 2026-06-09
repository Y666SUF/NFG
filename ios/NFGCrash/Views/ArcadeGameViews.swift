import SwiftUI

// MARK: - Vault Tap

struct VaultTapGameView: View {
    let busy: Bool
    let skillLevel: Int
    let maxLevel: Int
    let suggestedStake: Int
    let balance: Int
    var zoneWidth: CGFloat
    var runActive: Bool
    @Binding var message: String
    var onStartRun: () async -> Void
    var onFinish: (Int, Int, Int) async -> Void

    @State private var phase: ArcadeRunPhase = .intro
    @State private var marker: CGFloat = 0.12
    @State private var direction: CGFloat = 1
    @State private var hits = 0
    @State private var misses = 0
    @State private var perfect = 0
    @State private var flash: Color?
    @State private var running = false

    private var sessionScore: Int { hits * 10 + perfect * 25 - misses * 5 }

    private var zone: ClosedRange<CGFloat> {
        let half = max(0.06, zoneWidth / 2)
        let mid: CGFloat = 0.5
        return (mid - half)...(mid + half)
    }

    var body: some View {
        ArcadeGameShell(
            gameId: "vault_tap",
            title: "Vault Tap",
            icon: "🎯",
            subtitle: "Stake pts — 8 taps in the zone or lose",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: balance >= suggestedStake && !runActive && !running,
            busy: busy,
            onStart: {
                Task {
                    resetRun()
                    await onStartRun()
                    if !runActive {
                        running = false
                        phase = .intro
                        message = "Could not start run — check balance or connection."
                    }
                }
            },
            onReplay: {
                Task {
                    resetRun()
                    await onStartRun()
                    if !runActive {
                        running = false
                        phase = .intro
                        message = "Could not start run — check balance or connection."
                    }
                }
            }
        ) {
            VStack(spacing: 16) {
                ArcadeRiskBar(skillLevel: skillLevel, maxLevel: maxLevel, suggestedStake: suggestedStake, balance: balance)
                VaultTapArenaView(zoneWidth: zoneWidth, marker: marker, flash: flash)
                    .frame(maxWidth: 320)

                HStack(spacing: 20) {
                    statPill("Hits", hits, NFGTheme.accent2)
                    statPill("Perfect", perfect, NFGTheme.gold)
                    statPill("Miss", misses, NFGTheme.danger)
                }

                ArcadePrimaryButton(
                    title: running ? "TAP!" : "Submit run",
                    icon: running ? "hand.tap.fill" : "paperplane.fill",
                    tint: ArcadeGameTheme.accent(for: "vault_tap"),
                    disabled: busy || phase != .playing || !running
                ) {
                    if running {
                        tapNow()
                    } else {
                        ArcadeLocalHighScore.record(for: "vault_tap", score: sessionScore)
                        Task {
                            await onFinish(hits, misses, perfect)
                            phase = .gameOver
                        }
                    }
                }

                if running && phase == .playing {
                    Text("Hit the green zone 8 times — \(max(0, 8 - hits - misses)) taps left")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                } else if !running && phase == .playing {
                    Text("Submit run to settle your stake")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            guard running, phase == .playing else { return }
            marker += direction * 0.014
            if marker >= 0.96 { direction = -1 }
            if marker <= 0.04 { direction = 1 }
        }
    }

    private func resetRun() {
        marker = 0.12
        direction = 1
        hits = 0
        misses = 0
        perfect = 0
        flash = nil
        running = true
        message = "Tap in the green zone!"
    }

    private func tapNow() {
        ArcadeSoundFX.play(.tap)
        if zone.contains(marker) {
            hits += 1
            if abs(marker - 0.5) < 0.04 { perfect += 1 }
            flash = NFGTheme.accent2
            message = "Perfect hit!"
            ArcadeSoundFX.play(.success)
        } else {
            misses += 1
            flash = NFGTheme.danger
            message = "Missed the zone"
            ArcadeSoundFX.play(.fail)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { flash = nil }
        if hits + misses >= 8 {
            running = false
            let finalHits = hits
            let finalMisses = misses
            let finalPerfect = perfect
            Task {
                await onFinish(finalHits, finalMisses, finalPerfect)
                phase = .gameOver
                ArcadeSoundFX.play(.gameOver)
            }
        }
    }

    private func statPill(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
        }
    }
}

// MARK: - Daily Safe

struct DailySafeGameView: View {
    let busy: Bool
    let skillLevel: Int
    let maxLevel: Int
    let suggestedStake: Int
    let balance: Int
    let sessionActive: Bool
    let vaultHeat: Int
    let vaultStatus: String
    let hintText: String
    let guessesLeft: Int
    let maxGuesses: Int
    let solved: Bool
    let digitLocks: [Bool]
    @Binding var safeGuess: String
    var onStartSafe: () async -> Void
    var onGuess: (String) async -> Void

    @State private var dialSpin = false

    var body: some View {
        ArcadeStageCard(gameId: "daily_safe", icon: "🔐", title: "Daily Safe", subtitle: "Pay entry — crack the code or lose") {
            VStack(spacing: 16) {
                ArcadeRiskBar(skillLevel: skillLevel, maxLevel: maxLevel, suggestedStake: suggestedStake, balance: balance)

                if !sessionActive {
                    ArcadePrimaryButton(
                        title: "Open safe (\(suggestedStake.formatted()) pts)",
                        icon: "lock.open.fill",
                        tint: NFGTheme.gold,
                        disabled: busy || balance < suggestedStake
                    ) {
                        Task { await onStartSafe() }
                    }
                } else {
                    VaultSafeHeroView(heat: vaultHeat, solved: solved)
                    VaultHeatMeterView(heat: vaultHeat, status: vaultStatus, solved: solved)

                    HStack {
                        Label("\(guessesLeft) of \(maxGuesses) tries left", systemImage: "number")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(guessesLeft > 0 ? NFGTheme.accent2 : NFGTheme.danger)
                        Spacer()
                    }

                    if !hintText.isEmpty {
                        Text(hintText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NFGTheme.muted)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(NFGTheme.panel2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { i in
                            let ch = safeGuess.count > i ? String(safeGuess[safeGuess.index(safeGuess.startIndex, offsetBy: i)]) : "•"
                            let locked = digitLocks.count > i && digitLocks[i]
                            Text(ch)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .frame(width: 52, height: 58)
                                .background(locked ? NFGTheme.accent2.opacity(0.2) : NFGTheme.panel2)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(locked ? NFGTheme.accent2 : NFGTheme.gold.opacity(0.4), lineWidth: locked ? 2 : 1)
                                )
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(1...9, id: \.self) { n in
                            digitButton("\(n)") { appendDigit("\(n)") }
                        }
                        digitButton("⌫", danger: true) { safeGuess = String(safeGuess.dropLast()) }
                        digitButton("0") { appendDigit("0") }
                        Color.clear.frame(height: 48)
                    }

                    ArcadePrimaryButton(
                        title: "Unlock",
                        icon: "lock.open.fill",
                        tint: NFGTheme.gold,
                        disabled: busy || safeGuess.count < 4 || guessesLeft <= 0
                    ) {
                        ArcadeSoundFX.play(.tap)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { dialSpin.toggle() }
                        Task { await onGuess(safeGuess) }
                    }
                }
            }
        }
    }

    private func appendDigit(_ d: String) {
        guard safeGuess.count < 4, sessionActive else { return }
        safeGuess += d
        ArcadeSoundFX.play(.tap)
    }

    private func digitButton(_ label: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(danger ? NFGTheme.danger.opacity(0.2) : NFGTheme.panel2)
                .foregroundStyle(danger ? NFGTheme.danger : NFGTheme.text)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(ArcadePressStyle())
    }
}

// MARK: - Scratch

struct ScratchCardGameView: View {
    let busy: Bool
    let suggestedStake: Int
    let balance: Int
    let grid: [String]
    var onReveal: () async -> Void

    @State private var phase: ArcadeRunPhase = .intro
    @State private var revealed = false
    @State private var wiggle = false
    @State private var sessionScore = 0

    var body: some View {
        ArcadeGameShell(
            gameId: "scratch",
            title: "Scratch Card",
            icon: "🎫",
            subtitle: "Buy a card — match 3 or lose stake",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: balance >= suggestedStake,
            busy: busy,
            onStart: { revealed = false; wiggle = true },
            onReplay: { revealed = false; sessionScore = 0; wiggle = true }
        ) {
            VStack(spacing: 14) {
                ArcadeRiskBar(skillLevel: 1, maxLevel: 10, suggestedStake: suggestedStake, balance: balance)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Array((grid.isEmpty ? Array(repeating: "?", count: 9) : grid).enumerated()), id: \.offset) { i, sym in
                        ScratchHoloCell(symbol: sym, revealed: revealed || !grid.isEmpty, index: i)
                            .rotationEffect(.degrees(wiggle && !revealed && grid.isEmpty ? Double((i % 3) - 1) * 2 : 0))
                            .animation(.easeInOut(duration: 0.12), value: wiggle)
                    }
                }

                ArcadePrimaryButton(
                    title: "Buy & scratch (\(suggestedStake.formatted()) pts)",
                    icon: "sparkles",
                    tint: ArcadeGameTheme.accent(for: "scratch"),
                    disabled: busy || phase != .playing
                ) {
                    ArcadeSoundFX.play(.tap)
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                        revealed = true
                    }
                    Task {
                        await onReveal()
                        sessionScore = scoreFromGrid(grid)
                        ArcadeLocalHighScore.record(for: "scratch", score: sessionScore)
                        phase = .gameOver
                        ArcadeSoundFX.play(sessionScore > 0 ? .success : .fail)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true)) {
                wiggle = true
            }
        }
        .onChange(of: grid) { _, newGrid in
            revealed = true
            sessionScore = scoreFromGrid(newGrid)
            if phase == .playing {
                phase = .gameOver
            }
        }
    }

    private func scoreFromGrid(_ symbols: [String]) -> Int {
        guard symbols.count >= 3 else { return 0 }
        var counts: [String: Int] = [:]
        for s in symbols { counts[s, default: 0] += 1 }
        let best = counts.values.max() ?? 0
        return best * 500
    }
}

// MARK: - Crash Quiz

struct CrashQuizGameView: View {
    let busy: Bool
    let suggestedStake: Int
    let balance: Int
    @Binding var quizGuess: String
    var onSubmit: (Double) async -> Void

    var body: some View {
        ArcadeStageCard(gameId: "crash_quiz", icon: "📈", title: "Crash Quiz", subtitle: "Wager pts — wrong guess loses stake") {
            VStack(spacing: 16) {
                ArcadeRiskBar(skillLevel: 1, maxLevel: 10, suggestedStake: suggestedStake, balance: balance)
                CrashQuizArenaView(guess: Double(quizGuess) ?? 2)

                Slider(value: Binding(
                    get: { Double(quizGuess) ?? 1.5 },
                    set: { quizGuess = String(format: "%.2f", $0) }
                ), in: 1.1...8.0, step: 0.05)
                .tint(NFGTheme.accent2)

                ArcadePrimaryButton(
                    title: "Wager \(suggestedStake.formatted()) pts",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: NFGTheme.accent2,
                    disabled: busy || balance < suggestedStake
                ) {
                    Task { await onSubmit(Double(quizGuess) ?? 2) }
                }
            }
        }
    }
}

// MARK: - Vault Wheel

struct VaultWheelGameView: View {
    let busy: Bool
    let cooldownSecondsLeft: Int
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    var playVisual: ArcadePlayVisual?
    /// Server spin first; returns segment index, label, multiplier, and whether it was a winning segment.
    var onSpin: () async -> (index: Int, label: String, mult: Double, won: Bool)

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var winFlash = false
    @State private var showOutcome = false
    @State private var outcomeGen = 0
    @State private var landedSegmentLabel: String?
    @State private var landedSegmentMult: Double?

    private var wheelSegments: [VaultStreakWheelSegment] {
        ArcadeWheelLayout.vaultStreakSegments()
    }

    var body: some View {
        ArcadeStageCard(gameId: "nfg_wheel", icon: "🎡", title: "Vault Wheel", subtitle: "Spin your stake — LOSE is on the wheel") {
            VStack(spacing: 16) {
                ArcadeHowToPlayCard(gameId: "nfg_wheel")
                ArcadeStakeControl(
                    stake: $stake,
                    minStake: minStake,
                    maxStake: maxStake,
                    balance: balance,
                    suggestedStake: suggestedStake,
                    payoutMultiplier: 5 * arcadePayoutFactor,
                    payoutLabel: "Jackpot up to",
                    disabled: busy || spinning
                )

                ZStack {
                    if winFlash {
                        Circle()
                            .stroke(NFGTheme.gold, lineWidth: 3)
                            .frame(width: 280, height: 280)
                            .blur(radius: 2)
                            .opacity(0.8)
                    }
                    VaultStreakWheelView(rotation: rotation, segments: wheelSegments, size: 290)

                    if let landedSegmentLabel, let landedSegmentMult {
                        VStack(spacing: 2) {
                            Text("Landed: \(landedSegmentLabel)")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(NFGTheme.gold)
                            Text(landedSegmentMult == 0 ? "No payout" : "×\(String(format: "%.1f", landedSegmentMult))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NFGTheme.text)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.65))
                        .clipShape(Capsule())
                        .offset(y: 118)
                    }
                }

                ArcadeDelayedOutcomeStrip(visual: playVisual, show: showOutcome)

                VStack(alignment: .leading, spacing: 6) {
                    Text("What each color does")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(NFGTheme.text)
                    ForEach(wheelSegments) { seg in
                        HStack(spacing: 8) {
                            Image(systemName: seg.systemImage)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle().fill(
                                        LinearGradient(
                                            colors: seg.colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                )
                            Text(seg.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(NFGTheme.text)
                            Text(wheelChance(for: seg))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(seg.mult >= 3 ? NFGTheme.danger.opacity(0.9) : NFGTheme.muted)
                            Spacer(minLength: 8)
                            Text(payoutExplanation(for: seg, stake: stake))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NFGTheme.muted)
                        }
                    }
                }
                .padding(10)
                .background(NFGTheme.panel.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Higher multipliers land less often. House edge ~4%.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)

                ArcadePrimaryButton(
                    title: spinning
                        ? "Spinning…"
                        : arcadeCooldownTitle("Spin (\(stake.formatted()) pts)", cooldownSecondsLeft: cooldownSecondsLeft),
                    icon: "arrow.triangle.2.circlepath",
                    tint: .pink,
                    disabled: arcadeStakeBlocked(
                        busy: busy,
                        cooldownSecondsLeft: cooldownSecondsLeft,
                        balance: balance,
                        stake: stake,
                        minStake: minStake,
                        extra: spinning
                    )
                ) {
                    guard !spinning else { return }
                    spinning = true
                    winFlash = false
                    landedSegmentLabel = nil
                    landedSegmentMult = nil
                    Task {
                        outcomeGen = ArcadePlayReveal.schedule(gameId: "nfg_wheel", generation: outcomeGen, hide: {
                            showOutcome = false
                        }, show: { token in
                            guard token == outcomeGen else { return }
                            showOutcome = true
                        })
                        let spin = await onSpin()
                        landedSegmentLabel = spin.label
                        landedSegmentMult = spin.mult
                        let extra = Double.random(in: 4...6)
                        let targetRotation = ArcadeWheelLayout.rotationToLand(
                            segmentIndex: spin.index,
                            currentRotation: rotation,
                            extraFullSpins: extra
                        )
                        withAnimation(.timingCurve(0.12, 0.85, 0.2, 1, duration: 3.0)) {
                            rotation = targetRotation
                        }
                        try? await Task.sleep(nanoseconds: 3_100_000_000)
                        if spin.won {
                            withAnimation(.easeOut(duration: 0.35)) { winFlash = true }
                        }
                        spinning = false
                    }
                }
            }
        }
    }

    private func wheelChance(for seg: VaultStreakWheelSegment) -> String {
        switch seg.mult {
        case 0: return "56%"
        case 0.5: return "26%"
        case 1.5: return "11%"
        case 2: return "5%"
        case 3: return "1.5%"
        case 5: return "0.5%"
        default: return "—"
        }
    }

    private func payoutExplanation(for seg: VaultStreakWheelSegment, stake: Int) -> String {
        let pay = Int(Double(stake) * seg.mult * 0.96)
        if seg.mult == 0 { return "lose \(stake.formatted()) pts" }
        if seg.mult == 0.5 { return "get \(pay.formatted()) pts back" }
        return "pays \(pay.formatted()) pts"
    }
}

// MARK: - Vault Heist

struct VaultHeistGameView: View {
    let busy: Bool
    let skillLevel: Int
    let maxLevel: Int
    let suggestedStake: Int
    let balance: Int
    var heistStarted: Bool
    var heistStep: Int
    var onStart: () async -> Void
    var onPickDoor: (Int) async -> Void

    @State private var phase: ArcadeRunPhase = .intro
    @State private var shakeDoor: Int?

    private var sessionScore: Int { heistStep * 250 }

    var body: some View {
        ArcadeGameShell(
            gameId: "vault_heist",
            title: "Vault Heist",
            icon: "🚪",
            subtitle: "Stake a heist — wrong door loses all",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: balance >= suggestedStake && !heistStarted,
            busy: busy,
            onStart: {
                Task {
                    await onStart()
                    if heistStarted {
                        phase = .playing
                    } else {
                        phase = .intro
                    }
                }
            },
            onReplay: {
                Task {
                    await onStart()
                    if heistStarted {
                        phase = .playing
                    } else {
                        phase = .intro
                    }
                }
            }
        ) {
            VStack(spacing: 16) {
                ArcadeRiskBar(skillLevel: skillLevel, maxLevel: maxLevel, suggestedStake: suggestedStake, balance: balance)
                Text(heistStep == 0 ? "Pick a door to begin" : "Step \(heistStep) — pick a door")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.gold)

                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { d in
                        VaultHeistDoorView(
                            index: d,
                            isShaking: shakeDoor == d,
                            enabled: !busy && heistStarted && phase == .playing
                        ) {
                            ArcadeSoundFX.play(.tap)
                            withAnimation(.default.repeatCount(3, autoreverses: true)) {
                                shakeDoor = d
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { shakeDoor = nil }
                            Task { await onPickDoor(d) }
                        }
                    }
                }
            }
        }
        .onChange(of: heistStarted) { was, started in
            if started {
                phase = .playing
            } else if was && phase == .playing {
                ArcadeLocalHighScore.record(for: "vault_heist", score: sessionScore)
                phase = .gameOver
                ArcadeSoundFX.play(heistStep >= 3 ? .gameOver : .fail)
            }
        }
        .onChange(of: heistStep) { _, step in
            if step >= 3, heistStarted {
                ArcadeLocalHighScore.record(for: "vault_heist", score: sessionScore)
                phase = .gameOver
                ArcadeSoundFX.play(.success)
            }
        }
    }
}
