import SwiftUI

struct VaultRunGameScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var api: GameAPI?
    @State private var busy = false
    @State private var sessionPoints = 0
    @State private var rewardPreview = 3000
    @State private var sessionActive = false
    @State private var bestDistance = 0
    @State private var milestonesClaimed = 0
    @State private var balance = 0
    @State private var vaultShop: [VaultRunShipItem] = VaultRunShopCatalog.defaultItems()
    @State private var shipHull = "#62b8f8"
    @State private var shipCockpit = "#35e0ff"
    @State private var shipTrail = "#22d3ee"
    @State private var shipStyle = "scout"
    @State private var equippedShipId = VaultRunShopCatalog.defaultShipId
    @State private var message = ""
    @State private var loadError: String?

    var body: some View {
        VaultRunGameView(
            busy: busy,
            sessionPoints: sessionPoints,
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
            isFullscreen: true,
            onStart: { await startRun() },
            onMilestone: { distance in await claimMilestone(distance: distance) },
            onGameOver: { distance in await endRun(distance: distance) },
            onBuyShip: { itemId in await shopAction(action: "buy", itemId: itemId) },
            onEquipShip: { itemId in await shopAction(action: "equip", itemId: itemId) }
        )
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
        .navigationTitle("NFG Rush")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { dismiss() }
            }
        }
        .overlay(alignment: .bottom) {
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await bootstrap()
        }
        .alert("Could not load", isPresented: .constant(loadError != nil)) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    @MainActor
    private func bootstrap() async {
        busy = true
        defer { busy = false }
        do {
            let client = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            api = client
            let status = try await client.arcadePlay(gameId: "nfg_vault_run", action: "status")
            applyStatus(status, action: "status")
        } catch {
            loadError = error.localizedDescription
            message = error.localizedDescription
            applyLocalShopFallback()
            syncPersonalBest(serverBest: 0)
        }
    }

    @MainActor
    private func applyStatus(_ result: ArcadePlayResponse, action: String) {
        applyShop(from: result)
        if let bal = result.balance { balance = bal }
        if let active = result.sessionActive ?? result.runActive {
            sessionActive = active
        }
        if let pts = result.sessionPoints { sessionPoints = pts }
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
    }

    @MainActor
    private func applyShop(from result: ArcadePlayResponse) {
        let userKey = PlayerSession.tiktokUsername
        var ownedIds = Set(result.ownedVaultShips ?? [])
        var equipped = result.equippedVaultShip

        if let shop = result.vaultShop, !shop.isEmpty {
            vaultShop = shop
            for item in shop where item.owned == true {
                ownedIds.insert(item.id)
            }
            if equipped == nil {
                equipped = shop.first(where: { $0.equipped == true })?.id
            }
        } else {
            let local = VaultRunShopLocalStore.load(for: userKey)
            ownedIds = ownedIds.union(local.owned)
            equipped = equipped ?? local.equipped
            vaultShop = VaultRunShopCatalog.withOwnership(
                equippedId: equipped ?? VaultRunShopCatalog.defaultShipId,
                ownedIds: ownedIds
            )
        }

        if let hull = result.shipHull { shipHull = hull }
        if let cockpit = result.shipCockpit { shipCockpit = cockpit }
        if let trail = result.shipTrail { shipTrail = trail }
        if let style = result.shipStyle { shipStyle = style }

        let equippedId = equipped ?? VaultRunShopLocalStore.load(for: userKey).equipped
        equippedShipId = equippedId
        if result.shipHull == nil, let cosmetics = VaultRunShopCatalog.cosmetics(for: equippedId) {
            shipHull = cosmetics.hull
            shipCockpit = cosmetics.cockpit
            shipTrail = cosmetics.trail
            shipStyle = cosmetics.style
        }
        VaultRunShopLocalStore.save(ownedIds: ownedIds, equippedId: equippedId, for: userKey)
    }

    @MainActor
    private func applyLocalShopFallback() {
        let local = VaultRunShopLocalStore.load(for: PlayerSession.tiktokUsername)
        vaultShop = VaultRunShopCatalog.withOwnership(equippedId: local.equipped, ownedIds: local.owned)
        equippedShipId = local.equipped
        if let cosmetics = VaultRunShopCatalog.cosmetics(for: local.equipped) {
            shipHull = cosmetics.hull
            shipCockpit = cosmetics.cockpit
            shipTrail = cosmetics.trail
            shipStyle = cosmetics.style
        }
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
        guard let api else { return }
        busy = true
        defer { busy = false }
        do {
            let res = try await api.arcadePlay(gameId: "nfg_vault_run", action: "start")
            applyStatus(res, action: "start")
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func claimMilestone(distance: Int) async -> Bool {
        guard let api else { return false }
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_vault_run",
                action: "milestone",
                payload: ["distance": distance]
            )
            applyStatus(res, action: "milestone")
            return res.ok != false
        } catch {
            return false
        }
    }

    @MainActor
    private func endRun(distance: Int) async {
        guard let api else { return }
        busy = true
        defer { busy = false }
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
