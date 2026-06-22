import SwiftUI

// MARK: - 3D skill-game icons (Blocks, Jump, Rush)

struct ArcadeSkillGameIcon: View {
    let gameId: String
    var size: CGFloat = 48

    @State private var pulse = false

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    var body: some View {
        ZStack {
            Circle()
                .fill(ArcadeGameTheme.accent(for: gid).opacity(pulse ? 0.42 : 0.28))
                .frame(width: size * 1.35, height: size * 1.35)
                .blur(radius: size * 0.18)

            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.black.opacity(0.35),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ArcadeGameTheme.accent(for: gid).opacity(0.9),
                                    ArcadeGameTheme.accent(for: gid).opacity(0.25),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: ArcadeGameTheme.accent(for: gid).opacity(0.45), radius: size * 0.12, y: size * 0.06)

            iconContent
                .frame(width: size * 0.72, height: size * 0.72)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch gid {
        case "nfg_snake_jump":
            jumpIcon
        case "nfg_vault_run":
            rushIcon
        case "nfg_blocks":
            blocksIcon
        default:
            Text(ArcadeGameArt.icon(for: gameId))
                .font(.system(size: size * 0.4))
        }
    }

    private var jumpIcon: some View {
        ZStack {
            Image(systemName: "chevron.up")
                .font(.system(size: size * 0.22, weight: .black))
                .foregroundStyle(Color.white.opacity(0.25))
                .offset(y: -size * 0.14)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.45, green: 0.52, blue: 1), Color(red: 0.2, green: 0.28, blue: 0.75)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.35
                    )
                )
                .overlay(Circle().stroke(Color(red: 0.95, green: 0.78, blue: 0.2), lineWidth: size * 0.04))
                .shadow(color: Color(red: 0.35, green: 0.44, blue: 0.95).opacity(0.6), radius: 4, y: 2)
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: -size * 0.1, y: -size * 0.12)
        }
    }

    private var rushIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.22, blue: 0.16), Color(red: 0.04, green: 0.1, blue: 0.07)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.7, height: size * 0.5)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .stroke(Color(red: 0.95, green: 0.78, blue: 0.2), lineWidth: size * 0.03)
                )
            Image(systemName: "figure.run")
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.78, blue: 0.2), Color(red: 1, green: 0.55, blue: 0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0.95, green: 0.78, blue: 0.2).opacity(0.5), radius: 3, y: 2)
        }
    }

    private var blocksIcon: some View {
        let cell = size * 0.15
        let colors: [Color] = [
            Color(red: 0.13, green: 0.83, blue: 0.93),
            Color(red: 0.65, green: 0.55, blue: 0.98),
            Color(red: 0.29, green: 0.87, blue: 0.5),
            Color(red: 0.98, green: 0.45, blue: 0.52),
        ]
        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                let row = i / 2
                let col = i % 2
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [colors[i].opacity(0.95), colors[i].opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: cell, height: cell)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    )
                    .shadow(color: colors[i].opacity(0.4), radius: 2, y: 1)
                    .offset(
                        x: CGFloat(col - 1) * (cell + 3) * 0.5,
                        y: CGFloat(row - 1) * (cell + 3) * 0.5 - 1
                    )
            }
        }
    }
}

// MARK: - Fixed-aspect skill game stage

private enum ArcadeSkillStageMetrics {
    static let aspect: CGFloat = 10 / 16
}

struct ArcadeSkillStageFrame<Content: View>: View {
    let gameId: String
    @ViewBuilder var content: () -> Content

    @State private var rimGlow = false

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    var body: some View {
        ZStack {
            ArcadeCinematicBackdrop(gameId: gid)
                .allowsHitTesting(false)
            content()
        }
        .aspectRatio(ArcadeSkillStageMetrics.aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            ArcadeGameTheme.accent(for: gid).opacity(rimGlow ? 0.85 : 0.45),
                            ArcadeGameTheme.accent(for: gid).opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: ArcadeGameTheme.accent(for: gid).opacity(rimGlow ? 0.28 : 0.14), radius: rimGlow ? 14 : 8, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                rimGlow = true
            }
        }
    }
}

// MARK: - Locked full-screen play window (Jump-style)

