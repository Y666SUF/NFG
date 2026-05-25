import Foundation

enum GamePhase: String, Codable {
    case idle
    case betting
    case running
    case ended
}

struct TaxPotStatus: Codable, Equatable {
    var potAmount: Int?
    var amount: Int?

    var displayAmount: Int {
        potAmount ?? amount ?? 0
    }
}

struct LeaderboardRow: Codable, Identifiable, Hashable {
    var name: String?
    var user: String?
    var displayName: String?
    var balance: Int
    var allTime: Int?
    var level: Int?
    var rank: String?
    var nameStyle: String?
    var nameBadge: String?
    var superFan: Bool?
    var shieldActive: Bool?
    var shieldMsLeft: Int?
    var jetLockActive: Bool?

    var id: String { resolvedUser }
    var resolvedUser: String { user ?? name ?? displayName ?? "?" }
    var resolvedDisplayName: String {
        let d = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return d.isEmpty ? resolvedUser : d
    }

    var rankPosition: Int?

    enum CodingKeys: String, CodingKey {
        case name, user, displayName, balance, allTime, level, rank, nameStyle, nameBadge, superFan
        case shieldActive, shieldMsLeft, jetLockActive
    }
}

struct OpenBet: Codable, Identifiable, Hashable {
    var user: String
    var displayName: String
    var amount: Int
    var cashout: Double

    var id: String { "\(user)-\(amount)-\(cashout)" }

    init(user: String, displayName: String, amount: Int, cashout: Double) {
        self.user = user
        self.displayName = displayName
        self.amount = amount
        self.cashout = cashout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
        if let dn = try c.decodeIfPresent(String.self, forKey: .displayName), !dn.isEmpty {
            displayName = dn
        } else if let n = try c.decodeIfPresent(String.self, forKey: .name), !n.isEmpty {
            displayName = n
        } else {
            displayName = user
        }
        amount = try c.decodeIfPresent(Int.self, forKey: .amount) ?? 0
        if let co = try c.decodeIfPresent(Double.self, forKey: .cashout) {
            cashout = co
        } else if let co = try c.decodeIfPresent(Int.self, forKey: .cashout) {
            cashout = Double(co)
        } else {
            cashout = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user, forKey: .user)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(amount, forKey: .amount)
        try c.encode(cashout, forKey: .cashout)
    }

    private enum CodingKeys: String, CodingKey {
        case user, displayName, name, amount, cashout
    }
}

struct RoundOutcome: Codable, Identifiable, Hashable {
    var user: String
    var displayName: String?
    var result: String?
    var bet: Int?
    var cashout: Double?
    var payout: Int?
    var profit: Int?
    var grossPayout: Int?
    var level: Int?
    var rank: String?

    var id: String { user }
    var resolvedName: String {
        let d = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return d.isEmpty ? user : d
    }

    var isWin: Bool { result == "win" }
}

struct RoundLastResult: Codable, Equatable {
    var roundId: Int
    var crashPoint: Double
    var wins: [RoundOutcome]
    var losses: [RoundOutcome]
}

struct RoundResultSummary: Identifiable, Equatable {
    var id: Int { roundId }
    var roundId: Int
    var crashPoint: Double
    var wins: [RoundOutcome]
    var losses: [RoundOutcome]

    init(from result: RoundLastResult) {
        roundId = result.roundId
        crashPoint = result.crashPoint
        wins = result.wins
        losses = result.losses
    }

    var hasEntries: Bool { !wins.isEmpty || !losses.isEmpty }
}

struct CrashGameState: Codable, Equatable {
    var phase: GamePhase
    var roundId: Int
    var multiplier: Double
    var crashPoint: Double?
    var bettingEndsAt: Int64
    var nextRoundStartsAt: Int64?
    var openBets: [OpenBet]
    var queuedBets: [OpenBet]
    var taxPot: TaxPotStatus?
    var lastResult: RoundLastResult?
    var recentCrashes: [Double]

