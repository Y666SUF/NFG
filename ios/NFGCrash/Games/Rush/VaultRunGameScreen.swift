import SwiftUI

struct VaultRunGameScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncClient
    @State private var api: GameAPI?
    @State private var busy = false
    @State private var sessionPoints = 0
    @State private var offlinePendingPoints = 0
    @State private var rewardPreview = 3000
    @State private var sessionActive = false
    @State private var bestDistance = 0
    @State private var milestonesClaimed = 0
    @State private var balance = 0
    @State private var vaultShop: [VaultRunShipItem] = VaultRunShopCatalog.defaultItems()
    @State private var shipHull = "#1a6b4a"
    @State private var shipCockpit = "#f5c842"
    @State private var shipTrail = "#e8b020"
    @State private var shipStyle = "scout"
    @State private var equippedShipId = VaultRunShopCatalog.defaultShipId
    @State private var message = ""
    @State private var loadError: String?
    @State private var showPlaySession = false
    @State private var showShop = false
    @State private var leaderboardRefresh = 0
    @State private var runToken = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ArcadeSkillLobbyChrome(
                    gameId: "nfg_vault_run",
                    title: "NFG RUSH",
                    subtitle: "3-lane casino run · dodge busts · jackpot every 400m+",
                    titleColors: [VaultRunTheme.accentGold, .white],
                    stats: [
                        ArcadeSkillLobbyStat(text: "Best \(bestDistance)m", icon: "trophy.fill", tint: VaultRunTheme.accentGold),
                        ArcadeSkillLobbyStat(text: "Run \(sessionPoints.formatted())", icon: "star.fill", tint: VaultRunTheme.accentJade),
                        ArcadeSkillLobbyStat(text: "+\(rewardPreview.formatted())", icon: "gift.fill", tint: VaultRunTheme.accentOrange),
                    ],
                    previewSystemImage: "figure.run",
                    previewTitle: "Tap Play for a locked run window",
                    previewSubtitle: "Swipe lanes · jump cards · slide under arches",
                    previewAccent: VaultRunTheme.accentGold,
                    playTint: VaultRunTheme.accentOrange,
                    isLoading: busy,
                    offlinePendingPoints: offlinePendingPoints,
                    onPlay: { Task { await openPlaySession() } }
                )
                HStack {
                    Spacer()
                    VaultRunShopButton { showShop = true }
                }
                .padding(.horizontal, 4)
                ArcadeInGameLeaderboard(gameId: "nfg_vault_run", scoreSuffix: "m", fetchLimit: 10)
                    .id(leaderboardRefresh)
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 4 / 255, green: 12 / 255, blue: 8 / 255),
                    NFGTheme.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("NFG Rush")
        .navigationBarTitleDisplayMode(.inline)
        .arcadeGameNavigationLock()
        .arcadeGameBackButton { dismiss() }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShop) {
            VaultRunShopSheet(
                balance: balance,
                items: vaultShop.isEmpty ? VaultRunShopCatalog.defaultItems() : vaultShop,
                busy: busy,
                onBuy: { itemId in await shopAction(action: "buy", itemId: itemId) },
                onEquip: { itemId in await shopAction(action: "equip", itemId: itemId) }
            )
        }
        .fullScreenCover(isPresented: $showPlaySession) {
            rushPlaySession
                .interactiveDismissDisabled()
        }
        .task { await bootstrap() }
        .onReceive(NotificationCenter.default.publisher(for: .arcadeOfflineQueueDidChange)) { _ in
            refreshOfflinePending()
        }
        .alert("Could not load", isPresented: .constant(loadError != nil)) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var rushPlaySession: some View {
        VaultRunGameView(
            busy: busy,
            sessionPoints: sessionPoints,
            offlinePendingPoints: offlinePendingPoints,
            rewardPreview: rewardPreview,
            sessionActive: sessionActive,
            bestDistance: bestDistance,
            milestonesClaimed: milestonesClaimed,
            balance: balance,
            vaultShop: vaultShop,
            shipHullHex: shipHull,
            shipCockpitHex: shipCockpit,
            shipTrailHex: shipTrail,
            shipStyle: shipStyle,
            equippedShipId: equippedShipId,
            playSessionOnly: true,
            onCloseSession: { closePlaySession() },
            onStart: { await startRun() },
            onMilestone: { distance in await claimMilestone(distance: distance) },
            onGameOver: { distance in await endRun(distance: distance) },
            onBuyShip: { itemId in await shopAction(action: "buy", itemId: itemId) },
            onEquipShip: { itemId in await shopAction(action: "equip", itemId: itemId) }
        )
        .id(runToken)
    }

    @MainActor
    private func openPlaySession() async {
        await startRun()
        runToken += 1
        showPlaySession = true
    }

    private func closePlaySession() {
        showPlaySession = false
        leaderboardRefresh += 1
    }

    @MainActor
    private func bootstrap() async {
        busy = true
        defer { busy = false }
        do {
            let client = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            api = client
            let synced = await ArcadeOfflinePointsQueue.flush(api: client, sync: sync)
            if synced > 0 {
                message = "Synced \(synced) offline Rush reward\(synced == 1 ? "" : "s")."
            }
            refreshOfflinePending()
            let status = try await client.arcadePlay(gameId: "nfg_vault_run", action: "status")
            applyStatus(status, action: "status")
        } catch {
            loadError = error.localizedDescription
            message = "Offline mode — points save locally and sync later."
            applyLocalShopFallback()
            syncPersonalBest(serverBest: 0)
            refreshOfflinePending()
        }
    }

    private func refreshOfflinePending() {
        offlinePendingPoints = ArcadeOfflinePointsQueue.pendingPoints(for: "nfg_vault_run")
    }

    @MainActor
    private func applyStatus(_ result: ArcadePlayResponse, action: String) {
        ArcadePointsBridge.applyToGlobalWallet(result, sync: sync)
        applyShop(from: result)
        if let bal = result.balance { balance = bal }
        if let active = result.sessionActive ?? result.runActive {
            sessionActive = active
        }
        if action != "start" {
            if let pts = result.sessionPoints { sessionPoints = pts }
        }
        if let preview = result.levelRewardPreview { rewardPreview = preview }
        if let m = result.sessionMilestones ?? result.sessionLevels { milestonesClaimed = m }

        var serverBest = bestDistance
        if let best = result.bestLevel { serverBest = max(serverBest, best) }
        if let score = result.score { serverBest = max(serverBest, score) }
        syncPersonalBest(serverBest: serverBest)

        switch action {
        case "start":
            sessionActive = true
            sessionPoints = 0
            milestonesClaimed = 0
            message = result.message ?? "New run!"
        case "milestone":
            sessionActive = true
            if let g = result.gained, g > 0 {
                message = "+\(g.formatted()) pts · \(sessionPoints.formatted()) session"
            } else if let msg = result.message {
                message = msg
            }
        case "game_over":
            sessionActive = false
            if let msg = result.message {
                message = msg
            } else if let score = result.score {
                message = "Run over — \(score.formatted())m peak"
            }
        case "buy", "equip":
            if let msg = result.message { message = msg }
        default:
            if let msg = result.message, action == "status" { message = msg }
        }
        refreshOfflinePending()
    }

    @MainActor
    private func applyShop(from result: ArcadePlayResponse) {
        let userKey = PlayerSession.tiktokUsername
        var ownedIds = Set(result.ownedVaultShips ?? [])
        var equipped = result.equippedVaultShip

        if let shop = result.vaultShop, !shop.isEmpty {
            for item in shop where item.owned == true {
                ownedIds.insert(item.id)
            }
            if equipped == nil {
                equipped = shop.first(where: { $0.equipped == true })?.id
            }
            vaultShop = VaultRunShopCatalog.merged(
                serverItems: shop,
                equippedId: equipped ?? VaultRunShopCatalog.defaultShipId,
                ownedIds: ownedIds
            )
        } else {
            let local = VaultRunShopLocalStore.load(for: userKey)
            ownedIds = ownedIds.union(local.owned)
            equipped = equipped ?? local.equipped
            vaultShop = VaultRunShopCatalog.withOwnership(
                equippedId: equipped ?? VaultRunShopCatalog.defaultShipId,
                ownedIds: ownedIds
            )
        }

        let equippedId = equipped ?? VaultRunShopLocalStore.load(for: userKey).equipped
        equippedShipId = equippedId
        VaultRunShopCatalog.applyRunnerCosmetics(
            shipId: equippedId,
            to: &shipHull,
            cockpit: &shipCockpit,
            trail: &shipTrail,
            style: &shipStyle
        )
        VaultRunShopLocalStore.save(ownedIds: ownedIds, equippedId: equippedId, for: userKey)
    }

    @MainActor
    private func applyLocalShopFallback() {
        let local = VaultRunShopLocalStore.load(for: PlayerSession.tiktokUsername)
        vaultShop = VaultRunShopCatalog.withOwnership(equippedId: local.equipped, ownedIds: local.owned)
        equippedShipId = local.equipped
        VaultRunShopCatalog.applyRunnerCosmetics(
            shipId: local.equipped,
            to: &shipHull,
            cockpit: &shipCockpit,
            trail: &shipTrail,
            style: &shipStyle
        )
    }

    @MainActor
    private func syncPersonalBest(serverBest: Int) {
        bestDistance = NFGVaultRunPersonalBest.merged(
            serverBest: serverBest,
            for: PlayerSession.tiktokUsername
        )
    }

    @MainActor
    private func startRun() async {
        guard let api else {
            sessionActive = true
            sessionPoints = 0
            milestonesClaimed = 0
            message = "Offline run — milestone pts save locally."
            return
        }
        busy = true
        defer { busy = false }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        refreshOfflinePending()
        do {
            let res = try await api.arcadePlay(gameId: "nfg_vault_run", action: "start")
            applyStatus(res, action: "start")
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func claimMilestone(distance: Int) async -> Bool {
        let tier = milestonesClaimed + 1
        let reward = VaultRunEngine.milestoneReward(forTier: tier)
        guard let api else {
            queueOfflineMilestone(distance: distance, reward: reward)
            return true
        }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        refreshOfflinePending()
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_vault_run",
                action: "milestone",
                payload: ["distance": distance]
            )
            applyStatus(res, action: "milestone")
            return res.ok != false
        } catch {
            queueOfflineMilestone(distance: distance, reward: reward)
            return true
        }
    }

    private func queueOfflineMilestone(distance: Int, reward: Int) {
        ArcadeOfflinePointsQueue.enqueue(
            gameId: "nfg_vault_run",
            action: "milestone",
            payload: ["distance": distance],
            estimatedPoints: reward
        )
        milestonesClaimed += 1
        message = "+\(reward.formatted()) pts saved offline"
        refreshOfflinePending()
    }

    @MainActor
    private func endRun(distance: Int) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_vault_run",
                action: "game_over",
                payload: ["distance": distance]
            )
            applyStatus(res, action: "game_over")
            let peak = res.score ?? distance
            NFGVaultRunPersonalBest.save(for: PlayerSession.tiktokUsername, distance: peak)
            syncPersonalBest(serverBest: max(bestDistance, peak))
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func shopAction(action: String, itemId: String) async -> VaultRunShopOutcome {
        guard let api else {
            return .failure("Not connected")
        }
        busy = true
        defer { busy = false }
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_vault_run",
                action: action,
                payload: ["itemId": itemId]
            )
            if res.ok == false {
                let msg = ArcadeErrors.userMessage(reason: res.reason, message: res.message)
                return .failure(msg)
            }
            if action == "buy" {
                VaultRunShopLocalStore.recordPurchase(itemId: itemId, for: PlayerSession.tiktokUsername)
            } else {
                VaultRunShopLocalStore.recordEquip(itemId: itemId, for: PlayerSession.tiktokUsername)
            }
            applyStatus(res, action: action)
            let msg = res.message ?? (action == "buy" ? "Purchased & equipped!" : "Equipped!")
            return .success(msg)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
