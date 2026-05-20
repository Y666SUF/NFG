import Combine
import Foundation

@MainActor
final class SyncClient: ObservableObject {
    @Published var gameState: CrashGameState = .empty
    @Published var profile: PlayerProfile = .empty
    @Published var wallet: PlayerWallet = .empty
    @Published var walletError: String?
    @Published var isLoadingWallet = false
    @Published var appChatMessages: [AppChatMessage] = []
    @Published var appChatError: String?
    @Published var connectionStatus = "Offline"
    @Published var feed: [FeedLine] = []
    @Published var lastActionMessage: String?
    @Published var pendingOfflineCount: Int = OfflineQueue.count
    @Published var multiplierHistory: [Double] = [1]
    @Published var sublineText = "Connecting…"
    @Published var taxPotAmount: Int = 0
    @Published var fullBalances: [LeaderboardRow] = []
    @Published var isLoadingLeaderboard = false
    @Published var leaderboardError: String?
    @Published var roundResultPopup: RoundResultSummary?
    @Published var tiktokLive: TikTokLiveStatus = .unknown
    @Published var activeAppUserCount: Int = 0
    @Published var activeAppUserList: [ActiveAppUser] = []
    /// Server returned `activeAppUsers` or accepted a presence heartbeat.
    @Published var presenceTrackingAvailable = false
    @Published var leaderboardTotalCount: Int = 0

    /// Shown in the header and chat — prefer live list count from server.
    var displayedActiveAppUsers: Int {
        if !activeAppUserList.isEmpty { return activeAppUserList.count }
        if presenceTrackingAvailable { return max(activeAppUserCount, 1) }
        if connectionStatus == "Online" { return max(activeAppUserCount, 1) }
        return 0
    }

    var showActiveAppUserCount: Bool {
        presenceTrackingAvailable || connectionStatus == "Online"
    }
    @Published var rewardedAdStatus: RewardedAdStatusResponse?
    @Published var rewardedAdBanner: String?
    @Published var isClaimingRewardedAd = false
    @Published var storeProducts: [StoreProduct] = StoreCatalog.fallbackProducts
    @Published var storePurchaseMessage: String?
    @Published var isPurchasingStore = false
    @Published var storeIsTestMode = true

    var topBalances: [LeaderboardRow] {
        Array(fullBalances.prefix(5))
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var lastRoundId: Int = 0
    private var lastRoundResultShownId: Int = 0
    private var pingTimer: Timer?
    private var liveStatusTimer: Timer?
    private var presenceTimer: Timer?
    private var walletRefreshTimer: Timer?
    private var api: GameAPI?
    private var knownChatIds = Set<String>()
    private var reconnectTask: Task<Void, Never>?

    private func bootstrapFromServer(api: GameAPI) async {
        await refreshMobileStatus()
        await sendPresenceHeartbeat()

        do {
            gameState = try await api.fetchState()
            applyStateSideEffects(gameState)
            connectionStatus = "Online"

            await refreshProfile()
            await refreshWallet()
            await loadAppChatHistory()
            await flushOfflineQueue()
            await refreshLeaderboard()
            startLiveStatusPolling()
            startPresencePolling()
            startWalletPolling()
        } catch {
            connectionStatus = "Offline"
            appendFeed("Connection lost")
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard connectionStatus != "Online" else { return }
                connect()
            }
        }
    }

    func connect() {
        disconnect()
        connectionStatus = "Connecting…"

        do {
            api = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
        } catch {
            connectionStatus = error.localizedDescription
            return
        }

        guard let api else { return }

        Task {
            await bootstrapFromServer(api: api)
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: api.webSocketURL)
        webSocketTask?.resume()
        receiveLoop()
        startPing()
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        liveStatusTimer?.invalidate()
        liveStatusTimer = nil
        presenceTimer?.invalidate()
        presenceTimer = nil
        walletRefreshTimer?.invalidate()
        walletRefreshTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        if connectionStatus != "Server unreachable" {
            connectionStatus = "Offline"
        }
    }