    static let empty = CrashGameState(
        phase: .idle,
        roundId: 0,
        multiplier: 1,
        crashPoint: nil,
        bettingEndsAt: 0,
        nextRoundStartsAt: nil,
        openBets: [],
        queuedBets: [],
        taxPot: nil,
        lastResult: nil,
        recentCrashes: []
    )

    enum CodingKeys: String, CodingKey {
        case phase, roundId, multiplier, crashPoint, bettingEndsAt, nextRoundStartsAt
        case openBets, queuedBets, taxPot, lastResult, recentCrashes
    }

    init(
        phase: GamePhase,
        roundId: Int,
        multiplier: Double,
        crashPoint: Double?,
        bettingEndsAt: Int64,
        nextRoundStartsAt: Int64?,
        openBets: [OpenBet],
        queuedBets: [OpenBet],
        taxPot: TaxPotStatus?,
        lastResult: RoundLastResult?,
        recentCrashes: [Double] = []
    ) {
        self.phase = phase
        self.roundId = roundId
        self.multiplier = multiplier
        self.crashPoint = crashPoint
        self.bettingEndsAt = bettingEndsAt
        self.nextRoundStartsAt = nextRoundStartsAt
        self.openBets = openBets
        self.queuedBets = queuedBets
        self.taxPot = taxPot
        self.lastResult = lastResult
        self.recentCrashes = recentCrashes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decode(GamePhase.self, forKey: .phase)
        roundId = try c.decodeIfPresent(Int.self, forKey: .roundId) ?? 0
        multiplier = try c.decodeIfPresent(Double.self, forKey: .multiplier) ?? 1
        crashPoint = try c.decodeIfPresent(Double.self, forKey: .crashPoint)
        bettingEndsAt = try c.decodeIfPresent(Int64.self, forKey: .bettingEndsAt) ?? 0
        nextRoundStartsAt = try c.decodeIfPresent(Int64.self, forKey: .nextRoundStartsAt)
        openBets = try c.decodeIfPresent([OpenBet].self, forKey: .openBets) ?? []
        queuedBets = try c.decodeIfPresent([OpenBet].self, forKey: .queuedBets) ?? []
        taxPot = try c.decodeIfPresent(TaxPotStatus.self, forKey: .taxPot)
        lastResult = try c.decodeIfPresent(RoundLastResult.self, forKey: .lastResult)
        recentCrashes = try c.decodeIfPresent([Double].self, forKey: .recentCrashes) ?? []
    }
}

struct PlayerProfile: Codable, Equatable {
    var ok: Bool?
    var user: String
    var displayName: String
    var balance: Int
    var allTime: Int
    var level: Int
    var rank: String
    var nameStyle: String
    var superFan: Bool

    static let empty = PlayerProfile(
        ok: nil, user: "", displayName: "", balance: 0, allTime: 0,
        level: 1, rank: "Rookie", nameStyle: "none", superFan: false
    )

    init(
        ok: Bool?, user: String, displayName: String, balance: Int, allTime: Int,
        level: Int, rank: String, nameStyle: String, superFan: Bool
    ) {
        self.ok = ok
        self.user = user
        self.displayName = displayName
        self.balance = balance
        self.allTime = allTime
        self.level = level
        self.rank = rank
        self.nameStyle = nameStyle
        self.superFan = superFan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? user
        balance = try c.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        allTime = try c.decodeIfPresent(Int.self, forKey: .allTime) ?? 0
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 1
        rank = try c.decodeIfPresent(String.self, forKey: .rank) ?? "Rookie"
        nameStyle = try c.decodeIfPresent(String.self, forKey: .nameStyle) ?? "none"
        superFan = try c.decodeIfPresent(Bool.self, forKey: .superFan) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case ok, user, displayName, balance, allTime, level, rank, nameStyle, superFan
    }
}

struct ChatActionResult: Codable {
    var ok: Bool?
    var parsed: ParsedChat?
    var ignored: Bool?
    var error: String?

    struct ParsedChat: Codable {
        var type: String?
        var ok: Bool?
        var reason: String?
        var balance: Int?
        var amount: Int?
        var cashout: Double?
        var user: String?
        var displayName: String?
        var cooldown: Bool?
        var secondsLeft: Int?
        var inventory: PowerupInventory?
    }
}

