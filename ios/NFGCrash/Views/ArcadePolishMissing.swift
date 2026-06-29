import SwiftUI

let arcadePayoutFactor: Double = 1.0

func arcadeCooldownTitle(_ title: String, cooldownSecondsLeft: Int) -> String {
    cooldownSecondsLeft > 0 ? "Wait \(cooldownSecondsLeft)s" : title
}

func arcadeStakeBlocked(busy: Bool, cooldownSecondsLeft: Int, balance: Int, stake: Int, minStake: Int, extra: Bool = false) -> Bool {
    busy || cooldownSecondsLeft > 0 || balance < stake || stake < minStake || extra
}

enum ArcadeGameArt {
    struct Style { var glow: Color }

    static func normalizedId(_ gameId: String) -> String {
        ArcadeBundledCatalog.normalizeGameId(gameId)
    }

    static func style(for gameId: String) -> Style {
        Style(glow: ArcadeGameTheme.accent(for: gameId))
    }

    static func icon(for gameId: String) -> String {
        let gid = normalizedId(gameId)
        if let g = ArcadeBundledCatalog.games.first(where: { ArcadeBundledCatalog.normalizeGameId($0.id) == gid }) {
            return g.icon
        }
        return "🎮"
    }
}

struct ArcadeGameArtBadge: View {
    let gameId: String
    var size: CGFloat = 48
    var showGlow: Bool = false

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }
    private var usesSkillIcon: Bool {
        ["nfg_blocks", "nfg_snake_jump", "nfg_vault_run"].contains(gid)
    }

    var body: some View {
        ZStack {
            if showGlow, !usesSkillIcon {
                Circle()
                    .fill(ArcadeGameTheme.accent(for: gameId).opacity(0.35))
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: 10)
            }
            if usesSkillIcon {
                ArcadeSkillGameIcon(gameId: gid, size: size)
            } else {
                Text(ArcadeGameArt.icon(for: gameId))
                    .font(.system(size: size * 0.52))
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .fill(ArcadeGameTheme.gradient(for: gameId).opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .stroke(ArcadeGameTheme.accent(for: gameId).opacity(0.55), lineWidth: 1)
                    )
            }
        }
    }
}

struct ArcadeCinematicBackdrop: View {
    let gameId: String
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(ArcadeGameTheme.gradient(for: gameId).opacity(0.28))
            .overlay(
                LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            )
    }
}

/// How-to-play copy for arcade games.
enum ArcadeGameGuide {
    static func steps(for gameId: String) -> [String] {
        switch ArcadeGameArt.normalizedId(gameId) {
        case "nfg_vault_run":
            return [
                "NFG Rush — Temple Run-style 3-lane casino sprint with milestone pts.",
                "Tap Play, then swipe left/right to switch lanes on the felt runway.",
                "Swipe up to jump over low card rows · swipe down to slide under table arches.",
                "Red BUST slot machines block lanes — steer around them or it's game over.",
                "Every 400m earns Crash pts — 3,000 at first jackpot, scaling up the farther you run.",
                "Speed ramps as you run — your best distance saves to the leaderboard.",
                "Tap Shop for runner outfits — vest colors and chip trails show in-game.",
            ]
        default:
            return ["Spend points, play the round, win or lose virtual balance."]
        }
    }
}

struct ArcadeHowToPlayCard: View {
    let gameId: String
    var body: some View {
        let steps = ArcadeGameGuide.steps(for: gameId)
        if steps.count <= 1 {
            Text("Stake fun points — outcomes sync with the Vault Arcade server.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(NFGTheme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("How to play", systemImage: "questionmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(NFGTheme.accent2)

                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(NFGTheme.gold)
                            .frame(width: 16, alignment: .trailing)
                        Text(step)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NFGTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NFGTheme.panel.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NFGTheme.border.opacity(0.6), lineWidth: 1)
            )
        }
    }
}

