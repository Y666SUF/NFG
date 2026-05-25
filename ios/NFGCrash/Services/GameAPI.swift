import Foundation

/// Shared session with short timeouts so unreachable PCs fail in seconds, not minutes.
enum GameHTTP {
    static let requestTimeout: TimeInterval = 8

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout + 2
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var req = request
        req.timeoutInterval = requestTimeout
        return try await session.data(for: req)
    }

    static func data(from url: URL) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.timeoutInterval = requestTimeout
        return try await session.data(for: req)
    }
}

enum GameAPIError: LocalizedError {
    case invalidURL
    case serverError(String)
    case notLoggedIn
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Something went wrong. Try again."
        case .serverError(let s): return s
        case .notLoggedIn: return "Link your TikTok account on live first."
        case .timedOut:
            return "Connection timed out. Try again."
        }
    }
}

struct LinkStartResponse: Decodable {
    var ok: Bool?
    var code: String
    var expiresInSeconds: Int
    /// Older Windows server builds omit this; we synthesize it from `tiktokCommand`.
    var instructions: String?
    var tiktokCommand: String

    var resolvedInstructions: String {
        if let instructions, !instructions.isEmpty { return instructions }
        return "Comment on your LIVE stream from your TikTok account: \(tiktokCommand)"
    }
}

struct LinkStatusResponse: Decodable {
    var status: String
    var code: String?
    var secondsLeft: Int?
    var userId: String?
    var displayName: String?
    var token: String?
    var expiresAt: Int64?
}

struct AppReviewLoginResponse: Decodable {
    var ok: Bool?
    var token: String?
    var userId: String?
    var displayName: String?
    var balance: Int?
    var purpose: String?
}

struct GameAPI {
    let baseURL: URL
    var authToken: String?

    init(baseURLString: String) throws {
        var raw = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasSuffix("/") { raw.removeLast() }
        if !raw.hasPrefix("http") { raw = "http://\(raw)" }
        guard let url = URL(string: raw) else { throw GameAPIError.invalidURL }
        self.baseURL = url
        self.authToken = AuthStore.sessionToken
    }

    private func authorizedRequest(url: URL, method: String = "GET", jsonBody: [String: Any]? = nil) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let jsonBody {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        if let authToken, !authToken.isEmpty {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.setValue(AuthStore.deviceId, forHTTPHeaderField: "X-Device-Id")
        req.setValue("nfg-crash", forHTTPHeaderField: "X-Client-App")
        return req
    }

    var webSocketURL: URL {
        var comp = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comp.scheme = (comp.scheme == "https") ? "wss" : "ws"
        return comp.url!
    }

    func fetchState() async throws -> CrashGameState {
        let (data, _) = try await GameHTTP.data(from: baseURL.appending(path: "/api/state"))
        return try JSONDecoder().decode(CrashGameState.self, from: data)
    }

    func fetchMobileStatus() async throws -> Bool {
        let status = try await fetchMobileStatusDetail()
        return status.ok == true
    }

    func fetchMobileStatusDetail() async throws -> MobileStatusResponse {
        let (data, response) = try await GameHTTP.data(from: baseURL.appending(path: "/api/mobile/status"))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GameAPIError.serverError("Server status unavailable")
        }
        return try JSONDecoder().decode(MobileStatusResponse.self, from: data)
    }

    func fetchTikTokLiveStatus() async throws -> TikTokLiveStatus {
        let detail = try await fetchMobileStatusDetail()
        return detail.toTikTokLiveStatus()
    }

    struct PresenceSnapshot: Decodable {
        var activeAppUsers: Int?
        var activeAppUserList: [ActiveAppUser]?
    }

    /// Marks this device as active; returns count and who is online when the server supports it.
    func sendPresenceHeartbeat() async throws -> PresenceSnapshot {
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/presence/heartbeat"),
            method: "POST",
            jsonBody: ["deviceId": AuthStore.deviceId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("Active player count is not available on this server yet.")
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not update presence")
        }
        return try JSONDecoder().decode(PresenceSnapshot.self, from: data)
    }

