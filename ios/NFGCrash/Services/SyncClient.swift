import Combine
import Foundation

@MainActor
final class SyncClient: ObservableObject {
    @Published var gameState: CrashGameState = .empty
    @Published var profile: PlayerProfile = .empty
    @Published var wallet: PlayerWallet = .empty
    /// Mirrors `wallet.balance`; updated only via full wallet assign so Profile UI always refreshes.
    @Published private(set) var liveBalance: Int = 0
    @Published var walletError: String?
    @Published var isLoadingWallet = false
    @Published var appChatMessages: [AppChatMessage] = []
    @Published var appChatError: String?
    @Published var isChatAdmin = false
    @Published var isChatMutedSelf = false
    @Published var mutedChatUsers: [MutedChatUser] = []
    @Published var chatModerationError: String?
    @Published var activeChatBanner: AppChatBannerNotification?
    /// Hide banners while the chat sheet is open.
    @Published var suppressChatBanners = false
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
    /// Display name shown briefly when someone else opens the app.
    @Published var presenceJoinAnnouncement: PresenceActivityAnnouncement?
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
    @Published var cosmeticsCatalog: CosmeticsShopCatalog?
    @Published var cosmeticsShopError: String?
    @Published var cosmeticsPurchaseMessage: String?
    @Published var isLoadingCosmeticsShop = false