struct ArcadeStakeControl: View {
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let balance: Int
    let suggestedStake: Int
    var payoutMultiplier: Double = 2
    var payoutLabel: String = "Payout up to"
    var disabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stake")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("Balance \(balance.formatted())")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
            }
            Stepper(value: $stake, in: minStake...max(maxStake, minStake), step: max(50, minStake)) {
                Text("\(stake.formatted()) pts")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .disabled(disabled)
            Text("\(payoutLabel) ×\(String(format: "%.1f", payoutMultiplier))")
                .font(.system(size: 10))
                .foregroundStyle(NFGTheme.muted)
            Button("Use suggested (\(suggestedStake.formatted()))") { stake = suggestedStake }
                .font(.system(size: 10, weight: .semibold))
                .disabled(disabled)
        }
        .foregroundStyle(NFGTheme.text)
        .padding(12)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

enum ArcadeWheelLayout {
    struct Segment { let label: String; let mult: Double }

    static let segments: [Segment] = [
        .init(label: "LOSE", mult: 0),
        .init(label: "×1.5", mult: 1.5),
        .init(label: "×2", mult: 2),
        .init(label: "×3", mult: 3),
        .init(label: "×5", mult: 5),
    ]

    static func vaultStreakSegments() -> [VaultStreakWheelSegment] {
        let defs: [(String, Double, String, [Color])] = [
            ("LOSE", 0, "xmark", [.gray, .black]),
            ("×1.5", 1.5, "star.fill", [.blue, .cyan]),
            ("×2", 2, "sparkles", [.purple, .pink]),
            ("×3", 3, "flame.fill", [.orange, .red]),
            ("×5", 5, "crown.fill", [NFGTheme.gold, .orange]),
        ]
        return defs.enumerated().map { i, d in
            VaultStreakWheelSegment(id: i, label: d.0, mult: d.1, systemImage: d.2, colors: d.3)
        }
    }

    static func rotationToLand(segmentIndex: Int, currentRotation: Double, extraFullSpins: Double) -> Double {
        let count = max(vaultStreakSegments().count, 1)
        let step = 360.0 / Double(count)
        let target = Double(segmentIndex) * step + step / 2
        return currentRotation + extraFullSpins * 360 + (360 - (currentRotation.truncatingRemainder(dividingBy: 360)) + target).truncatingRemainder(dividingBy: 360)
    }
}

enum ArcadePlayReveal {
    static func delay(for gameId: String) -> TimeInterval {
        switch ArcadeGameArt.normalizedId(gameId) {
        case "nfg_wheel", "nfg_plinko", "nfg_mines", "nfg_hilo": return 0.35
        default: return 0
        }
    }

    @discardableResult
    static func schedule(gameId: String, generation: Int, hide: () -> Void, show: @escaping (Int) -> Void) -> Int {
        hide()
        let next = generation + 1
        let token = next
        DispatchQueue.main.asyncAfter(deadline: .now() + delay(for: gameId)) {
            show(token)
        }
        return next
    }
}

// MARK: - Lightweight arena widgets

struct VaultTapArenaView: View {
    var zoneWidth: CGFloat
    var marker: CGFloat
    var flash: Color?
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(NFGTheme.panel2)
                Capsule().fill(NFGTheme.accent2.opacity(0.35))
                    .frame(width: max(12, w * zoneWidth))
                    .offset(x: w * marker - max(12, w * zoneWidth) / 2)
                if let flash {
                    Circle().fill(flash).frame(width: 10, height: 10)
                        .offset(x: w * marker)
                }
            }
        }
        .frame(height: 18)
    }
}


