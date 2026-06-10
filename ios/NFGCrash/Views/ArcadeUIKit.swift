import SwiftUI
import AudioToolbox

// MARK: - Per-game visual identity

enum ArcadeGameTheme {
    static func gradient(for gameId: String) -> LinearGradient {
        let gid = ArcadeGameArt.normalizedId(gameId)
        let colors: [Color]
        switch gid {
        case "nfg_dice":
            colors = [Color(red: 0.2, green: 0.85, blue: 0.95), Color(red: 0.1, green: 0.45, blue: 0.9)]
        case "nfg_hilo":
            colors = [Color(red: 0.15, green: 0.72, blue: 0.48), Color(red: 0.05, green: 0.38, blue: 0.28)]
        case "nfg_mines":
            colors = [Color(red: 0.25, green: 0.9, blue: 0.65), Color(red: 0.1, green: 0.45, blue: 0.35)]
        case "nfg_plinko":
            colors = [Color(red: 0.95, green: 0.45, blue: 0.55), Color(red: 0.45, green: 0.15, blue: 0.9)]
        case "nfg_wheel":
            colors = [Color(red: 0.95, green: 0.35, blue: 0.55), Color(red: 0.55, green: 0.15, blue: 0.85)]
        case "nfg_tower":
            colors = [Color(red: 0.95, green: 0.42, blue: 0.15), Color(red: 0.72, green: 0.12, blue: 0.18)]
        case "nfg_blocks":
            colors = [Color(red: 0.31, green: 0.82, blue: 1.0), Color(red: 0.12, green: 0.35, blue: 0.55)]
        case "nfg_snake_jump":
            colors = [Color(red: 0.35, green: 0.44, blue: 0.95), Color(red: 0.12, green: 0.18, blue: 0.45)]
        case "nfg_vault_run":
            colors = [Color(red: 0.98, green: 0.42, blue: 0.21), Color(red: 0.12, green: 0.08, blue: 0.28)]
        case "daily_safe":
            colors = [Color(red: 0.95, green: 0.75, blue: 0.2), Color(red: 0.75, green: 0.45, blue: 0.1)]
        case "scratch":
            colors = [Color(red: 0.85, green: 0.35, blue: 0.95), Color(red: 0.45, green: 0.15, blue: 0.75)]
        case "crash_quiz":
            colors = [Color(red: 0.35, green: 0.95, blue: 0.65), Color(red: 0.1, green: 0.55, blue: 0.45)]
        case "vault_wheel":
            colors = [Color(red: 0.95, green: 0.35, blue: 0.55), Color(red: 0.55, green: 0.15, blue: 0.85)]
        case "vault_heist":
            colors = [Color(red: 0.95, green: 0.55, blue: 0.15), Color(red: 0.55, green: 0.1, blue: 0.15)]
        case "double_nothing":
            colors = [Color(red: 0.95, green: 0.9, blue: 0.25), Color(red: 0.85, green: 0.35, blue: 0.05)]
        case "badge_hunt":
            colors = [Color(red: 0.45, green: 0.75, blue: 1), Color(red: 0.15, green: 0.35, blue: 0.85)]
        case "duel":
            colors = [Color(red: 0.95, green: 0.25, blue: 0.35), Color(red: 0.35, green: 0.1, blue: 0.55)]
        case "arcade_missions":
            colors = [Color(red: 0.55, green: 0.85, blue: 0.95), Color(red: 0.2, green: 0.45, blue: 0.75)]
        case "crash_course":
            colors = [Color(red: 0.55, green: 0.95, blue: 0.75), Color(red: 0.15, green: 0.65, blue: 0.55)]
        case "tycoon":
            colors = [Color(red: 0.85, green: 0.75, blue: 0.25), Color(red: 0.45, green: 0.35, blue: 0.05)]
        case "season_ladder":
            colors = [Color(red: 0.95, green: 0.8, blue: 0.25), Color(red: 0.75, green: 0.45, blue: 0.05)]
        default:
            colors = [NFGTheme.accent, NFGTheme.accent2]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func accent(for gameId: String) -> Color {
        switch ArcadeGameArt.normalizedId(gameId) {
        case "nfg_dice": return Color(red: 0.2, green: 0.85, blue: 0.95)
        case "nfg_hilo": return Color(red: 0.2, green: 0.82, blue: 0.55)
        case "nfg_mines": return Color(red: 0.25, green: 0.9, blue: 0.65)
        case "nfg_plinko": return Color(red: 0.95, green: 0.45, blue: 0.55)
        case "nfg_wheel": return Color(red: 0.95, green: 0.35, blue: 0.55)
        case "nfg_tower": return Color(red: 0.95, green: 0.42, blue: 0.15)
        case "nfg_blocks": return Color(red: 0.31, green: 0.82, blue: 1.0)
        case "nfg_snake_jump": return Color(red: 0.35, green: 0.44, blue: 0.95)
        case "nfg_vault_run": return Color(red: 0.98, green: 0.42, blue: 0.21)
        case "double_nothing": return NFGTheme.gold
        case "badge_hunt": return Color(red: 0.45, green: 0.75, blue: 1)
        case "duel": return Color(red: 0.95, green: 0.25, blue: 0.35)
        case "arcade_missions": return Color(red: 0.55, green: 0.85, blue: 0.95)
        case "crash_course": return Color(red: 0.55, green: 0.95, blue: 0.75)
        case "tycoon": return NFGTheme.gold
        case "season_ladder": return Color(red: 0.95, green: 0.8, blue: 0.25)
        default: return NFGTheme.accent
        }
    }
}

// MARK: - Hub tile

private func hubPlayBadge(for game: ArcadeGameInfo) -> String {
    if game.playsPerDay == 0 { return "∞ PLAY" }
    if let left = game.playsLeft {
        if left >= 9999 { return "∞ PLAY" }
        return "\(left) left"
    }
    return "PLAY"
}

struct ArcadeHubTile: View {
    let game: ArcadeGameInfo
    let action: () -> Void

    @State private var shimmer = false

    private var gid: String { ArcadeBundledCatalog.normalizeGameId(game.id) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [NFGTheme.panel2, NFGTheme.panel.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                RoundedRectangle(cornerRadius: 14)
                    .fill(ArcadeGameTheme.gradient(for: gid).opacity(0.22))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [ArcadeGameTheme.accent(for: gid).opacity(0.7), NFGTheme.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                Circle()
                    .fill(ArcadeGameTheme.accent(for: gid).opacity(0.35))
                    .frame(width: 80, height: 80)
                    .blur(radius: 24)
                    .offset(x: 50, y: -20)
                    .opacity(shimmer ? 0.9 : 0.45)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        ArcadeGameArtBadge(gameId: gid, size: 58, showGlow: true)
                        Spacer(minLength: 4)
                        Text(hubPlayBadge(for: game))
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(NFGTheme.text.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.35))
                            .clipShape(Capsule())
                    }
                    Text(game.title)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(NFGTheme.text)
                    Text(game.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                        .lineLimit(2)
                }
                .padding(12)
            }
            .frame(minHeight: 118)
        }
        .buttonStyle(ArcadePressStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Shared stage chrome

struct ArcadeStageCard<Content: View>: View {
    let gameId: String
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    @State private var glow = false

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ArcadeCinematicBackdrop(gameId: gid)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(spacing: 10) {
                    ArcadeGameArtBadge(gameId: gid, size: 88, showGlow: true)
                        .scaleEffect(glow ? 1.05 : 0.98)
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(NFGTheme.text)
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NFGTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(NFGTheme.panel)
                RoundedRectangle(cornerRadius: 22)
                    .stroke(ArcadeGameTheme.gradient(for: gid).opacity(glow ? 0.75 : 0.35), lineWidth: glow ? 2 : 1)
            }
        )
        .shadow(color: ArcadeGameArt.style(for: gid).glow.opacity(glow ? 0.28 : 0.08), radius: glow ? 22 : 8, y: 6)
    }
}

struct ArcadeCooldownBanner: View {
    let secondsLeft: Int