    func refreshProfile() async {
        guard PlayerSession.isLoggedIn, let api else { return }
        do {
            profile = try await api.fetchProfile(user: PlayerSession.tiktokUsername)
            if wallet.user.isEmpty {
                wallet.balance = profile.balance
                wallet.allTime = profile.allTime
                wallet.displayName = profile.displayName
                wallet.user = profile.user
            }
        } catch {
            lastActionMessage = "Profile sync failed"
        }
    }

    func refreshWallet() async {
        guard PlayerSession.isLoggedIn, let api else { return }
        isLoadingWallet = true
        walletError = nil
        defer { isLoadingWallet = false }
        do {
            wallet = try await api.fetchMobileWallet()
            profile.balance = wallet.balance
            profile.allTime = wallet.allTime
            profile.displayName = wallet.displayName
            profile.level = wallet.level
            profile.rank = wallet.rank
        } catch {
            walletError = error.localizedDescription
        }
    }

    /// True when the user can tap “Watch ad”.
    var canTapRewardedAdButton: Bool {
        guard PlayerSession.isLoggedIn, !isClaimingRewardedAd else { return false }
        guard let status = rewardedAdStatus else { return true }
        return status.effectivelyCanClaim
    }

    func refreshRewardedAdStatus() async {
        guard let api else { return }
        do {
            let raw = try await api.fetchRewardedAdStatus()
            rewardedAdStatus = raw.normalizedForApp()
            if rewardedAdBanner?.contains("game server") == true {
                rewardedAdBanner = nil
            }
        } catch {
            // Keep button tappable so AdMob can still be tested; claim will explain server setup.
            rewardedAdStatus = nil
            rewardedAdBanner = error.localizedDescription
        }
    }

    func refreshStoreProducts() async {
        guard let api else {
            storeProducts = StoreCatalog.fallbackProducts
            return
        }
        do {
            storeProducts = try await api.fetchStoreProducts()
        } catch {
            storeProducts = StoreCatalog.fallbackProducts
        }
    }

    func testPurchaseStoreProduct(_ product: StoreProduct) async {
        guard PlayerSession.isLoggedIn else {
            storePurchaseMessage = "Link your TikTok account first."
            return
        }
        isPurchasingStore = true
        storePurchaseMessage = nil
        defer { isPurchasingStore = false }

        guard let api else {
            storePurchaseMessage = "Not connected to the game."
            return
        }

        do {
            let resp = try await api.testPurchase(productId: product.id)
            if resp.ok == true {
                if let bal = resp.balance {
                    wallet.balance = bal
                    profile.balance = bal
                }
                let gained = resp.gained ?? product.points
                storePurchaseMessage = "+\(gained.formatted()) pts added (test — no charge)."
                await refreshWallet()
                await refreshLeaderboard()
            } else {
                storePurchaseMessage = resp.message ?? "Purchase failed."
            }
        } catch {
            storePurchaseMessage = error.localizedDescription
        }
    }

    func watchRewardedAdAndClaim(using coordinator: RewardedAdCoordinator) async {
        isClaimingRewardedAd = true
        rewardedAdBanner = nil
        defer { isClaimingRewardedAd = false }

        let watched = await coordinator.watchAdForReward()
        guard watched else {
            rewardedAdBanner = coordinator.lastLoadError ?? "Ad was not completed."
            return
        }

        guard let api else {
            rewardedAdBanner = "Not connected to the game."
            return
        }

        do {
            let resp = try await api.claimRewardedAd()
            if resp.ok == true {
                if let bal = resp.balance {
                    wallet.balance = bal
                    profile.balance = bal
                }
                let gained = resp.gained ?? AdMobConfig.rewardPoints
                rewardedAdBanner = "+\(gained.formatted()) pts added!"
            } else {
                rewardedAdBanner = resp.message ?? "Could not claim reward."
            }
            await refreshWallet()
            await refreshRewardedAdStatus()
        } catch {
            rewardedAdBanner = error.localizedDescription
        }
    }