struct FeedLine: Identifiable, Hashable {
    let id: String
    let text: String
    let ts: Date
}

struct TikTokLiveStatus: Equatable {
    var enabled: Bool
    var uniqueId: String
    var state: String
    var isLive: Bool
    var roomId: String?

    static let unknown = TikTokLiveStatus(
        enabled: false, uniqueId: "y666.suf", state: "unknown", isLive: false, roomId: nil
    )

    var label: String {
        switch state {
        case "live": return "LIVE"
        case "waiting": return "OFFLINE"
        case "offline": return "OFFLINE"
        case "disabled": return "BRIDGE OFF"
        default: return "UNKNOWN"
        }
    }

    var isOnLive: Bool { isLive || state == "live" }

    /// Opens the host’s live room in the TikTok app (universal link) when available.
    var tikTokLiveOpenURL: URL? {
        guard isOnLive else { return nil }
        let handle = Self.normalizedHandle(uniqueId)
        guard !handle.isEmpty else { return nil }
        if let room = roomId?.trimmingCharacters(in: .whitespacesAndNewlines), !room.isEmpty {
            let encoded = room.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? room
            return URL(string: "https://www.tiktok.com/share/live/\(encoded)")
        }
        return URL(string: "https://www.tiktok.com/@\(handle)/live")
    }

    private static func normalizedHandle(_ raw: String) -> String {
        var h = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("@") { h.removeFirst() }
        return h
    }
}

struct BalancesResponse: Decodable {
    var balances: [LeaderboardRow]
    var total: Int?
    var shown: Int?
}

struct PowerupInventory: Codable, Equatable {
    var stealCharges: Int
    var shieldBreakCharges: Int
    var jetLockCharges: Int

    static let empty = PowerupInventory(stealCharges: 0, shieldBreakCharges: 0, jetLockCharges: 0)

    init(stealCharges: Int, shieldBreakCharges: Int, jetLockCharges: Int) {
        self.stealCharges = stealCharges
        self.shieldBreakCharges = shieldBreakCharges
        self.jetLockCharges = jetLockCharges
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stealCharges = try c.decodeIfPresent(Int.self, forKey: .stealCharges) ?? 0
        shieldBreakCharges = try c.decodeIfPresent(Int.self, forKey: .shieldBreakCharges) ?? 0
        jetLockCharges = try c.decodeIfPresent(Int.self, forKey: .jetLockCharges) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case stealCharges, shieldBreakCharges, jetLockCharges
    }
}

struct PlayerWallet: Codable, Equatable {
    var ok: Bool?
    var user: String
    var displayName: String
    var displayNameLocked: Bool?
    var displayNameMaxLength: Int?
    var balance: Int
    var allTime: Int
    var level: Int
    var rank: String
    var nameStyle: String
    var nameBadge: String
    var ownedNameStyles: [String]
    var ownedBadges: [String]
    var superFan: Bool
    var shieldActive: Bool
    var shieldMsLeft: Int
    var jetLockActive: Bool
    var jetLockSecondsLeft: Int
    var inventory: PowerupInventory

    static let empty = PlayerWallet(
        ok: nil, user: "", displayName: "", balance: 0, allTime: 0,
        level: 1, rank: "Rookie", nameStyle: "none", nameBadge: "none",
        ownedNameStyles: [], ownedBadges: [],
        superFan: false,
        shieldActive: false, shieldMsLeft: 0, jetLockActive: false,
        jetLockSecondsLeft: 0, inventory: .empty
    )

    var shieldSecondsLeft: Int { max(0, shieldMsLeft / 1000) }

