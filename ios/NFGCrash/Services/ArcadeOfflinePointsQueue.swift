import Foundation

struct ArcadePendingCredit: Codable, Identifiable, Equatable {
    var id: String
    var gameId: String
    var action: String
    var payloadJSON: String?
    var estimatedPoints: Int
    var createdAt: TimeInterval
}

/// Queues arcade point awards when the server or network is unavailable; flushes when back online.
enum ArcadeOfflinePointsQueue {
    private static let storageKey = "nfg.arcade.pendingCredits"

    static func userKey() -> String {
        let name = PlayerSession.tiktokUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name.isEmpty ? AuthStore.deviceId : name
    }

    static func enqueue(
        gameId: String,
        action: String,
        payload: [String: Any] = [:],
        estimatedPoints: Int,
        user: String? = nil
    ) {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty, estimatedPoints > 0 else { return }
        var items = loadAll(for: key)
        let payloadJSON: String? = {
            guard !payload.isEmpty,
                  let data = try? JSONSerialization.data(withJSONObject: payload),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return text
        }()
        items.append(
            ArcadePendingCredit(
                id: UUID().uuidString,
                gameId: gameId,
                action: action,
                payloadJSON: payloadJSON,
                estimatedPoints: estimatedPoints,
                createdAt: Date().timeIntervalSince1970
            )
        )
        save(items, for: key)
    }

    static func pending(for gameId: String, user: String? = nil) -> [ArcadePendingCredit] {
        loadAll(for: normalized(user ?? userKey())).filter { $0.gameId == gameId }
    }

    static func pendingPoints(for gameId: String, user: String? = nil) -> Int {
        pending(for: gameId, user: user).reduce(0) { $0 + $1.estimatedPoints }
    }

    static func flush(api: GameAPI, sync: SyncClient? = nil, user: String? = nil) async -> Int {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty else { return 0 }
        var items = loadAll(for: key)
        guard !items.isEmpty else { return 0 }

        var synced = 0
        var remaining: [ArcadePendingCredit] = []
        for item in items {
            var payload: [String: Any] = [:]
            if let payloadJSON = item.payloadJSON,
               let data = payloadJSON.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                payload = obj
            }
            do {
                let result = try await api.arcadePlay(gameId: item.gameId, action: item.action, payload: payload)
                await MainActor.run {
                    ArcadePointsBridge.applyToGlobalWallet(result, sync: sync)
                }
                synced += 1
            } catch {
                remaining.append(item)
            }
        }
        save(remaining, for: key)
        return synced
    }

    /// Flush any queued credits before starting a new server-backed action.
    static func flushBeforePlay(api: GameAPI, sync: SyncClient?) async {
        _ = await flush(api: api, sync: sync)
    }

    private static func loadAll(for user: String) -> [ArcadePendingCredit] {
        guard !user.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey(for: user)),
              let decoded = try? JSONDecoder().decode([ArcadePendingCredit].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func save(_ items: [ArcadePendingCredit], for user: String) {
        guard !user.isEmpty else { return }
        if items.isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey(for: user))
            return
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey(for: user))
        }
    }

    private static func normalized(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func storageKey(for user: String) -> String {
        "\(storageKey).\(user)"
    }
}

/// Keeps arcade point awards reflected in the global NFG Crash wallet.
@MainActor
enum ArcadePointsBridge {
    static func applyToGlobalWallet(_ result: ArcadePlayResponse, sync: SyncClient?) {
        guard let sync else { return }
        if let wallet = result.wallet {
            sync.applyWalletFromServer(wallet)
        } else if let balance = result.balance {
            sync.applyBalanceFromServer(balance: balance)
        }
    }
}