    var topBalances: [LeaderboardRow] {
        Array(fullBalances.prefix(5))
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private var lastRoundId: Int = 0
    private var lastRoundResultShownId: Int = 0
    private var pingTimer: Timer?
    private var liveStatusTimer: Timer?
    private var presenceTimer: Timer?
    private var knownPresenceUserIds = Set<String>()
    private var presenceSnapshotReady = false
    private var presenceJoinDismissTask: Task<Void, Never>?
    private var walletRefreshTimer: Timer?
    /// Bumped whenever wallet balance is updated from a purchase or `applyWalletFromServer` — stale `refreshWallet` responses are ignored.
    private var walletDataRevision: UInt64 = 0
    private var api: GameAPI?
    private var knownChatIds = Set<String>()
    private var reconnectTask: Task<Void, Never>?
    private var pendingRoundResultPopup: RoundResultSummary?
    private var localRecentCrashes: [Double] = []
    /// Keeps entries visible when the live server omits `openBets` after betting (older PC builds).
    private var cachedOpenBets: [OpenBet] = []
    private var cachedOpenBetsRoundId: Int = -1

    private func bootstrapFromServer(api: GameAPI) async {
        await refreshMobileStatus()
        await sendPresenceHeartbeat()

        do {
            gameState = enrichState(try await api.fetchState())
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
        presenceJoinDismissTask?.cancel()
        presenceJoinDismissTask = nil
        presenceJoinAnnouncement = nil
        knownPresenceUserIds.removeAll()
        presenceSnapshotReady = false
        walletRefreshTimer?.invalidate()
        walletRefreshTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        if connectionStatus != "Server unreachable" {
            connectionStatus = "Offline"
        }
    }

    /// Unlink TikTok or App Review demo; returns user to the link / sign-in screen.
    func signOut() async {
        if let api {
            await api.logoutSession()
        }
        disconnect()
        reconnectTask?.cancel()
        reconnectTask = nil
        AuthStore.clearSession()
        api = nil
        profile = .empty
        wallet = .empty
        liveBalance = 0
        walletError = nil
        gameState = .empty
        appChatMessages = []
        appChatError = nil
        feed = []
        fullBalances = []
        lastActionMessage = nil
        roundResultPopup = nil
        pendingRoundResultPopup = nil
        rewardedAdBanner = nil
        storePurchaseMessage = nil
        sublineText = "Signed out"
        knownChatIds.removeAll()
    }

    func refreshProfile() async {
        guard PlayerSession.isLoggedIn, let api else { return }
        do {
            profile = try await api.fetchProfile(user: PlayerSession.tiktokUsername)
            AuthStore.adoptDisplayNameFromServer(profile.displayName, userId: profile.user)
            patchWallet { w in
                if w.user.isEmpty {
                    w.user = profile.user
                }
                let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { w.displayName = name }
            }
        } catch {
            lastActionMessage = "Profile sync failed"
        }
    }

    /// Name sent with !bet / !balance — prefer server-remembered nickname over bare username.
    func resolvedChatDisplayName() -> String {
        let user = AuthStore.verifiedUserId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        let walletName = wallet.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !walletName.isEmpty {
            let key = walletName.lowercased().replacingOccurrences(of: "@", with: "")
            if key != user { return walletName }
        }
        let verified = AuthStore.verifiedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !verified.isEmpty {
            let key = verified.lowercased().replacingOccurrences(of: "@", with: "")
            if key != user { return verified }
        }
        if !walletName.isEmpty { return walletName }
        if !verified.isEmpty { return verified }
        return user
    }

    /// Reassign `wallet` so `@Published` fires (in-place struct mutation does not update SwiftUI).
    private func patchWallet(_ mutate: (inout PlayerWallet) -> Void) {
        var next = wallet
        mutate(&next)
        guard next != wallet else { return }
        wallet = next
        liveBalance = next.balance
    }

    func refreshWallet(force: Bool = false) async {
        guard PlayerSession.isLoggedIn, let api else { return }
        let revisionAtStart = walletDataRevision
        isLoadingWallet = true
        walletError = nil
        defer { isLoadingWallet = false }
        do {
            let next = try await api.fetchMobileWallet()
            guard force || revisionAtStart == walletDataRevision else { return }
            applyWalletFromServer(next)
        } catch {
            walletError = error.localizedDescription
        }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let api else { throw GameAPIError.notLoggedIn }
        let next = try await api.updateDisplayName(name)
        applyWalletFromServer(next)
    }

    func applyWalletFromServer(_ next: PlayerWallet) {
        walletDataRevision &+= 1
        wallet = next
        liveBalance = next.balance
        profile.balance = next.balance
        profile.allTime = next.allTime
        profile.displayName = next.displayName
        profile.level = next.level
        profile.rank = next.rank
        if let locked = next.displayNameLocked {
            AuthStore.displayNameLocked = locked
        }
        if !next.user.isEmpty {
            if AuthStore.displayNameLocked || next.displayNameLocked == true {
                AuthStore.applyCustomDisplayName(next.displayName)
            } else {
                AuthStore.adoptDisplayNameFromServer(next.displayName, userId: next.user)
            }
        }
        syncCosmeticsCatalogFromWallet(next)
    }

    func applyBalanceFromServer(balance: Int, allTime: Int? = nil) {
        walletDataRevision &+= 1
        patchWallet { w in
            w.balance = balance
            if let allTime { w.allTime = allTime }
        }
        liveBalance = balance
        profile.balance = balance
        if let allTime { profile.allTime = allTime }
        syncCosmeticsCatalogBalance(balance)
    }

    private func syncCosmeticsCatalogBalance(_ balance: Int) {
        guard var cat = cosmeticsCatalog else { return }
        cat.balance = balance
        cosmeticsCatalog = cat
    }

    private func syncCosmeticsCatalogFromWallet(_ next: PlayerWallet) {
        guard var cat = cosmeticsCatalog else { return }
        cat.nameStyle = next.nameStyle
        cat.nameBadge = next.nameBadge
        cat.ownedNameStyles = next.ownedNameStyles
        cat.ownedBadges = next.ownedBadges
        cat.balance = next.balance
        cosmeticsCatalog = cat
    }

    func refreshCosmeticsShop() async {
        guard PlayerSession.isLoggedIn, let api else {
            cosmeticsCatalog = nil
            return
        }
        isLoadingCosmeticsShop = true
        cosmeticsShopError = nil
        defer { isLoadingCosmeticsShop = false }
        do {
            var cat = try await api.fetchCosmeticsShopCatalog()
            mergeCosmeticsCatalogIntoWallet(&cat)
            cosmeticsCatalog = cat
        } catch {
            cosmeticsShopError = error.localizedDescription
        }
    }

    /// Apply server catalog without overwriting wallet balance; union owned lists so nothing disappears.
    private func mergeCosmeticsCatalogIntoWallet(_ cat: inout CosmeticsShopCatalog) {
        patchWallet { w in
            if let style = cat.nameStyle, !style.isEmpty { w.nameStyle = style }
            if let badge = cat.nameBadge, !badge.isEmpty { w.nameBadge = badge }
            let styles = Set(w.ownedNameStyles.map { $0.lowercased() })
                .union((cat.ownedNameStyles ?? []).map { $0.lowercased() })
            w.ownedNameStyles = Array(styles)
            let badges = Set(w.ownedBadges.map { $0.lowercased() })
                .union((cat.ownedBadges ?? []).map { $0.lowercased() })
            w.ownedBadges = Array(badges)
        }
        cat.nameStyle = wallet.nameStyle
        cat.nameBadge = wallet.nameBadge
        cat.ownedNameStyles = wallet.ownedNameStyles
        cat.ownedBadges = wallet.ownedBadges
        cat.balance = wallet.balance
    }

    private func applyCosmeticsPurchaseResult(_ result: CosmeticsPurchaseResponse) async {
        if let w = result.wallet {
            applyWalletFromServer(w)
        } else if let bal = result.resolvedBalance {
            applyBalanceFromServer(balance: bal)
        }
        if let details = result.purchase {
            patchWallet { w in
                if let style = details.nameStyle, !style.isEmpty { w.nameStyle = style }
                let extra = (details.ownedNameStyles ?? []).map { $0.lowercased() }
                let merged = Set(w.ownedNameStyles.map { $0.lowercased() }).union(extra)
                w.ownedNameStyles = Array(merged)
            }
            if var cat = cosmeticsCatalog {
                cat.nameStyle = wallet.nameStyle
                cat.ownedNameStyles = wallet.ownedNameStyles
                cat.balance = wallet.balance
                cosmeticsCatalog = cat
            }
        }
        await refreshWallet(force: true)
        await refreshCosmeticsShop()
    }

    func purchaseNameStyle(_ styleId: String) async {
        guard let api else { return }
        cosmeticsShopError = nil
        cosmeticsPurchaseMessage = nil
        do {
            let result = try await api.purchaseNameStyle(styleId: styleId)
            await applyCosmeticsPurchaseResult(result)
            cosmeticsPurchaseMessage = result.message
        } catch {
            cosmeticsShopError = error.localizedDescription
        }
    }

    func purchaseNameBadge(_ badgeId: String) async {
        guard let api else { return }
        cosmeticsShopError = nil
        cosmeticsPurchaseMessage = nil
        do {
            let result = try await api.purchaseNameBadge(badgeId: badgeId)
            await applyCosmeticsPurchaseResult(result)
            cosmeticsPurchaseMessage = result.message
        } catch {
            cosmeticsShopError = error.localizedDescription
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
            let resp = try await api.fetchStoreProductsResponse()
            storeProducts = resp.products ?? StoreCatalog.fallbackProducts
            storeIsTestMode = resp.testMode == true && AppDistribution.allowsDevTestStore
            let ids = resp.productIds ?? storeProducts.map(\.id)
            await StoreKitService.shared.loadProducts(ids: ids)
        } catch {
            storeProducts = StoreCatalog.fallbackProducts
            await StoreKitService.shared.loadProducts(ids: StoreCatalog.fallbackProducts.map(\.id))
        }
    }

    func purchaseStoreProduct(_ product: StoreProduct) async {
        guard PlayerSession.isLoggedIn else {
            storePurchaseMessage = "Link your TikTok account first."
            return
        }
        guard let api else {
            storePurchaseMessage = "Not connected to the game."
            return
        }

        isPurchasingStore = true
        storePurchaseMessage = nil
        defer { isPurchasingStore = false }

        if storeIsTestMode && AppDistribution.allowsDevTestStore {
            await testPurchaseStoreProduct(product)
            return
        }

        do {
            let resp = try await StoreKitService.shared.purchase(productId: product.id) { pid, txnId, signed in
                try await api.verifyPurchase(
                    productId: pid,
                    transactionId: txnId,
                    signedTransactionInfo: signed
                )
            }
            if resp.ok == true {
                if let bal = resp.balance {
                    applyBalanceFromServer(balance: bal)
                }
                let gained = resp.gained ?? product.points
                if resp.alreadyProcessed == true {
                    storePurchaseMessage = "Purchase already credited. Balance updated."
                } else {
                    storePurchaseMessage = "+\(gained.formatted()) pts added."
                }
                await refreshWallet(force: true)
                await refreshLeaderboard()
            } else {
                storePurchaseMessage = resp.message ?? "Purchase failed."
            }
        } catch {
            storePurchaseMessage = error.localizedDescription
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
                    applyBalanceFromServer(balance: bal)
                }
                let gained = resp.gained ?? AdMobConfig.rewardPoints
                rewardedAdBanner = "+\(gained.formatted()) pts added!"
            } else {
                rewardedAdBanner = resp.message ?? "Could not claim reward."
            }
            await refreshWallet(force: true)
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
        await refreshChatModeration()
    }

    func refreshChatModeration() async {
        let ownerOnDevice = ChatOwnerConfig.isOwnerLinkedAccount()
        guard AuthStore.isLinked, let api else {
            isChatAdmin = false
            isChatMutedSelf = false
            mutedChatUsers = []
            return
        }
        do {
            let status = try await api.fetchChatModerationStatus()
            isChatAdmin = (status.isAdmin == true) || ownerOnDevice
            isChatMutedSelf = status.isMuted == true
            if let list = status.mutedUsers {
                applyMutedChatUsers(list)
            } else if !isChatAdmin {
                mutedChatUsers = []
            }
            chatModerationError = nil
        } catch {
            isChatAdmin = ownerOnDevice
            chatModerationError = nil
        }
    }

    func isUserChatMuted(_ userId: String) -> Bool {
        let key = normalizeChatUserId(userId)
        return mutedChatUsers.contains { normalizeChatUserId($0.userId) == key }
    }

    func muteTargetUserId(for user: ActiveAppUser) -> String? {
        if user.isGuest == true { return nil }
        let handle = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !handle.isEmpty { return handle }
        let id = user.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.lowercased().hasPrefix("guest:") { return nil }
        return id
    }

    func deleteAppChatMessage(_ messageId: String) async {
        guard isChatAdmin, let api else { return }
        do {
            try await api.deleteAppChatMessage(messageId: messageId)
            removeAppChatMessageLocally(messageId)
            chatModerationError = nil
        } catch {
            chatModerationError = error.localizedDescription
        }
    }

    func muteChatUser(userId: String, displayName: String?) async {
        guard isChatAdmin, let api else { return }
        do {
            let list = try await api.muteAppChatUser(userId: userId, displayName: displayName)
            applyMutedChatUsers(list)
            chatModerationError = nil
        } catch {
            chatModerationError = error.localizedDescription
        }
    }

    func unmuteChatUser(userId: String) async {
        guard isChatAdmin, let api else { return }
        do {
            let list = try await api.unmuteAppChatUser(userId: userId)
            applyMutedChatUsers(list)
            chatModerationError = nil
        } catch {
            chatModerationError = error.localizedDescription
        }
    }

    func sendAppChat(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard AuthStore.isLinked else {
            appChatError = "Link your TikTok on live first."
            return
        }
        if isChatMutedSelf {
            appChatError = "You are muted from app chat."
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
            if error.localizedDescription.localizedCaseInsensitiveContains("muted") {
                isChatMutedSelf = true
            }
        }
    }

    func sendCommand(_ message: String) async {
        guard AuthStore.isLinked else {
            lastActionMessage = "Link your TikTok on live first."
            return
        }

        let user = AuthStore.verifiedUserId
        let name = resolvedChatDisplayName()

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
                let amt = parsed.amount ?? 0
                let co = parsed.cashout ?? 0
                lastActionMessage = "Bet placed: \(amt) @ \(co)×"
                rememberPlacedBet(amount: amt, cashout: co)
            } else {
                lastActionMessage = betErrorMessage(parsed.reason)
            }
        case "balance_shout":
            if parsed.ok == true, let bal = parsed.balance {
                lastActionMessage = "Balance: \(bal.formatted()) pts"
                applyBalanceFromServer(balance: bal)
                if let inv = parsed.inventory {
                    patchWallet { $0.inventory = inv }
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
                let enriched = enrichState(state)
                gameState = enriched
                applyStateSideEffects(enriched)
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
        case "app_chat_delete":
            if let payload = json["payload"] as? [String: Any],
               let messageId = payload["messageId"] as? String {
                removeAppChatMessageLocally(messageId)
            }
        case "app_chat_mute_state":
            if let payload = json["payload"],
               let payloadData = try? JSONSerialization.data(withJSONObject: payload),
               let state = try? JSONDecoder().decode(ChatMuteStatePayload.self, from: payloadData) {
                applyMutedChatUsers(state.mutedUsers ?? [])
                let me = normalizeChatUserId(PlayerSession.tiktokUsername)
                isChatMutedSelf = state.mutedUsers?.contains { normalizeChatUserId($0.userId) == me } == true
            }
        case "balance_toast":
            if let payload = json["payload"] as? [String: Any],
               let user = payload["user"] as? String,
               user.lowercased() == PlayerSession.tiktokUsername.lowercased(),
               let bal = payload["balance"] as? Int {
                applyBalanceFromServer(balance: bal)
                if let invObj = payload["inventory"] as? [String: Any],
                   let invData = try? JSONSerialization.data(withJSONObject: invObj),
                   let inv = try? JSONDecoder().decode(PowerupInventory.self, from: invData) {
                    patchWallet { $0.inventory = inv }
                }
            }
        case "presence_update":
            if let payload = json["payload"],
               let payloadData = try? JSONSerialization.data(withJSONObject: payload),
               let snap = try? JSONDecoder().decode(PresenceWirePayload.self, from: payloadData) {
                applyPresenceSnapshot(count: snap.activeAppUsers, users: snap.activeAppUserList)
            }
        default:
            break
        }
    }

    private var chatBannerDismissTask: Task<Void, Never>?

    func dismissChatBanner() {
        chatBannerDismissTask?.cancel()
        activeChatBanner = nil
    }

    private func ingestAppChatMessage(_ row: AppChatMessage, showBanner: Bool = true) {
        guard knownChatIds.insert(row.id).inserted else { return }
        appChatMessages.append(row)
        appChatMessages.sort { $0.at < $1.at }
        if appChatMessages.count > 80 {
            let drop = appChatMessages.count - 80
            let removed = appChatMessages.prefix(drop)
            for r in removed { knownChatIds.remove(r.id) }
            appChatMessages.removeFirst(drop)
        }
        if showBanner {
            presentChatBannerIfNeeded(for: row)
        }
    }

    private func presentChatBannerIfNeeded(for row: AppChatMessage) {
        guard AppPreferences.chatBannerNotificationsEnabled else { return }
        guard !suppressChatBanners else { return }
        guard !row.isMine else { return }

        let text = row.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        activeChatBanner = AppChatBannerNotification(
            messageId: row.id,
            displayName: row.displayName,
            userId: row.userId,
            message: text,
            appLabel: row.resolvedAppLabel
        )

        chatBannerDismissTask?.cancel()
        let bannerId = row.id
        chatBannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_500_000_000)
            guard !Task.isCancelled else { return }
            if activeChatBanner?.messageId == bannerId {
                activeChatBanner = nil
            }
        }
    }

    private func mergeAppChatMessages(_ rows: [AppChatMessage]) {
        for row in rows {
            ingestAppChatMessage(row, showBanner: false)
        }
    }

    private func removeAppChatMessageLocally(_ messageId: String) {
        knownChatIds.remove(messageId)
        appChatMessages.removeAll { $0.id == messageId }
    }

    private func applyMutedChatUsers(_ rows: [MutedChatUser]) {
        mutedChatUsers = rows
        let me = normalizeChatUserId(PlayerSession.tiktokUsername)
        isChatMutedSelf = rows.contains { normalizeChatUserId($0.userId) == me }
    }

    private func normalizeChatUserId(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
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
            notePresenceJoins(users)
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

    private func notePresenceJoins(_ users: [ActiveAppUser]) {
        let newIds = Set(users.map(\.userId))
        let previousUsers = activeAppUserList
        defer {
            knownPresenceUserIds = newIds
            presenceSnapshotReady = true
        }
        guard presenceSnapshotReady else { return }

        let newcomers = users.filter { !$0.isMe && !knownPresenceUserIds.contains($0.userId) }
        if let joined = newcomers.last {
            showPresenceAnnouncement(for: joined, kind: .joined)
            return
        }

        let departures = previousUsers.filter {
            !$0.isMe && knownPresenceUserIds.contains($0.userId) && !newIds.contains($0.userId)
        }
        if let left = departures.last {
            showPresenceAnnouncement(for: left, kind: .left)
        }
    }

    private func showPresenceAnnouncement(for user: ActiveAppUser, kind: PresenceActivityAnnouncement.Kind) {
        let label = user.presenceUsernameLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        let announcement = PresenceActivityAnnouncement(username: label, kind: kind)
        presenceJoinDismissTask?.cancel()
        presenceJoinAnnouncement = announcement
        presenceJoinDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            if presenceJoinAnnouncement == announcement {
                presenceJoinAnnouncement = nil
            }
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
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendPresenceHeartbeat()
            }
        }
    }

    func dismissRoundResultPopup() {
        roundResultPopup = nil
        pendingRoundResultPopup = nil
    }

    /// Called when the chart crash slam animation finishes — shows round results.
    func presentPendingRoundResultPopup() {
        guard let pending = pendingRoundResultPopup else { return }
        roundResultPopup = pending
        pendingRoundResultPopup = nil
    }

    /// Keeps last-five crash list when server sends it; falls back to local tracking on older PC builds.
    private func enrichState(_ s: CrashGameState) -> CrashGameState {
        var out = enrichOpenBets(s)
        if !out.recentCrashes.isEmpty {
            localRecentCrashes = out.recentCrashes
            return out
        }
        if out.phase == .ended, let cp = out.crashPoint, cp > 0 {
            let v = (cp * 100).rounded() / 100
            if localRecentCrashes.last != v {
                localRecentCrashes.append(v)
                if localRecentCrashes.count > 5 {
                    localRecentCrashes.removeFirst(localRecentCrashes.count - 5)
                }
            }
        }
        out.recentCrashes = localRecentCrashes
        return out
    }

    /// Server on y666suf.com may still clear `openBets` during running/ended — cache + merge last result.
    private func enrichOpenBets(_ s: CrashGameState) -> CrashGameState {
        var out = s

        if out.roundId != cachedOpenBetsRoundId, out.phase == .betting {
            cachedOpenBets = []
            cachedOpenBetsRoundId = out.roundId
        }

        if !out.openBets.isEmpty {
            cachedOpenBets = out.openBets
            cachedOpenBetsRoundId = out.roundId
            return out
        }

        if out.roundId == cachedOpenBetsRoundId, !cachedOpenBets.isEmpty,
           out.phase == .running || out.phase == .ended {
            out.openBets = cachedOpenBets
            return out
        }

        if out.phase == .ended,
           let result = out.lastResult,
           result.roundId == out.roundId {
            let fromResult = openBets(from: result)
            if !fromResult.isEmpty {
                out.openBets = fromResult
                cachedOpenBets = fromResult
                cachedOpenBetsRoundId = out.roundId
            }
        }

        return out
    }

    private func openBets(from result: RoundLastResult) -> [OpenBet] {
        var rows: [OpenBet] = []
        var seen = Set<String>()
        func append(_ user: String, name: String, amount: Int, cashout: Double) {
            let key = "\(user)|\(amount)|\(cashout)"
            guard seen.insert(key).inserted else { return }
            rows.append(OpenBet(user: user, displayName: name, amount: amount, cashout: cashout))
        }
        for row in result.wins + result.losses {
            guard let bet = row.bet, let cashout = row.cashout, bet > 0 else { continue }
            append(row.user, name: row.resolvedName, amount: bet, cashout: cashout)
        }
        return rows
    }

    private func rememberPlacedBet(amount: Int, cashout: Double) {
        guard amount > 0, cashout >= 1.05 else { return }
        let user = PlayerSession.tiktokUsername
        guard !user.isEmpty else { return }
        let name = PlayerSession.displayName
        let bet = OpenBet(user: user, displayName: name.isEmpty ? user : name, amount: amount, cashout: cashout)
        if cachedOpenBetsRoundId != gameState.roundId {
            cachedOpenBetsRoundId = gameState.roundId
            cachedOpenBets = []
        }
        cachedOpenBets.removeAll { $0.user == user }
        cachedOpenBets.append(bet)
        var state = gameState
        if state.roundId == cachedOpenBetsRoundId {
            state.openBets = cachedOpenBets
            gameState = enrichState(state)
        }
    }

    private func applyStateSideEffects(_ s: CrashGameState) {
        if s.roundId != lastRoundId {
            lastRoundId = s.roundId
            multiplierHistory = [1]
            if s.phase != .ended {
                roundResultPopup = nil
                pendingRoundResultPopup = nil
            }
        }
        taxPotAmount = s.taxPot?.displayAmount ?? 0
        updateSubline(s)
        updateRoundResultPopup(s)
        if s.phase == .running {
            let m = max(s.multiplier, 1)
            let last = multiplierHistory.last ?? 1
            if multiplierHistory.isEmpty || abs(last - m) > 0.0005 {
                multiplierHistory.append(m)
                if multiplierHistory.count > 240 { multiplierHistory.removeFirst() }
            }
        } else if s.phase == .ended {
            let final = max(s.crashPoint ?? s.multiplier, 1)
            let last = multiplierHistory.last ?? 1
            if abs(last - final) > 0.0005 {
                multiplierHistory.append(final)
                if multiplierHistory.count > 240 { multiplierHistory.removeFirst() }
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
                pendingRoundResultPopup = summary
                roundResultPopup = nil
            }
        }
        if s.phase == .betting {
            roundResultPopup = nil
            pendingRoundResultPopup = nil
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

private struct PresenceWirePayload: Decodable {
    var activeAppUsers: Int?
    var activeAppUserList: [ActiveAppUser]?
}
