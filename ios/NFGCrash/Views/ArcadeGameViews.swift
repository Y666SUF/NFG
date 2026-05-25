import SwiftUI

// MARK: - Vault Tap

struct VaultTapGameView: View {
    let busy: Bool
    let skillLevel: Int
    let maxLevel: Int
    let playsLeft: Int
    let playsPerDay: Int
    var zoneWidth: CGFloat
    @Binding var message: String
    var onFinish: (Int, Int) async -> Void

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
            subtitle: "8 taps — nail the green zone",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: playsLeft > 0,
            busy: busy,
            onStart: { resetRun() },
            onReplay: { resetRun() }
        ) {
            VStack(spacing: 16) {
                ArcadeGameStatusBar(skillLevel: skillLevel, maxLevel: maxLevel, playsLeft: playsLeft, playsPerDay: playsPerDay)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NFGTheme.panel2)
                        .frame(height: 22)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NFGTheme.accent2.opacity(0.35))
                        .frame(width: 56, height: 18)
                        .offset(x: max(0, (280 - 56) * zone.lowerBound))
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, NFGTheme.accent],
                                center: .center,
                                startRadius: 0,
                                endRadius: 14
                            )
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: NFGTheme.accent.opacity(0.8), radius: 8)
                        .offset(x: max(0, (280 - 28) * marker))
                }
                .frame(width: 280)
                .overlay(flash.map { RoundedRectangle(cornerRadius: 10).stroke($0, lineWidth: 2) })

                HStack(spacing: 20) {
                    statPill("Hits", hits, NFGTheme.accent2)
                    statPill("Perfect", perfect, NFGTheme.gold)
                    statPill("Miss", misses, NFGTheme.danger)
                }

                ArcadePrimaryButton(
                    title: running ? "TAP!" : "Submit run",
                    icon: running ? "hand.tap.fill" : "paperplane.fill",
                    tint: ArcadeGameTheme.accent(for: "vault_tap"),
                    disabled: busy || playsLeft <= 0 || phase != .playing
                ) {
                    if running {
                        tapNow()
                    } else {
                        ArcadeLocalHighScore.record(for: "vault_tap", score: sessionScore)
                        Task {
                            await onFinish(hits, perfect)
                        }
                    }
                }

                if !running && phase == .playing {
                    Text("Run complete — submit for points")
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
            phase = .gameOver
            ArcadeSoundFX.play(.gameOver)
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
    let playsLeft: Int
    let playsPerDay: Int
    let vaultHeat: Int
    let vaultStatus: String
    let hintText: String
    let guessesLeft: Int
    let maxGuesses: Int
    let solved: Bool
    let digitLocks: [Bool]
    @Binding var safeGuess: String
    var onGuess: (String) async -> Void

    @State private var dialSpin = false

    var body: some View {
        ArcadeStageCard(gameId: "daily_safe", icon: "🔐", title: "Daily Safe", subtitle: "Crack today's 4-digit vault code") {
            VStack(spacing: 16) {
                ArcadeGameStatusBar(skillLevel: skillLevel, maxLevel: maxLevel, playsLeft: playsLeft, playsPerDay: playsPerDay)

                VaultHeatMeterView(heat: vaultHeat, status: vaultStatus, solved: solved)

                HStack {
                    Label("\(guessesLeft) of \(maxGuesses) tries left", systemImage: "number")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(guessesLeft > 0 ? NFGTheme.accent2 : NFGTheme.danger)
                    Spacer()
                    if solved {
                        Label("Solved today", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(NFGTheme.accent2)
                    }
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

                ZStack {
                    Circle()
                        .stroke(NFGTheme.gold.opacity(0.25), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    Circle()
                        .stroke(NFGTheme.gold, lineWidth: 4)
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(dialSpin ? 360 : 0))
                    Image(systemName: solved ? "lock.open.fill" : "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(solved ? NFGTheme.accent2 : NFGTheme.gold)
                        .symbolEffect(.pulse, options: .repeating)
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
                    title: solved ? "Already solved" : "Unlock",
                    icon: "lock.open.fill",
                    tint: NFGTheme.gold,
                    disabled: busy || safeGuess.count < 4 || solved || guessesLeft <= 0
                ) {
                    ArcadeSoundFX.play(.tap)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { dialSpin.toggle() }
                    Task { await onGuess(safeGuess) }
                }
            }
        }
    }

    private func appendDigit(_ d: String) {
        guard safeGuess.count < 4, !solved else { return }
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
            subtitle: "Match symbols for a payout",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: true,
            busy: busy,
            onStart: { revealed = false; wiggle = true },
            onReplay: { revealed = false; sessionScore = 0; wiggle = true }
        ) {
            VStack(spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(Array((grid.isEmpty ? Array(repeating: "?", count: 9) : grid).enumerated()), id: \.offset) { i, sym in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.25)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .opacity(revealed || !grid.isEmpty ? 0 : 1)
                            Text(sym)
                                .font(.system(size: grid.isEmpty && !revealed ? 22 : 30))
                                .opacity(revealed || !grid.isEmpty ? 1 : 0)
                        }
                        .frame(height: 64)
                        .rotationEffect(.degrees(wiggle && !revealed ? Double((i % 3) - 1) * 2 : 0))
                        .animation(.easeInOut(duration: 0.12), value: wiggle)
                    }
                }

                ArcadePrimaryButton(
                    title: grid.isEmpty ? "Scratch!" : "Reveal again",
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
    @Binding var quizGuess: String
    var onSubmit: (Double) async -> Void

    @State private var needle: CGFloat = 0.3

    var body: some View {
        ArcadeStageCard(gameId: "crash_quiz", icon: "📈", title: "Crash Quiz", subtitle: "Guess where the round will crash") {
            VStack(spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(NFGTheme.panel2)
                        .frame(height: 120)
                    Path { p in
                        p.move(to: CGPoint(x: 12, y: 108))
                        for i in 0..<12 {
                            let x = 12 + CGFloat(i) * 22
                            let y = 108 - CGFloat(i) * 6 - sin(CGFloat(i) * 0.8) * 8
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(NFGTheme.accent2, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    Text("\(quizGuess)×")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.accent2)
                        .frame(maxWidth: .infinity)
                }

                Slider(value: Binding(
                    get: { Double(quizGuess) ?? 1.5 },
                    set: { quizGuess = String(format: "%.2f", $0) }
                ), in: 1.1...8.0, step: 0.05)
                .tint(NFGTheme.accent2)

                ArcadePrimaryButton(title: "Lock in guess", icon: "chart.line.uptrend.xyaxis", tint: NFGTheme.accent2, disabled: busy) {
                    Task { await onSubmit(Double(quizGuess) ?? 2) }
                }
            }
        }
    }
}

// MARK: - Streak Spinner

struct StreakSpinnerGameView: View {
    let busy: Bool
    var streak: Int
    var spunToday: Bool
    var onSpin: () async -> Void

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var winFlash = false

    private var wheelSegments: [VaultStreakWheelSegment] {
        [
            VaultStreakWheelSegment(id: 0, label: "2K", icon: "🪙", colors: [.purple, .indigo]),
            VaultStreakWheelSegment(id: 1, label: "5K", icon: "💵", colors: [.pink, .purple]),
            VaultStreakWheelSegment(id: 2, label: "8K", icon: "✨", colors: [.orange, .pink]),
            VaultStreakWheelSegment(id: 3, label: "10K", icon: "🔥", colors: [.red, .orange]),
            VaultStreakWheelSegment(id: 4, label: "15K", icon: "⚡", colors: [.yellow, .orange]),
            VaultStreakWheelSegment(id: 5, label: "25K", icon: "💎", colors: [.cyan, .blue]),
            VaultStreakWheelSegment(id: 6, label: "50K", icon: "👑", colors: [.mint, .teal]),
            VaultStreakWheelSegment(id: 7, label: "JACKPOT", icon: "🎰", colors: [NFGTheme.gold, .orange]),
            VaultStreakWheelSegment(id: 8, label: "3K", icon: "🎁", colors: [.blue, .purple]),
            VaultStreakWheelSegment(id: 9, label: "6K", icon: "🌟", colors: [.green, .mint]),
            VaultStreakWheelSegment(id: 10, label: "12K", icon: "🚀", colors: [.indigo, .cyan]),
            VaultStreakWheelSegment(id: 11, label: "20K", icon: "🏆", colors: [.yellow, .green]),
        ]
    }

    var body: some View {
        ArcadeStageCard(gameId: "streak_spinner", icon: "🎡", title: "Streak Spinner", subtitle: "Daily spin — streak boosts your loot") {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Label("\(max(0, streak)) day streak", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(spunToday ? "Used today" : "1 spin left")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(spunToday ? NFGTheme.muted : NFGTheme.accent2)
                }
                .padding(.horizontal, 4)

                ZStack {
                    if winFlash {
                        Circle()
                            .stroke(NFGTheme.gold, lineWidth: 3)
                            .frame(width: 280, height: 280)
                            .blur(radius: 2)
                            .opacity(0.8)
                    }
                    VaultStreakWheelView(rotation: rotation, segments: wheelSegments, size: 248)
                }

                Text("Pointer at top wins — prizes scale with login streak")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)

                ArcadePrimaryButton(
                    title: spinning ? "Spinning…" : (spunToday ? "Come back tomorrow" : "SPIN"),
                    icon: "arrow.triangle.2.circlepath",
                    tint: .pink,
                    disabled: busy || spinning || spunToday
                ) {
                    guard !spinning, !spunToday else { return }
                    spinning = true
                    winFlash = false
                    let segmentAngle = 360.0 / Double(wheelSegments.count)
                    let target = Double.random(in: 0..<Double(wheelSegments.count))
                    let align = 270 - (target * segmentAngle + segmentAngle / 2)
                    let extra = Double.random(in: 4...6) * 360
                    withAnimation(.timingCurve(0.12, 0.85, 0.2, 1, duration: 3.2)) {
                        rotation += extra + align - rotation.truncatingRemainder(dividingBy: 360)
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 3_300_000_000)
                        await onSpin()
                        withAnimation(.easeOut(duration: 0.35)) { winFlash = true }
                        spinning = false
                    }
                }
            }
        }
    }
}

// MARK: - Vault Heist

struct VaultHeistGameView: View {
    let busy: Bool
    let skillLevel: Int
    let maxLevel: Int
    let playsLeft: Int
    let playsPerDay: Int
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
            subtitle: "3 steps — avoid the alarm",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: playsLeft > 0,
            busy: busy,
            onStart: {
                Task {
                    await onStart()
                    phase = .playing
                }
            },
            onReplay: {
                Task {
                    await onStart()
                    phase = .playing
                }
            }
        ) {
            VStack(spacing: 16) {
                ArcadeGameStatusBar(skillLevel: skillLevel, maxLevel: maxLevel, playsLeft: playsLeft, playsPerDay: playsPerDay)
                Text(heistStep == 0 ? "Pick a door to begin" : "Step \(heistStep) — pick a door")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.gold)

                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { d in
                        Button {
                            ArcadeSoundFX.play(.tap)
                            Task { await onPickDoor(d) }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: heistStep > 0 ? "door.left.hand.closed" : "lock.fill")
                                    .font(.system(size: 32))
                                Text("Door \(d + 1)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(NFGTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.35), NFGTheme.panel2],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.gold.opacity(0.4)))
                            .offset(x: shakeDoor == d ? 6 : 0)
                        }
                        .buttonStyle(ArcadePressStyle())
                        .disabled(busy || !heistStarted || phase != .playing)
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

// MARK: - Double or Nothing

struct DoubleNothingGameView: View {
    let busy: Bool
    var onRisk: () async -> Void

    @State private var coinAngle: Double = 0
    @State private var flipping = false

    var body: some View {
        ArcadeStageCard(gameId: "double_nothing", icon: "⚡", title: "Double or Nothing", subtitle: "Risk 5,000 fun pts for a double-up") {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [NFGTheme.gold, Color.orange],
                                center: .center,
                                startRadius: 4,
                                endRadius: 70
                            )
                        )
                        .frame(width: 120, height: 120)
                        .rotation3DEffect(.degrees(coinAngle), axis: (x: 0, y: 1, z: 0))
                        .shadow(color: NFGTheme.gold.opacity(0.5), radius: 16)
                    Text("₿")
                        .font(.system(size: 44, weight: .black))
                        .rotation3DEffect(.degrees(coinAngle), axis: (x: 0, y: 1, z: 0))
                }

                Text("5,000 fun pts at stake")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)

                ArcadePrimaryButton(title: flipping ? "Flipping…" : "Risk it!", icon: "bolt.fill", tint: NFGTheme.gold, disabled: busy || flipping) {
                    flipping = true
                    withAnimation(.easeInOut(duration: 0.15).repeatCount(12, autoreverses: true)) {
                        coinAngle += 180
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        await onRisk()
                        flipping = false
                    }
                }
            }
        }
    }
}