    var body: some View {
        if secondsLeft > 0 {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Next round in \(secondsLeft)s")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(NFGTheme.gold)
            .padding(10)
            .background(NFGTheme.gold.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct ArcadePrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = NFGTheme.accent2
    var disabled: Bool = false
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.black.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: tint.opacity(pulse ? 0.55 : 0.25), radius: pulse ? 14 : 6)
            .scaleEffect(pulse && !disabled ? 1.01 : 1)
        }
        .buttonStyle(ArcadePressStyle())
        .disabled(disabled)
        .onAppear {
            guard !disabled else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct ArcadeSecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(NFGTheme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(NFGTheme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
        }
        .buttonStyle(ArcadePressStyle())
    }
}

struct ArcadeResultBanner: View {
    let text: String
    var isError: Bool = false
    var isGain: Bool = false

    @State private var appear = false

    var body: some View {
        if !text.isEmpty {
            HStack(spacing: 8) {
                if isGain {
                    Image(systemName: "sparkles")
                        .foregroundStyle(NFGTheme.gold)
                } else if isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(NFGTheme.danger)
                }
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isError ? NFGTheme.danger : (isGain ? NFGTheme.gold : NFGTheme.accent2))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill((isError ? NFGTheme.danger : NFGTheme.accent2).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke((isError ? NFGTheme.danger : NFGTheme.accent2).opacity(0.35))
            )
            .scaleEffect(appear ? 1 : 0.92)
            .opacity(appear ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    appear = true
                }
            }
            .onChange(of: text) { _, _ in
                appear = false
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    appear = true
                }
            }
        }
    }
}

