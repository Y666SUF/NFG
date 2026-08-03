import Foundation

private func jumpVsJSONInt(_ value: Any?) -> Int? {
    if let i = value as? Int { return i }
    if let d = value as? Double { return Int(d) }
    if let n = value as? NSNumber { return n.intValue }
    if let s = value as? String, let i = Int(s) { return i }
    return nil
}

private func jumpVsJSONInt64(_ value: Any?) -> Int64? {
    if let i = value as? Int64 { return i }
    if let i = value as? Int { return Int64(i) }
    if let d = value as? Double { return Int64(d) }
    if let n = value as? NSNumber { return n.int64Value }
    if let s = value as? String, let i = Int64(s) { return i }
    return nil
}

private func jumpVsJSONDouble(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let f = value as? Float { return Double(f) }
    if let i = value as? Int { return Double(i) }
    if let n = value as? NSNumber { return n.doubleValue }
    return nil
}

@MainActor
final class JumpVSClient {
    struct Hooks {
        var skinId: String = "classic"
        var fill: String = "#596ff2"
        var ring: String = "#f2c733"
        var onConnected: (() -> Void)?
        var onDisconnected: (() -> Void)?
        var onError: ((String) -> Void)?
        var onLobbyState: ((JumpVsSnapshot) -> Void)?
        var onMatchStart: ((JumpVsSnapshot) -> Void)?
        var onOpponentUpdate: ((JumpVsOpponent) -> Void)?
        var onEliminated: ((String) -> Void)?
        var onMatchEnd: (([String: Any]) -> Void)?
    }

    private let api: GameAPI
    private var hooks: Hooks
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var joinSent = false
    private var joinAttempts = 0

    private(set) var phase = "waiting"
    private(set) var players: [JumpVsPlayer] = []
    private(set) var countdownSeconds = 0
    private(set) var matchSeed: Int?
    private(set) var matchId: String?
    private(set) var matchStartedAtMs: Int64?
    private(set) var eliminated = false
    private(set) var pot = 0
    private(set) var winnerId: String?
    private var opponents: [String: JumpVsOpponent] = [:]
    private var selfUserId: String = AuthStore.verifiedUserId
    private(set) var isConnected = false

    init(api: GameAPI, hooks: Hooks = Hooks()) {
        self.api = api
        self.hooks = hooks
    }

    func updateHooks(_ hooks: Hooks) {
        self.hooks = hooks
    }

