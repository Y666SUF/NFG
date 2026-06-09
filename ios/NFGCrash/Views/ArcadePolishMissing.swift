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

    var body: some View {
        ZStack {
            if showGlow {
                Circle()
                    .fill(ArcadeGameTheme.accent(for: gameId).opacity(0.35))
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: 10)
            }
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

struct ArcadeHowToPlayCard: View {
    let gameId: String
    var body: some View {
        Text("Stake fun points — outcomes sync with the Vault Arcade server.")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NFGTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(NFGTheme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ArcadeStageCard(gameId: gameId, icon: icon, title: title, subtitle: "Stake pts — server decides outcome") {
            VStack(spacing: 12) {
                ArcadeHowToPlayCard(gameId: gameId)
                ArcadeStakeControl(stake: $stake, minStake: minStake, maxStake: maxStake, balance: balance, suggestedStake: suggestedStake, disabled: busy)
                if let playVisual {
                    ArcadeDelayedOutcomeStrip(visual: playVisual, show: true)
                }
                actions()
            }
        }
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
    var onPlay: (String, Double) async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_dice", title: "Roll Line", icon: "🎯", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual) {
            if let lastRoll { Text("Last roll: \(String(format: "%.2f", lastRoll))").font(.caption).foregroundStyle(NFGTheme.muted) }
            HStack {
                ArcadePrimaryButton(title: "Under 50", icon: "arrow.down", tint: .cyan, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: stake, minStake: minStake)) {
                    Task { await onPlay("under", 50) }
                }
                ArcadePrimaryButton(title: "Over 50", icon: "arrow.up", tint: .cyan, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: stake, minStake: minStake)) {
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
    var onStart: () async -> Void
    var onGuess: (String) async -> Void
    var onCashOut: () async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_hilo", title: "Hi-Lo", icon: "🃏", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual) {
            Text("Card \(cardRank) \(cardSuit) · ×\(String(format: "%.2f", multiplier)) · streak \(streak)")
                .font(.caption).foregroundStyle(NFGTheme.muted)
            if !sessionActive {
                ArcadePrimaryButton(title: arcadeCooldownTitle("Start", cooldownSecondsLeft: cooldownSecondsLeft), icon: "play.fill", tint: .green, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: stake, minStake: minStake)) {
                    Task { await onStart() }
                }
            } else {
                HStack {
                    ArcadePrimaryButton(title: "Lower", icon: "arrow.down", tint: .green, disabled: busy) { Task { await onGuess("lower") } }
                    ArcadePrimaryButton(title: "Higher", icon: "arrow.up", tint: .green, disabled: busy) { Task { await onGuess("higher") } }
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
    let revealingIndex: Int?
    var onStart: (Int) async -> Void
    var onReveal: (Int) async -> Void
    var onCashOut: () async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_mines", title: "Mines", icon: "💣", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual) {
            Text("×\(String(format: "%.2f", multiplier)) · revealed \(safeRevealed.count)")
                .font(.caption).foregroundStyle(NFGTheme.muted)
            if !sessionActive {
                ArcadePrimaryButton(title: "Start (3 mines)", icon: "play.fill", tint: .mint, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: stake, minStake: minStake)) {
                    Task { await onStart(3) }
                }
            } else {
                ArcadePrimaryButton(title: "Reveal #0", icon: "hand.tap", tint: .mint, disabled: busy) { Task { await onReveal(0) } }
                ArcadeSecondaryButton(title: "Cash out") { Task { await onCashOut() } }
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
    var onDrop: (String) async -> Void

    var body: some View {
        ArcadeStakePlayShell(gameId: "nfg_plinko", title: "Plinko", icon: "⚪", busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, stake: $stake, minStake: minStake, maxStake: maxStake, suggestedStake: suggestedStake, balance: balance, playVisual: playVisual) {
            if let lastBucket, let lastMult {
                Text("Bucket \(lastBucket) · ×\(String(format: "%.2f", lastMult))").font(.caption).foregroundStyle(NFGTheme.muted)
            }
            ArcadePrimaryButton(title: arcadeCooldownTitle("Drop", cooldownSecondsLeft: cooldownSecondsLeft), icon: "arrow.down.circle", tint: .pink, disabled: arcadeStakeBlocked(busy: busy, cooldownSecondsLeft: cooldownSecondsLeft, balance: balance, stake: stake, minStake: minStake)) {
                Task { await onDrop("medium") }
            }
        }
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