    func loadAppChatHistory() async {
        guard let api else { return }
        do {
            let rows = try await api.fetchAppChatHistory(limit: 60)
            mergeAppChatMessages(rows)
            appChatError = nil
        } catch {
            appChatError = error.localizedDescription
        }
    }

    func sendAppChat(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard AuthStore.isLinked else {
            appChatError = "Link your TikTok on live first."
            return
        }
        guard let api else {
            appChatError = "You're offline"
            return
        }
        do {
            let row = try await api.sendAppChat(message: trimmed)
            ingestAppChatMessage(row)
            appChatError = nil
        } catch {
            appChatError = error.localizedDescription
        }
    }

    func sendCommand(_ message: String) async {
        guard AuthStore.isLinked else {
            lastActionMessage = "Link your TikTok on live first."
            return
        }

        let user = AuthStore.verifiedUserId
        let name = AuthStore.verifiedDisplayName

        guard let api else {
            OfflineQueue.enqueue(message: message, userId: user, displayName: name)
            pendingOfflineCount = OfflineQueue.count
            lastActionMessage = "Queued offline (\(pendingOfflineCount))"
            return
        }

        do {
            let result = try await api.sendChat(message: message, userId: user, displayName: name)
            handleChatResult(result)
            await refreshProfile()
            await refreshWallet()
            pendingOfflineCount = OfflineQueue.count
        } catch {
            OfflineQueue.enqueue(message: message, userId: user, displayName: name)
            pendingOfflineCount = OfflineQueue.count
            lastActionMessage = "Queued — will send when you're back online"
        }
    }

    func placeBet(amountText: String, cashout: Double) async {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, cashout >= 1.05 else {
            lastActionMessage = "Enter amount (e.g. 100, 30k) and cashout ≥ 1.05"
            return
        }
        await sendCommand("!\(trimmed) \(cashout)")
    }

    func checkBalance() async {
        await sendCommand("!balance")
    }

    func flushOfflineQueue() async {
        guard let api, PlayerSession.isLoggedIn else { return }
        var queue = OfflineQueue.load()
        guard !queue.isEmpty else {
            pendingOfflineCount = 0
            return
        }

        var remaining: [QueuedChat] = []
        for item in queue {
            do {
                let result = try await api.sendChat(
                    message: item.message,
                    userId: item.userId,
                    displayName: item.displayName
                )
                handleChatResult(result)
            } catch {
                remaining.append(item)
                break
            }
        }
        OfflineQueue.save(remaining)
        pendingOfflineCount = remaining.count
        if remaining.isEmpty && !queue.isEmpty {
            appendFeed("Synced \(queue.count) offline action(s) to your account.")
        }
        await refreshProfile()
    }

    private func handleChatResult(_ result: ChatActionResult) {
        guard let parsed = result.parsed else {
            if result.ignored == true {
                lastActionMessage = "Command not recognized"
            }
            return
        }
        switch parsed.type {
        case "bet":
            if parsed.ok == true {
                lastActionMessage = "Bet placed: \(parsed.amount ?? 0) @ \(parsed.cashout ?? 0)×"
            } else {
                lastActionMessage = betErrorMessage(parsed.reason)
            }
        case "balance_shout":
            if parsed.ok == true, let bal = parsed.balance {
                lastActionMessage = "Balance: \(bal.formatted()) pts"
                wallet.balance = bal
                profile.balance = bal
                if let inv = parsed.inventory {
                    wallet.inventory = inv
                }
            } else if parsed.cooldown == true, let sec = parsed.secondsLeft {
                lastActionMessage = "Balance shout cooldown — \(sec)s"
            } else {
                lastActionMessage = "Balance on cooldown"
            }
        default:
            if parsed.ok == false, let reason = parsed.reason {
                lastActionMessage = reason.replacingOccurrences(of: "_", with: " ")
            } else {
                lastActionMessage = "OK"
            }
        }
    }