struct ScratchHoloCell: View {
    let symbol: String
    var revealed: Bool = false
    var index: Int = 0
    var body: some View {
        Text(revealed ? symbol : "?")
            .font(.system(size: 22, weight: .heavy))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(NFGTheme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CrashQuizArenaView: View {
    var guess: Double = 2
    var body: some View {
        RoundedRectangle(cornerRadius: 12).fill(NFGTheme.panel2).frame(height: 80)
            .overlay(Text(String(format: "%.2fx", guess)).font(.title3.weight(.heavy)).foregroundStyle(NFGTheme.gold))
    }
}

// MARK: - Dedicated game shells (server-driven outcomes)

private struct ArcadeStakePlayShell<Actions: View>: View {
    let gameId: String
    let title: String
    let icon: String
    let busy: Bool
    let cooldownSecondsLeft: Int
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    var playVisual: ArcadePlayVisual?
    var inPlaySession: Bool = false
    var lockedStake: Int?
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        Group {
            if inPlaySession {
                VStack(spacing: 14) {
                    if let lockedStake {
                        ArcadeLockedStakeChip(stake: lockedStake)
                    }
                    if let playVisual {
                        ArcadeDelayedOutcomeStrip(visual: playVisual, show: true)
                    }
                    actions()
                }
            } else {
                ArcadeStageCard(gameId: gameId, icon: icon, title: title, subtitle: "Set stake in lobby · open game to play") {
                    EmptyView()
                }
            }
        }
    }
}

/// Lobby card for staked arcade games — stake picker + open full-screen table.
struct ArcadeStakedGameLobbyCard<Extra: View>: View {
    let gameId: String
    let title: String
    let icon: String
    let busy: Bool
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    var openDisabled: Bool = false
    var openTitle: String = "Open game"
    var onOpen: () -> Void
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.system(size: 44))
                Text(title.uppercased())
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ArcadeGameTheme.accent(for: gameId), .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            ArcadeHowToPlayCard(gameId: gameId)

            extra()

            ArcadeStakeControl(
                stake: $stake,
                minStake: minStake,
                maxStake: maxStake,
                balance: balance,
                suggestedStake: suggestedStake,
                disabled: busy
            )

            ArcadePrimaryButton(
                title: openTitle,
                icon: "play.rectangle.fill",
                tint: ArcadeGameTheme.accent(for: gameId),
                disabled: openDisabled || arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: 0, balance: balance, stake: stake, minStake: minStake)
            ) {
                onOpen()
            }
        }
        .padding(16)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ArcadeGameTheme.accent(for: gameId).opacity(0.3), lineWidth: 1)
        )
    }
}

extension ArcadeStakedGameLobbyCard where Extra == EmptyView {
    init(
        gameId: String,
        title: String,
        icon: String,
        busy: Bool,
        stake: Binding<Int>,
        minStake: Int,
        maxStake: Int,
        suggestedStake: Int,
        balance: Int,
        openDisabled: Bool = false,
        openTitle: String = "Open game",
        onOpen: @escaping () -> Void
    ) {
        self.gameId = gameId
        self.title = title
        self.icon = icon
        self.busy = busy
        _stake = stake
        self.minStake = minStake
        self.maxStake = maxStake
        self.suggestedStake = suggestedStake
        self.balance = balance
        self.openDisabled = openDisabled
        self.openTitle = openTitle
        self.onOpen = onOpen
        self.extra = { EmptyView() }
    }
}

struct NFGDiceGameView: View {
    let busy: Bool
    let cooldownSecondsLeft: Int
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    let lastRoll: Double?
    var playVisual: ArcadePlayVisual?
    var inPlaySession: Bool = false
    var lockedStake: Int?
    var onPlay: (String, Double) async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_dice", title: "Roll Line", icon: "🎯", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual, inPlaySession: inPlaySession, lockedStake: lockedStake ?? (inPlaySession ? stake : nil)) {
            ArcadeDiceRollView(value: lastRoll)
                .padding(.vertical, 8)
            if let lastRoll {
                Text("Roll: \(String(format: "%.2f", lastRoll))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NFGTheme.text)
                Text("Pick under or over 50")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
            } else {
                Text("Tap Under or Over to roll")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
            }
            HStack(spacing: 10) {
                ArcadePrimaryButton(title: "Under 50", icon: "arrow.down", tint: .cyan, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: lockedStake ?? stake, minStake: minStake)) {
                    Task { await onPlay("under", 50) }
                }
                ArcadePrimaryButton(title: "Over 50", icon: "arrow.up", tint: .cyan, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: lockedStake ?? stake, minStake: minStake)) {
                    Task { await onPlay("over", 50) }
                }
            }
        }
    }
}

