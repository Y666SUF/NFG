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
                    subtitle: "Emoji climb · +3,000 pts every 2,500m · slide thumb to steer",
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
                            text: "Run \(displaySessionPoints.formatted())",
                            icon: "star.fill",
                            tint: NFGTheme.accent2
                        ),
                        ArcadeSkillLobbyStat(
                            text: "+\(rewardPreview)/\(SnakeJumpEngine.milestoneStep.formatted())m",
                            icon: "gift.fill",
                            tint: NFGTheme.gold
                        ),
                    ],
                    previewSystemImage: "hand.draw.fill",
                    previewTitle: "Tap Play for a locked game window",
                    previewSubtitle: "No page scroll during play — fixed stage, smooth touch",
                    previewAccent: SnakeJumpTheme.swiftColor(hex: skinRing, fallback: NFGTheme.gold),
                    playTint: SnakeJumpTheme.swiftColor(hex: skinFill, fallback: NFGTheme.accent),
                    isLoading: isLoading,
                    offlinePendingPoints: offlinePendingPoints,
                    offlinePendingHeight: offlinePendingHeight,
                    onPlay: { Task { await openPlaySession() } },
                    middleContent: { hudRow }
                )
                jumpLeaderboard
                if playMode == .vs {
                    vsLobbyPanel
                }
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

    private var displaySessionPoints: Int {
        sessionPoints + offlinePendingPoints
    }

    private func preparePlaySession() {
        let w = max(UIScreen.main.bounds.width - 32, 280)
        canvas.resetSteering()
        canvas.running = false
        canvas.sessionActive = false
        canvas.resetSteering()
        canvas.configureMatchSeed(playMode == .vs ? vsMatchSeed : nil)
        canvas.resetEngine(viewWidth: Double(w))
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
        leaderboardRefresh += 1
        showPlaySession = false
    }

    private func toggleVsMode() {
        if playMode == .solo {
            playMode = .vs
            joinVs()
        } else {
            playMode = .solo
            leaveVs()
        }
    }

    private var hudRow: some View {
        HStack(spacing: 8) {
            JumpVsToggleButton(isVS: playMode == .vs) {
                toggleVsMode()
            }
            if playMode == .vs, let vsSnapshot {
                Text("VS lobby · \(vsSnapshot.opponents.count) waiting")
                    .foregroundStyle(NFGTheme.accent2)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Jump VS")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(vsPhaseLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent)
            }
            Text(vsHelpText)
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
            if let players = vsSnapshot?.players, !players.isEmpty {
                ForEach(players) { player in
                    HStack {
                        Text(player.displayName ?? player.id)
                        Spacer()
                        Text("\(player.height ?? 0)m")
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                }
            } else {
                Text("Waiting for players…")
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
            }
            HStack {
                if vsClient == nil {
                    Button("Join VS lobby") {
                        joinVs()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NFGTheme.accent)
                } else {
                    Button("Leave lobby") {
                        leaveVs()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    @MainActor
    private func openPlaySession() async {
        await startRunOnServer()
        preparePlaySession()
        showPlaySession = true
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
            vsClient?.reportProgress(height: height, sessionPoints: points)
        }
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
        } else {
            sessionPoints = status.sessionPoints ?? sessionPoints
            canvas.engine.milestonesClaimed = status.sessionMilestones ?? canvas.engine.milestonesClaimed
        }
        jumpTotalEarned = status.totalJumpEarned ?? jumpTotalEarned
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
            applyStatus(res)
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
        jumpTotalEarned += reward
        canvas.sessionPoints = sessionPoints
        canvas.lifetimeJumpEarned = jumpTotalEarned
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
        hooks.onLobbyState = { state in
            Task { @MainActor in
                vsSnapshot = state
            }
        }
        hooks.onMatchStart = { state in
            Task { @MainActor in
                vsSnapshot = state
                vsMatchSeed = state.matchSeed
                vsMatchId = state.matchId
                canvas.configureMatchSeed(state.matchSeed)
            canvas.ghostOpponents = JumpVSClient.ghostOpponents(from: state.opponents)
            }
        }
        hooks.onOpponents = { opponents in
            Task { @MainActor in
                canvas.ghostOpponents = JumpVSClient.ghostOpponents(from: opponents)
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
                vsSnapshot = JumpVsSnapshot(
                    phase: "results",
                    players: vsSnapshot?.players ?? [],
                    countdownSeconds: 0,
                    matchSeed: nil,
                    matchId: nil,
                    eliminated: false,
                    opponents: [],
                    pot: msg["pot"] as? Int ?? 0,
                    winnerId: msg["winnerId"] as? String
                )
            }
        }
        hooks.onError = { err in
            Task { @MainActor in message = err }
        }
        return hooks
    }

    private func joinVs() {
        guard let api else { return }
        let client = JumpVSClient(api: api, hooks: makeVsHooks())
        vsClient = client
        do {
            try client.connect()
            message = "Connecting to Jump VS…"
        } catch {
            message = error.localizedDescription
            vsClient = nil
        }
    }

    private func leaveVs() {
        vsClient?.disconnect()
        vsClient = nil
        vsSnapshot = nil
        vsMatchSeed = nil
        vsMatchId = nil
        canvas.ghostOpponents = []
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
        canvas.sessionPoints + offlinePendingPoints
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
