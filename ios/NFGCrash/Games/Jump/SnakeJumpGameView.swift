import SwiftUI

enum JumpPlayMode: String, CaseIterable, Identifiable {
    case solo = "Solo"
    case vs = "VS"

    var id: String { rawValue }
}

struct SnakeJumpGameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncClient
    @StateObject private var canvas = SnakeJumpCanvasController()
    @State private var api: GameAPI?
    @State private var playStatus: ArcadePlayResponse?
    @State private var sessionPoints = 0
    @State private var jumpTotalEarned = 0
    @State private var offlinePendingPoints = 0
    @State private var offlinePendingHeight = 0
    @State private var bestHeight = 0
    @State private var rewardPreview = SnakeJumpEngine.milestoneReward
    @State private var balance = 0
    @State private var shopItems: [JumpShopItem] = JumpShopCatalog.fallback
    @State private var equippedSkin = "classic"
    @State private var ownedSkins: [String] = ["classic"]
    @State private var skinFill = "#596ff2"
    @State private var skinRing = "#f2c733"
    @State private var message = ""
    @State private var playMode: JumpPlayMode = .solo
    @State private var vsClient: JumpVSClient?
    @State private var vsSnapshot: JumpVsSnapshot?
    @State private var vsMatchSeed: Int?
    @State private var vsMatchId: String?
    @State private var vsMatchStartedAtMs: Int64?
    @State private var vsConnecting = false
    @State private var showShop = false
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showPlaySession = false
    @State private var showRunSummary = false
    @State private var lastRunHeight = 0
    @State private var lastRunPointsEarned = 0
    @State private var leaderboardRefresh = 0

    var body: some View {
        lobbyContent
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 5 / 255, green: 8 / 255, blue: 16 / 255),
                        NFGTheme.background,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("NFG Jump")
            .navigationBarTitleDisplayMode(.inline)
            .arcadeGameNavigationLock()
            .arcadeGameBackButton { dismiss() }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showShop) {
                JumpShopSheet(
                    balance: balance,
                    items: shopItems,
                    onBuy: { itemId in await buySkin(itemId) },
                    onEquip: { itemId in await equipSkin(itemId) },
                    onDismiss: { showShop = false }
                )
            }
            .sheet(isPresented: $showRunSummary) {
                SnakeJumpRunSummarySheet(
                    peakHeight: lastRunHeight,
                    pointsEarned: lastRunPointsEarned,
                    jumpTotalEarned: jumpTotalEarned,
                    personalBest: bestHeight,
                    isNewBest: lastRunHeight >= bestHeight && lastRunHeight > 0
                )
            }
            .fullScreenCover(isPresented: $showPlaySession) {
                SnakeJumpPlaySessionView(
                    canvas: canvas,
                    skinFill: skinFill,
                    skinRing: skinRing,
                    offlinePendingPoints: offlinePendingPoints,
                    rewardPreview: rewardPreview,
                    bestHeight: bestHeight,
                    onClose: { closePlaySession() }
                )
                .interactiveDismissDisabled()
            }
            .task {
                await bootstrap()
            }
            .onReceive(NotificationCenter.default.publisher(for: .arcadeOfflineQueueDidChange)) { _ in
                refreshOfflinePending()
            }
            .onDisappear {
                vsClient?.disconnect()
            }
    }

    private var lobbyContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                ArcadeSkillLobbyChrome(
                    gameId: "nfg_snake_jump",
                    title: "NFG JUMP",
                    subtitle: playMode == .vs
                        ? "VS mode — join the lobby, wait for rivals, then race together"
                        : "Emoji climb · +3,000 pts every 2,500m · slide thumb to steer",
                    titleColors: [
                        SnakeJumpTheme.swiftColor(hex: skinFill, fallback: NFGTheme.accent),
                        .white,
                    ],
                    stats: [
                        ArcadeSkillLobbyStat(
                            text: "Best \(bestHeight)m",
                            icon: "trophy.fill",
                            tint: SnakeJumpTheme.swiftColor(hex: skinRing, fallback: NFGTheme.gold)
                        ),
                        ArcadeSkillLobbyStat(
                            text: "Total \(jumpTotalEarned.formatted())",
                            icon: "star.fill",
                            tint: NFGTheme.accent2
                        ),
                        ArcadeSkillLobbyStat(
                            text: "+\(rewardPreview)/\(SnakeJumpEngine.milestoneStep.formatted())m",
                            icon: "gift.fill",
                            tint: NFGTheme.gold
                        ),
                    ],
                    previewSystemImage: playMode == .vs ? "person.3.fill" : "hand.draw.fill",
                    previewTitle: playMode == .vs ? "Multiplayer VS lobby" : "Tap Play for a locked game window",
                    previewSubtitle: playMode == .vs
                        ? "2+ players trigger a 15s countdown — winner takes the pot"
                        : "No page scroll during play — fixed stage, smooth touch",
                    previewAccent: playMode == .vs
                        ? NFGTheme.accent2
                        : SnakeJumpTheme.swiftColor(hex: skinRing, fallback: NFGTheme.gold),
                    playTint: playMode == .vs ? NFGTheme.accent2 : SnakeJumpTheme.swiftColor(hex: skinFill, fallback: NFGTheme.accent),
                    isLoading: isLoading,
                    offlinePendingPoints: offlinePendingPoints,
                    offlinePendingHeight: offlinePendingHeight,
                    playTitle: vsPlayButtonTitle,
                    playDisabled: vsPlayButtonDisabled,
                    onPlay: { Task { await handlePrimaryPlayAction() } },
                    middleContent: { hudRow },
                    footerContent: {
                        if playMode == .vs {
                            vsLobbyPanel
                        }
                    }
                )
                jumpLeaderboard
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(NFGTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
    }

    private var jumpLeaderboard: some View {
        ArcadeInGameLeaderboard(
            gameId: "nfg_snake_jump",
            scoreSuffix: "m",
            showJumpSkins: true,
            fetchLimit: 10
        )
        .id(leaderboardRefresh)
    }

    private func preparePlaySession() {
        let w = max(UIScreen.main.bounds.width - 32, 280)
        canvas.resetSteering()
        canvas.running = false
        canvas.sessionActive = false
        if playMode == .vs, let seed = vsMatchSeed {
            canvas.configureMatchSeed(seed)
            canvas.resetEngine(
                viewWidth: SnakeJumpEngine.vsCanonicalViewWidth,
                matchSeed: seed,
                matchStartedAtMs: vsMatchStartedAtMs
            )
        } else {
            canvas.configureMatchSeed(nil)
            canvas.resetEngine(viewWidth: Double(w))
        }
        canvas.skinFill = skinFill
        canvas.skinRing = skinRing
        canvas.sessionPoints = sessionPoints
        canvas.lifetimeJumpEarned = jumpTotalEarned
        canvas.engine.milestonesClaimed = playStatus?.sessionMilestones ?? 0
    }

    private func closePlaySession() {
        if canvas.running || canvas.sessionActive {
            let height = canvas.engine.currentHeight
            Task { await endRun(height: height) }
        }
        canvas.resetSteering()
        canvas.running = false
        canvas.sessionActive = false
        sessionPoints = 0
        canvas.sessionPoints = 0
        leaderboardRefresh += 1
        showPlaySession = false
    }

    private func toggleVsMode() {
        if playMode == .solo {
            guard PlayerSession.isLoggedIn else {
                message = "Sign in to use Jump VS multiplayer."
                return
            }
            playMode = .vs
            joinVs()
        } else {
            playMode = .solo
            leaveVs()
        }
    }

    private var vsPlayerCount: Int {
        vsSnapshot?.players.count ?? vsClient?.players.count ?? 0
    }

    private var vsPlayButtonTitle: String {
        guard playMode == .vs else { return "Play" }
        if vsConnecting || (vsClient != nil && vsClient?.isConnected != true) {
            return "Connecting…"
        }
        if vsClient == nil {
            return "Join VS Lobby"
        }
        switch vsSnapshot?.phase ?? "waiting" {
        case "countdown":
            return "Starting in \(vsSnapshot?.countdownSeconds ?? 0)s…"
        case "match":
            return showPlaySession ? "Match live" : "Start VS Match"
        case "results":
            return "Back to VS Lobby"
        default:
            return vsPlayerCount >= 2 ? "Waiting for countdown…" : "Waiting for players (\(vsPlayerCount)/2)…"
        }
    }

    private var vsPlayButtonDisabled: Bool {
        guard playMode == .vs else { return false }
        if vsConnecting { return true }
        if vsClient == nil { return false }
        if vsClient?.isConnected != true { return true }
        switch vsSnapshot?.phase ?? "waiting" {
        case "match":
            return showPlaySession
        case "results":
            return false
        default:
            return true
        }
    }

    @MainActor
    private func handlePrimaryPlayAction() async {
        if playMode == .solo {
            await openPlaySession()
            return
        }
        if vsClient == nil {
            joinVs()
            return
        }
        if vsSnapshot?.phase == "results" {
            vsSnapshot = nil
            joinVs()
            return
        }
        if vsSnapshot?.phase == "match", vsMatchSeed != nil, !showPlaySession {
            await openPlaySession()
        }
    }

    private var hudRow: some View {
        HStack(spacing: 8) {
            JumpVsToggleButton(isVS: playMode == .vs) {
                toggleVsMode()
            }
            if playMode == .vs {
                if vsConnecting {
                    Text("Connecting to VS…")
                        .foregroundStyle(NFGTheme.muted)
                } else if let vsSnapshot {
                    Text("VS · \(vsSnapshot.players.count) in lobby · \(vsPhaseLabel)")
                        .foregroundStyle(NFGTheme.accent2)
                } else if vsClient != nil {
                    Text("VS · joining lobby…")
                        .foregroundStyle(NFGTheme.accent2)
                } else {
                    Text("VS · tap Join below")
                        .foregroundStyle(NFGTheme.muted)
                }
            } else {
                Text("Solo climb")
            }
            Spacer(minLength: 0)
            JumpShopButton { showShop = true }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(NFGTheme.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var vsLobbyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Jump VS Lobby", systemImage: "person.3.fill")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(vsPhaseLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent2)
            }

            Text(vsHelpText)
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)

            if let players = vsSnapshot?.players, !players.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(SnakeJumpTheme.swiftColor(hex: player.fill ?? "#596ff2", fallback: NFGTheme.accent))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(SnakeJumpTheme.swiftColor(hex: player.ring ?? "#f2c733", fallback: NFGTheme.gold), lineWidth: 2)
                                    )
                                    .overlay {
                                        if player.id == AuthStore.verifiedUserId {
                                            Text("You")
                                                .font(.system(size: 8, weight: .heavy))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                Text(player.displayName ?? "Player")
                                    .font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1)
                                    .frame(maxWidth: 72)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if vsConnecting || (vsClient != nil && vsClient?.isConnected != true) {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Connecting to multiplayer…")
                        .font(.system(size: 12))
                        .foregroundStyle(NFGTheme.muted)
                }
            } else if let players = vsSnapshot?.players, !players.isEmpty {
                VStack(spacing: 6) {
                    ForEach(players) { player in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(SnakeJumpTheme.swiftColor(hex: player.fill ?? "#596ff2", fallback: NFGTheme.accent))
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(SnakeJumpTheme.swiftColor(hex: player.ring ?? "#f2c733", fallback: NFGTheme.gold), lineWidth: 1))
                            Text(player.displayName ?? player.id)
                                .lineLimit(1)
                            if player.id == AuthStore.verifiedUserId {
                                Text("You")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(NFGTheme.accent2)
                            }
                            Spacer(minLength: 0)
                            if player.eliminated == true {
                                Text("Out")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(NFGTheme.danger)
                            } else if vsSnapshot?.phase == "match" {
                                Text("\(player.height ?? 0)m")
                                    .monospacedDigit()
                            } else {
                                Text("Ready")
                                    .foregroundStyle(NFGTheme.muted)
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                }
            } else if vsClient != nil {
                Text("You're in the lobby — waiting for other players to join…")
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
            } else {
                Text("Tap Join VS Lobby to enter matchmaking.")
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
            }

            if vsSnapshot?.phase == "countdown", let sec = vsSnapshot?.countdownSeconds {
                Text("Match starts in \(sec)s — tap Start VS Match when the countdown hits 0")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NFGTheme.gold)
            }

            HStack(spacing: 8) {
                if vsClient == nil {
                    Button("Join VS Lobby") {
                        joinVs()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NFGTheme.accent2)
                } else {
                    Button("Leave Lobby") {
                        playMode = .solo
                        leaveVs()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.accent2.opacity(0.35)))
    }

    @MainActor
    private func openPlaySession() async {
        await startRunOnServer()
        preparePlaySession()
        showPlaySession = true
        if playMode == .vs, vsMatchSeed != nil {
            let w = max(UIScreen.main.bounds.width - 32, 280)
            canvas.autoStartVSMatch(viewWidth: w, startedAtMs: vsMatchStartedAtMs)
        }
    }

    @MainActor
    private func startRunOnServer() async {
        if let api {
            await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
            await JumpPendingRunStore.flush(api: api, sync: sync)
            refreshOfflinePending()
            var payload: [String: Any] = [:]
            if playMode == .vs, let vsMatchId {
                payload["vsMatchId"] = vsMatchId
            }
            do {
                let res = try await api.arcadePlay(
                    gameId: "nfg_snake_jump",
                    action: "start",
                    payload: payload
                )
                applyStatus(res, action: "start")
            } catch {
                sessionPoints = 0
                canvas.engine.milestonesClaimed = 0
                message = error.localizedDescription
            }
        } else {
            sessionPoints = 0
            canvas.engine.milestonesClaimed = 0
        }
    }

    private var vsPhaseLabel: String {
        guard let vsSnapshot else { return "Lobby" }
        switch vsSnapshot.phase {
        case "countdown": return "Starting in \(vsSnapshot.countdownSeconds)s"
        case "match": return vsSnapshot.eliminated ? "Eliminated" : "Match live"
        case "results": return "Results"
        default: return "Lobby"
        }
    }

    private var vsHelpText: String {
        guard let vsSnapshot else {
            return "2+ players start a 15s countdown. Winner takes the combined pot."
        }
        switch vsSnapshot.phase {
        case "countdown":
            return "\(vsSnapshot.players.count) players — match starts in \(vsSnapshot.countdownSeconds)s"
        case "match":
            return "Stay within one milestone of the leader or you're eliminated!"
        case "results":
            if let winnerId = vsSnapshot.winnerId {
                return "Winner \(winnerId) takes \(vsSnapshot.pot.formatted()) pts"
            }
            return "Match ended."
        default:
            return "2+ players start a 15s countdown. Winner takes the combined pot."
        }
    }

    @MainActor
    private func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        applyLocalShopFallback()
        refreshOfflinePending()
        refreshJumpTotals()
        syncPersonalBest(serverBest: 0)
        do {
            let client = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            api = client
            wireCanvasCallbacks()
            let synced = await ArcadeOfflinePointsQueue.flush(api: client, sync: sync)
            if synced > 0 {
                message = "Synced \(synced) offline arcade reward\(synced == 1 ? "" : "s")."
            }
            refreshOfflinePending()
            if await JumpPendingRunStore.flush(api: client, sync: sync) {
                let status = try await client.arcadePlay(gameId: "nfg_snake_jump", action: "status")
                applyStatus(status)
                message = "Synced local Jump high score to the server."
            }
            let status = try await client.arcadePlay(gameId: "nfg_snake_jump", action: "status")
            applyStatus(status)
            if let data = try? await client.fetchProfileAvatar(), let img = UIImage(data: data) {
                canvas.profileImage = img
            }
        } catch {
            loadError = error.localizedDescription
            message = "Offline mode — points save locally and sync later."
            applyLocalShopFallback()
        }
    }

    private func wireCanvasCallbacks() {
        canvas.skinFill = skinFill
        canvas.skinRing = skinRing
        canvas.onMilestone = { await claimMilestone() }
        canvas.onGameOver = { height in
            let earnedThisRun = sessionPoints
            await endRun(height: height)
            await MainActor.run {
                lastRunHeight = height
                lastRunPointsEarned = earnedThisRun
                showRunSummary = true
            }
        }
        canvas.onProgressTick = { height, points in
            let userKey = ArcadeOfflinePointsQueue.userKey()
            NFGJumpPersonalBest.save(for: userKey, height: height)
        }
        canvas.onVsNetworkTick = { playerX, playerY, velocityY, height, points, elapsed in
            vsClient?.reportLiveState(
                playerX: playerX,
                playerY: playerY,
                velocityY: velocityY,
                height: height,
                sessionPoints: points,
                elapsed: elapsed
            )
        }
    }

    private func refreshJumpTotals() {
        let userKey = ArcadeOfflinePointsQueue.userKey()
        jumpTotalEarned = NFGJumpLocalEarnedStore.load(for: userKey)
        canvas.lifetimeJumpEarned = jumpTotalEarned
    }

    private func recordJumpPointsEarned(_ points: Int) {
        guard points > 0 else { return }
        let userKey = ArcadeOfflinePointsQueue.userKey()
        jumpTotalEarned = NFGJumpLocalEarnedStore.add(points, for: userKey)
        canvas.lifetimeJumpEarned = jumpTotalEarned
    }

    private func refreshOfflinePending() {
        let userKey = ArcadeOfflinePointsQueue.userKey()
        offlinePendingPoints = ArcadeOfflinePointsQueue.pendingPoints(for: "nfg_snake_jump")
        offlinePendingHeight = JumpPendingRunStore.pendingHeight(for: userKey)
    }

    private func syncPersonalBest(serverBest: Int) {
        let userKey = ArcadeOfflinePointsQueue.userKey()
        bestHeight = NFGJumpPersonalBest.merged(serverBest: serverBest, for: userKey)
    }

    private func applyLocalShopFallback() {
        let userKey = ArcadeOfflinePointsQueue.userKey()
        let local = JumpShopLocalStore.load(for: userKey)
        ownedSkins = Array(local.owned).sorted()
        equippedSkin = local.equipped
        shopItems = JumpShopCatalog.withOwnership(equippedId: equippedSkin, ownedSkins: local.owned)
        if let cosmetics = JumpShopCatalog.cosmetics(for: equippedSkin) {
            skinFill = cosmetics.fill
            skinRing = cosmetics.ring
            canvas.skinFill = skinFill
            canvas.skinRing = skinRing
        }
    }

    private func persistShopLocally() {
        let userKey = ArcadeOfflinePointsQueue.userKey()
        JumpShopLocalStore.save(ownedIds: Set(ownedSkins), equippedId: equippedSkin, for: userKey)
    }

    @MainActor
    private func applyStatus(_ status: ArcadePlayResponse, action: String? = nil) {
        ArcadePointsBridge.applyToGlobalWallet(status, sync: sync)
        playStatus = status
        if action == "start" {
            sessionPoints = 0
            canvas.engine.milestonesClaimed = 0
        } else if action == "milestone" {
            let reward = max(status.gained ?? 0, SnakeJumpEngine.milestoneReward)
            sessionPoints += reward
            recordJumpPointsEarned(reward)
            canvas.engine.milestonesClaimed = status.sessionMilestones ?? canvas.engine.milestonesClaimed
        } else if action == "game_over" {
            canvas.engine.milestonesClaimed = status.sessionMilestones ?? canvas.engine.milestonesClaimed
        } else if showPlaySession && (canvas.sessionActive || canvas.running) {
            if let sp = status.sessionPoints { sessionPoints = sp }
            canvas.engine.milestonesClaimed = status.sessionMilestones ?? canvas.engine.milestonesClaimed
        } else {
            sessionPoints = 0
            canvas.engine.milestonesClaimed = status.sessionMilestones ?? canvas.engine.milestonesClaimed
        }

        let userKey = ArcadeOfflinePointsQueue.userKey()
        refreshJumpTotals()
        if jumpTotalEarned == 0, let serverTotal = status.totalJumpEarned, serverTotal > 0 {
            NFGJumpLocalEarnedStore.set(serverTotal, for: userKey)
            jumpTotalEarned = serverTotal
            canvas.lifetimeJumpEarned = jumpTotalEarned
        }
        var serverBest = status.bestLevel ?? 0
        if let score = status.score { serverBest = max(serverBest, score) }
        syncPersonalBest(serverBest: serverBest)
        rewardPreview = status.levelRewardPreview ?? SnakeJumpEngine.milestoneReward
        balance = status.balance ?? balance
        shopItems = JumpShopCatalog.merged(
            serverItems: status.jumpShop,
            equippedId: status.equippedSkin ?? equippedSkin,
            ownedSkins: status.ownedSkins ?? ownedSkins
        )
        equippedSkin = status.equippedSkin ?? equippedSkin
        ownedSkins = status.ownedSkins ?? ownedSkins
        skinFill = status.skinFill ?? skinFill
        skinRing = status.skinRing ?? skinRing
        canvas.skinFill = skinFill
        canvas.skinRing = skinRing
        canvas.sessionPoints = sessionPoints
        canvas.lifetimeJumpEarned = jumpTotalEarned
        persistShopLocally()
        refreshOfflinePending()
        leaderboardRefresh += 1
    }

    @MainActor
    private func claimMilestone() async {
        let height = canvas.engine.currentHeight
        guard let api else {
            queueOfflineMilestone(height: height)
            return
        }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_snake_jump",
                action: "milestone",
                payload: ["height": height]
            )
            applyStatus(res, action: "milestone")
            canvas.engine.milestonesClaimed = res.sessionMilestones ?? canvas.engine.milestonesClaimed + 1
            message = res.message ?? "Milestone! +\(SnakeJumpEngine.milestoneReward.formatted()) pts"
            refreshOfflinePending()
        } catch {
            queueOfflineMilestone(height: height)
            message = "+\(SnakeJumpEngine.milestoneReward.formatted()) pts saved offline"
        }
    }

    private func queueOfflineMilestone(height: Int? = nil) {
        let h = height ?? canvas.engine.currentHeight
        let reward = SnakeJumpEngine.milestoneReward
        ArcadeOfflinePointsQueue.enqueue(
            gameId: "nfg_snake_jump",
            action: "milestone",
            payload: ["height": h],
            estimatedPoints: reward
        )
        canvas.engine.milestonesClaimed += 1
        sessionPoints += reward
        recordJumpPointsEarned(reward)
        canvas.sessionPoints = sessionPoints
        refreshOfflinePending()
    }

    @MainActor
    private func endRun(height: Int) async {
        if playMode == .vs {
            vsClient?.sendForfeit()
        }

        let userKey = ArcadeOfflinePointsQueue.userKey()
        NFGJumpPersonalBest.save(for: userKey, height: height)
        syncPersonalBest(serverBest: max(bestHeight, height))

        guard let api else {
            JumpPendingRunStore.enqueue(height: height, for: userKey)
            refreshOfflinePending()
            message = "Run over at \(height)m — saved locally, will sync when online."
            return
        }

        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_snake_jump",
                action: "game_over",
                payload: ["height": height]
            )
            applyStatus(res, action: "game_over")
            let peak = res.score ?? height
            NFGJumpPersonalBest.save(for: userKey, height: peak)
            syncPersonalBest(serverBest: max(bestHeight, peak))
            if await JumpPendingRunStore.flush(api: api, sync: sync) {
                let status = try await api.arcadePlay(gameId: "nfg_snake_jump", action: "status")
                applyStatus(status)
            }
            message = res.message ?? "Run over at \(height)m"
            refreshOfflinePending()
        } catch {
            JumpPendingRunStore.enqueue(height: height, for: userKey)
            refreshOfflinePending()
            message = "Run over at \(height)m — saved locally, will sync when online."
        }
    }

    @MainActor
    private func buySkin(_ itemId: String) async -> SnakeJumpShopOutcome {
        guard let api else {
            guard let item = shopItems.first(where: { $0.id == itemId }),
                  let cost = item.cost, balance >= cost || cost == 0 else {
                return .failure("Not enough points.")
            }
            JumpShopLocalStore.recordPurchase(itemId: itemId, for: ArcadeOfflinePointsQueue.userKey())
            applyLocalShopFallback()
            return .success("Purchased offline — will sync when online.")
        }
        do {
            let res = try await api.arcadePlay(gameId: "nfg_snake_jump", action: "buy", payload: ["itemId": itemId])
            applyStatus(res)
            vsClient?.updateHooks(makeVsHooks())
            return .success(res.message ?? "Purchased!")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    @MainActor
    private func equipSkin(_ itemId: String) async -> SnakeJumpShopOutcome {
        guard let api else {
            JumpShopLocalStore.recordEquip(itemId: itemId, for: ArcadeOfflinePointsQueue.userKey())
            applyLocalShopFallback()
            return .success("Equipped locally.")
        }
        do {
            let res = try await api.arcadePlay(gameId: "nfg_snake_jump", action: "equip", payload: ["itemId": itemId])
            applyStatus(res)
            vsClient?.updateHooks(makeVsHooks())
            return .success(res.message ?? "Equipped!")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func makeVsHooks() -> JumpVSClient.Hooks {
        var hooks = JumpVSClient.Hooks()
        hooks.skinId = equippedSkin
        hooks.fill = skinFill
        hooks.ring = skinRing
        hooks.onConnected = {
            Task { @MainActor in
                vsConnecting = false
                message = "In VS lobby — waiting for rivals…"
            }
        }
        hooks.onDisconnected = {
            Task { @MainActor in
                vsConnecting = false
                if playMode == .vs {
                    message = "Disconnected from VS lobby."
                }
            }
        }
        hooks.onLobbyState = { state in
            Task { @MainActor in
                vsConnecting = false
                vsSnapshot = state
            }
        }
        hooks.onMatchStart = { state in
            Task { @MainActor in
                vsConnecting = false
                vsSnapshot = state
                vsMatchSeed = state.matchSeed
                vsMatchId = state.matchId
                vsMatchStartedAtMs = state.matchStartedAtMs
                canvas.configureMatchSeed(state.matchSeed)
                canvas.applyLiveOpponents(state.opponents)
                message = "VS match started — tap Start VS Match!"
                if !showPlaySession, state.matchSeed != nil {
                    await openPlaySession()
                }
            }
        }
        hooks.onOpponentUpdate = { opp in
            Task { @MainActor in
                canvas.applyOpponentUpdate(opp)
            }
        }
        hooks.onEliminated = { reason in
            Task { @MainActor in
                message = "Eliminated — \(reason)"
                canvas.running = false
                canvas.sessionActive = false
            }
        }
        hooks.onMatchEnd = { msg in
            Task { @MainActor in
                vsMatchSeed = nil
                vsMatchId = nil
                vsMatchStartedAtMs = nil
                vsSnapshot = JumpVsSnapshot(
                    phase: "results",
                    players: vsSnapshot?.players ?? [],
                    countdownSeconds: 0,
                    matchSeed: nil,
                    matchId: nil,
                    matchStartedAtMs: nil,
                    eliminated: false,
                    opponents: [],
                    pot: msg["pot"] as? Int ?? 0,
                    winnerId: msg["winnerId"] as? String
                )
            }
        }
        hooks.onError = { err in
            Task { @MainActor in
                vsConnecting = false
                message = err
            }
        }
        return hooks
    }

    private func joinVs() {
        guard PlayerSession.isLoggedIn else {
            message = "Sign in to use Jump VS multiplayer."
            return
        }
        guard let api else {
            message = "Connect to the server to use Jump VS."
            return
        }
        vsConnecting = true
        message = "Connecting to Jump VS…"
        let client = JumpVSClient(api: api, hooks: makeVsHooks())
        vsClient = client
        do {
            try client.connect()
        } catch {
            vsConnecting = false
            message = error.localizedDescription
            vsClient = nil
        }
    }

    private func leaveVs() {
        vsConnecting = false
        vsClient?.disconnect()
        vsClient = nil
        vsSnapshot = nil
        vsMatchSeed = nil
        vsMatchId = nil
        vsMatchStartedAtMs = nil
        canvas.clearLiveOpponents()
    }
}

// MARK: - Fixed full-screen play window (no scroll, locked stage)

private struct SnakeJumpPlaySessionView: View {
    @ObservedObject var canvas: SnakeJumpCanvasController
    let skinFill: String
    let skinRing: String
    let offlinePendingPoints: Int
    let rewardPreview: Int
    let bestHeight: Int
    let onClose: () -> Void

    private var displaySessionPoints: Int {
        canvas.sessionPoints
    }

    var body: some View {
        GeometryReader { geo in
            let safeW = geo.size.width
            let maxStageH = safeW * (16 / 10)
            let stageH = min(geo.size.height - 72, maxStageH)

            ZStack {
                Color(red: 5 / 255, green: 8 / 255, blue: 14 / 255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    playSessionHeader
                        .frame(height: 44)

                    Spacer(minLength: 0)

                    ArcadeSkillStageFrame(gameId: "nfg_snake_jump") {
                        SnakeJumpCanvasHost(controller: canvas)
                            .frame(width: safeW - 16, height: stageH)
                    }
                    .frame(width: safeW - 16, height: stageH)
                    .padding(.horizontal, 8)

                    Spacer(minLength: 0)

                    playSessionFooter
                        .frame(height: 28)
                }
                .frame(width: safeW, height: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .preferredColorScheme(.dark)
    }

    private var playSessionHeader: some View {
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
            Text("\(canvas.engine.currentHeight)m")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(SnakeJumpTheme.swiftColor(hex: skinFill, fallback: NFGTheme.accent))
                .monospacedDigit()
            Text("Best \(bestHeight)m")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
            VStack(alignment: .trailing, spacing: 1) {
                Text("This run \(displaySessionPoints.formatted())")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent2)
                Text("Jump total \(canvas.lifetimeJumpEarned.formatted())")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var playSessionFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
            Text("Slide thumb on stage — emoji follows under your finger")
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(NFGTheme.muted)
        .padding(.horizontal, 12)
    }
}