struct NFGHiLoGameView: View {
    let busy: Bool
    let cooldownSecondsLeft: Int
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    let sessionActive: Bool
    let cardRank: Int
    let cardSuit: String
    let multiplier: Double
    let streak: Int
    let roundEnded: Bool
    let flipTick: Int
    let lastGuessCorrect: Bool?
    var playVisual: ArcadePlayVisual?
    var inPlaySession: Bool = false
    var lockedStake: Int?
    var onStart: () async -> Void
    var onGuess: (String) async -> Void
    var onCashOut: () async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_hilo", title: "Hi-Lo", icon: "🃏", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual, inPlaySession: inPlaySession, lockedStake: lockedStake ?? (inPlaySession ? stake : nil)) {
            ArcadeHiLoCardView(
                rank: cardRank,
                suit: cardSuit,
                flipTick: flipTick,
                guessCorrect: lastGuessCorrect
            )
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                Label("×\(String(format: "%.2f", multiplier))", systemImage: "multiply")
                Label("Streak \(streak)", systemImage: "flame.fill")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(NFGTheme.gold)

            if !sessionActive {
                ArcadePrimaryButton(title: arcadeCooldownTitle("Start", cooldownSecondsLeft: cooldownSecondsLeft), icon: "play.fill", tint: .green, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: lockedStake ?? stake, minStake: minStake)) {
                    Task { await onStart() }
                }
            } else {
                Text("Will the next card be higher or lower?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                HStack {
                    ArcadePrimaryButton(title: "Lower", icon: "arrow.down", tint: .green, disabled: busy) {
                        Task { await onGuess("lo") }
                    }
                    ArcadePrimaryButton(title: "Higher", icon: "arrow.up", tint: .green, disabled: busy) {
                        Task { await onGuess("hi") }
                    }
                }
                ArcadeSecondaryButton(title: "Cash out") { Task { await onCashOut() } }
            }
        }
    }
}

struct NFGMinesGameView: View {
    let busy: Bool
    let cooldownSecondsLeft: Int
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    let sessionActive: Bool
    let minesCount: Int
    let safeRevealed: [Int]
    let multiplier: Double
    let hitCell: Int?
    let allMinePositions: [Int]
    let roundEnded: Bool
    let livesRemaining: Int
    var playVisual: ArcadePlayVisual?
    var inPlaySession: Bool = false
    var lockedStake: Int?
    let revealingIndex: Int?
    var onStart: (Int) async -> Void
    var onReveal: (Int) async -> Void
    var onCashOut: () async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_mines", title: "Mines", icon: "💣", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual, inPlaySession: inPlaySession, lockedStake: lockedStake ?? (inPlaySession ? stake : nil)) {
            HStack(spacing: 12) {
                Label("×\(String(format: "%.2f", multiplier))", systemImage: "multiply")
                Label("\(safeRevealed.count) gems", systemImage: "sparkles")
                Label("\(livesRemaining) life", systemImage: "heart.fill")
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(NFGTheme.muted)

            ArcadeMinesGridView(
                sessionActive: sessionActive,
                revealed: safeRevealed,
                minePositions: allMinePositions,
                hitCell: hitCell,
                revealingIndex: revealingIndex,
                roundEnded: roundEnded,
                disabled: busy,
                onReveal: onReveal
            )

            if !sessionActive {
                ArcadePrimaryButton(title: "Start (3 mines)", icon: "play.fill", tint: .mint, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: lockedStake ?? stake, minStake: minStake)) {
                    Task { await onStart(3) }
                }
            } else {
                ArcadeSecondaryButton(title: "Cash out") { Task { await onCashOut() } }
                    .disabled(busy || safeRevealed.isEmpty)
            }
        }
    }
}

