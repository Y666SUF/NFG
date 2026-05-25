import SwiftUI
import AudioToolbox

// MARK: - Per-game visual identity

enum ArcadeGameTheme {
    static func gradient(for gameId: String) -> LinearGradient {
        let colors: [Color]
        switch gameId {
        case "vault_tap":
            colors = [Color(red: 0.2, green: 0.85, blue: 0.95), Color(red: 0.1, green: 0.45, blue: 0.9)]
        case "daily_safe":
            colors = [Color(red: 0.95, green: 0.75, blue: 0.2), Color(red: 0.75, green: 0.45, blue: 0.1)]
        case "scratch":
            colors = [Color(red: 0.85, green: 0.35, blue: 0.95), Color(red: 0.45, green: 0.15, blue: 0.75)]
        case "crash_quiz":
            colors = [Color(red: 0.35, green: 0.95, blue: 0.65), Color(red: 0.1, green: 0.55, blue: 0.45)]
        case "streak_spinner":
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
        switch gameId {
        case "vault_tap": return Color(red: 0.2, green: 0.85, blue: 0.95)
        case "daily_safe": return Color(red: 0.95, green: 0.75, blue: 0.2)
        case "scratch": return Color(red: 0.85, green: 0.35, blue: 0.95)
        case "crash_quiz": return Color(red: 0.35, green: 0.95, blue: 0.65)
        case "streak_spinner": return Color(red: 0.95, green: 0.35, blue: 0.55)
        case "vault_heist": return Color(red: 0.95, green: 0.55, blue: 0.15)
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

struct ArcadeHubTile: View {
    let game: ArcadeGameInfo
    let action: () -> Void

    @State private var shimmer = false

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
                    .fill(ArcadeGameTheme.gradient(for: game.id).opacity(0.22))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [ArcadeGameTheme.accent(for: game.id).opacity(0.7), NFGTheme.border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                Circle()
                    .fill(ArcadeGameTheme.accent(for: game.id).opacity(0.35))
                    .frame(width: 80, height: 80)
                    .blur(radius: 24)
                    .offset(x: 50, y: -20)
                    .opacity(shimmer ? 0.9 : 0.45)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(game.icon)
                            .font(.system(size: 32))
                            .shadow(color: ArcadeGameTheme.accent(for: game.id).opacity(0.6), radius: 8)
                        Spacer()
                        Text(game.playsLeft.map { "\($0) left" } ?? "PLAY")
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

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(ArcadeGameTheme.gradient(for: gameId))
                    .frame(width: 72, height: 72)
                    .blur(radius: 28)
                    .opacity(glow ? 0.7 : 0.45)
                    .scaleEffect(glow ? 1.08 : 0.95)
                Text(icon)
                    .font(.system(size: 44))
                    .shadow(color: ArcadeGameTheme.accent(for: gameId).opacity(0.8), radius: 12)
                    .scaleEffect(glow ? 1.04 : 1)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(NFGTheme.text)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(NFGTheme.panel)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(ArcadeGameTheme.gradient(for: gameId).opacity(glow ? 0.65 : 0.35), lineWidth: glow ? 1.5 : 1)
            }
        )
        .shadow(color: ArcadeGameTheme.accent(for: gameId).opacity(glow ? 0.2 : 0.05), radius: glow ? 16 : 6)
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
            Text(icon).font(.system(size: 48))
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

struct ArcadeGameStatusBar: View {
    let skillLevel: Int
    let maxLevel: Int
    let playsLeft: Int
    let playsPerDay: Int

    var body: some View {
        HStack(spacing: 12) {
            Label("Lv \(skillLevel)/\(maxLevel)", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.gold)
            Spacer()
            if playsPerDay > 0 {
                Text("\(playsLeft) of \(playsPerDay) plays today")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(playsLeft > 0 ? NFGTheme.accent2 : NFGTheme.danger)
            } else {
                Text("View only")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
    let icon: String
    let colors: [Color]
}

struct VaultStreakWheelView: View {
    let rotation: Double
    let segments: [VaultStreakWheelSegment]
    var size: CGFloat = 260

    @State private var lightPhase = false

    var body: some View {
        let count = max(segments.count, 1)
        let step = 360.0 / Double(count)

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.black.opacity(0.5), Color.black.opacity(0.85)],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size + 24, height: size + 24)

            ForEach(0..<24, id: \.self) { peg in
                Circle()
                    .fill(lightPhase && peg % 2 == 0 ? NFGTheme.gold : Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
                    .offset(y: -(size / 2 + 8))
                    .rotationEffect(.degrees(Double(peg) * 15))
            }

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                    let start = Double(index) * step - 90
                    WheelSliceShape(startAngle: start, endAngle: start + step)
                        .fill(
                            LinearGradient(
                                colors: seg.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            WheelSliceShape(startAngle: start, endAngle: start + step)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                        )

                    let mid = start + step / 2
                    VStack(spacing: 2) {
                        Text(seg.icon)
                            .font(.system(size: 15))
                        Text(seg.label)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .rotationEffect(.degrees(mid + 90))
                    .offset(y: -(size * 0.33))
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [NFGTheme.gold, Color.orange, Color.purple.opacity(0.9)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 44
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                .shadow(color: NFGTheme.gold.opacity(0.6), radius: 12)

            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.white, NFGTheme.gold], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: NFGTheme.gold.opacity(0.9), radius: 8)
                .offset(y: -(size / 2 + 18))
                .scaleEffect(lightPhase ? 1.06 : 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                lightPhase = true
            }
        }
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