    init(
        ok: Bool?, user: String, displayName: String, balance: Int, allTime: Int,
        level: Int, rank: String, nameStyle: String, nameBadge: String,
        ownedNameStyles: [String], ownedBadges: [String],
        superFan: Bool,
        shieldActive: Bool, shieldMsLeft: Int, jetLockActive: Bool, jetLockSecondsLeft: Int,
        inventory: PowerupInventory
    ) {
        self.ok = ok
        self.user = user
        self.displayName = displayName
        self.balance = balance
        self.allTime = allTime
        self.level = level
        self.rank = rank
        self.nameStyle = nameStyle
        self.nameBadge = nameBadge
        self.ownedNameStyles = ownedNameStyles
        self.ownedBadges = ownedBadges
        self.superFan = superFan
        self.shieldActive = shieldActive
        self.shieldMsLeft = shieldMsLeft
        self.jetLockActive = jetLockActive
        self.jetLockSecondsLeft = jetLockSecondsLeft
        self.inventory = inventory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? user
        displayNameLocked = try c.decodeIfPresent(Bool.self, forKey: .displayNameLocked)
        displayNameMaxLength = try c.decodeIfPresent(Int.self, forKey: .displayNameMaxLength)
        balance = try c.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        allTime = try c.decodeIfPresent(Int.self, forKey: .allTime) ?? 0
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 1
        rank = try c.decodeIfPresent(String.self, forKey: .rank) ?? "Rookie"
        nameStyle = try c.decodeIfPresent(String.self, forKey: .nameStyle) ?? "none"
        nameBadge = try c.decodeIfPresent(String.self, forKey: .nameBadge) ?? "none"
        ownedNameStyles = try c.decodeIfPresent([String].self, forKey: .ownedNameStyles) ?? []
        ownedBadges = try c.decodeIfPresent([String].self, forKey: .ownedBadges) ?? []
        superFan = try c.decodeIfPresent(Bool.self, forKey: .superFan) ?? false
        shieldActive = try c.decodeIfPresent(Bool.self, forKey: .shieldActive) ?? false
        shieldMsLeft = try c.decodeIfPresent(Int.self, forKey: .shieldMsLeft) ?? 0
        jetLockActive = try c.decodeIfPresent(Bool.self, forKey: .jetLockActive) ?? false
        jetLockSecondsLeft = try c.decodeIfPresent(Int.self, forKey: .jetLockSecondsLeft) ?? 0
        inventory = try c.decodeIfPresent(PowerupInventory.self, forKey: .inventory) ?? .empty
    }

    private enum CodingKeys: String, CodingKey {
        case ok, user, displayName, displayNameLocked, displayNameMaxLength, balance, allTime, level, rank, nameStyle, nameBadge
        case ownedNameStyles, ownedBadges, superFan
        case shieldActive, shieldMsLeft, jetLockActive, jetLockSecondsLeft, inventory
    }
}

struct NameStyleShopItem: Codable, Identifiable, Hashable {
    var id: String
    var icon: String?
    var label: String?
    var cost: Int

    var resolvedLabel: String {
        let t = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? id.capitalized : t
    }
}

struct NameBadgeShopItem: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var short: String
    var tier: Int
    var cost: Int
}

struct CosmeticsShopCatalog: Codable, Equatable {
    var ok: Bool?
    var balance: Int?
    var nameStyle: String?
    var nameBadge: String?
    var ownedNameStyles: [String]?
    var ownedBadges: [String]?
    var nameStyles: [NameStyleShopItem]?
    var nameBadges: [NameBadgeShopItem]?

    var equippedStyle: String { nameStyle ?? "none" }
    var equippedBadge: String { nameBadge ?? "none" }
    var ownedStyleSet: Set<String> {
        Set((ownedNameStyles ?? []).map { $0.lowercased() })
    }
    var ownedBadgeSet: Set<String> {
        Set((ownedBadges ?? []).map { $0.lowercased() })
    }
}

struct CosmeticPurchaseDetails: Decodable {
    var balance: Int?
    var cost: Int?
    var nameStyle: String?
    var ownedNameStyles: [String]?
}

struct CosmeticsPurchaseResponse: Decodable {
    var ok: Bool?
    var message: String?
    var reason: String?
    var balance: Int?
    var wallet: PlayerWallet?
    var purchase: CosmeticPurchaseDetails?

    /// Best available balance after a shop purchase (wallet payload preferred).
    var resolvedBalance: Int? {
        wallet?.balance ?? balance ?? purchase?.balance
    }
}