struct NFGPlinkoGameView: View {
    let busy: Bool
    let cooldownSecondsLeft: Int
    @Binding var stake: Int
    let minStake: Int
    let maxStake: Int
    let suggestedStake: Int
    let balance: Int
    let lastBucket: Int?
    let lastMult: Double?
    var playVisual: ArcadePlayVisual?
    var inPlaySession: Bool = false
    var lockedStake: Int?
    var onDrop: (String) async -> (bucket: Int, mult: Double)?

    @State private var selectedRisk = "med"
    @State private var dropping = false
    @State private var ballState = ArcadePlinkoBallState.idle
    @State private var highlightBucket: Int?

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_plinko", title: "Plinko", icon: "⚪", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual, inPlaySession: inPlaySession, lockedStake: lockedStake ?? (inPlaySession ? stake : nil)) {
            ArcadePlinkoBoardView(
                risk: selectedRisk,
                ballState: ballState,
                highlightBucket: highlightBucket ?? lastBucket
            )

            HStack(spacing: 8) {
                ForEach(["low", "med", "high"], id: \.self) { risk in
                    Button {
                        selectedRisk = risk
                    } label: {
                        Text(risk.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(selectedRisk == risk ? .white : NFGTheme.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedRisk == risk ? riskTint(risk).opacity(0.45) : NFGTheme.panel2)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selectedRisk == risk ? riskTint(risk).opacity(0.7) : NFGTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(dropping)
                }
            }

            if let lastBucket, let lastMult, !dropping {
                Text("×\(String(format: "%.2f", lastMult)) in slot \(lastBucket + 1)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(lastMult >= 1 ? NFGTheme.gold : NFGTheme.muted)
            }

            ArcadePrimaryButton(
                title: dropping ? "Dropping…" : arcadeCooldownTitle("Drop ball", cooldownSecondsLeft: cooldownSecondsLeft),
                icon: "arrow.down.circle.fill",
                tint: .pink,
                disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: lockedStake ?? stake, minStake: minStake, extra: dropping)
            ) {
                Task { await runDrop() }
            }
        }
    }

    private func riskTint(_ risk: String) -> Color {
        switch risk {
        case "low": return .green
        case "high": return .red
        default: return NFGTheme.accent
        }
    }

    @MainActor
    private func runDrop() async {
        guard !dropping else { return }
        dropping = true
        highlightBucket = nil
        ballState = .idle

        let result = await onDrop(selectedRisk)
        guard let result else {
            dropping = false
            return
        }

        let path = ArcadePlinkoLayout.bouncePath(to: result.bucket)
        ballState = .atTop

        for step in path {
            ballState = .bouncing(row: step.row, col: step.colAfter, flashRow: step.row, flashCol: step.colBefore)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            try? await Task.sleep(nanoseconds: 95_000_000)
        }

        ballState = .landed(bucket: result.bucket)
        highlightBucket = result.bucket
        UINotificationFeedbackGenerator().notificationOccurred(result.mult >= 1 ? .success : .warning)
        try? await Task.sleep(nanoseconds: 700_000_000)

        dropping = false
        ballState = .idle
    }
}

struct BlockBlastGameView: View {
    let busy: Bool
    let serverLevel: Int
    let sessionPoints: Int
    let linesTarget: Int
    let rewardPreview: Int
    let sessionActive: Bool
    var onStart: () async -> Void
    var onLevelClear: () async -> Void
    var onGameOver: () async -> Void

    var body: some View {
        ArcadeStageCard(gameId: "nfg_blocks", icon: "🧱", title: "NFG Blocks", subtitle: "Line clears earn pts") {
            Text("Lv \(serverLevel) · \(sessionPoints) pts · target \(linesTarget) lines")
                .font(.caption).foregroundStyle(NFGTheme.muted)
            ArcadePrimaryButton(title: sessionActive ? "Level clear" : "Start", icon: "play.fill", tint: .cyan, disabled: busy) {
                Task { if sessionActive { await onLevelClear() } else { await onStart() } }
            }
            if sessionActive {
                ArcadeSecondaryButton(title: "Game over") { Task { await onGameOver() } }
            }
        }
    }
}