struct ArcadePlaySessionChrome<HeaderTrailing: View, Content: View, Footer: View, BottomBar: View>: View {
    let gameId: String
    let onClose: () -> Void
    var useStageFrame: Bool = true
    @ViewBuilder var headerTrailing: () -> HeaderTrailing
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer
    @ViewBuilder var bottomBar: () -> BottomBar

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    var body: some View {
        GeometryReader { geo in
            let safeW = geo.size.width
            let maxStageH = safeW * (16 / 10)
            let bottomBarH: CGFloat = 56
            let headerH: CGFloat = 48
            let footerH: CGFloat = 28
            let stageH = useStageFrame
                ? min(geo.size.height - headerH - footerH - bottomBarH - 16, maxStageH)
                : geo.size.height - headerH - footerH - bottomBarH - 24

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 5 / 255, green: 8 / 255, blue: 14 / 255),
                        NFGTheme.background,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    sessionHeader
                        .frame(height: headerH)
                        .padding(.top, 8)

                    Spacer(minLength: 0)

                    Group {
                        if useStageFrame {
                            ArcadeSkillStageFrame(gameId: gid) {
                                content()
                                    .frame(width: safeW - 16, height: stageH)
                            }
                            .frame(width: safeW - 16, height: stageH)
                        } else {
                            ScrollView {
                                content()
                                    .frame(maxWidth: safeW - 24)
                                    .padding(.horizontal, 12)
                            }
                            .frame(maxHeight: stageH)
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer(minLength: 0)

                    footer()
                        .frame(minHeight: footerH)

                    bottomBar()
                        .frame(height: bottomBarH)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .frame(width: safeW, height: geo.size.height)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sessionHeader: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Label("Close", systemImage: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NFGTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(NFGTheme.panel)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
            headerTrailing()
        }
        .padding(.horizontal, 12)
    }
}

extension ArcadePlaySessionChrome where BottomBar == EmptyView {
    init(
        gameId: String,
        onClose: @escaping () -> Void,
        useStageFrame: Bool = true,
        @ViewBuilder headerTrailing: @escaping () -> HeaderTrailing,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.gameId = gameId
        self.onClose = onClose
        self.useStageFrame = useStageFrame
        self.headerTrailing = headerTrailing
        self.content = content
        self.footer = footer
        self.bottomBar = { EmptyView() }
    }
}

struct ArcadeLockedStakeChip: View {
    let stake: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(NFGTheme.gold)
            Text("Stake \(stake.formatted())")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.gold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NFGTheme.gold.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Corner leaderboard overlay (in-game)

struct ArcadeCornerLeaderboard: View {
    let gameId: String
    let scoreSuffix: String
    var showJumpSkins: Bool = false

    @State private var rows: [ArcadeLadderRow] = []
    @State private var myRank: Int?
    @State private var loadError: String?
    @State private var showFull = false

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    var body: some View {
        Button {
            showFull = true
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NFGTheme.gold)
                    Text("TOP")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.gold)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(NFGTheme.muted)
                }

                if rows.isEmpty {
                    Text(loadError ?? "No scores yet")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                        .lineLimit(1)
                } else {
                    ForEach(Array(rows.prefix(3).enumerated()), id: \.element.id) { idx, row in
                        cornerRow(rank: idx + 1, row: row)
                    }
                }

                Text("View full board")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent2.opacity(0.9))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(width: 148, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.78))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ArcadeGameTheme.accent(for: gid).opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFull) {
            ArcadeFullLeaderboardSheet(
                gameId: gid,
                scoreSuffix: scoreSuffix,
                showJumpSkins: showJumpSkins
            )
        }
        .task(id: gameId) {
            await loadPreview()
        }
    }

    private func cornerRow(rank: Int, row: ArcadeLadderRow) -> some View {
        HStack(spacing: 5) {
            Text("\(rank)")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(rank == 1 ? NFGTheme.gold : NFGTheme.muted)
                .frame(width: 12, alignment: .center)
            if showJumpSkins, let fill = row.jumpSkinFill {
                JumpCirclePreview(fill: fill, ring: row.jumpSkinRing ?? "#f2c733", size: 14)
            }
            Text(row.label)
                .font(.system(size: 9, weight: rank == 1 ? .bold : .semibold))
                .foregroundStyle(rank == 1 ? .white : NFGTheme.text.opacity(0.88))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(row.points.formatted())\(scoreSuffix)")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(rank == 1 ? NFGTheme.accent2 : NFGTheme.muted)
        }
    }

    private func loadPreview() async {
        guard PlayerSession.isLoggedIn else {
            rows = []
            return
        }
        do {
            let api = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            let res = try await api.fetchArcadeLeaderboard(gameId: gid, limit: 3)
            rows = res.top ?? []
            myRank = res.myRank
            loadError = nil
        } catch {
            rows = []
            loadError = "Offline"
        }
    }
}