struct AppChatMessage: Codable, Identifiable, Hashable {
    var id: String
    var userId: String
    var displayName: String
    var message: String
    var at: Int64
    var clientApp: String?
    var appLabel: String?
    var superFan: Bool?
    var superFanLevel: Int?
    var nameStyle: String?
    var nameBadge: String?

    var resolvedAppLabel: String {
        let label = appLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !label.isEmpty { return label }
        let raw = clientApp?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if raw == "nfg-hangman" { return "NFG Hangman" }
        if raw == "nfg-crash" { return "NFG Crash" }
        return ""
    }

    var isMine: Bool {
        userId.lowercased() == PlayerSession.tiktokUsername.lowercased()
    }

    var badge: SuperFanBadgeDisplay {
        SuperFanBadgeDisplay(superFan: superFan, level: superFanLevel)
    }
}

struct AppChatHistoryResponse: Decodable {
    var ok: Bool?
    var messages: [AppChatMessage]
}

struct MutedChatUser: Codable, Identifiable, Hashable {
    var userId: String
    var displayName: String?
    var mutedAt: Int64?
    var mutedBy: String?

    var id: String { userId.lowercased() }

    var resolvedName: String {
        let n = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !n.isEmpty { return n }
        return userId
    }
}

struct ChatModerationStatusResponse: Decodable {
    var ok: Bool?
    var isAdmin: Bool?
    var isMuted: Bool?
    var mutedUsers: [MutedChatUser]?
}

struct ChatMuteStatePayload: Decodable {
    var mutedUsers: [MutedChatUser]?
}

struct AppChatBannerNotification: Equatable, Identifiable {
    var messageId: String
    var displayName: String
    var userId: String
    var message: String
    var appLabel: String

    var id: String { messageId }
}

struct RewardedAdStatusResponse: Decodable {
    var ok: Bool?
    var rewardAmount: Int?
    var claimsToday: Int?
    var maxClaimsPerDay: Int?
    var unlimited: Bool?
    var cooldownSecondsLeft: Int?
    var canClaim: Bool?
    var reason: String?

    init(
        ok: Bool? = nil,
        rewardAmount: Int? = nil,
        claimsToday: Int? = nil,
        maxClaimsPerDay: Int? = nil,
        unlimited: Bool? = nil,
        cooldownSecondsLeft: Int? = nil,
        canClaim: Bool? = nil,
        reason: String? = nil
    ) {
        self.ok = ok
        self.rewardAmount = rewardAmount
        self.claimsToday = claimsToday
        self.maxClaimsPerDay = maxClaimsPerDay
        self.unlimited = unlimited
        self.cooldownSecondsLeft = cooldownSecondsLeft
        self.canClaim = canClaim
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        rewardAmount = try c.decodeIfPresent(Int.self, forKey: .rewardAmount)
        claimsToday = try c.decodeIfPresent(Int.self, forKey: .claimsToday)
        maxClaimsPerDay = try c.decodeIfPresent(Int.self, forKey: .maxClaimsPerDay)
        unlimited = try c.decodeIfPresent(Bool.self, forKey: .unlimited)
        cooldownSecondsLeft = try c.decodeIfPresent(Int.self, forKey: .cooldownSecondsLeft)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        if let b = try? c.decode(Bool.self, forKey: .canClaim) {
            canClaim = b
        } else if let n = try? c.decode(Int.self, forKey: .canClaim) {
            canClaim = n != 0
        } else {
            canClaim = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case ok, rewardAmount, claimsToday, maxClaimsPerDay, unlimited, cooldownSecondsLeft, canClaim, reason
    }

    /// Seconds until next claim (0 = ready now).
    var effectiveCooldownSeconds: Int {
        max(0, cooldownSecondsLeft ?? 0)
    }

    var isEffectivelyUnlimited: Bool {
        unlimited == true || maxClaimsPerDay == nil || AdMobConfig.rewardedAdsUnlimited
    }

    var effectivelyCanClaim: Bool {
        if isEffectivelyUnlimited, effectiveCooldownSeconds <= 0 { return true }
        if effectiveCooldownSeconds > 0 { return false }
        return canClaim != false
    }

    /// Apply app policy (unlimited ads) on top of server JSON.
    func normalizedForApp() -> RewardedAdStatusResponse {
        guard AdMobConfig.rewardedAdsUnlimited else { return self }
        return RewardedAdStatusResponse(
            ok: ok ?? true,
            rewardAmount: rewardAmount ?? AdMobConfig.rewardPoints,
            claimsToday: claimsToday,
            maxClaimsPerDay: nil,
            unlimited: true,
            cooldownSecondsLeft: 0,
            canClaim: true,
            reason: nil
        )
    }
}

struct RewardedAdClaimResponse: Decodable {
    var ok: Bool?
    var gained: Int?
    var balance: Int?
    var claimsToday: Int?
    var message: String?
    var error: String?
}

struct StoreProduct: Identifiable, Decodable, Hashable {
    var id: String
    var points: Int
    var priceLabel: String
    var title: String?

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return "\(points.formatted()) points"
    }
}