struct DragonTowerRPGView: View {
    let busy: Bool
    let tower: ArcadeTowerState
    let lastMessage: String?
    var onCustomize: ([String: Any], Bool) async -> Void
    var onEnter: () async -> Void
    var onAttack: () async -> Void
    var onDefend: () async -> Void
    var onPotion: () async -> Void
    var onFlee: () async -> Void
    var onBuy: (String, String) async -> Void
    var onEquip: (String, String) async -> Void

    var body: some View {
        ArcadeStageCard(gameId: "nfg_tower", icon: "🐉", title: "Dragon Tower", subtitle: "RPG combat") {
            if let lastMessage, !lastMessage.isEmpty {
                Text(lastMessage).font(.caption).foregroundStyle(NFGTheme.muted)
            }
            ArcadePrimaryButton(title: "Enter tower", icon: "door.left.hand.open", tint: .orange, disabled: busy) { Task { await onEnter() } }
            HStack {
                ArcadeSecondaryButton(title: "Attack") { Task { await onAttack() } }
                ArcadeSecondaryButton(title: "Defend") { Task { await onDefend() } }
            }
            HStack {
                ArcadeSecondaryButton(title: "Potion") { Task { await onPotion() } }
                ArcadeSecondaryButton(title: "Flee") { Task { await onFlee() } }
            }
        }
    }
}

struct VaultSafeHeroView: View {
    var heat: Int = 0
    var solved: Bool = false
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(NFGTheme.panel2)
            .frame(height: 100)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: solved ? "lock.open.fill" : "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(NFGTheme.gold)
                    Text("Heat \(heat)")
                        .font(.caption2)
                        .foregroundStyle(NFGTheme.muted)
                }
            )
    }
}




struct VaultHeistDoorView: View {
    let index: Int
    var isShaking: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Door \(index + 1)")
                .font(.system(size: 12, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(NFGTheme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!enabled)
        .rotationEffect(.degrees(isShaking ? 3 : 0))
        .buttonStyle(ArcadePressStyle())
    }
}

// MARK: - Casino mini-game visuals (Hi-Lo, Plinko, Mines, Dice)

enum ArcadeHiLoFormat {
    static let ranks = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

    static func rankLabel(rank: Int) -> String {
        guard rank >= 1, rank <= 13 else { return "?" }
        return ranks[rank - 1]
    }

    static func suitSymbol(suit: String) -> String {
        switch suit.lowercased() {
        case "hearts": return "♥"
        case "diamonds": return "♦"
        case "clubs": return "♣"
        case "spades": return "♠"
        default: return "•"
        }
    }

    static func isRedSuit(suit: String) -> Bool {
        let s = suit.lowercased()
        return s == "hearts" || s == "diamonds"
    }
}

struct ArcadeHiLoCardView: View {
    let rank: Int
    let suit: String
    var flipTick: Int = 0
    var guessCorrect: Bool? = nil

    @State private var wiggle = false

    private var rankText: String { ArcadeHiLoFormat.rankLabel(rank: rank) }
    private var suitText: String { ArcadeHiLoFormat.suitSymbol(suit: suit) }
    private var accent: Color {
        ArcadeHiLoFormat.isRedSuit(suit: suit)
            ? Color(red: 0.92, green: 0.22, blue: 0.32)
            : Color.white.opacity(0.95)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.97, blue: 0.94),
                            Color(red: 0.88, green: 0.90, blue: 0.95),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            guessCorrect == true ? NFGTheme.accent2
                                : guessCorrect == false ? NFGTheme.danger
                                : NFGTheme.gold.opacity(0.55),
                            lineWidth: guessCorrect != nil ? 3 : 1.5
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)