    func fetchActiveAppUsers() async throws -> PresenceSnapshot {
        let (data, response) = try await GameHTTP.data(
            from: baseURL.appending(path: "/api/mobile/presence/active")
        )
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("Online player list is not available on this server yet.")
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not load online players")
        }
        return try JSONDecoder().decode(PresenceSnapshot.self, from: data)
    }

    func fetchProfile(user: String) async throws -> PlayerProfile {
        let encoded = user.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? user
        let (data, _) = try await GameHTTP.data(from: baseURL.appending(path: "/api/economy/profile/\(encoded)"))
        return try JSONDecoder().decode(PlayerProfile.self, from: data)
    }

    /// Full wallet: balance, shield, jet lock, powerup inventory (same data as !balance, no cooldown).
    func fetchMobileWallet() async throws -> PlayerWallet {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(url: baseURL.appending(path: "/api/mobile/me"))
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("Wallet is temporarily unavailable. Try again later.")
        }
        if http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GameAPIError.serverError(text)
        }
        return try JSONDecoder().decode(PlayerWallet.self, from: data)
    }

    func fetchRewardedAdStatus() async throws -> RewardedAdStatusResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(url: baseURL.appending(path: "/api/mobile/rewarded-ad/status"))
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Ad rewards are not enabled on the game server yet. Copy mobile-rewarded-ad.js to your PC and restart the game."
            )
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not load ad reward status.")
        }
        return try JSONDecoder().decode(RewardedAdStatusResponse.self, from: data)
    }

    func fetchStoreProducts() async throws -> [StoreProduct] {
        let (data, response) = try await GameHTTP.data(from: baseURL.appending(path: "/api/mobile/store/products"))
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 404 {
            return StoreCatalog.fallbackProducts
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not load store.")
        }
        let resp = try JSONDecoder().decode(StoreProductsResponse.self, from: data)
        return resp.products ?? StoreCatalog.fallbackProducts
    }

    func fetchStoreProductsResponse() async throws -> StoreProductsResponse {
        let (data, response) = try await GameHTTP.data(from: baseURL.appending(path: "/api/mobile/store/products"))
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 404 {
            return StoreProductsResponse(
                ok: true,
                testMode: false,
                appleIAP: true,
                productIds: StoreCatalog.fallbackProducts.map(\.id),
                message: nil,
                products: StoreCatalog.fallbackProducts
            )
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not load store.")
        }
        return try JSONDecoder().decode(StoreProductsResponse.self, from: data)
    }

    func verifyPurchase(
        productId: String,
        transactionId: String,
        signedTransactionInfo: String
    ) async throws -> StorePurchaseResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/store/verify-purchase"),
            method: "POST",
            jsonBody: [
                "productId": productId,
                "transactionId": transactionId,
                "signedTransactionInfo": signedTransactionInfo,
            ]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Purchase verify API not on server yet. git pull on PC and restart Node."
            )
        }
        if http.statusCode >= 400 {
            let err = try? JSONDecoder().decode(StorePurchaseResponse.self, from: data)
            throw GameAPIError.serverError(err?.message ?? "Purchase verification failed.")
        }
        return try JSONDecoder().decode(StorePurchaseResponse.self, from: data)
    }

    func testPurchase(productId: String) async throws -> StorePurchaseResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/store/test-purchase"),
            method: "POST",
            jsonBody: ["productId": productId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Store is not enabled on the game server yet. Copy mobile-store.js to your PC and restart."
            )
        }
        if http.statusCode >= 400 {
            let err = try? JSONDecoder().decode(StorePurchaseResponse.self, from: data)
            throw GameAPIError.serverError(err?.message ?? "Purchase failed.")
        }
        return try JSONDecoder().decode(StorePurchaseResponse.self, from: data)
    }

    func claimRewardedAd() async throws -> RewardedAdClaimResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/rewarded-ad/claim"),
            method: "POST",
            jsonBody: [:]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Ad rewards are not enabled on the game server yet. Copy mobile-rewarded-ad.js to your PC and restart the game."
            )
        }
        if http.statusCode == 429 {
            let err = try? JSONDecoder().decode(RewardedAdClaimResponse.self, from: data)
            throw GameAPIError.serverError(err?.message ?? "Ad reward not available yet.")
        }
        if http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GameAPIError.serverError(text)
        }
        return try JSONDecoder().decode(RewardedAdClaimResponse.self, from: data)
    }

    func fetchCosmeticsShopCatalog() async throws -> CosmeticsShopCatalog {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(url: baseURL.appending(path: "/api/mobile/shop/catalog"))
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Display shop is not on the game server yet. Copy mobile-cosmetics.js to your PC and restart Node."
            )
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not load display shop.")
        }
        return try JSONDecoder().decode(CosmeticsShopCatalog.self, from: data)
    }

    func purchaseNameStyle(styleId: String) async throws -> CosmeticsPurchaseResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/shop/namefx"),
            method: "POST",
            jsonBody: ["styleId": styleId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Name FX shop is not on the game server yet. Copy mobile-cosmetics.js to your PC and restart Node."
            )
        }
        let decoded = try JSONDecoder().decode(CosmeticsPurchaseResponse.self, from: data)
        if http.statusCode >= 400 || decoded.ok == false {
            throw GameAPIError.serverError(decoded.message ?? "Could not equip name style.")
        }
        return decoded
    }

    func purchaseNameBadge(badgeId: String) async throws -> CosmeticsPurchaseResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/shop/badge"),
            method: "POST",
            jsonBody: ["badgeId": badgeId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Status icon shop is not on the game server yet. Copy mobile-cosmetics.js to your PC and restart Node."
            )
        }
        let decoded = try JSONDecoder().decode(CosmeticsPurchaseResponse.self, from: data)
        if http.statusCode >= 400 || decoded.ok == false {
            throw GameAPIError.serverError(decoded.message ?? "Could not buy status icon.")
        }
        return decoded
    }

    func fetchAppChatHistory(limit: Int = 50) async throws -> [AppChatMessage] {
        var comp = URLComponents(url: baseURL.appending(path: "/api/mobile/chat"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = comp.url else { throw GameAPIError.invalidURL }
        let (data, response) = try await GameHTTP.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response from server")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("App chat isn't on the game server yet. Update the PC server and restart.")
        }
        if http.statusCode != 200 {
            throw GameAPIError.serverError("Chat history unavailable (HTTP \(http.statusCode))")
        }
        let resp = try JSONDecoder().decode(AppChatHistoryResponse.self, from: data)
        return resp.messages
    }

    func sendAppChat(message: String) async throws -> AppChatMessage {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/chat"),
            method: "POST",
            jsonBody: ["message": message]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 429 {
            struct RateErr: Decodable { var secondsLeft: Int? }
            let err = try? JSONDecoder().decode(RateErr.self, from: data)
            let sec = err?.secondsLeft ?? 1
            throw GameAPIError.serverError("Slow down — wait \(sec)s before sending again.")
        }
        if http.statusCode == 403 {
            struct ChatErr: Decodable { var error: String?; var message: String? }
            let err = try? JSONDecoder().decode(ChatErr.self, from: data)
            if err?.error == "chat_muted" {
                throw GameAPIError.serverError(err?.message ?? "You are muted from app chat.")
            }
        }
        if http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GameAPIError.serverError(text)
        }
        struct SendResp: Decodable { var message: AppChatMessage }
        return try JSONDecoder().decode(SendResp.self, from: data).message
    }

    func fetchChatModerationStatus() async throws -> ChatModerationStatusResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/chat/moderation"),
            method: "GET"
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response from server")
        }
        if http.statusCode == 404 {
            let owner = ChatOwnerConfig.isOwnerLinkedAccount()
            return ChatModerationStatusResponse(
                ok: true,
                isAdmin: owner,
                isMuted: false,
                mutedUsers: []
            )
        }
        try validateMobileResponse(data: data, response: response, endpoint: "chat/moderation")
        return try JSONDecoder().decode(ChatModerationStatusResponse.self, from: data)
    }

    func deleteAppChatMessage(messageId: String) async throws {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/chat/moderation/delete"),
            method: "POST",
            jsonBody: ["messageId": messageId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        try validateModerationResponse(data: data, response: response, endpoint: "chat/moderation/delete")
    }

    func muteAppChatUser(userId: String, displayName: String?) async throws -> [MutedChatUser] {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        var body: [String: String] = ["userId": userId]
        if let displayName, !displayName.isEmpty { body["displayName"] = displayName }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/chat/moderation/mute"),
            method: "POST",
            jsonBody: body
        )
        let (data, response) = try await GameHTTP.data(for: req)
        try validateMobileResponse(data: data, response: response, endpoint: "chat/moderation/mute")
        struct MuteResp: Decodable { var mutedUsers: [MutedChatUser]? }
        return try JSONDecoder().decode(MuteResp.self, from: data).mutedUsers ?? []
    }

    func unmuteAppChatUser(userId: String) async throws -> [MutedChatUser] {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/chat/moderation/unmute"),
            method: "POST",
            jsonBody: ["userId": userId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        try validateModerationResponse(data: data, response: response, endpoint: "chat/moderation/unmute")
        struct UnmuteResp: Decodable { var mutedUsers: [MutedChatUser]? }
        return try JSONDecoder().decode(UnmuteResp.self, from: data).mutedUsers ?? []
    }

    private func validateModerationResponse(data: Data, response: URLResponse, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response from server")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Mute and delete need a server update. Copy the latest server folder to your PC and restart the game server."
            )
        }
        try validateMobileResponse(data: data, response: response, endpoint: endpoint)
    }

    func startTikTokLink(deviceId: String) async throws -> LinkStartResponse {
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/link/start"),
            method: "POST",
            jsonBody: ["deviceId": deviceId]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        try validateMobileResponse(data: data, response: response, endpoint: "link/start")
        do {
            return try JSONDecoder().decode(LinkStartResponse.self, from: data)
        } catch {
            throw GameAPIError.serverError("Could not start linking. Try again.")
        }
    }

    func linkStatus(code: String) async throws -> LinkStatusResponse {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        let req = try authorizedRequest(url: baseURL.appending(path: "/api/mobile/link/status/\(encoded)"))
        let (data, response) = try await GameHTTP.data(for: req)
        try validateMobileResponse(data: data, response: response, endpoint: "link/status")
        return try JSONDecoder().decode(LinkStatusResponse.self, from: data)
    }

    func logoutSession() async {
        guard let authToken, !authToken.isEmpty else { return }
        guard let url = URL(string: baseURL.absoluteString + "/api/mobile/session/logout") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.setValue(AuthStore.deviceId, forHTTPHeaderField: "X-Device-Id")
        req.timeoutInterval = GameHTTP.requestTimeout
        _ = try? await GameHTTP.data(for: req)
    }

    /// App Store Review only — server validates code from `MOBILE_APP_REVIEW_CODE` (no TikTok LIVE).
    func appReviewLogin(deviceId: String, code: String) async throws -> AppReviewLoginResponse {
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/auth/app-review"),
            method: "POST",
            jsonBody: ["deviceId": deviceId, "code": code]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response from server")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("App Review sign-in is not enabled on the server.")
        }
        if http.statusCode == 401 {
            throw GameAPIError.serverError("Invalid App Review code.")
        }
        try validateMobileResponse(data: data, response: response, endpoint: "auth/app-review")
        let decoded = try JSONDecoder().decode(AppReviewLoginResponse.self, from: data)
        guard decoded.ok == true, let token = decoded.token, let userId = decoded.userId else {
            throw GameAPIError.serverError("Could not sign in for App Review.")
        }
        return decoded
    }

    private func validateMobileResponse(data: Data, response: URLResponse, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response from server")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("Linking is not available right now. Try again later.")
        }
        if http.statusCode >= 400 {
            struct MobileErr: Decodable { var message: String?; var error: String? }
            if let err = try? JSONDecoder().decode(MobileErr.self, from: data),
               let msg = err.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !msg.isEmpty {
                throw GameAPIError.serverError(msg)
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GameAPIError.serverError(body.isEmpty ? "HTTP \(http.statusCode) on \(endpoint)" : body)
        }
    }

    func sendChat(message: String, userId: String, displayName: String) async throws -> ChatActionResult {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/chat"),
            method: "POST",
            jsonBody: [
                "message": message,
                "userId": userId,
                "user": userId,
                "displayName": displayName,
                "source": "mobile",
            ]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GameAPIError.serverError(text)
        }
        return try JSONDecoder().decode(ChatActionResult.self, from: data)
    }

    /// Full sorted balance list; requests all players when server supports `?limit=all`.
    func fetchAllBalances() async throws -> (rows: [LeaderboardRow], total: Int) {
        var comp = URLComponents(url: baseURL.appending(path: "/api/balances"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "limit", value: "all")]
        guard let url = comp.url else { throw GameAPIError.invalidURL }
        let (data, _) = try await GameHTTP.data(from: url)
        let resp = try JSONDecoder().decode(BalancesResponse.self, from: data)
        let rows = resp.balances.enumerated().map { index, row -> LeaderboardRow in
            var r = row
            r.rankPosition = index + 1
            return r
        }
        let total = resp.total ?? rows.count
        return (rows, total)
    }

    func fetchArcadeCatalog() async throws -> ArcadeCatalogResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(url: baseURL.appending(path: "/api/mobile/arcade/catalog"))
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Vault Arcade is not on the game server yet. Copy arcade files to your PC and restart Node."
            )
        }
        guard http.statusCode == 200 else {
            throw GameAPIError.serverError("Could not load Vault Arcade.")
        }
        return try JSONDecoder().decode(ArcadeCatalogResponse.self, from: data)
    }

    func arcadePlay(
        gameId: String,
        action: String = "status",
        payload: [String: Any] = [:]
    ) async throws -> ArcadePlayResponse {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/arcade/play"),
            method: "POST",
            jsonBody: ["gameId": gameId, "action": action, "payload": payload]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Vault Arcade is not on the game server yet. Copy arcade files to your PC and restart Node."
            )
        }
        let decoded = try JSONDecoder().decode(ArcadePlayResponse.self, from: data)
        if http.statusCode >= 400 || decoded.ok == false {
            throw GameAPIError.serverError(ArcadeErrors.userMessage(reason: decoded.reason, message: decoded.message))
        }
        return decoded
    }

    func updateDisplayName(_ displayName: String) async throws -> PlayerWallet {
        guard authToken != nil else { throw GameAPIError.notLoggedIn }
        let req = try authorizedRequest(
            url: baseURL.appending(path: "/api/mobile/profile/display-name"),
            method: "POST",
            jsonBody: ["displayName": displayName]
        )
        let (data, response) = try await GameHTTP.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response")
        }
        if http.statusCode == 401 {
            AuthStore.clearSession()
            throw GameAPIError.notLoggedIn
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError(
                "Display name settings are not on the game server yet. Copy mobile-profile.js to your PC and restart Node."
            )
        }
        struct DisplayNameResp: Decodable {
            var ok: Bool?
            var reason: String?
            var message: String?
            var wallet: PlayerWallet?
        }
        let decoded = try JSONDecoder().decode(DisplayNameResp.self, from: data)
        if http.statusCode >= 400 || decoded.ok == false {
            let msg = decoded.message ?? decoded.reason ?? "This display name is not allowed."
            throw GameAPIError.serverError(msg)
        }
        guard let wallet = decoded.wallet else {
            throw GameAPIError.serverError("Could not save display name.")
        }
        return wallet
    }
}