    func connect() throws {
        if let webSocketTask, webSocketTask.state == .running || webSocketTask.state == .suspended {
            return
        }
        guard let token = AuthStore.sessionToken, !token.isEmpty else {
            throw GameAPIError.notLoggedIn
        }
        var comp = URLComponents(url: api.webSocketURL.appending(path: "/api/mobile/jump/vs/ws"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = comp.url else { throw GameAPIError.invalidURL }

        joinSent = false
        joinAttempts = 0
        isConnected = false
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveLoop()
        scheduleJoinWhenReady()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        joinSent = false
        joinAttempts = 0
        isConnected = false
        hooks.onDisconnected?()
    }

    private func scheduleJoinWhenReady() {
        guard let webSocketTask, !joinSent else { return }
        webSocketTask.sendPing { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if error == nil {
                    self.sendJoin()
                    self.joinSent = true
                    self.hooks.onConnected?()
                    return
                }
                self.joinAttempts += 1
                if self.joinAttempts < 25 {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    self.scheduleJoinWhenReady()
                } else {
                    self.hooks.onError?("Jump VS connection failed.")
                }
            }
        }
    }

    private func sendJoin() {
        send([
            "type": "join",
            "displayName": AuthStore.verifiedDisplayName.isEmpty ? AuthStore.verifiedUserId : AuthStore.verifiedDisplayName,
            "skinId": hooks.skinId,
            "fill": hooks.fill,
            "ring": hooks.ring,
        ])
    }

    private func send(_ obj: [String: Any]) {
        guard let webSocketTask else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask.send(.string(text)) { _ in }
    }

    func reportLiveState(
        playerX: Double,
        playerY: Double,
        velocityY: Double,
        height: Int,
        sessionPoints: Int,
        elapsed: Double
    ) {
        guard phase == "match", !eliminated else { return }
        send([
            "type": "progress",
            "playerX": playerX,
            "playerY": playerY,
            "velocityY": velocityY,
            "height": height,
            "sessionPoints": sessionPoints,
            "elapsed": elapsed,
        ])
    }

    func reportProgress(height: Int, sessionPoints: Int) {
        reportLiveState(
            playerX: 0,
            playerY: Double(height) + 80,
            velocityY: 0,
            height: height,
            sessionPoints: sessionPoints,
            elapsed: 0
        )
    }

    func sendForfeit() {
        send(["type": "forfeit"])
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
                    self.hooks.onDisconnected?()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let raw: String?
        switch message {
        case .string(let text): raw = text
        case .data(let data): raw = String(data: data, encoding: .utf8)
        @unknown default: raw = nil
        }
        guard let raw,
              let data = raw.data(using: .utf8),
              let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let type = String(describing: msg["type"] ?? "")

        if type == "welcome" {
            if let id = msg["id"] as? String, !id.isEmpty {
                selfUserId = id
            }
            phase = msg["phase"] as? String ?? phase
            isConnected = true
            return
        }

        if type == "lobby_state" {
            phase = msg["phase"] as? String ?? phase
            if let rows = msg["players"] as? [[String: Any]] {
                players = decodePlayers(rows)
            }
            countdownSeconds = msg["countdownSeconds"] as? Int ?? 0
            if let match = msg["match"] as? [String: Any], let seed = jumpVsJSONInt(match["matchSeed"]) {
                matchSeed = seed
            }
            hooks.onLobbyState?(snapshot())
            return
        }

        if type == "match_start" {
            phase = "match"
            matchSeed = jumpVsJSONInt(msg["matchSeed"])
            matchId = msg["matchId"] as? String
            matchStartedAtMs = jumpVsJSONInt64(msg["startedAt"])
            eliminated = false
            opponents.removeAll()
            if let rows = msg["players"] as? [[String: Any]] {
                for row in rows {
                    guard let id = row["id"] as? String, id != selfUserId else { continue }
                    opponents[id] = decodeOpponent(row)
                }
            }
            hooks.onMatchStart?(snapshot())
            return
        }

        if type == "opponent_progress" {
            guard let id = msg["id"] as? String, id != selfUserId else { return }
            let opp = decodeOpponent(msg)
            opponents[id] = opp
            hooks.onOpponentUpdate?(opp)
            return
        }

        if type == "eliminated", msg["id"] as? String == selfUserId {
            eliminated = true
            hooks.onEliminated?(msg["reason"] as? String ?? "pace")
            return
        }

        if type == "match_end" {
            phase = "results"
            pot = msg["pot"] as? Int ?? 0
            winnerId = msg["winnerId"] as? String
            if let rows = msg["rankings"] as? [[String: Any]] {
                players = decodePlayers(rows)
            }
            hooks.onMatchEnd?(msg)
            return
        }
    }

    func opponentList() -> [JumpVsOpponent] {
        opponents.values.filter { !$0.eliminated }.sorted { $0.id < $1.id }
    }

    func snapshot() -> JumpVsSnapshot {
        JumpVsSnapshot(
            phase: phase,
            players: players,
            countdownSeconds: countdownSeconds,
            matchSeed: matchSeed,
            matchId: matchId,
            matchStartedAtMs: matchStartedAtMs,
            eliminated: eliminated,
            opponents: opponentList(),
            pot: pot,
            winnerId: winnerId
        )
    }

    private func decodePlayers(_ rows: [[String: Any]]) -> [JumpVsPlayer] {
        rows.compactMap { row in
            guard let id = row["id"] as? String else { return nil }
            return JumpVsPlayer(
                id: id,
                displayName: row["displayName"] as? String,
                height: row["height"] as? Int,
                skinId: row["skinId"] as? String,
                fill: row["fill"] as? String,
                ring: row["ring"] as? String,
                sessionPoints: row["sessionPoints"] as? Int,
                eliminated: row["eliminated"] as? Bool
            )
        }
    }

    private func decodeOpponent(_ row: [String: Any]) -> JumpVsOpponent {
        let height = jumpVsJSONInt(row["height"]) ?? 0
        return JumpVsOpponent(
            id: row["id"] as? String ?? UUID().uuidString,
            displayName: row["displayName"] as? String,
            height: height,
            playerX: jumpVsJSONDouble(row["playerX"]),
            playerY: jumpVsJSONDouble(row["playerY"]),
            velocityY: jumpVsJSONDouble(row["velocityY"]),
            elapsed: jumpVsJSONDouble(row["elapsed"]),
            skinId: row["skinId"] as? String,
            fill: row["fill"] as? String,
            ring: row["ring"] as? String,
            sessionPoints: jumpVsJSONInt(row["sessionPoints"]) ?? 0,
            eliminated: (row["eliminated"] as? Bool) ?? false
        )
    }
}