            VStack(spacing: 2) {
                Text(rankText)
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                Text(suitText)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack {
                HStack {
                    Text("\(rankText)\(suitText)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent.opacity(0.9))
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Text("\(rankText)\(suitText)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent.opacity(0.9))
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .rotationEffect(.degrees(wiggle ? 2 : 0))
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: flipTick)
        .onChange(of: flipTick) { _, _ in
            wiggle = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { wiggle = false }
        }
    }
}

enum ArcadePlinkoBallState: Equatable {
    case idle
    case atTop
    case bouncing(row: Int, col: Int, flashRow: Int, flashCol: Int)
    case landed(bucket: Int)
}

struct ArcadePlinkoBounceStep: Equatable {
    var row: Int
    var colBefore: Int
    var colAfter: Int
}

enum ArcadePlinkoLayout {
    /// Matches server: 10 peg rows → 11 buckets (binomial spread).
    static let rowCount = 10
    static let bucketCount = 11

    static let bucketMults: [String: [Double]] = [
        "low": [0.4, 0.6, 0.8, 1, 1.2, 1.5, 1.2, 1, 0.8, 0.6, 0.4],
        "med": [0.2, 0.5, 0.8, 1.1, 1.6, 2.2, 1.6, 1.1, 0.8, 0.5, 0.2],
        "high": [0, 0.2, 0.5, 1, 2, 5, 2, 1, 0.5, 0.2, 0],
    ]

    /// Build a shuffled left/right path that lands in `targetBucket` (server bucket index).
    static func bouncePath(to targetBucket: Int) -> [ArcadePlinkoBounceStep] {
        let target = max(0, min(bucketCount - 1, targetBucket))
        var rights = target
        var lefts = rowCount - rights
        var dirs: [Bool] = []
        dirs.reserveCapacity(rowCount)
        while rights > 0 || lefts > 0 {
            if rights == 0 { dirs.append(false); lefts -= 1; continue }
            if lefts == 0 { dirs.append(true); rights -= 1; continue }
            if Bool.random() {
                dirs.append(true)
                rights -= 1
            } else {
                dirs.append(false)
                lefts -= 1
            }
        }
        var col = 0
        var steps: [ArcadePlinkoBounceStep] = []
        for (row, goRight) in dirs.enumerated() {
            let before = col
            if goRight { col += 1 }
            steps.append(ArcadePlinkoBounceStep(row: row, colBefore: before, colAfter: col))
        }
        return steps
    }

    static func pegCenter(row: Int, col: Int, in size: CGSize) -> CGPoint {
        let spacing = min(size.width / CGFloat(bucketCount + 1), size.height * 0.072)
        let x = size.width * 0.5 + (CGFloat(col) - CGFloat(row) * 0.5) * spacing
        let y = size.height * 0.1 + CGFloat(row) * spacing
        return CGPoint(x: x, y: y)
    }

    static func ballPosition(for state: ArcadePlinkoBallState, in size: CGSize) -> CGPoint {
        let spacing = min(size.width / CGFloat(bucketCount + 1), size.height * 0.072)
        switch state {
        case .idle, .atTop:
            return CGPoint(x: size.width * 0.5, y: size.height * 0.04)
        case .bouncing(let row, let col, _, _):
            return pegCenter(row: row, col: col, in: size)
        case .landed(let bucket):
            let x = size.width * (CGFloat(bucket) + 0.5) / CGFloat(bucketCount)
            return CGPoint(x: x, y: size.height * 0.88)
        }
    }

    static func bucketColor(mult: Double, hot: Bool) -> Color {
        if mult >= 5 { return Color(red: 1, green: 0.78, blue: 0.1) }
        if mult >= 2 { return Color(red: 0.95, green: 0.35, blue: 0.45) }
        if mult >= 1 { return Color(red: 0.35, green: 0.75, blue: 0.95) }
        return Color(red: 0.35, green: 0.42, blue: 0.58)
    }
}

struct ArcadePlinkoBoardView: View {
    let risk: String
    var ballState: ArcadePlinkoBallState = .idle
    var highlightBucket: Int?

    private var mults: [Double] {
        ArcadePlinkoLayout.bucketMults[risk] ?? ArcadePlinkoLayout.bucketMults["med"]!
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.09, blue: 0.17),
                                Color(red: 0.03, green: 0.05, blue: 0.11),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Canvas { context, canvasSize in
                    for row in 0..<ArcadePlinkoLayout.rowCount {
                        for col in 0...row {
                            let center = ArcadePlinkoLayout.pegCenter(row: row, col: col, in: canvasSize)
                            let flash: Bool = {
                                if case .bouncing(let r, _, let flashRow, let flashCol) = ballState {
                                    return r == row && flashRow == row && flashCol == col
                                }
                                return false
                            }()
                            let r: CGFloat = flash ? 5.5 : 4
                            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(flash ? Color.white : Color.white.opacity(0.7))
                            )
                            if flash {
                                context.fill(
                                    Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                                    with: .color(Color.cyan.opacity(0.25))
                                )
                            }
                        }
                    }
                }

                HStack(spacing: 3) {
                    ForEach(0..<ArcadePlinkoLayout.bucketCount, id: \.self) { idx in
                        let mult = mults[idx]
                        let landed = highlightBucket == idx
                        VStack(spacing: 1) {
                            Text(mult == 0 ? "0×" : String(format: "%.1f×", mult))
                                .font(.system(size: 7, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            ArcadePlinkoLayout.bucketColor(mult: mult, hot: mult >= 2)
                                .opacity(landed ? 1 : 0.72)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(landed ? Color.white.opacity(0.9) : Color.clear, lineWidth: 2)
                        )
                        .scaleEffect(landed ? 1.08 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: landed)
                    }
                }
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)

                let ballPos = ArcadePlinkoLayout.ballPosition(for: ballState, in: size)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white, Color(red: 1, green: 0.45, blue: 0.58)],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 12
                        )
                    )
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.pink.opacity(0.7), radius: 8)
                    .position(ballPos)
                    .animation(.spring(response: 0.2, dampingFraction: 0.68), value: ballState)
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.5), NFGTheme.border.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ArcadeMinesGridView: View {
    let sessionActive: Bool
    let revealed: [Int]
    let minePositions: [Int]
    let hitCell: Int?
    let revealingIndex: Int?
    let roundEnded: Bool
    var disabled: Bool = false
    var onReveal: (Int) async -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<25, id: \.self) { index in
                let isRevealed = revealed.contains(index)
                let isMine = minePositions.contains(index)
                let isHit = hitCell == index
                let isRevealing = revealingIndex == index
                Button {
                    Task { await onReveal(index) }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(cellFill(revealed: isRevealed, mine: isMine, hit: isHit))
                        if isRevealed {
                            Text("💎")
                                .font(.system(size: 20))
                        } else if roundEnded && isMine {
                            Text("💣")
                                .font(.system(size: 20))
                        } else if isRevealing {
                            ProgressView()
                                .tint(NFGTheme.accent2)
                        }
                    }
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isHit ? NFGTheme.danger : NFGTheme.border.opacity(0.35), lineWidth: isHit ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(disabled || !sessionActive || isRevealed || roundEnded)
            }
        }
        .padding(8)
        .background(NFGTheme.panel2.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func cellFill(revealed: Bool, mine: Bool, hit: Bool) -> Color {
        if hit { return NFGTheme.danger.opacity(0.35) }
        if revealed { return NFGTheme.accent2.opacity(0.22) }
        if roundEnded && mine { return NFGTheme.danger.opacity(0.25) }
        return Color.white.opacity(0.06)
    }
}

struct ArcadeDiceRollView: View {
    let value: Double?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NFGTheme.panel2)
                .frame(height: 100)
            if let value {
                Text(String(format: "%.2f", value))
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(
                        value < 50 ? Color.cyan : Color.orange
                    )
                Text(value < 50 ? "UNDER 50" : "OVER 50")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(NFGTheme.muted)
                    .offset(y: 36)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(NFGTheme.gold)
                    Text("Roll to play")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                }
            }
        }
    }
}