struct StoreProductsResponse: Decodable {
    var ok: Bool?
    var testMode: Bool?
    var appleIAP: Bool?
    var productIds: [String]?
    var message: String?
    var products: [StoreProduct]?
}

struct StorePurchaseResponse: Decodable {
    var ok: Bool?
    var testMode: Bool?
    var alreadyProcessed: Bool?
    var productId: String?
    var gained: Int?
    var balance: Int?
    var priceLabel: String?
    var message: String?
    var error: String?
}

struct SuperFanBadgeDisplay {
    let superFan: Bool
    let level: Int

    init(superFan: Bool?, level: Int? = nil) {
        self.superFan = superFan == true
        self.level = max(0, level ?? 0)
    }
}

struct ActiveAppUser: Identifiable, Hashable, Decodable {
    var userId: String
    var displayName: String
    var username: String?
    var isGuest: Bool?
    var chatMuted: Bool?
    var superFan: Bool?
    var superFanLevel: Int?
    var nameStyle: String?
    var nameBadge: String?

    var id: String { userId }

    var badge: SuperFanBadgeDisplay {
        SuperFanBadgeDisplay(superFan: superFan, level: superFanLevel)
    }

    var resolvedName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let u = username, !u.isEmpty { return u }
        return isGuest == true ? "Guest" : userId
    }

    var isMe: Bool {
        if userId.lowercased().hasPrefix("guest:") {
            let device = String(userId.dropFirst(6))
            return device == AuthStore.deviceId
        }
        let me = PlayerSession.tiktokUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !me.isEmpty else { return false }
        return userId.lowercased() == me.lowercased()
            || username?.lowercased() == me.lowercased()
    }

    /// TikTok-style @handle for presence join/leave toasts.
    var presenceUsernameLabel: String {
        if let raw = username?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let clean = raw.replacingOccurrences(of: "@", with: "")
            return "@\(clean)"
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if isGuest == true { return "Guest" }
        return userId
    }
}

/// Brief header toast when someone opens or closes the app.
struct PresenceActivityAnnouncement: Equatable {
    enum Kind: Equatable {
        case joined
        case left
    }

    var username: String
    var kind: Kind
}

struct MobileStatusResponse: Decodable {
    var ok: Bool?
    var activeAppUsers: Int?
    var activeAppUserList: [ActiveAppUser]?
    var tiktokLive: TikTokLivePayload?

    struct TikTokLivePayload: Decodable {
        var enabled: Bool?
        var uniqueId: String?
        var state: String?
        var isLive: Bool?
        var roomId: String?
    }

    func toTikTokLiveStatus() -> TikTokLiveStatus {
        guard let t = tiktokLive else { return .unknown }
        let st = t.state ?? "unknown"
        return TikTokLiveStatus(
            enabled: t.enabled ?? false,
            uniqueId: t.uniqueId ?? "y666.suf",
            state: st,
            isLive: t.isLive ?? (st == "live"),
            roomId: t.roomId
        )
    }
}
