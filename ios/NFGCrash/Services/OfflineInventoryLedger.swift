import Foundation

/// Queues powerup charge spends made while offline so the server inventory matches the app after reconnect.
struct OfflineInventorySpend: Codable, Identifiable, Equatable {
    var id: String
    var kind: String
    var count: Int
    var target: String?
    var createdAt: TimeInterval
}

enum OfflineInventoryLedger {
    private static let keyPrefix = "nfg.offlineInventory.v1."

    static func userKey() -> String { LocalWalletStore.userKey() }

    static func enqueue(kind: String, count: Int = 1, target: String? = nil, user: String? = nil) {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty, count > 0 else { return }
        var items = load(user: key)
        items.append(
            OfflineInventorySpend(
                id: UUID().uuidString,
                kind: kind,
                count: count,
                target: target,
                createdAt: Date().timeIntervalSince1970
            )
        )
        save(items, user: key)
    }

    static func load(user: String? = nil) -> [OfflineInventorySpend] {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey(for: key)),
              let items = try? JSONDecoder().decode([OfflineInventorySpend].self, from: data) else {
            return []
        }
        return items
    }

    static func pendingCount(user: String? = nil) -> Int {
        load(user: user).count
    }

    static func pendingStealSpends(user: String? = nil) -> Int {
        load(user: user)
            .filter { $0.kind == "steal" }
            .reduce(0) { $0 + max(0, $1.count) }
    }

    static func replaceAll(_ items: [OfflineInventorySpend], user: String? = nil) {
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

    private static func save(_ items: [OfflineInventorySpend], user: String) {
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