// MARK: - Badge Hunt

struct BadgeHuntGameView: View {
    let busy: Bool
    var onFind: (String) async -> Void

    private let huntIds = ["acespades", "chip", "dice", "bullion", "bitcoin", "whale"]

    var body: some View {
        ArcadeStageCard(gameId: "badge_hunt", icon: "🕵️", title: "Badge Hunt", subtitle: "Tap vault badges you've spotted in the app") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(huntIds, id: \.self) { bid in
                    Button {
                        Task { await onFind(bid) }
                    } label: {
                        VStack(spacing: 6) {
                            if let img = VaultBadgeAssets.imageName(for: bid) {
                                Image(img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                            } else {
                                Text("🏅").font(.system(size: 36))
                            }
                            Text(VaultBadgeAssets.label(for: bid))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(NFGTheme.muted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(NFGTheme.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.accent.opacity(0.35)))
                    }
                    .buttonStyle(ArcadePressStyle())
                    .disabled(busy)
                }
            }
        }
    }
}

// MARK: - Duel

struct VaultDuelGameView: View {
    let busy: Bool
    var onDuel: () async -> Void

    @State private var playerBar: CGFloat = 0.3
    @State private var rivalBar: CGFloat = 0.55
    @State private var clashing = false

    var body: some View {
        ArcadeStageCard(gameId: "duel", icon: "⚔️", title: "Vault Duel", subtitle: "Face off for vault glory") {
            VStack(spacing: 18) {
                HStack(alignment: .bottom, spacing: 16) {
                    duelColumn(label: "YOU", value: playerBar, color: NFGTheme.accent2)
                    Text("VS")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(NFGTheme.danger)
                        .scaleEffect(clashing ? 1.15 : 1)
                    duelColumn(label: "RIVAL", value: rivalBar, color: NFGTheme.danger)
                }
                .frame(height: 140)

                ArcadePrimaryButton(title: "Fight!", icon: "flame.fill", tint: NFGTheme.danger, disabled: busy) {
                    clashing = true
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                        playerBar = CGFloat.random(in: 0.55...0.95)
                        rivalBar = CGFloat.random(in: 0.15...0.5)
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await onDuel()
                        clashing = false
                    }
                }
            }
        }
    }

    private func duelColumn(label: String, value: CGFloat, color: Color) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(height: geo.size.height * value)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Arcade Missions

