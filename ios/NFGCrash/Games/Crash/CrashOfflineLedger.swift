import Foundation

/// Queues local crash round net balance changes until the server is online.
struct CrashPendingRound: Codable, Identifiable, Equatable {
    var id: String
    var roundId: Int
    var stake: Int
    var result: String
    var settleMult: Double?
    var crashPoint: Double
    var payout: Int
    var tax: Int
    var netDelta: Int
    var createdAt: TimeInterval
}

enum CrashOfflineLedger {
    private static let keyPrefix = "nfg.crashSolo.ledger.v1."

    static func userKey() -> String { LocalWalletStore.userKey() }

    static func enqueue(_ settlement: LocalCrashEngine.RoundSettlement, user: String? = nil) {
        guard settlement.result == "win" || settlement.result == "lose" else { return }
        let key = normalized(user ?? userKey())
        guard !key.isEmpty else { return }
        var items = load(user: key)
        items.append(
            CrashPendingRound(
                id: settlement.id,
                roundId: settlement.roundId,
                stake: settlement.stake,
                result: settlement.result,
                settleMult: settlement.settleMult,
                crashPoint: settlement.crashPoint,
                payout: settlement.payout,
                tax: settlement.tax,
                netDelta: settlement.netDelta,
                createdAt: settlement.createdAt
            )
        )
        // Keep last 200
        if items.count > 200 {
            items = Array(items.suffix(200))
        }
        save(items, user: key)
    }

    static func load(user: String? = nil) -> [CrashPendingRound] {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey(for: key)),
              let items = try? JSONDecoder().decode([CrashPendingRound].self, from: data) else {
            return []
        }
        return items
    }

    static func pendingCount(user: String? = nil) -> Int { load(user: user).count }

    static func replaceAll(_ items: [CrashPendingRound], user: String? = nil) {
        save(items, user: normalized(user ?? userKey()))
    }

    static func clear(user: String? = nil) {
        save([], user: normalized(user ?? userKey()))
    }

    static func migrate(from oldUser: String, to newUser: String) {
        let from = normalized(oldUser)
        let to = normalized(newUser)
        guard !from.isEmpty, !to.isEmpty, from != to else { return }
        let guest = load(user: from)
        guard !guest.isEmpty else { return }
        var merged = load(user: to)
        merged.append(contentsOf: guest)
        save(merged, user: to)
        save([], user: from)
    }

    private static func save(_ items: [CrashPendingRound], user: String) {
        guard !user.isEmpty else { return }
        if items.isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey(for: user))
        } else if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey(for: user))
        }
    }

    private static func normalized(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func storageKey(for user: String) -> String {
        "\(keyPrefix)\(user)"
    }
}