struct ArcadeProgressBar: View {
    let progress: Double
    var tint: Color = NFGTheme.accent2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(NFGTheme.panel2)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * min(1, max(0, progress))))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 8)
    }
}

struct ArcadeAmbientOrbs: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<5 {
                    let phase = t * 0.35 + Double(i) * 1.2
                    let x = size.width * (0.2 + 0.15 * Double(i) + 0.08 * sin(phase))
                    let y = size.height * (0.25 + 0.12 * cos(phase * 0.9 + Double(i)))
                    let r = 40 + CGFloat(i) * 18
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(tint.opacity(0.08 + 0.04 * sin(phase)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ArcadePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Sound & local high scores

enum ArcadeSoundFX {
    static func play(_ kind: Kind) {
        guard AppPreferences.soundEffectsEnabled else { return }
        AudioServicesPlaySystemSound(kind.systemSound)
    }

    enum Kind {
        case tap, success, fail, gameOver, start

        var systemSound: SystemSoundID {
            switch self {
            case .tap: return 1104
            case .success: return 1025
            case .fail: return 1053
            case .gameOver: return 1073
            case .start: return 1110
            }
        }
    }
}

enum ArcadeLocalHighScore {
    static func best(for gameId: String) -> Int {
        UserDefaults.standard.integer(forKey: "arcade.best.\(gameId)")
    }

    static func record(for gameId: String, score: Int) -> Int {
        let prev = best(for: gameId)
        if score > prev {
            UserDefaults.standard.set(score, forKey: "arcade.best.\(gameId)")
            return score
        }
        return prev
    }
}

enum ArcadeRunPhase: Equatable {
    case intro
    case playing
    case gameOver
}

struct ArcadeGameShell<Content: View>: View {
    let gameId: String
    let title: String
    let icon: String
    let subtitle: String
    @Binding var phase: ArcadeRunPhase
    let sessionScore: Int
    let canStart: Bool
    let busy: Bool
    var onStart: () -> Void
    var onReplay: () -> Void
    @ViewBuilder var content: () -> Content

    private var best: Int { ArcadeLocalHighScore.best(for: gameId) }

    var body: some View {
        ArcadeStageCard(gameId: gameId, icon: icon, title: title, subtitle: subtitle) {
            VStack(spacing: 14) {
                HStack {
                    scoreChip("Run", sessionScore)
                    scoreChip("Best", max(sessionScore, best))
                    Spacer()
                    Text(phaseLabel)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(NFGTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(NFGTheme.panel2)
                        .clipShape(Capsule())
                }

                ZStack {
                    content()
                        .opacity(phase == .playing ? 1 : 0.35)
                        .allowsHitTesting(phase == .playing)

                    if phase == .intro {
                        introOverlay
                    } else if phase == .gameOver {
                        gameOverOverlay
                    }
                }
            }
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .intro: return "READY"
        case .playing: return "LIVE"
        case .gameOver: return "DONE"
        }
    }

    private var introOverlay: some View {
        VStack(spacing: 12) {
            ArcadeGameArtBadge(gameId: gameId, size: 64, showGlow: true)
            Text("Tap Start to play")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NFGTheme.text)
            if best > 0 {
                Text("High score: \(best)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(NFGTheme.gold)
            }
            ArcadePrimaryButton(
                title: "Start",
                icon: "play.fill",
                tint: ArcadeGameTheme.accent(for: gameId),
                disabled: busy || !canStart
            ) {
                ArcadeSoundFX.play(.start)
                onStart()
                phase = .playing
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var gameOverOverlay: some View {
        VStack(spacing: 12) {
            Text("Run complete")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(NFGTheme.text)
            Text("Score: \(sessionScore)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(ArcadeGameTheme.accent(for: gameId))
            if sessionScore >= best && sessionScore > 0 {
                Text("New high score!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NFGTheme.gold)
            }
            ArcadePrimaryButton(
                title: "Play again",
                icon: "arrow.counterclockwise",
                tint: ArcadeGameTheme.accent(for: gameId),
                disabled: busy || !canStart
            ) {
                ArcadeSoundFX.play(.start)
                onReplay()
                phase = .playing
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func scoreChip(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            Text("\(value)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
        }
    }
}

struct VaultHeatMeterView: View {
    let heat: Int
    let status: String
    let solved: Bool

    private var label: String {
        if solved { return "Unlocked" }
        switch status.lowercased() {
        case "burning": return "Burning hot"
        case "hot": return "Very warm"
        case "warm": return "Warm"
        case "cool": return "Cool"
        case "frozen": return "Ice cold"
        case "locked": return "Locked"
        default: return status.capitalized
        }
    }

    private var tint: Color {
        if solved { return NFGTheme.accent2 }
        switch status.lowercased() {
        case "burning", "hot": return .orange
        case "warm": return NFGTheme.gold
        case "cool": return NFGTheme.accent2
        default: return Color.cyan.opacity(0.8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Vault Heat", systemImage: solved ? "lock.open.fill" : "thermometer.medium")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                Spacer()
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(NFGTheme.panel2)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.cyan, tint, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, heat))) / 100)
                }
            }
            .frame(height: 12)
            Text("\(heat)%")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.muted)
        }
        .padding(12)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.35)))
    }
}

struct ArcadeRiskBar: View {
    let skillLevel: Int
    let maxLevel: Int
    let suggestedStake: Int
    let balance: Int

    var body: some View {
        HStack(spacing: 12) {
            Label("Lv \(skillLevel)/\(maxLevel)", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.gold)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Stake ~\(suggestedStake.formatted())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(NFGTheme.accent2)
                Text("Balance \(balance.formatted())")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(balance >= suggestedStake ? NFGTheme.muted : NFGTheme.danger)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Legacy alias — arcade no longer uses daily play limits.
struct ArcadeGameStatusBar: View {
    let skillLevel: Int
    let maxLevel: Int
    let playsLeft: Int
    let playsPerDay: Int

    var body: some View {
        ArcadeRiskBar(skillLevel: skillLevel, maxLevel: maxLevel, suggestedStake: 2000, balance: 0)
    }
}

struct ArcadeBusyOverlay: View {
    let busy: Bool

    var body: some View {
        if busy {
            HStack(spacing: 10) {
                ProgressView().tint(NFGTheme.accent2)
                Text("Syncing…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Hub sparkles

struct ArcadeHubSparkles: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for i in 0..<18 {
                    let phase = t * 0.6 + Double(i) * 0.7
                    let x = size.width * (0.08 + (Double(i) * 0.053).truncatingRemainder(dividingBy: 1))
                    let y = size.height * (0.1 + 0.75 * (sin(phase) * 0.5 + 0.5))
                    let s: CGFloat = 2 + CGFloat(i % 3)
                    let rect = CGRect(x: x, y: y, width: s, height: s)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(NFGTheme.gold.opacity(0.15 + 0.12 * sin(phase * 2)))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Streak spinner wheel

struct VaultStreakWheelSegment: Identifiable {
    let id: Int
    let label: String
    let mult: Double
    let systemImage: String
    let colors: [Color]
}

struct VaultStreakWheelView: View {
    let rotation: Double
    let segments: [VaultStreakWheelSegment]
    var size: CGFloat = 280

    @State private var lightPhase = false

    var body: some View {
        let count = max(segments.count, 1)
        let step = 360.0 / Double(count)

        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = dim / 2
            // Push labels closer to the rim so each segment has clear space.
            let labelRadius = radius * 0.74

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.12), Color.black.opacity(0.92)],
                            center: .center,
                            startRadius: radius * 0.15,
                            endRadius: radius * 1.05
                        )
                    )
                    .frame(width: dim + 28, height: dim + 28)
                    .position(center)
                    .shadow(color: ArcadeGameArt.style(for: "vault_wheel").glow.opacity(0.35), radius: 20)

                ForEach(0..<32, id: \.self) { peg in
                    Circle()
                        .fill(lightPhase && peg % 2 == 0 ? NFGTheme.gold : Color.white.opacity(0.4))
                        .frame(width: 5, height: 5)
                        .position(
                            x: center.x + CGFloat(cos((Double(peg) * 11.25 - 90) * .pi / 180)) * (radius + 10),
                            y: center.y + CGFloat(sin((Double(peg) * 11.25 - 90) * .pi / 180)) * (radius + 10)
                        )
                }

                ZStack {
                    ForEach(0..<count, id: \.self) { index in
                        let start = Double(index) * step - 90
                        WheelSliceShape(startAngle: start, endAngle: start + step)
                            .fill(
                                LinearGradient(
                                    colors: segments[index].colors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                WheelSliceShape(startAngle: start, endAngle: start + step)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                            )
                    }

                    ForEach(0..<count, id: \.self) { index in
                        let mid = (Double(index) + 0.5) * step - 90
                        let rad = mid * .pi / 180
                        wheelSegmentLabel(segments[index])
                            .position(
                                x: center.x + CGFloat(cos(rad)) * labelRadius,
                                y: center.y + CGFloat(sin(rad)) * labelRadius
                            )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .rotationEffect(.degrees(rotation))

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.9), NFGTheme.gold, Color.purple.opacity(0.85)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 38
                        )
                    )
                    .frame(width: 58, height: 58)
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 2))
                    .shadow(color: NFGTheme.gold.opacity(0.65), radius: 14)
                    .position(center)

                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, NFGTheme.gold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: NFGTheme.gold.opacity(0.9), radius: 10)
                    .position(x: center.x, y: center.y - radius - 22)
                    .scaleEffect(lightPhase ? 1.08 : 1)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                lightPhase = true
            }
        }
    }

    private func wheelSegmentLabel(_ seg: VaultStreakWheelSegment) -> some View {
        Image(systemName: seg.systemImage)
            .font(.system(size: 18, weight: .black))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(.black.opacity(0.4))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
    }
}

private struct WheelSliceShape: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.move(to: center)
        p.addArc(
            center: center,
            radius: r,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Play outcome visuals

struct ArcadePlayVisual: Equatable {
    var title: String
    var subtitle: String?
    var isGain: Bool
    var isLoss: Bool
}

enum ArcadePlayVisualBuilder {
    static func from(_ result: ArcadePlayResponse, gameId: String) -> ArcadePlayVisual? {
        if let lost = result.lost, lost > 0 {
            return ArcadePlayVisual(title: "-\(lost.formatted()) pts", subtitle: result.message, isGain: false, isLoss: true)
        }
        if let gained = result.gained, gained > 0 {
            return ArcadePlayVisual(title: "+\(gained.formatted()) pts", subtitle: result.message, isGain: true, isLoss: false)
        }
        if let msg = result.message, !msg.isEmpty, result.bust == true || result.cleared == true || result.won == true {
            let gain = result.won == true || result.cleared == true
            return ArcadePlayVisual(title: msg, subtitle: nil, isGain: gain, isLoss: result.bust == true)
        }
        if gameId == "nfg_dice", let roll = result.actual ?? result.roll {
            return ArcadePlayVisual(title: String(format: "Rolled %.2f", roll), subtitle: result.message, isGain: result.won == true, isLoss: result.lost ?? 0 > 0)
        }
        return nil
    }
}

struct ArcadeDelayedOutcomeStrip: View {
    let visual: ArcadePlayVisual?
    let show: Bool

    var body: some View {
        if show, let visual {
            HStack(spacing: 8) {
                Image(systemName: visual.isGain ? "arrow.up.circle.fill" : visual.isLoss ? "arrow.down.circle.fill" : "info.circle.fill")
                    .foregroundStyle(visual.isGain ? NFGTheme.accent2 : visual.isLoss ? Color.red.opacity(0.9) : NFGTheme.muted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(visual.title)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(visual.isGain ? NFGTheme.accent2 : visual.isLoss ? Color.red.opacity(0.95) : NFGTheme.text)
                    if let subtitle = visual.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(NFGTheme.muted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke((visual.isGain ? NFGTheme.accent2 : visual.isLoss ? Color.red : NFGTheme.border).opacity(0.35), lineWidth: 1)
            )
        }
    }
}
