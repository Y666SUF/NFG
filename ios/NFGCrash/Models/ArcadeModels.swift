import Foundation

struct ArcadeCatalogResponse: Decodable {
    var ok: Bool?
    var earnedToday: Int?
    var earnCap: Int?
    var earnLeft: Int?
    var liveBonusMultiplier: Double?
    var isLive: Bool?
    var funPoints: Int?
    var balance: Int?
    var games: [ArcadeGameInfo]?
    var missions: [ArcadeMissionInfo]?
    var season: ArcadeSeasonInfo?

    init(
        ok: Bool? = nil,
        earnedToday: Int? = nil,
        earnCap: Int? = nil,
        earnLeft: Int? = nil,
        liveBonusMultiplier: Double? = nil,
        isLive: Bool? = nil,
        funPoints: Int? = nil,
        balance: Int? = nil,
        games: [ArcadeGameInfo]? = nil,
        missions: [ArcadeMissionInfo]? = nil,
        season: ArcadeSeasonInfo? = nil
    ) {
        self.ok = ok
        self.earnedToday = earnedToday
        self.earnCap = earnCap
        self.earnLeft = earnLeft
        self.liveBonusMultiplier = liveBonusMultiplier
        self.isLive = isLive
        self.funPoints = funPoints
        self.balance = balance
        self.games = games
        self.missions = missions
        self.season = season
    }
}

struct ArcadeGameInfo: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var playsPerDay: Int
    var icon: String
    var playsLeft: Int?
    var playsUsed: Int?
    var skillLevel: Int?
    var maxSkillLevel: Int?

    init(
        id: String,
        title: String,
        subtitle: String,
        playsPerDay: Int,
        icon: String,
        playsLeft: Int?,
        playsUsed: Int?
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.playsPerDay = playsPerDay
        self.icon = icon
        self.playsLeft = playsLeft
        self.playsUsed = playsUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title =
            (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? id
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        playsPerDay =
            c.flexInt(forKey: .playsPerDay)
            ?? c.flexInt(forKey: .plays_per_day)
            ?? 99
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "🎮"
        playsLeft = c.flexInt(forKey: .playsLeft) ?? c.flexInt(forKey: .plays_left)
        playsUsed = c.flexInt(forKey: .playsUsed) ?? c.flexInt(forKey: .plays_used)
        skillLevel = c.flexInt(forKey: .skillLevel) ?? c.flexInt(forKey: .skill_level)
        maxSkillLevel = c.flexInt(forKey: .maxSkillLevel) ?? c.flexInt(forKey: .max_skill_level)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, icon, name
        case playsPerDay, plays_per_day
        case playsLeft, plays_left
        case playsUsed, plays_used
        case skillLevel, skill_level, maxSkillLevel, max_skill_level
    }
}

struct ArcadeMissionInfo: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var goal: Int
    var progress: Int?
    var done: Bool?
    var claimed: Bool?

    init(
        id: String,
        title: String,
        goal: Int,
        progress: Int? = nil,
        done: Bool? = nil,
        claimed: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.progress = progress
        self.done = done
        self.claimed = claimed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Mission"
        goal = c.flexInt(forKey: .goal) ?? 1
        progress = c.flexInt(forKey: .progress)
        done = c.flexBool(forKey: .done)
        claimed = c.flexBool(forKey: .claimed)
    }
}

struct ArcadeSeasonInfo: Decodable, Hashable {
    var weekKey: String?
    var points: Int?
    var rank: Int?
    var totalPlayers: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekKey = try c.decodeIfPresent(String.self, forKey: .weekKey)
        points = c.flexInt(forKey: .points)
        rank = c.flexInt(forKey: .rank)
        totalPlayers = c.flexInt(forKey: .totalPlayers)
    }

    private enum CodingKeys: String, CodingKey {
        case weekKey, points, rank, totalPlayers
    }
}