// MARK: - Full leaderboard sheet

struct ArcadeFullLeaderboardSheet: View {
    let gameId: String
    let scoreSuffix: String
    var showJumpSkins: Bool = false
    var limit: Int = 25

    @Environment(\.dismiss) private var dismiss

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    private var gameTitle: String {
        switch gid {
        case "nfg_blocks": return "NFG Blocks"
        case "nfg_snake_jump": return "NFG Jump"
        case "nfg_vault_run": return "NFG Rush"
        default: return "Leaderboard"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ArcadeInGameLeaderboard(
                    gameId: gid,
                    scoreSuffix: scoreSuffix,
                    showJumpSkins: showJumpSkins,
                    compact: false,
                    fetchLimit: limit
                )
                .padding(16)
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle(gameTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - In-game + hub leaderboards (scroll panel)

struct ArcadeInGameLeaderboard: View {
    let gameId: String
    let scoreSuffix: String
    var showJumpSkins: Bool = false
    var compact: Bool = false
    var fetchLimit: Int = 5

    @State private var rows: [ArcadeLadderRow] = []
    @State private var myRank: Int?
    @State private var myScore: Int?
    @State private var loadError: String?

    private var gid: String { ArcadeGameArt.normalizedId(gameId) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 10) {
                ArcadeSkillGameIcon(gameId: gid, size: compact ? 36 : 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leaderboard")
                        .font(.system(size: compact ? 13 : 14, weight: .bold))
                    Text(titleForGame)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                }
                Spacer()
                if let myRank, let myScore {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("You #\(myRank)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(NFGTheme.gold)
                        Text("\(myScore.formatted())\(scoreSuffix)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NFGTheme.accent2)
                    }
                }
            }

            if rows.isEmpty {
                Text(loadError ?? "Play to claim a spot on the board.")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    leaderboardRow(rank: idx + 1, row: row)
                }
            }
        }
        .padding(compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NFGTheme.panel.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ArcadeGameTheme.accent(for: gid).opacity(0.28), lineWidth: 1)
                )
        )
        .task(id: gameId) {
            await load()
        }
    }

    private var titleForGame: String {
        switch gid {
        case "nfg_blocks": return "Top block puzzle levels"
        case "nfg_snake_jump": return "Highest climb distance"
        case "nfg_vault_run": return "Farthest casino run"
        default: return "Top players"
        }
    }

    private func leaderboardRow(rank: Int, row: ArcadeLadderRow) -> some View {
        HStack(spacing: 8) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(rank <= 3 ? NFGTheme.gold : NFGTheme.muted)
                .frame(width: 18, alignment: .center)
            if showJumpSkins, let fill = row.jumpSkinFill {
                JumpCirclePreview(fill: fill, ring: row.jumpSkinRing ?? "#f2c733", size: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(row.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                if showJumpSkins, let skinName = row.jumpSkinName, row.jumpSkinId != "classic" {
                    Text(skinName)
                        .font(.system(size: 9))
                        .foregroundStyle(NFGTheme.muted)
                }
            }
            Spacer()
            Text("\(row.points.formatted())\(scoreSuffix)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
        }
    }

    private func load() async {
        guard PlayerSession.isLoggedIn else {
            rows = []
            return
        }
        do {
            let api = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            let res = try await api.fetchArcadeLeaderboard(gameId: gid, limit: fetchLimit)
            rows = res.top ?? []
            myRank = res.myRank
            myScore = res.myScore
            loadError = nil
        } catch {
            rows = []
            loadError = "Leaderboard offline"
        }
    }
}

// MARK: - Arcade game navigation (toolbar Back only — no edge swipe to exit)

private final class ArcadeSwipeBackDisablerViewController: UIViewController {
    weak var capturedNav: UINavigationController?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let nav = navigationController else { return }
        capturedNav = nav
        nav.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            capturedNav?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

private struct ArcadeSwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ArcadeSwipeBackDisablerViewController {
        ArcadeSwipeBackDisablerViewController()
    }

    func updateUIViewController(_ uiViewController: ArcadeSwipeBackDisablerViewController, context: Context) {}
}

extension View {
    /// Prevents accidental swipe-back while playing; use toolbar Back to exit.
    func arcadeGameNavigationLock() -> some View {
        navigationBarBackButtonHidden(true)
            .background(ArcadeSwipeBackDisabler())
    }

    func arcadeGameBackButton(action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: action) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
    }
}