struct ArcadeMissionsGameView: View {
    let busy: Bool
    let missions: [ArcadeMissionInfo]
    var onRefresh: () async -> Void
    var onClaim: (String) async -> Void

    @State private var claimPulse: String?

    var body: some View {
        ArcadeStageCard(gameId: "arcade_missions", icon: "📋", title: "Arcade Missions", subtitle: "Daily goals — progress updates after each game") {
            VStack(spacing: 10) {
                Text("Play other arcade games, then return here to claim.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(displayMissions) { m in
                    let progress = Double(m.progress ?? 0) / Double(max(1, m.goal))
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            missionIcon(m)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(progressCaption(m))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(NFGTheme.muted)
                            }
                            Spacer(minLength: 8)
                            missionAction(m)
                        }
                        ArcadeProgressBar(progress: min(1, progress), tint: m.done == true ? NFGTheme.gold : NFGTheme.accent2)
                    }
                    .padding(12)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(m.done == true && m.claimed != true ? NFGTheme.gold.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .scaleEffect(claimPulse == m.id ? 1.02 : 1)
                }

                ArcadeSecondaryButton(title: busy ? "Refreshing…" : "Refresh progress", icon: "arrow.clockwise") {
                    Task { await onRefresh() }
                }
            }
        }
        .task { await onRefresh() }
    }

    private var displayMissions: [ArcadeMissionInfo] {
        missions.isEmpty ? placeholderMissions : missions
    }

    @ViewBuilder
    private func missionIcon(_ m: ArcadeMissionInfo) -> some View {
        Image(systemName: missionSymbol(m.id))
            .font(.system(size: 18))
            .foregroundStyle(NFGTheme.accent2)
            .frame(width: 32)
    }

    @ViewBuilder
    private func missionAction(_ m: ArcadeMissionInfo) -> some View {
        if m.claimed == true {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(NFGTheme.muted)
        } else if m.done == true {
            Button {
                claimPulse = m.id
                Task {
                    await onClaim(m.id)
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    claimPulse = nil
                }
            } label: {
                Text("Claim")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NFGTheme.gold)
                    .clipShape(Capsule())
            }
            .disabled(busy)
        } else {
            Text("\(Int((Double(m.progress ?? 0) / Double(max(1, m.goal))) * 100))%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.muted)
        }
    }

    private func missionSymbol(_ id: String) -> String {
        switch id {
        case "play_3": return "gamecontroller.fill"
        case "earn_25k": return "banknote.fill"
        case "live_bonus": return "dot.radiowaves.left.and.right"
        default: return "star.fill"
        }
    }

    private func progressCaption(_ m: ArcadeMissionInfo) -> String {
        let p = m.progress ?? 0
        let g = m.goal
        if m.id == "play_3" { return "\(p) / \(g) different games today" }
        if m.id == "earn_25k" { return "\(p.formatted()) / \(g.formatted()) pts earned today" }
        if m.id == "live_bonus" { return p >= 1 ? "Live bonus earned" : "Earn any arcade pts while LIVE" }
        return "\(p.formatted()) / \(g.formatted())"
    }

    private var placeholderMissions: [ArcadeMissionInfo] {
        [
            ArcadeMissionInfo(id: "play_3", title: "Play 3 different games today", goal: 3, progress: 0),
            ArcadeMissionInfo(id: "earn_25k", title: "Earn 25k from arcade today", goal: 25_000, progress: 0),
            ArcadeMissionInfo(id: "live_bonus", title: "Earn while live is on", goal: 1, progress: 0),
        ]
    }
}