    private func betErrorMessage(_ reason: String?) -> String {
        switch reason {
        case "insufficient": return "Not enough points — open Wallet to watch an ad for free pts"
        case "not_betting": return "Bet queued for next round"
        case "bad_cashout": return "Cashout must be 1.05–500×"
        case "bad_amount": return "Invalid bet amount"
        case "already_bet": return "You already have a bet this round"
        default: return reason ?? "Bet failed"
        }
    }

    private func appendFeed(_ text: String) {
        feed.insert(FeedLine(id: UUID().uuidString, text: text, ts: Date()), at: 0)
        feed = Array(feed.prefix(50))
    }

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.webSocketTask?.send(.string("{\"type\":\"ping\"}")) { _ in }
            }
        }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    self.receiveLoop()
                case .failure:
                    if self.connectionStatus == "Online" {
                        self.connectionStatus = "Reconnecting…"
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let text): data = text.data(using: .utf8)
        case .data(let blob): data = blob
        @unknown default: data = nil
        }

        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "state":
            if let payload = json["payload"],
               let payloadData = try? JSONSerialization.data(withJSONObject: payload),
               let state = try? JSONDecoder().decode(CrashGameState.self, from: payloadData) {
                gameState = state
                applyStateSideEffects(state)
                if connectionStatus != "Online" { connectionStatus = "Online" }
            }
        case "chat_result":
            if let payload = json["payload"] as? [String: Any] {
                formatChatFeed(payload)
            }
        case "game_event":
            if let payload = json["payload"] as? [String: Any],
               let kind = payload["kind"] as? String {
                appendFeed(kind)
            }
        case "app_chat":
            if let payload = json["payload"],
               let payloadData = try? JSONSerialization.data(withJSONObject: payload),
               let row = try? JSONDecoder().decode(AppChatMessage.self, from: payloadData) {
                ingestAppChatMessage(row)
            }
        case "balance_toast":
            if let payload = json["payload"] as? [String: Any],
               let user = payload["user"] as? String,
               user.lowercased() == PlayerSession.tiktokUsername.lowercased(),
               let bal = payload["balance"] as? Int {
                wallet.balance = bal
                profile.balance = bal
                if let invObj = payload["inventory"] as? [String: Any],
                   let invData = try? JSONSerialization.data(withJSONObject: invObj),
                   let inv = try? JSONDecoder().decode(PowerupInventory.self, from: invData) {
                    wallet.inventory = inv
                }
            }
        default:
            break
        }
    }

    private func ingestAppChatMessage(_ row: AppChatMessage) {
        guard knownChatIds.insert(row.id).inserted else { return }
        appChatMessages.append(row)
        appChatMessages.sort { $0.at < $1.at }
        if appChatMessages.count > 80 {
            let drop = appChatMessages.count - 80
            let removed = appChatMessages.prefix(drop)
            for r in removed { knownChatIds.remove(r.id) }
            appChatMessages.removeFirst(drop)
        }
    }

    private func mergeAppChatMessages(_ rows: [AppChatMessage]) {
        for row in rows {
            ingestAppChatMessage(row)
        }
    }

    private func startWalletPolling() {
        walletRefreshTimer?.invalidate()
        walletRefreshTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshWallet()
            }
        }
    }

    func refreshLeaderboard() async {
        guard let api else { return }
        isLoadingLeaderboard = true
        leaderboardError = nil
        defer { isLoadingLeaderboard = false }
        do {
            let result = try await api.fetchAllBalances()
            fullBalances = result.rows
            leaderboardTotalCount = result.total
        } catch {
            leaderboardError = error.localizedDescription
        }
    }

    func refreshTikTokLiveStatus() async {
        await refreshMobileStatus()
    }

    func refreshMobileStatus() async {
        guard let api else { return }
        do {
            let status = try await api.fetchMobileStatusDetail()
            applyMobileStatus(status)
        } catch {
            /* keep last known */
        }
    }

    private func applyMobileStatus(_ status: MobileStatusResponse) {
        tiktokLive = status.toTikTokLiveStatus()
        applyPresenceSnapshot(
            count: status.activeAppUsers,
            users: status.activeAppUserList
        )
    }

    private func applyPresenceSnapshot(count: Int?, users: [ActiveAppUser]?) {
        if let users {
            presenceTrackingAvailable = true
            activeAppUserList = users
            activeAppUserCount = users.count
            return
        }
        if let count {
            presenceTrackingAvailable = true
            activeAppUserCount = max(0, count)
        }
    }

    func sendPresenceHeartbeat() async {
        guard let api else { return }
        do {
            let snap = try await api.sendPresenceHeartbeat()
            applyPresenceSnapshot(count: snap.activeAppUsers, users: snap.activeAppUserList)
        } catch {
            /* server may not have presence routes yet — header still shows 1 while online */
        }
    }

    /// Refreshes who is in the app (heartbeat + public active list).
    func refreshActiveAppUsers() async {
        await sendPresenceHeartbeat()
        guard let api else { return }
        do {
            let snap = try await api.fetchActiveAppUsers()
            applyPresenceSnapshot(count: snap.activeAppUsers, users: snap.activeAppUserList)
        } catch {
            /* keep heartbeat result */
        }
    }

    private func startLiveStatusPolling() {
        liveStatusTimer?.invalidate()
        liveStatusTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshMobileStatus()
            }
        }
    }

    private func startPresencePolling() {
        presenceTimer?.invalidate()
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendPresenceHeartbeat()
            }
        }
    }

    func dismissRoundResultPopup() {
        roundResultPopup = nil
    }

    private func applyStateSideEffects(_ s: CrashGameState) {
        if s.roundId != lastRoundId {
            lastRoundId = s.roundId
            multiplierHistory = [1]
            if s.phase != .ended {
                roundResultPopup = nil
            }
        }
        taxPotAmount = s.taxPot?.displayAmount ?? 0
        updateSubline(s)
        updateRoundResultPopup(s)
        if s.phase == .running {
            let m = max(s.multiplier, 1)
            let last = multiplierHistory.last ?? 1
            if multiplierHistory.isEmpty || m >= last - 0.0001 {
                if multiplierHistory.isEmpty || abs(last - m) > 0.001 {
                    multiplierHistory.append(m)
                    if multiplierHistory.count > 200 { multiplierHistory.removeFirst() }
                }
            }
        } else if s.phase == .betting {
            multiplierHistory = [1]
        }
    }

    private func updateRoundResultPopup(_ s: CrashGameState) {
        if s.phase == .ended, let result = s.lastResult, result.roundId != lastRoundResultShownId {
            let summary = RoundResultSummary(from: result)
            if summary.hasEntries {
                lastRoundResultShownId = result.roundId
                roundResultPopup = summary
            }
        }
        if s.phase == .betting, s.roundId != lastRoundResultShownId {
            roundResultPopup = nil
        }
    }

    private func updateSubline(_ s: CrashGameState) {
        switch s.phase {
        case .betting:
            let sec = max(0, Int((Double(s.bettingEndsAt) - Date().timeIntervalSince1970 * 1000) / 1000))
            sublineText = "Entry window \(sec)s — !amount mult (e.g. !3m 2.5, !30k 2)"
        case .running:
            sublineText = "Multiplier climbing — auto cashout when targets hit."
        case .ended:
            if let crash = s.crashPoint {
                sublineText = "Crashed at \(String(format: "%.2f", crash))×"
            } else {
                sublineText = "Round ended"
            }
        case .idle:
            if let next = s.nextRoundStartsAt {
                let sec = max(0, Int((Double(next) - Date().timeIntervalSince1970 * 1000) / 1000))
                sublineText = "Next round ~\(sec)s"
            } else {
                sublineText = "Waiting for round…"
            }
        }
    }

    private func formatChatFeed(_ payload: [String: Any]) {
        let t = payload["type"] as? String ?? ""
        let user = payload["displayName"] as? String ?? payload["user"] as? String ?? "?"
        switch t {
        case "bet_line", "bet":
            if let amt = payload["amount"], let co = payload["cashout"] {
                appendFeed("\(user) bet \(amt) @ \(co)×")
            }
        default:
            break
        }
    }
}
