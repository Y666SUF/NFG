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

    func fetchAppChatHistory(limit: Int = 50) async throws -> [AppChatMessage] {
        var comp = URLComponents(url: baseURL.appending(path: "/api/mobile/chat"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = comp.url else { throw GameAPIError.invalidURL }
        let (data, response) = try await GameHTTP.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GameAPIError.serverError("Chat history unavailable")
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
        if http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GameAPIError.serverError(text)
        }
        struct SendResp: Decodable { var message: AppChatMessage }
        return try JSONDecoder().decode(SendResp.self, from: data).message
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

    private func validateMobileResponse(data: Data, response: URLResponse, endpoint: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GameAPIError.serverError("No response from server")
        }
        if http.statusCode == 404 {
            throw GameAPIError.serverError("Linking is not available right now. Try again later.")
        }
        if http.statusCode >= 400 {
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
}