// MARK: - Crash Course

struct CrashCourseGameView: View {
    let busy: Bool
    let skillLevel: Int
    let maxLevel: Int
    let playsLeft: Int
    let playsPerDay: Int
    var roundActive: Bool
    var serverCrashAt: Double?
    var onStart: () async -> Void
    var onCashout: (Double) async -> Void

    @State private var phase: ArcadeRunPhase = .intro
    @State private var mult: Double = 1.0
    @State private var timer: Timer?
    @State private var lastCashoutMult: Double = 0

    private var running: Bool { roundActive }
    private var sessionScore: Int { Int(lastCashoutMult * 100) }

    var body: some View {
        ArcadeGameShell(
            gameId: "crash_course",
            title: "Crash Course",
            icon: "🚀",
            subtitle: "Cash out before the hidden bust",
            phase: $phase,
            sessionScore: sessionScore,
            canStart: playsLeft > 0,
            busy: busy,
            onStart: { lastCashoutMult = 0 },
            onReplay: { lastCashoutMult = 0; mult = 1.0 }
        ) {
            VStack(spacing: 16) {
                ArcadeGameStatusBar(skillLevel: skillLevel, maxLevel: maxLevel, playsLeft: playsLeft, playsPerDay: playsPerDay)

                Text(String(format: "%.2f×", mult))
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(running ? NFGTheme.accent2 : NFGTheme.muted)
                    .contentTransition(.numericText())

                if running {
                    Text("Round live — cash out in time!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NFGTheme.accent2)
                } else {
                    Text("Tap Launch to begin")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                }

                RoundedRectangle(cornerRadius: 12)
                    .fill(NFGTheme.panel2)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(running ? NFGTheme.accent2 : NFGTheme.muted)
                            .frame(width: min(280, max(8, 280 * CGFloat((mult - 1) / max(1, (serverCrashAt ?? 3) - 0.8)))))
                    }
                    .frame(width: 280)

                HStack(spacing: 10) {
                    ArcadeSecondaryButton(title: "Launch", icon: "play.fill") {
                        guard !running, phase == .playing else { return }
                        ArcadeSoundFX.play(.start)
                        mult = 1.0
                        Task { await onStart() }
                    }
                    .disabled(busy || playsLeft <= 0 || running || phase != .playing)

                    ArcadePrimaryButton(title: "Cash out", icon: "banknote.fill", tint: NFGTheme.accent2, disabled: busy || !running || phase != .playing) {
                        stopLocalTimer()
                        lastCashoutMult = mult
                        ArcadeLocalHighScore.record(for: "crash_course", score: sessionScore)
                        Task { await onCashout(mult) }
                    }
                }
            }
        }
        .onChange(of: roundActive) { _, active in
            if active {
                phase = .playing
                mult = 1.0
                startLocalTimer()
            } else {
                stopLocalTimer()
                if phase == .playing {
                    phase = .gameOver
                    ArcadeSoundFX.play(lastCashoutMult > 0 ? .success : .fail)
                }
                mult = 1.0
            }
        }
        .onDisappear { stopLocalTimer() }
    }

