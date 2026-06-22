import SwiftUI

// MARK: - Hub

struct VaultArcadeHubView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @State private var catalog: ArcadeCatalogResponse?
    @State private var error: String?
    @State private var serverWarning: String?
    @State private var isLoading = true
    @State private var selectedGame: ArcadeGameInfo?
    @State private var blocksLeaderboard: ArcadeLeaderboardResponse?
    @State private var jumpLeaderboard: ArcadeLeaderboardResponse?

    @State private var rushLeaderboard: ArcadeLeaderboardResponse?

    private var displayGames: [ArcadeGameInfo] {
        ArcadeBundledCatalog.hubDisplayOrder(
            ArcadeBundledCatalog.merge(serverGames: catalog?.games)
        )
    }

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
            ArcadeCinematicBackdrop(gameId: "arcade_hub")
                .ignoresSafeArea()
                .opacity(0.5)
            ArcadeHubSparkles()
                .ignoresSafeArea()
            ArcadeAmbientOrbs(tint: NFGTheme.accent)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let serverWarning {
                        Text(serverWarning)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NFGTheme.gold)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    if let error {
                        ArcadeResultBanner(text: error, isError: true)
                    }
                    if isLoading && catalog == nil {
                        ProgressView().tint(NFGTheme.accent2)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                    if let cat = catalog {
                        earnBanner(cat)
                    } else if !isLoading {
                        earnBannerPlaceholder
                    }
                    gamesSection
                    arcadeLeaderboardsSection
                    if let cat = catalog, !(cat.missions ?? []).isEmpty {
                        missionsSection(cat.missions ?? [])
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Vault Arcade")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .navigationDestination(item: $selectedGame) { game in
            if game.id == ArcadeBundledCatalog.jumpGameId {
                SnakeJumpGameView()
                    .environmentObject(sync)
            } else if game.id == ArcadeBundledCatalog.rushGameId {
                VaultRunGameScreen()
                    .environmentObject(sync)
            } else if game.id == "nfg_blocks" {
                BlocksGameScreen()
                    .environmentObject(sync)
            } else {
                VaultArcadeGameView(game: game)
                    .environmentObject(sync)
            }
        }
        .task {
            await load()
            await loadLeaderboards()
        }
        .onAppear {
            Task {
                await load()
                await loadLeaderboards()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var arcadeLeaderboardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SKILL GAME LEADERBOARDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            if let blocks = blocksLeaderboard?.top, !blocks.isEmpty {
                hubLeaderboardCard(gameId: "nfg_blocks", title: "NFG Blocks", rows: blocks, scoreSuffix: " Lv")
            }
            if let jump = jumpLeaderboard?.top, !jump.isEmpty {
                hubLeaderboardCard(gameId: "nfg_snake_jump", title: "NFG Jump", rows: jump, scoreSuffix: "m", showJumpSkins: true)
            }
            if let rush = rushLeaderboard?.top, !rush.isEmpty {
                hubLeaderboardCard(gameId: "nfg_vault_run", title: "NFG Rush", rows: rush, scoreSuffix: "m")
            }
            if (blocksLeaderboard?.top ?? []).isEmpty
                && (jumpLeaderboard?.top ?? []).isEmpty
                && (rushLeaderboard?.top ?? []).isEmpty {
                Text("Play Blocks, Jump, or Rush to appear on the board.")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
    }

    private func hubLeaderboardCard(gameId: String, title: String, rows: [ArcadeLadderRow], scoreSuffix: String, showJumpSkins: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ArcadeSkillGameIcon(gameId: gameId, size: 34)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
            }
            ForEach(Array(rows.prefix(5).enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 8) {
                    Text("\(idx + 1).")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(idx < 3 ? NFGTheme.gold : NFGTheme.muted)
                        .frame(width: 18, alignment: .trailing)
                    if showJumpSkins, let fill = row.jumpSkinFill {
                        JumpCirclePreview(fill: fill, ring: row.jumpSkinRing ?? "#f2c733", size: 16)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.label)
                            .font(.system(size: 11, weight: .semibold))
                        if showJumpSkins, let skinName = row.jumpSkinName, row.jumpSkinId != "classic" {
                            Text(skinName)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(SnakeJumpTheme.swiftColor(hex: row.jumpSkinRing ?? "#f2c733", fallback: NFGTheme.gold))
                        }
                    }
                    Spacer()
                    Text("\(row.points.formatted())\(scoreSuffix)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(NFGTheme.accent2)
                }
            }
        }
        .padding(10)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ArcadeGameTheme.accent(for: gameId).opacity(0.25), lineWidth: 1)
        )
    }

    private func loadLeaderboards() async {
        guard let api = sync.apiForArcade() else { return }
        blocksLeaderboard = try? await api.fetchArcadeLeaderboard(gameId: "nfg_blocks", limit: 5)
        jumpLeaderboard = try? await api.fetchArcadeLeaderboard(gameId: "nfg_snake_jump", limit: 5)
        rushLeaderboard = try? await api.fetchArcadeLeaderboard(gameId: "nfg_vault_run", limit: 5)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ArcadeGameArtBadge(gameId: "arcade_hub", size: 52, showGlow: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vault Arcade")
                        .font(.system(size: 20, weight: .heavy))
                    Text("Unlimited plays · stake pts · win or lose")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                }
            }
        }
        .foregroundStyle(NFGTheme.text)
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GAMES")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
                Spacer()
                Text("\(displayGames.count) total · scroll ↓")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NFGTheme.accent2)
            }
            let rows = stride(from: 0, to: displayGames.count, by: 2).map { $0 }
            ForEach(rows, id: \.self) { rowStart in
                HStack(spacing: 10) {
                    ArcadeHubTile(game: displayGames[rowStart]) {
                        selectedGame = displayGames[rowStart]
                    }
                    .disabled(!PlayerSession.isLoggedIn)
                    if rowStart + 1 < displayGames.count {
                        ArcadeHubTile(game: displayGames[rowStart + 1]) {
                            selectedGame = displayGames[rowStart + 1]
                        }
                        .disabled(!PlayerSession.isLoggedIn)
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var earnBannerPlaceholder: some View {
        Text("Connect to sync balance. Games still stake pts when online.")
            .font(.system(size: 11))
            .foregroundStyle(NFGTheme.muted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func earnBanner(_ cat: ArcadeCatalogResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Real points at risk", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NFGTheme.gold)
            Text("Every round stakes balance from your wallet. Bad runs lose pts — skilled play can profit. No daily earn cap.")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
            if cat.isLive == true {
                Text("+\(Int((cat.liveBonusMultiplier ?? 1.15) * 100 - 100))% on wins while LIVE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.accent2)
            }
            Text("Balance \((cat.balance ?? sync.liveBalance).formatted()) pts")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.text)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.gold.opacity(0.35)))
    }

    private func missionsSection(_ missions: [ArcadeMissionInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ARCADE MISSIONS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            ForEach(missions) { m in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.title).font(.system(size: 12, weight: .semibold))
                        ArcadeProgressBar(
                            progress: Double(m.progress ?? 0) / Double(max(1, m.goal)),
                            tint: NFGTheme.accent2
                        )
                    }
                    Spacer()
                    if m.claimed == true {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(NFGTheme.muted)
                    } else if m.done == true {
                        Text("Claim").font(.system(size: 10, weight: .bold)).foregroundStyle(NFGTheme.gold)
                    }
                }
                .padding(10)
                .background(NFGTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func load() async {
        guard let api = sync.apiForArcade() else {
            error = "Link TikTok in Profile first."
            catalog = fallbackCatalog()
            isLoading = false
            return
        }
        isLoading = true
        error = nil
        serverWarning = nil
        defer { isLoading = false }
        do {
            catalog = try await api.fetchArcadeCatalog()
        } catch {
            if catalog == nil { catalog = fallbackCatalog() }
            serverWarning = "Stats offline — games still work."
            self.error = nil
        }
    }

    private func fallbackCatalog() -> ArcadeCatalogResponse {
        ArcadeCatalogResponse(
            ok: false, earnedToday: nil, earnCap: 0, earnLeft: nil,
            liveBonusMultiplier: 1.15, isLive: false, funPoints: nil,
            balance: sync.liveBalance, games: ArcadeBundledCatalog.games,
            missions: nil, season: nil
        )
    }
}

// MARK: - Game screen

struct VaultArcadeGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncClient
    let game: ArcadeGameInfo

    @State private var message = ""
    @State private var error: String?
    @State private var busy = false

    @State private var skillLevel = 1
    @State private var maxSkillLevel = 10
    @State private var suggestedStake = 2000
    @State private var stakeAmount = 2000
    @State private var stakeMin = 100
    @State private var stakeMax = 100_000
    @State private var zoneWidth: CGFloat = 0.18
    @State private var tapRunActive = false
    @State private var safeSessionActive = false

    @State private var scratchGrid: [String] = []
    @State private var safeGuess = ""
    @State private var safeVaultHeat = 0
    @State private var safeVaultStatus = "locked"
    @State private var safeHint = "Enter a 4-digit code. Vault Heat updates after each guess."
    @State private var safeGuessesLeft = 5
    @State private var safeMaxGuesses = 5
    @State private var safeSolved = false
    @State private var safeDigitLocks: [Bool] = []
    @State private var quizGuess = "2.00"

    @State private var heistStarted = false
    @State private var heistStep = 0

    @State private var diceLastRoll: Double?
    @State private var hiloSessionActive = false
    @State private var hiloCardRank = 7
    @State private var hiloCardSuit = "spades"
    @State private var hiloMultiplier = 1.0
    @State private var hiloStreak = 0
    @State private var hiloRoundEnded = false
    @State private var hiloFlipTick = 0
    @State private var hiloShowOutcome = false
    @State private var hiloOutcomeGen = 0
    @State private var hiloIgnoreStaleStatus = false
    @State private var hiloStatusEpoch = 0
    @State private var hiloLastGuessCorrect: Bool?
    @State private var minesSessionActive = false
    @State private var minesCount = 3
    @State private var minesRevealed: [Int] = []
    @State private var minesMultiplier = 1.0
    @State private var plinkoLastBucket: Int?
    @State private var plinkoLastMult: Double?
    @State private var blocksSessionActive = false
    @State private var blocksLevel = 1
    @State private var blocksSessionPoints = 0
    @State private var blocksLinesTarget = 6
    @State private var blocksRewardPreview = 5000
    @State private var blocksOfflinePending = 0
    @State private var playVisual: ArcadePlayVisual?
    @State private var minesHitCell: Int?
    @State private var minesAllPositions: [Int] = []
    @State private var minesRoundEnded = false
    @State private var minesLivesRemaining = 1
    @State private var minesShowOutcome = false
    @State private var minesOutcomeGen = 0
    @State private var minesIgnoreStaleStatus = false
    @State private var minesStatusEpoch = 0
    @State private var minesRevealingIndex: Int?

    @State private var missions: [ArcadeMissionInfo] = []
    @State private var messageRevealGen = 0
    @State private var cooldownSecondsLeft = 0
    @State private var showPlaySession = false
    @State private var lockedStake = 2000

    private var onArcadeCooldown: Bool { cooldownSecondsLeft > 0 }
    private var isStakedCasinoGame: Bool {
        ["nfg_dice", "nfg_hilo", "nfg_mines", "nfg_plinko", "nfg_wheel"].contains(arcadeApiGameId)
    }

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
            ArcadeAmbientOrbs(tint: ArcadeGameTheme.accent(for: ArcadeBundledCatalog.normalizeGameId(game.id)))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    lobbyGameControls
                    ArcadeCooldownBanner(secondsLeft: cooldownSecondsLeft)
                    ArcadeBusyOverlay(busy: busy)
                    ArcadeResultBanner(text: message, isError: message.hasPrefix("-"), isGain: message.hasPrefix("+"))
                    if let error {
                        ArcadeResultBanner(text: error, isError: true)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .arcadeGameNavigationLock()
        .arcadeGameBackButton { dismiss() }
        .fullScreenCover(isPresented: $showPlaySession) {
            stakedPlaySession
                .interactiveDismissDisabled()
        }
        .task(id: game.id) {
            let epoch = minesStatusEpoch
            refreshBlocksOfflinePending()
            if let api = sync.apiForArcade() {
                let synced = await ArcadeOfflinePointsQueue.flush(api: api, sync: sync)
                if synced > 0, game.id == "nfg_blocks" {
                    message = "Synced \(synced) offline Blocks reward\(synced == 1 ? "" : "s")."
                }
                refreshBlocksOfflinePending()
            }
            await play(
                action: "status",
                minesEpoch: game.id == "nfg_mines" ? epoch : nil
            )
        }
        .preferredColorScheme(.dark)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if cooldownSecondsLeft > 0 {
                cooldownSecondsLeft -= 1
            }
        }
    }

    private func isStakedAction(_ action: String) -> Bool {
        let a = action.lowercased()
        return a == "play" || a == "spin" || a == "start"
    }

    private func syncCooldown(from result: ArcadePlayResponse) {
        if let sec = result.cooldownSecondsLeft {
            cooldownSecondsLeft = max(cooldownSecondsLeft, max(0, sec))
        }
    }

    private var arcadeApiGameId: String {
        ArcadeBundledCatalog.normalizeGameId(game.id)
    }

    @ViewBuilder
    private var lobbyGameControls: some View {
        switch arcadeApiGameId {
        case "nfg_dice":
            ArcadeStakedGameLobbyCard(
                gameId: "nfg_dice", title: "Roll Line", icon: "🎯",
                busy: busy, stake: $stakeAmount, minStake: stakeMin, maxStake: stakeMax,
                suggestedStake: suggestedStake, balance: sync.liveBalance,
                openDisabled: onArcadeCooldown,
                onOpen: { lockedStake = stakeAmount; showPlaySession = true }
            )
        case "nfg_hilo":
            ArcadeStakedGameLobbyCard(
                gameId: "nfg_hilo", title: "Hi-Lo", icon: "🃏",
                busy: busy, stake: $stakeAmount, minStake: stakeMin, maxStake: stakeMax,
                suggestedStake: suggestedStake, balance: sync.liveBalance,
                openDisabled: onArcadeCooldown,
                openTitle: "Start & play",
                onOpen: {
                    Task {
                        lockedStake = stakeAmount
                        hiloStatusEpoch += 1
                        await play(action: "start", payload: ["stake": stakeAmount], hiloEpoch: hiloStatusEpoch)
                        showPlaySession = true
                    }
                }
            )
        case "nfg_mines":
            ArcadeStakedGameLobbyCard(
                gameId: "nfg_mines", title: "Mines", icon: "💣",
                busy: busy, stake: $stakeAmount, minStake: stakeMin, maxStake: stakeMax,
                suggestedStake: suggestedStake, balance: sync.liveBalance,
                openDisabled: onArcadeCooldown,
                openTitle: "Start & play",
                onOpen: {
                    Task {
                        lockedStake = stakeAmount
                        minesStatusEpoch += 1
                        await play(action: "start", payload: ["stake": stakeAmount, "mines": 3], minesEpoch: minesStatusEpoch)
                        showPlaySession = true
                    }
                }
            )
        case "nfg_plinko":
            ArcadeStakedGameLobbyCard(
                gameId: "nfg_plinko", title: "Plinko", icon: "⚪",
                busy: busy, stake: $stakeAmount, minStake: stakeMin, maxStake: stakeMax,
                suggestedStake: suggestedStake, balance: sync.liveBalance,
                openDisabled: onArcadeCooldown,
                onOpen: { lockedStake = stakeAmount; showPlaySession = true }
            )
        case "nfg_wheel":
            ArcadeStakedGameLobbyCard(
                gameId: "nfg_wheel", title: "Vault Wheel", icon: "🎡",
                busy: busy, stake: $stakeAmount, minStake: stakeMin, maxStake: stakeMax,
                suggestedStake: suggestedStake, balance: sync.liveBalance,
                openDisabled: onArcadeCooldown,
                onOpen: { lockedStake = stakeAmount; showPlaySession = true }
            )
        case "nfg_blocks":
            Text("Open NFG Blocks from the Arcade hub.")
                .font(.system(size: 12))
                .foregroundStyle(NFGTheme.muted)
        default:
            ArcadeStageCard(gameId: game.id, icon: game.icon, title: game.title, subtitle: game.subtitle) {
                ArcadePrimaryButton(title: "Refresh", icon: "arrow.clockwise", tint: NFGTheme.accent2, disabled: busy) {
                    Task { await play(action: "status") }
                }
            }
        }
    }

    private var stakedPlaySession: some View {
        ArcadePlaySessionChrome(
            gameId: arcadeApiGameId,
            onClose: { closeStakedSession() },
            useStageFrame: false,
            headerTrailing: {
                HStack(spacing: 8) {
                    ArcadeLockedStakeChip(stake: lockedStake)
                    Text("\(sync.liveBalance.formatted()) pts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                }
            },
            content: { sessionGameView },
            footer: {
                if isStakedCasinoGame {
                    Text("Stake locked for this table — close to change amount")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            },
            bottomBar: {
                if hiloSessionActive || minesSessionActive {
                    ArcadeSecondaryButton(title: "Cash out & close") {
                        Task {
                            await play(action: "cashout")
                            showPlaySession = false
                        }
                    }
                    .disabled(busy)
                }
            }
        )
    }

    @ViewBuilder
    private var sessionGameView: some View {
        switch arcadeApiGameId {
        case "nfg_dice":
            NFGDiceGameView(
                busy: busy,
                cooldownSecondsLeft: cooldownSecondsLeft,
                stake: $stakeAmount,
                minStake: stakeMin,
                maxStake: stakeMax,
                suggestedStake: suggestedStake,
                balance: sync.liveBalance,
                lastRoll: diceLastRoll,
                playVisual: playVisual,
                inPlaySession: true,
                lockedStake: lockedStake
            ) { mode, target in
                await play(action: "play", payload: ["stake": lockedStake, "mode": mode, "target": target])
            }
        case "nfg_hilo":
            NFGHiLoGameView(
                busy: busy,
                cooldownSecondsLeft: cooldownSecondsLeft,
                stake: $stakeAmount,
                minStake: stakeMin,
                maxStake: stakeMax,
                suggestedStake: suggestedStake,
                balance: sync.liveBalance,
                sessionActive: hiloSessionActive,
                cardRank: hiloCardRank,
                cardSuit: hiloCardSuit,
                multiplier: hiloMultiplier,
                streak: hiloStreak,
                roundEnded: hiloRoundEnded,
                flipTick: hiloFlipTick,
                lastGuessCorrect: hiloLastGuessCorrect,
                playVisual: hiloShowOutcome ? playVisual : nil,
                inPlaySession: true,
                lockedStake: lockedStake,
                onStart: {
                    hiloStatusEpoch += 1
                    await play(action: "start", payload: ["stake": lockedStake], hiloEpoch: hiloStatusEpoch)
                },
                onGuess: { direction in
                    await play(action: "guess", payload: ["direction": direction])
                },
                onCashOut: {
                    await play(action: "cashout")
                    showPlaySession = false
                }
            )
        case "nfg_mines":
            NFGMinesGameView(
                busy: busy,
                cooldownSecondsLeft: cooldownSecondsLeft,
                stake: $stakeAmount,
                minStake: stakeMin,
                maxStake: stakeMax,
                suggestedStake: suggestedStake,
                balance: sync.liveBalance,
                sessionActive: minesSessionActive,
                minesCount: minesCount,
                safeRevealed: minesRevealed,
                multiplier: minesMultiplier,
                hitCell: minesHitCell,
                allMinePositions: minesAllPositions,
                roundEnded: minesRoundEnded,
                livesRemaining: minesLivesRemaining,
                playVisual: minesShowOutcome ? playVisual : nil,
                inPlaySession: true,
                lockedStake: lockedStake,
                revealingIndex: minesRevealingIndex,
                onStart: { mines in
                    minesStatusEpoch += 1
                    await play(action: "start", payload: ["stake": lockedStake, "mines": mines], minesEpoch: minesStatusEpoch)
                },
                onReveal: { index in
                    await playMinesReveal(index: index)
                },
                onCashOut: {
                    await play(action: "cashout")
                    showPlaySession = false
                }
            )
        case "nfg_plinko":
            NFGPlinkoGameView(
                busy: busy,
                cooldownSecondsLeft: cooldownSecondsLeft,
                stake: $stakeAmount,
                minStake: stakeMin,
                maxStake: stakeMax,
                suggestedStake: suggestedStake,
                balance: sync.liveBalance,
                lastBucket: plinkoLastBucket,
                lastMult: plinkoLastMult,
                playVisual: playVisual,
                inPlaySession: true,
                lockedStake: lockedStake
            ) { risk in
                await playPlinkoDrop(risk: risk, stake: lockedStake)
            }
        case "nfg_wheel":
            VaultWheelGameView(
                busy: busy,
                cooldownSecondsLeft: cooldownSecondsLeft,
                stake: $stakeAmount,
                minStake: stakeMin,
                maxStake: stakeMax,
                suggestedStake: suggestedStake,
                balance: sync.liveBalance,
                playVisual: playVisual,
                inPlaySession: true,
                lockedStake: lockedStake
            ) {
                await playWheelSpin(stake: lockedStake)
            }
        default:
            EmptyView()
        }
    }

    private func closeStakedSession() {
        if hiloSessionActive && !hiloRoundEnded {
            Task { await play(action: "cashout") }
        } else if minesSessionActive && !minesRoundEnded {
            Task { await play(action: "cashout") }
        }
        showPlaySession = false
    }

    private func playMinesReveal(index: Int) async {
        guard minesSessionActive, !minesRoundEnded, !minesRevealed.contains(index) else { return }
        minesRevealingIndex = index
        defer { minesRevealingIndex = nil }
        await play(action: "reveal", payload: ["index": index], minesEpoch: minesStatusEpoch)
    }

    private func playPlinkoDrop(risk: String, stake: Int? = nil) async -> (bucket: Int, mult: Double)? {
        let useStake = stake ?? stakeAmount
        let result = await play(action: "play", payload: ["stake": useStake, "risk": risk])
        guard let idx = result?.segmentIndex, let mult = result?.multiplier else { return nil }
        plinkoLastBucket = idx
        plinkoLastMult = mult
        return (idx, mult)
    }

    private func playWheelSpin(stake: Int? = nil) async -> (index: Int, label: String, mult: Double, won: Bool) {
        let useStake = stake ?? stakeAmount
        let result = await play(action: "spin", payload: ["stake": useStake])
        let idx = result?.segmentIndex ?? 0
        let layout = ArcadeWheelLayout.segments
        let safeIdx = max(0, min(layout.count - 1, idx))
        let label = result?.segmentLabel ?? layout[safeIdx].label
        let mult = result?.multiplier ?? layout[safeIdx].mult
        let net = result?.net ?? ((result?.gained ?? 0) - (result?.lost ?? 0))
        let won = result?.won == true || net > 0 || (result?.gained ?? 0) > 0
        return (safeIdx, label, mult, won)
    }

    @discardableResult
    private func playBlocks(action: String) async -> ArcadePlayResponse? {
        if let api = sync.apiForArcade(), action != "status" {
            await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
            refreshBlocksOfflinePending()
        }
        if let result = await play(action: action) {
            refreshBlocksOfflinePending()
            return result
        }
        guard arcadeApiGameId == "nfg_blocks" else { return nil }
        switch action {
        case "start":
            blocksSessionActive = true
            blocksSessionPoints = 0
            error = nil
            message = "Playing offline — points save locally."
        case "level_clear":
            let reward = blocksRewardPreview
            ArcadeOfflinePointsQueue.enqueue(
                gameId: "nfg_blocks",
                action: "level_clear",
                estimatedPoints: reward
            )
            blocksSessionActive = true
            blocksLevel += 1
            blocksLinesTarget = BlocksEngine.linesTarget(for: blocksLevel)
            blocksRewardPreview = min(25000, 5000 + (blocksLevel - 1) * 450)
            message = "+\(reward.formatted()) pts saved offline"
            error = nil
        case "game_over":
            blocksSessionActive = false
            BlocksLocalStore.clear(user: ArcadeOfflinePointsQueue.userKey())
        default:
            break
        }
        refreshBlocksOfflinePending()
        return nil
    }

    private func refreshBlocksOfflinePending() {
        blocksOfflinePending = ArcadeOfflinePointsQueue.pendingPoints(for: "nfg_blocks")
    }

    @discardableResult
    private func play(action: String, payload: [String: Any] = [:], minesEpoch: Int? = nil, hiloEpoch: Int? = nil) async -> ArcadePlayResponse? {
        guard let api = sync.apiForArcade() else {
            if action == "status" {
                message = "Link TikTok in Profile to sync arcade plays."
            } else {
                error = "Link TikTok in Profile first."
            }
            return nil
        }
        if isStakedAction(action), cooldownSecondsLeft > 0 {
            error = "Wait \(cooldownSecondsLeft)s before the next staked round."
            return nil
        }
        busy = true
        if action != "status" {
            error = nil
            if ArcadePlayReveal.delay(for: arcadeApiGameId) > 0, action != "reveal", action != "guess", action != "climb" {
                if message.hasPrefix("+") || message.hasPrefix("-") {
                    message = ""
                }
            }
        }
        defer { busy = false }
        if action != "status", let api = sync.apiForArcade() {
            await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
            if arcadeApiGameId == "nfg_blocks" {
                refreshBlocksOfflinePending()
            }
        }
        do {
            let result = try await api.arcadePlay(gameId: arcadeApiGameId, action: action, payload: payload)
            error = nil
            applyResult(result, action: action, minesEpoch: minesEpoch, hiloEpoch: hiloEpoch)
            return result
        } catch let err {
            let msg: String
            if let apiErr = err as? GameAPIError, case .serverError(let s) = apiErr {
                msg = s
            } else {
                msg = err.localizedDescription
            }
            if action == "status" {
                error = nil
                message = "Offline stats — you can still play (Lv \(skillLevel))."
            } else {
                error = msg
            }
            return nil
        }
    }

    private func applyResult(_ result: ArcadePlayResponse, action: String, minesEpoch: Int? = nil, hiloEpoch: Int? = nil) {
        ArcadePointsBridge.applyToGlobalWallet(result, sync: sync)
        syncCooldown(from: result)

        if let lv = result.skillLevel { skillLevel = lv }
        if let mx = result.maxSkillLevel { maxSkillLevel = mx }
        if let stake = result.suggestedStake { suggestedStake = stake }
        syncStakeBounds(from: result, resetToSuggested: action == "status")
        if let used = result.stake, used > 0, action != "status" { stakeAmount = used }
        if let zw = result.zoneWidth { zoneWidth = CGFloat(zw) }
        if let active = result.runActive { tapRunActive = active }

        if let roll = result.actual ?? result.roll {
            if arcadeApiGameId == "nfg_dice" { diceLastRoll = roll }
        }

        if arcadeApiGameId == "nfg_mines" {
            applyMinesResult(result, action: action, minesEpoch: minesEpoch)
        }

        if arcadeApiGameId == "nfg_hilo" {
            applyHiLoResult(result, action: action, hiloEpoch: hiloEpoch)
        }

        if arcadeApiGameId == "nfg_blocks" {
            applyBlockBlastResult(result, action: action)
        }

        if arcadeApiGameId == "nfg_plinko" {
            if let idx = result.segmentIndex { plinkoLastBucket = idx }
            if let mult = result.multiplier { plinkoLastMult = mult }
        }

        if action != "status" {
            if let visual = ArcadePlayVisualBuilder.from(result, gameId: arcadeApiGameId) {
                if arcadeApiGameId == "nfg_mines", result.bust == true || result.cleared == true {
                    minesOutcomeGen += 1
                    let token = minesOutcomeGen
                    minesShowOutcome = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                        if token == minesOutcomeGen {
                            minesShowOutcome = true
                        }
                    }
                    playVisual = visual
                } else if arcadeApiGameId == "nfg_mines", minesSessionActive {
                    playVisual = nil
                } else if arcadeApiGameId == "nfg_hilo", result.bust == true || result.cleared == true {
                    hiloOutcomeGen += 1
                    let token = hiloOutcomeGen
                    hiloShowOutcome = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                        if token == hiloOutcomeGen {
                            hiloShowOutcome = true
                        }
                    }
                    playVisual = visual
                } else if arcadeApiGameId == "nfg_hilo", hiloSessionActive {
                    playVisual = nil
                } else {
                    playVisual = visual
                }
            } else if arcadeApiGameId == "nfg_mines", minesSessionActive {
                playVisual = nil
            } else if arcadeApiGameId == "nfg_hilo", hiloSessionActive {
                playVisual = nil
            }
        }

        syncArcadeMeta(from: result)

        applyMessage(from: result, action: action)
    }

    private func applyMessage(from result: ArcadePlayResponse, action: String) {
        let gainLoss: String? = {
            if let lost = result.lost, lost > 0 { return "-\(lost.formatted()) pts" }
            if let g = result.gained, g > 0 { return "+\(g.formatted()) pts" }
            return nil
        }()

        if let gainLoss, action != "status", action != "reveal", action != "guess", action != "climb" {
            let delay = ArcadePlayReveal.delay(for: arcadeApiGameId)
            if delay > 0 {
                messageRevealGen += 1
                let token = messageRevealGen
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if token == messageRevealGen {
                        message = gainLoss
                    }
                }
                return
            }
        }

        if arcadeApiGameId == "nfg_blocks" {
            if let g = result.gained, g > 0 {
                message = "+\(g.formatted()) pts"
            } else if let msg = result.message, !msg.isEmpty {
                message = msg
            } else if action == "status" {
                message = msgOrDefault(result, "Clear lines each level — ~5,000 pts per level, streak bonus in session.")
            }
            return
        }

        if let lost = result.lost, lost > 0 {
            message = "-\(lost.formatted()) pts"
        } else if let g = result.gained, g > 0 {
            message = "+\(g.formatted()) pts"
        } else if let msg = result.message, !msg.isEmpty {
            message = msg
        } else if action == "status" {
            message = "Stake \(stakeAmount.formatted()) pts ( \(stakeMin.formatted())–\(stakeMax.formatted()) ) · Lv \(skillLevel)"
        }
    }

    private func msgOrDefault(_ result: ArcadePlayResponse, _ fallback: String) -> String {
        if let msg = result.message, !msg.isEmpty { return msg }
        return fallback
    }

    private func applyMinesResult(_ result: ArcadePlayResponse, action: String, minesEpoch: Int?) {
        if action == "status", let minesEpoch, minesEpoch < minesStatusEpoch {
            return
        }

        switch action {
        case "start":
            playVisual = nil
            minesShowOutcome = false
            minesHitCell = nil
            minesAllPositions = []
            minesRoundEnded = false
            minesLivesRemaining = result.livesRemaining ?? 1
            minesIgnoreStaleStatus = true
            minesSessionActive = result.sessionActive ?? true
            minesRevealed = result.revealed ?? []
            minesMultiplier = result.multiplier ?? 1
            if let mc = result.minesCount { minesCount = mc }
            if let st = result.stake, st > 0 { stakeAmount = st }
            error = nil

        case "reveal", "cashout":
            minesIgnoreStaleStatus = true
            if let sess = result.sessionActive { minesSessionActive = sess }
            if let mc = result.minesCount { minesCount = mc }
            if let rev = result.revealed { minesRevealed = rev }
            if let mult = result.multiplier { minesMultiplier = mult }
            if let lives = result.livesRemaining { minesLivesRemaining = lives }

            if result.bust == true {
                minesRevealingIndex = nil
                minesHitCell = result.mineHitIndex ?? result.revealed?.last
                if let rev = result.revealed { minesRevealed = rev }
                minesAllPositions = result.minePositions ?? []
                minesRoundEnded = true
                minesSessionActive = false
                minesLivesRemaining = 0
                minesIgnoreStaleStatus = false
            } else if result.cleared == true {
                minesAllPositions = result.minePositions ?? []
                minesRoundEnded = true
                minesSessionActive = false
                minesLivesRemaining = 0
                minesHitCell = nil
                minesIgnoreStaleStatus = false
            }

        case "status":
            if minesIgnoreStaleStatus, result.sessionActive != true {
                return
            }
            if minesRoundEnded { return }
            if let sess = result.sessionActive {
                minesSessionActive = sess
                minesIgnoreStaleStatus = sess
            }
            if let mc = result.minesCount { minesCount = mc }
            if let rev = result.revealed { minesRevealed = rev }
            if let mult = result.multiplier { minesMultiplier = mult }
            if let lives = result.livesRemaining { minesLivesRemaining = lives }
            if let st = result.stake, st > 0, minesSessionActive { stakeAmount = st }
            if !minesSessionActive, !minesRoundEnded {
                minesIgnoreStaleStatus = false
                minesHitCell = nil
                minesAllPositions = []
            }

        default:
            break
        }
    }

    private func applyHiLoResult(_ result: ArcadePlayResponse, action: String, hiloEpoch: Int?) {
        if action == "status", let hiloEpoch, hiloEpoch < hiloStatusEpoch {
            return
        }

        func syncCard(from result: ArcadePlayResponse) {
            if let r = result.cardRank { hiloCardRank = r }
            if let s = result.cardSuit { hiloCardSuit = s }
        }

        switch action {
        case "start":
            playVisual = nil
            hiloShowOutcome = false
            hiloRoundEnded = false
            hiloLastGuessCorrect = nil
            hiloIgnoreStaleStatus = true
            hiloSessionActive = result.sessionActive ?? true
            hiloMultiplier = result.multiplier ?? 1
            hiloStreak = result.streak ?? 0
            syncCard(from: result)
            if let st = result.stake, st > 0 { stakeAmount = st }
            error = nil

        case "guess":
            hiloIgnoreStaleStatus = true
            hiloFlipTick += 1
            if let correct = result.hiloCorrect { hiloLastGuessCorrect = correct }
            if let mult = result.multiplier { hiloMultiplier = mult }
            if let streak = result.streak { hiloStreak = streak }
            syncCard(from: result)

            if result.bust == true {
                hiloSessionActive = false
                hiloRoundEnded = true
                hiloIgnoreStaleStatus = false
            } else if result.hiloCorrect == true {
                hiloSessionActive = true
            }

        case "cashout":
            hiloIgnoreStaleStatus = true
            if result.cleared == true {
                hiloSessionActive = false
                hiloRoundEnded = true
                hiloIgnoreStaleStatus = false
                if let mult = result.multiplier { hiloMultiplier = mult }
                if let streak = result.streak { hiloStreak = streak }
                syncCard(from: result)
            }

        case "status":
            if hiloIgnoreStaleStatus, result.sessionActive != true {
                return
            }
            if hiloRoundEnded { return }
            if let sess = result.sessionActive {
                hiloSessionActive = sess
                hiloIgnoreStaleStatus = sess
            }
            if let mult = result.multiplier { hiloMultiplier = mult }
            if let streak = result.streak { hiloStreak = streak }
            syncCard(from: result)
            if let st = result.stake, st > 0, hiloSessionActive { stakeAmount = st }
            if !hiloSessionActive, !hiloRoundEnded {
                hiloIgnoreStaleStatus = false
            }

        default:
            break
        }
    }

    private func applyBlockBlastResult(_ result: ArcadePlayResponse, action: String) {
        if let active = result.sessionActive ?? result.runActive {
            blocksSessionActive = active
        }
        if let lv = result.level { blocksLevel = max(1, lv) }
        if let pts = result.sessionPoints { blocksSessionPoints = pts }
        if let target = result.linesTarget { blocksLinesTarget = target }
        if let preview = result.levelRewardPreview { blocksRewardPreview = preview }

        switch action {
        case "start":
            blocksSessionActive = true
            blocksSessionPoints = 0
            if let lv = result.level { blocksLevel = lv }
            error = nil
        case "level_clear":
            blocksSessionActive = true
        case "game_over":
            blocksSessionActive = false
            if let pts = result.sessionPoints { blocksSessionPoints = pts }
        case "status":
            break
        default:
            break
        }
        refreshBlocksOfflinePending()
    }

    private func syncStakeBounds(from result: ArcadePlayResponse, resetToSuggested: Bool) {
        if arcadeApiGameId == "nfg_blocks" { return }
        if let mn = result.stakeMin { stakeMin = max(100, mn) }
        if let mx = result.stakeMax { stakeMax = mx }
        if let s = result.suggestedStake {
            suggestedStake = s
            if resetToSuggested || stakeAmount < stakeMin || stakeAmount > stakeMax {
                stakeAmount = min(stakeMax, max(stakeMin, s))
            }
        }
        let bal = sync.liveBalance
        if bal > 0 { stakeMax = min(stakeMax, bal) }
        stakeAmount = min(stakeMax, max(stakeMin, stakeAmount))
    }

    private func syncDailySafe(from result: ArcadePlayResponse, action: String) {
        if let heat = result.vaultHeat { safeVaultHeat = heat }
        if let status = result.vaultStatus, !status.isEmpty { safeVaultStatus = status }
        if let hint = result.hint, !hint.isEmpty { safeHint = hint }
        if let left = result.guessesLeft { safeGuessesLeft = left }
        if let max = result.maxAttempts { safeMaxGuesses = max }
        if let solved = result.solved { safeSolved = solved }
        if let locks = result.digitLocks { safeDigitLocks = locks }
        if result.sessionActive == false {
            safeGuess = ""
            safeSolved = false
            safeVaultHeat = 0
        }
        if action == "guess" {
            if result.won == true {
                ArcadeSoundFX.play(.success)
                safeSolved = true
            } else if result.closeWin == true {
                ArcadeSoundFX.play(.success)
            } else {
                ArcadeSoundFX.play(.fail)
            }
            safeGuess = ""
        }
    }

    private func syncArcadeMeta(from result: ArcadePlayResponse) {
        if let m = result.missions, !m.isEmpty { missions = m }
        if let arc = result.arcade, let m = arc.missions, !m.isEmpty { missions = m }
    }
}

extension SyncClient {
    func apiForArcade() -> GameAPI? {
        guard PlayerSession.isLoggedIn else { return nil }
        return try? GameAPI(baseURLString: PlayerSession.serverBaseURL)
    }
}