struct ArcadePlayResponse: Decodable {
    var ok: Bool?
    var reason: String?
    var message: String?
    var game: String?
    var gained: Int?
    var balance: Int?
    var capped: Bool?
    var wallet: PlayerWallet?
    var arcade: ArcadeCatalogResponse?
    var grid: [String]?
    var won: Bool?
    var guess: Double?
    var actual: Double?
    var win: Bool?
    var opponentScore: Int?
    var score: Int?
    var doors: [Int]?
    var bust: Bool?
    var cleared: Bool?
    var funPoints: Int?
    var found: [String]?
    var complete: Bool?
    var targets: [String]?
    var missions: [ArcadeMissionInfo]?
    var pending: Int?
    var level: Int?
    var yourPoints: Int?
    var rank: Int?
    var top: [ArcadeLadderRow]?
    var streak: Int?
    var prize: Int?
    var active: ArcadeHeistActive?
    var attempts: Int?
    var maxAttempts: Int?
    var solved: Bool?
    var hasRound: Bool?
    var multiplier: Double?
    var crashAt: Double?
    var skillLevel: Int?
    var maxSkillLevel: Int?
    var playsLeft: Int?
    var playsPerDay: Int?
    var zoneWidth: Double?
    var practiceMode: Bool?
    var started: Bool?
    var suggestedRisk: Int?
    var weekKey: String?
    var totalPlayers: Int?
    var spunToday: Bool?
    var season: ArcadeSeasonInfo?
    var hint: String?
    var vaultHeat: Int?
    var vaultStatus: String?
    var direction: String?
    var digitLocks: [Bool]?
    var guessesLeft: Int?
    var closeWin: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.flexBool(forKey: .ok)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        if reason == nil {
            reason = try c.decodeIfPresent(String.self, forKey: .error)
        }
        message = try c.decodeIfPresent(String.self, forKey: .message)
        game = try c.decodeIfPresent(String.self, forKey: .game)
        gained = c.flexInt(forKey: .gained)
        balance = c.flexInt(forKey: .balance)
        capped = c.flexBool(forKey: .capped)
        wallet = try? c.decode(PlayerWallet.self, forKey: .wallet)
        arcade = try? c.decode(ArcadeCatalogResponse.self, forKey: .arcade)
        grid = try c.decodeIfPresent([String].self, forKey: .grid)
        won = c.flexBool(forKey: .won)
        guess = c.flexDouble(forKey: .guess)
        actual = c.flexDouble(forKey: .actual)
        win = c.flexBool(forKey: .win)
        opponentScore = c.flexInt(forKey: .opponentScore)
        score = c.flexInt(forKey: .score)
        doors = try c.decodeIfPresent([Int].self, forKey: .doors)
        bust = c.flexBool(forKey: .bust)
        cleared = c.flexBool(forKey: .cleared)
        funPoints = c.flexInt(forKey: .funPoints)
        found = try c.decodeIfPresent([String].self, forKey: .found)
        complete = c.flexBool(forKey: .complete)
        targets = try c.decodeIfPresent([String].self, forKey: .targets)
        if let decoded = try? c.decode([ArcadeMissionInfo].self, forKey: .missions) {
            missions = decoded.filter { !$0.id.isEmpty }
        } else {
            missions = nil
        }
        pending = c.flexInt(forKey: .pending)
        level = c.flexInt(forKey: .level)
        yourPoints = c.flexInt(forKey: .yourPoints)
        rank = c.flexInt(forKey: .rank)
        if let decoded = try? c.decode([ArcadeLadderRow].self, forKey: .top) {
            top = decoded.filter { !$0.userId.isEmpty }
        } else {
            top = nil
        }
        streak = c.flexInt(forKey: .streak)
        prize = c.flexInt(forKey: .prize)
        active = try? c.decode(ArcadeHeistActive.self, forKey: .active)
        attempts = c.flexInt(forKey: .attempts)
        maxAttempts = c.flexInt(forKey: .maxAttempts)
        solved = c.flexBool(forKey: .solved)
        hasRound = c.flexBool(forKey: .hasRound)
        multiplier = c.flexDouble(forKey: .multiplier)
        crashAt = c.flexDouble(forKey: .crashAt)
        skillLevel = c.flexInt(forKey: .skillLevel)
        maxSkillLevel = c.flexInt(forKey: .maxSkillLevel)
        playsLeft = c.flexInt(forKey: .playsLeft)
        playsPerDay = c.flexInt(forKey: .playsPerDay)
        zoneWidth = c.flexDouble(forKey: .zoneWidth)
        practiceMode = c.flexBool(forKey: .practiceMode)
        started = c.flexBool(forKey: .started)
        suggestedRisk = c.flexInt(forKey: .suggestedRisk)
        weekKey = try c.decodeIfPresent(String.self, forKey: .weekKey)
        totalPlayers = c.flexInt(forKey: .totalPlayers)
        spunToday = c.flexBool(forKey: .spunToday)
        season = try? c.decode(ArcadeSeasonInfo.self, forKey: .season)
    }

    private enum CodingKeys: String, CodingKey {
        case ok, reason, error, message, game, gained, balance, capped, wallet, arcade
        case grid, won, guess, actual, win, opponentScore, score, doors
        case bust, cleared, funPoints, found, complete, targets, missions
        case pending, level, yourPoints, rank, top, streak, prize, active
        case attempts, maxAttempts, solved, hasRound, multiplier, crashAt
        case skillLevel, maxSkillLevel, playsLeft, playsPerDay, zoneWidth
        case practiceMode, started, suggestedRisk, weekKey, totalPlayers, spunToday, season
        case hint, vaultHeat, vaultStatus, direction, digitLocks, guessesLeft, closeWin
    }
}

enum ArcadeErrors {
    static func userMessage(reason: String?, message: String?) -> String {
        let code = reason ?? message
        if let message, !message.isEmpty, !isReasonCode(message) {
            return message
        }
        return friendlyReason(code)
    }