    private func startLocalTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            mult += Double.random(in: 0.03...0.09)
            if let cap = serverCrashAt, mult > cap + 0.5 { stopLocalTimer() }
        }
    }

    private func stopLocalTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Tycoon

struct VaultTycoonGameView: View {
    let busy: Bool
    var pending: Int
    var level: Int
    var onCollect: () async -> Void
    var onUpgrade: () async -> Void

    @State private var coinsFall = false

    var body: some View {
        ArcadeStageCard(gameId: "tycoon", icon: "🏦", title: "Vault Tycoon", subtitle: "Idle vault — collect & upgrade") {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [NFGTheme.gold.opacity(0.3), NFGTheme.panel2],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 100)
                    VStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(NFGTheme.gold)
                        Text("Level \(max(1, level))")
                            .font(.system(size: 14, weight: .bold))
                    }
                    if coinsFall {
                        ForEach(0..<6, id: \.self) { i in
                            Text("🪙")
                                .offset(y: coinsFall ? 40 : -20)
                                .offset(x: CGFloat(i - 3) * 24)
                                .opacity(coinsFall ? 0 : 1)
                                .animation(.easeIn(duration: 0.8).delay(Double(i) * 0.05), value: coinsFall)
                        }
                    }
                }

                Text("\(pending.formatted()) pts ready")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(NFGTheme.gold)

                ArcadePrimaryButton(title: "Collect", icon: "arrow.down.circle.fill", tint: NFGTheme.gold, disabled: busy) {
                    coinsFall = false
                    withAnimation { coinsFall = true }
                    Task { await onCollect() }
                }
                ArcadeSecondaryButton(title: "Upgrade vault (3K fun)", icon: "arrow.up.circle") {
                    Task { await onUpgrade() }
                }
            }
        }
    }
}

