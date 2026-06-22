import Foundation

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
        var onOpponents: (([JumpVsOpponent]) -> Void)?
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
    private(set) var eliminated = false
    private(set) var pot = 0
    private(set) var winnerId: String?
    private var opponents: [String: JumpVsOpponent] = [:]

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

    func reportProgress(height: Int, sessionPoints: Int) {
        guard phase == "match", !eliminated else { return }
        send(["type": "progress", "height": height, "sessionPoints": sessionPoints])
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

        if type == "lobby_state" {
            phase = msg["phase"] as? String ?? phase
            if let rows = msg["players"] as? [[String: Any]] {
                players = decodePlayers(rows)
            }
            countdownSeconds = msg["countdownSeconds"] as? Int ?? 0
            if let match = msg["match"] as? [String: Any], let seed = match["matchSeed"] as? Int {
                matchSeed = seed
            }
            hooks.onLobbyState?(snapshot())
            return
        }

        if type == "match_start" {
            phase = "match"
            matchSeed = msg["matchSeed"] as? Int
            matchId = msg["matchId"] as? String
            eliminated = false
            opponents.removeAll()
            if let rows = msg["players"] as? [[String: Any]] {
                for row in rows {
                    guard let id = row["id"] as? String, id != AuthStore.verifiedUserId else { continue }
                    opponents[id] = decodeOpponent(row)
                }
            }
            hooks.onMatchStart?(snapshot())
            return
        }

        if type == "opponent_progress" {
            guard let id = msg["id"] as? String, id != AuthStore.verifiedUserId else { return }
            opponents[id] = decodeOpponent(msg)
            hooks.onOpponents?(opponentList())
            return
        }

        if type == "eliminated", msg["id"] as? String == AuthStore.verifiedUserId {
            eliminated = true
            hooks.onEliminated?(msg["reason"] as? String ?? "pace")
            return
        }

        if type == "match_end" {
            phase = "results"
            pot = msg["pot"] as? Int ?? 0
            winnerId = msg["winnerId"] as? String
            hooks.onMatchEnd?(msg)
            return
        }

        if type == "player_join" || type == "player_leave" {
            hooks.onLobbyState?(snapshot())
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
        JumpVsOpponent(
            id: row["id"] as? String ?? UUID().uuidString,
            height: row["height"] as? Int ?? 0,
            skinId: row["skinId"] as? String,
            fill: row["fill"] as? String,
            ring: row["ring"] as? String,
            sessionPoints: row["sessionPoints"] as? Int ?? 0,
            eliminated: (row["eliminated"] as? Bool) ?? false
        )
    }

    static func ghostOpponents(from opponents: [JumpVsOpponent]) -> [JumpGhostOpponent] {
        opponents.enumerated().map { index, opp in
            let charCode = opp.id.unicodeScalars.first?.value ?? 65
            let x = Double(Int(charCode) % 7) * 18 - 54 + Double(index) * 12
            return JumpGhostOpponent(
                id: opp.id,
                fill: opp.fill ?? "#94a3b8",
                ring: opp.ring ?? "#cbd5e1",
                x: x,
                worldY: Double(opp.height) + 80
            )
        }
    }
}