    private static func isReasonCode(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "invalid_action" || t == "invalid action" || t.contains("invalid_action")
    }

    private static func friendlyReason(_ reason: String?) -> String {
        switch reason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "invalid_action", "invalid action": return "That button isn't ready yet — follow the steps above."
        case "no_plays_left": return "No plays left today (max 5). Come back tomorrow."
        case "need_start": return "Start the round first."
        case "run_active": return "Finish the current round first."
        case "already_spun": return "You already used today's spin."
        case "already_solved": return "You already solved this today."
        case "nothing_to_collect": return "Nothing to collect yet — check back soon."
        case "insufficient_fun": return "Not enough fun points."
        case "unknown_game": return "This game is not on the server yet — update the PC server."
        case "no_round": return "Practice round loading — try again in a moment."
        case "bad_guess": return "Check your guess and try again."
        default:
            if let reason, !reason.isEmpty {
                return reason.replacingOccurrences(of: "_", with: " ").capitalized
            }
            return "Something went wrong."
        }
    }
}

struct ArcadeHeistActive: Decodable, Hashable {
    var runId: String?
    var step: Int?
    var multiplier: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runId = try c.decodeIfPresent(String.self, forKey: .runId)
        step = c.flexInt(forKey: .step)
        multiplier = c.flexInt(forKey: .multiplier)
    }

    private enum CodingKeys: String, CodingKey {
        case runId, step, multiplier
    }
}

struct ArcadeLadderRow: Decodable, Identifiable, Hashable {
    var userId: String
    var displayName: String?
    var points: Int
    var id: String { userId }

    var label: String {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        if userId.count > 14 { return String(userId.prefix(12)) + "…" }
        return userId.isEmpty ? "Player" : userId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId =
            (try? c.decode(String.self, forKey: .userId))
            ?? (try? c.decode(String.self, forKey: .user))
            ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        points = c.flexInt(forKey: .points) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case userId, user, displayName, points
    }
}

// MARK: - Lenient JSON helpers (server may send numbers as doubles or omit keys)

private extension KeyedDecodingContainer {
    func flexInt(forKey key: Key) -> Int? {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let v = try? decode(Double.self, forKey: key) { return Int(v) }
        if let s = try? decode(String.self, forKey: key), let v = Int(s) { return v }
        return nil
    }

    func flexDouble(forKey key: Key) -> Double? {
        if let v = try? decode(Double.self, forKey: key) { return v }
        if let v = try? decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? decode(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }

    func flexBool(forKey key: Key) -> Bool? {
        if let v = try? decode(Bool.self, forKey: key) { return v }
        if let v = try? decode(Int.self, forKey: key) { return v != 0 }
        return nil
    }
}

/// Built-in list so all 13 mini-games always appear in the hub (merged with server plays-left when online).
enum ArcadeBundledCatalog {
    static let games: [ArcadeGameInfo] = [
        ArcadeGameInfo(id: "vault_tap", title: "Vault Tap", subtitle: "Hit the zone", playsPerDay: 5, icon: "🎯", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "daily_safe", title: "Daily Safe", subtitle: "Crack the code", playsPerDay: 5, icon: "🔐", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "scratch", title: "Scratch Card", subtitle: "Match symbols", playsPerDay: 5, icon: "🎫", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "crash_quiz", title: "Crash Quiz", subtitle: "Guess the crash", playsPerDay: 5, icon: "📈", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "streak_spinner", title: "Streak Spinner", subtitle: "Login rewards", playsPerDay: 1, icon: "🎡", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "vault_heist", title: "Vault Heist", subtitle: "Pick doors", playsPerDay: 5, icon: "🚪", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "double_nothing", title: "Double or Nothing", subtitle: "Risk fun pts", playsPerDay: 5, icon: "⚡", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "badge_hunt", title: "Badge Hunt", subtitle: "Find vault icons", playsPerDay: 5, icon: "🕵️", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "duel", title: "Vault Duel", subtitle: "Beat a rival", playsPerDay: 5, icon: "⚔️", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "arcade_missions", title: "Arcade Missions", subtitle: "Daily goals", playsPerDay: 99, icon: "📋", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "crash_course", title: "Crash Course", subtitle: "Solo practice", playsPerDay: 5, icon: "🚀", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "tycoon", title: "Vault Tycoon", subtitle: "Idle collectors", playsPerDay: 5, icon: "🏦", playsLeft: nil, playsUsed: nil),
        ArcadeGameInfo(id: "season_ladder", title: "Season Ladder", subtitle: "Weekly race", playsPerDay: 0, icon: "🏆", playsLeft: nil, playsUsed: nil),
    ]

    static func merge(serverGames: [ArcadeGameInfo]?) -> [ArcadeGameInfo] {
        let fromServer = serverGames ?? []
        if fromServer.isEmpty { return games }
        return games.map { bundled in
            fromServer.first(where: { $0.id == bundled.id }) ?? bundled
        }
    }
}
