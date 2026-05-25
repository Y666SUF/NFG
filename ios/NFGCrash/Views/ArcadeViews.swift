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

    private var displayGames: [ArcadeGameInfo] {
        ArcadeBundledCatalog.merge(serverGames: catalog?.games)
    }

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
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
            VaultArcadeGameView(game: game)
                .environmentObject(sync)
        }
        .task { await load() }
        .onAppear { Task { await load() } }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(NFGTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vault Arcade")
                        .font(.system(size: 20, weight: .heavy))
                    Text("\(displayGames.count) games · 5 plays/day each · levels get harder")
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
        Text("Connect to load today’s earn cap.")
            .font(.system(size: 11))
            .foregroundStyle(NFGTheme.muted)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func earnBanner(_ cat: ArcadeCatalogResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ArcadeProgressBar(
                progress: Double(cat.earnedToday ?? 0) / Double(max(1, cat.earnCap ?? 150_000)),
                tint: NFGTheme.gold
            )
            Text("\((cat.earnedToday ?? 0).formatted()) / \((cat.earnCap ?? 0).formatted()) pts today")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            if cat.isLive == true {
                Text("+\(Int((cat.liveBonusMultiplier ?? 1) * 100 - 100))% while LIVE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.gold)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            ok: false, earnedToday: nil, earnCap: 150_000, earnLeft: nil,
            liveBonusMultiplier: 1.25, isLive: false, funPoints: nil,
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
    @State private var playsLeft = 5
    @State private var playsPerDay = 5
    @State private var zoneWidth: CGFloat = 0.18

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

    @State private var crashRoundActive = false
    @State private var serverCrashAt: Double?

    @State private var missions: [ArcadeMissionInfo] = []
    @State private var tycoonPending = 0
    @State private var tycoonLevel = 1
    @State private var ladderPoints = 0
    @State private var ladderRank: Int?
    @State private var ladderTop: [ArcadeLadderRow] = []
    @State private var ladderWeekKey = ""
    @State private var ladderTotalPlayers = 0
    @State private var loginStreak = 0
    @State private var spinnerUsedToday = false

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()
            ArcadeAmbientOrbs(tint: ArcadeGameTheme.accent(for: game.id))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    gameControls
                    ArcadeBusyOverlay(busy: busy)
                    ArcadeResultBanner(text: message, isGain: message.hasPrefix("+"))
                    if let error {
                        ArcadeResultBanner(text: error, isError: true)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await play(action: "status") }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var gameControls: some View {
        switch game.id {
        case "vault_tap":
            VaultTapGameView(
                busy: busy, skillLevel: skillLevel, maxLevel: maxSkillLevel,
                playsLeft: playsLeft, playsPerDay: playsPerDay, zoneWidth: zoneWidth,
                message: $message
            ) { score, perfect in
                await play(action: "finish", payload: ["score": score, "perfectTaps": perfect])
            }
        case "daily_safe":
            DailySafeGameView(
                busy: busy, skillLevel: skillLevel, maxLevel: maxSkillLevel,
                playsLeft: playsLeft, playsPerDay: playsPerDay,
                vaultHeat: safeVaultHeat, vaultStatus: safeVaultStatus,
                hintText: safeHint, guessesLeft: safeGuessesLeft, maxGuesses: safeMaxGuesses,
                solved: safeSolved, digitLocks: safeDigitLocks, safeGuess: $safeGuess
            ) { code in
                await play(action: "guess", payload: ["code": code])
            }
        case "scratch":
            ScratchCardGameView(busy: busy, grid: scratchGrid) {
                await play(action: "reveal")
            }
        case "crash_quiz":
            CrashQuizGameView(busy: busy, quizGuess: $quizGuess) { guess in
                await play(action: "answer", payload: ["guess": guess])
            }
        case "streak_spinner":
            StreakSpinnerGameView(
                busy: busy, streak: loginStreak, spunToday: spinnerUsedToday
            ) {
                await play(action: "spin")
            }
        case "vault_heist":
            VaultHeistGameView(
                busy: busy, skillLevel: skillLevel, maxLevel: maxSkillLevel,
                playsLeft: playsLeft, playsPerDay: playsPerDay,
                heistStarted: heistStarted, heistStep: heistStep,
                onStart: {
                    await play(action: "start")
                },
                onPickDoor: { door in
                    await play(action: "pick", payload: ["door": door])
                }
            )
        case "double_nothing":
            DoubleNothingGameView(busy: busy) {
                await play(action: "risk", payload: ["amount": 1500 + skillLevel * 350])
            }
        case "badge_hunt":
            BadgeHuntGameView(busy: busy) { bid in
                await play(action: "find", payload: ["badgeId": bid])
            }
        case "duel":
            VaultDuelGameView(busy: busy) {
                let score = 55 + skillLevel * 3 + Int.random(in: 0...12)
                await play(action: "submit", payload: ["score": score])
            }
        case "arcade_missions":
            ArcadeMissionsGameView(busy: busy, missions: missions, onRefresh: {
                await play(action: "status")
            }, onClaim: { mid in
                await play(action: "claim", payload: ["missionId": mid])
            })
        case "crash_course":
            CrashCourseGameView(
                busy: busy, skillLevel: skillLevel, maxLevel: maxSkillLevel,
                playsLeft: playsLeft, playsPerDay: playsPerDay,
                roundActive: crashRoundActive, serverCrashAt: serverCrashAt,
                onStart: { await play(action: "start") },
                onCashout: { mult in
                    await play(action: "cashout", payload: ["multiplier": mult])
                }
            )
        case "tycoon":
            VaultTycoonGameView(
                busy: busy, pending: tycoonPending, level: tycoonLevel,
                onCollect: { await play(action: "collect") },
                onUpgrade: { await play(action: "upgrade") }
            )
        case "season_ladder":
            SeasonLadderGameView(
                busy: busy, yourPoints: ladderPoints, rank: ladderRank, top: ladderTop,
                weekKey: ladderWeekKey, totalPlayers: ladderTotalPlayers,
                onRefresh: { await play(action: "status") }
            )
        default:
            ArcadeStageCard(gameId: game.id, icon: game.icon, title: game.title, subtitle: game.subtitle) {
                ArcadePrimaryButton(title: "Refresh", icon: "arrow.clockwise", tint: NFGTheme.accent2, disabled: busy) {
                    Task { await play(action: "status") }
                }
            }
        }
    }

    private func play(action: String, payload: [String: Any] = [:]) async {
        guard let api = sync.apiForArcade() else {
            if action == "status" {
                message = "Link TikTok in Profile to sync arcade plays."
            } else {
                error = "Link TikTok in Profile first."
            }
            return
        }
        busy = true
        if action != "status" { error = nil }
        defer { busy = false }
        do {
            let result = try await api.arcadePlay(gameId: game.id, action: action, payload: payload)
            error = nil
            applyResult(result, action: action)
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
        }
    }

    private func applyResult(_ result: ArcadePlayResponse, action: String) {
        if let w = result.wallet { sync.applyWalletFromServer(w) }

        if let lv = result.skillLevel { skillLevel = lv }
        if let mx = result.maxSkillLevel { maxSkillLevel = mx }
        if let left = result.playsLeft { playsLeft = left }
        if let ppd = result.playsPerDay { playsPerDay = ppd }
        if let zw = result.zoneWidth { zoneWidth = CGFloat(zw) }

        if let grid = result.grid { scratchGrid = grid }
        syncArcadeMeta(from: result)
        if let p = result.pending { tycoonPending = p }
        if let lv = result.level { tycoonLevel = lv }
        if let yp = result.yourPoints { ladderPoints = yp }
        if let r = result.rank { ladderRank = r }
        if let top = result.top { ladderTop = top }

        if result.active != nil || action == "start" && game.id == "vault_heist" {
            heistStarted = result.active != nil || (result.message?.contains("started") == true)
        }
        if result.bust == true || result.cleared == true {
            heistStarted = false
            heistStep = 0
        } else if let step = result.active?.step {
            heistStep = step + 1
            heistStarted = true
        } else if action == "pick" {
            heistStep += 1
        }

        if game.id == "crash_course" {
            if action == "start", let cap = result.crashAt {
                crashRoundActive = true
                serverCrashAt = cap
            }
            if action == "cashout" || result.win == false {
                crashRoundActive = false
                serverCrashAt = nil
            }
            if action == "status", let cap = result.crashAt {
                crashRoundActive = true
                serverCrashAt = cap
            }
        }

        if game.id == "daily_safe" {
            syncDailySafe(from: result, action: action)
        }

        if let g = result.gained, g > 0 {
            message = "+\(g.formatted()) pts"
        } else if let msg = result.message, !msg.isEmpty {
            message = msg
        } else if action == "status" {
            message = playsLeft > 0 ? "Ready — \(playsLeft) plays left today (Lv \(skillLevel))" : "No plays left today"
        }
    }

    private func syncDailySafe(from result: ArcadePlayResponse, action: String) {
        if let heat = result.vaultHeat { safeVaultHeat = heat }
        if let status = result.vaultStatus, !status.isEmpty { safeVaultStatus = status }
        if let hint = result.hint, !hint.isEmpty { safeHint = hint }
        if let left = result.guessesLeft { safeGuessesLeft = left }
        if let max = result.maxAttempts { safeMaxGuesses = max }
        if let solved = result.solved { safeSolved = solved }
        if let locks = result.digitLocks { safeDigitLocks = locks }
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
        if let arc = result.arcade {
            if let m = arc.missions, !m.isEmpty { missions = m }
            if let s = arc.season {
                if let p = s.points { ladderPoints = p }
                if let r = s.rank { ladderRank = r }
            }
        }
        if let s = result.season {
            if let p = s.points { ladderPoints = p }
            if let r = s.rank { ladderRank = r }
        }
    }
}

extension SyncClient {
    func apiForArcade() -> GameAPI? {
        guard PlayerSession.isLoggedIn else { return nil }
        return try? GameAPI(baseURLString: PlayerSession.serverBaseURL)
    }
}
