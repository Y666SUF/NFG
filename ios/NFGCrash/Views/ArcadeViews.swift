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

    private var displayGames: [ArcadeGameInfo] {
        ArcadeBundledCatalog.merge(serverGames: catalog?.games)
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
            } else if game.id == ArcadeBundledCatalog.rushGameId {
                VaultRunGameScreen()
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
            Text("LEADERBOARDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            if let blocks = blocksLeaderboard?.top, !blocks.isEmpty {
                arcadeLeaderboardCard(title: "NFG Blocks top", rows: blocks, scoreSuffix: " Lv")
            }
            if let jump = jumpLeaderboard?.top, !jump.isEmpty {
                arcadeLeaderboardCard(title: "NFG Jump top", rows: jump, scoreSuffix: "m", showJumpSkins: true)
            }
            if (blocksLeaderboard?.top ?? []).isEmpty && (jumpLeaderboard?.top ?? []).isEmpty {
                Text("Play Blocks or Jump to appear on the board.")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
    }

    private func arcadeLeaderboardCard(title: String, rows: [ArcadeLadderRow], scoreSuffix: String, showJumpSkins: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NFGTheme.text)
            ForEach(Array(rows.prefix(5).enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 8) {
                    Text("\(idx + 1).")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(NFGTheme.muted)
                        .frame(width: 18, alignment: .trailing)
                    if showJumpSkins, let fill = row.jumpSkinFill {
                        Circle()
                            .fill(SnakeJumpTheme.swiftColor(hex: fill, fallback: NFGTheme.accent))
                            .overlay(Circle().stroke(SnakeJumpTheme.swiftColor(hex: row.jumpSkinRing ?? "#f2c733", fallback: NFGTheme.gold), lineWidth: 2))
                            .frame(width: 14, height: 14)
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
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadLeaderboards() async {
        guard let api = sync.apiForArcade() else { return }
        blocksLeaderboard = try? await api.fetchArcadeLeaderboard(gameId: "nfg_blocks", limit: 5)
        jumpLeaderboard = try? await api.fetchArcadeLeaderboard(gameId: "nfg_snake_jump", limit: 5)
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
    @State private var stakeMax = 5000
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
    @State private var towerRPG: ArcadeTowerState = .empty
    @State private var towerStatusEpoch = 0
    @State private var blocksSessionActive = false
    @State private var blocksLevel = 1
    @State private var blocksSessionPoints = 0
    @State private var blocksLinesTarget = 6
    @State private var blocksRewardPreview = 5000
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

    private var onArcadeCooldown: Bool { cooldownSecondsLeft > 0 }

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
            ArcadeAmbientOrbs(tint: ArcadeGameTheme.accent(for: ArcadeBundledCatalog.normalizeGameId(game.id)))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    gameControls
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
        .task(id: game.id) {
            let epoch = minesStatusEpoch
            let towerEpoch = towerStatusEpoch
            await play(
                action: "status",
                minesEpoch: game.id == "nfg_mines" ? epoch : nil,
                towerEpoch: game.id == "nfg_tower" ? towerEpoch : nil
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
    private var gameControls: some View {
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
                playVisual: playVisual
            ) { mode, target in
                await play(action: "play", payload: ["stake": stakeAmount, "mode": mode, "target": target])
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
                onStart: {
                    hiloStatusEpoch += 1
                    await play(action: "start", payload: ["stake": stakeAmount], hiloEpoch: hiloStatusEpoch)
                },
                onGuess: { direction in
                    await play(action: "guess", payload: ["direction": direction])
                },
                onCashOut: {
                    await play(action: "cashout")
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
                revealingIndex: minesRevealingIndex,
                onStart: { mines in
                    minesStatusEpoch += 1
                    await play(action: "start", payload: ["stake": stakeAmount, "mines": mines], minesEpoch: minesStatusEpoch)
                },
                onReveal: { index in
                    await playMinesReveal(index: index)
                },
                onCashOut: {
                    await play(action: "cashout")
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
                playVisual: playVisual
            ) { risk in
                await playPlinkoDrop(risk: risk)
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
                playVisual: playVisual
            ) {
                await playWheelSpin()
            }
        case "nfg_blocks":
            BlocksGameView(
                busy: busy,
                serverLevel: blocksLevel,
                sessionPoints: blocksSessionPoints,
                linesTarget: blocksLinesTarget,
                rewardPreview: blocksRewardPreview,
                sessionActive: blocksSessionActive,
                onStart: {
                    await play(action: "start")
                },
                onLevelClear: {
                    await play(action: "level_clear")
                },
                onGameOver: {
                    await play(action: "game_over")
                }
            )
        case "nfg_tower":
            DragonTowerRPGView(
                busy: busy,
                tower: towerRPG,
                lastMessage: message.isEmpty ? nil : message,
                onCustomize: { payload, finalize in
                    await play(action: "customize", payload: payload)
                },
                onEnter: {
                    towerStatusEpoch += 1
                    await play(action: "enter", towerEpoch: towerStatusEpoch)
                },
                onAttack: {
                    await play(action: "attack")
                },
                onDefend: {
                    await play(action: "defend")
                },
                onPotion: {
                    await play(action: "potion")
                },
                onFlee: {
                    await play(action: "flee")
                },
                onBuy: { kind, itemId in
                    await play(action: "buy", payload: ["kind": kind, "itemId": itemId])
                },
                onEquip: { kind, itemId in
                    await play(action: "equip", payload: ["kind": kind, "itemId": itemId])
                }
            )
        default:
            ArcadeStageCard(gameId: game.id, icon: game.icon, title: game.title, subtitle: game.subtitle) {
                ArcadePrimaryButton(title: "Refresh", icon: "arrow.clockwise", tint: NFGTheme.accent2, disabled: busy) {
                    Task { await play(action: "status") }
                }
            }
        }
    }

    private func playMinesReveal(index: Int) async {
        guard minesSessionActive, !minesRoundEnded, !minesRevealed.contains(index) else { return }
        minesRevealingIndex = index
        defer { minesRevealingIndex = nil }
        await play(action: "reveal", payload: ["index": index], minesEpoch: minesStatusEpoch)
    }

    private func playPlinkoDrop(risk: String) async -> (bucket: Int, mult: Double)? {
        let result = await play(action: "play", payload: ["stake": stakeAmount, "risk": risk])
        guard let idx = result?.segmentIndex, let mult = result?.multiplier else { return nil }
        plinkoLastBucket = idx
        plinkoLastMult = mult
        return (idx, mult)
    }

    private func playWheelSpin() async -> (index: Int, label: String, mult: Double, won: Bool) {
        let result = await play(action: "spin", payload: ["stake": stakeAmount])
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
    private func play(action: String, payload: [String: Any] = [:], minesEpoch: Int? = nil, hiloEpoch: Int? = nil, towerEpoch: Int? = nil) async -> ArcadePlayResponse? {
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
        do {
            let result = try await api.arcadePlay(gameId: arcadeApiGameId, action: action, payload: payload)
            error = nil
            applyResult(result, action: action, minesEpoch: minesEpoch, hiloEpoch: hiloEpoch, towerEpoch: towerEpoch)
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

    private func applyResult(_ result: ArcadePlayResponse, action: String, minesEpoch: Int? = nil, hiloEpoch: Int? = nil, towerEpoch: Int? = nil) {
        if let w = result.wallet { sync.applyWalletFromServer(w) }
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

        if arcadeApiGameId == "nfg_tower" {
            applyTowerResult(result, action: action, towerEpoch: towerEpoch)
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

    private func applyTowerResult(_ result: ArcadePlayResponse, action: String, towerEpoch: Int?) {
        if action == "status", let towerEpoch, towerEpoch < towerStatusEpoch {
            return
        }
        if let tower = result.tower {
            towerRPG = tower
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