// MARK: - Season Ladder

struct SeasonLadderGameView: View {
    let busy: Bool
    let yourPoints: Int
    let rank: Int?
    let top: [ArcadeLadderRow]
    var weekKey: String
    var totalPlayers: Int
    var onRefresh: () async -> Void

    @State private var shimmer = false

    private var rankLabel: String {
        if let rank { return "#\(rank)" }
        return "—"
    }

    private var weekLabel: String {
        weekKey.isEmpty ? "This week" : "Week \(weekKey)"
    }

    var body: some View {
        ArcadeStageCard(gameId: "season_ladder", icon: "🏆", title: "Season Ladder", subtitle: "Weekly vault race — arcade pts count") {
            VStack(spacing: 12) {
                weekHeader
                statsCard
                zeroPointsHint
                ladderRows
                emptyHint
                refreshButton
            }
        }
        .task { await onRefresh() }
    }

    private var weekHeader: some View {
        HStack {
            Text(weekLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.muted)
            Spacer()
            Text("\(totalPlayers) racers")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NFGTheme.accent2)
        }
    }

    private var statsCard: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your pts")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
                Text(yourPoints.formatted())
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NFGTheme.gold)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Rank")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
                Text(rankLabel)
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NFGTheme.accent2)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [NFGTheme.gold.opacity(shimmer ? 0.2 : 0.08), NFGTheme.panel2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    @ViewBuilder
    private var zeroPointsHint: some View {
        if yourPoints <= 0 {
            Text("Play any arcade game to earn weekly ladder points.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var ladderRows: some View {
        ForEach(Array(top.prefix(10).enumerated()), id: \.offset) { idx, row in
            ladderRow(rank: idx + 1, row: row, highlight: idx == 0)
        }
    }

    @ViewBuilder
    private var emptyHint: some View {
        if top.isEmpty {
            Text("No racers yet — be the first to score this week!")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var refreshButton: some View {
        ArcadePrimaryButton(
            title: busy ? "Updating…" : "Refresh ladder",
            icon: "arrow.clockwise",
            tint: NFGTheme.gold,
            disabled: busy
        ) {
            Task { await onRefresh() }
        }
    }

    private func ladderRow(rank: Int, row: ArcadeLadderRow, highlight: Bool) -> some View {
        HStack(spacing: 10) {
            Text(medal(rank))
                .font(.system(size: 18))
                .frame(width: 28)
            Text(row.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Spacer()
            Text(row.points.formatted())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(row.points > 0 ? NFGTheme.accent2 : NFGTheme.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(NFGTheme.panel2.opacity(highlight ? 1 : 0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func medal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "•"
        }
    }
}
