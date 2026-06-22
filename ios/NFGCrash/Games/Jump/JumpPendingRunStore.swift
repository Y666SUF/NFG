import Foundation

/// Queues a Jump run peak for `game_over` sync when the network or server is unavailable.
enum JumpPendingRunStore {
    private static func key(for user: String) -> String {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "nfg.jump.pendingRun.v1.\(u.isEmpty ? "guest" : u)"
    }

    static func pendingHeight(for user: String) -> Int {
        max(0, UserDefaults.standard.integer(forKey: key(for: user)))
    }

    static func enqueue(height: Int, for user: String) {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !u.isEmpty else { return }
        let h = max(0, height)
        let k = key(for: u)
        let current = UserDefaults.standard.integer(forKey: k)
        if h > current {
            UserDefaults.standard.set(h, forKey: k)
        }
    }

    static func clear(for user: String) {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !u.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: key(for: u))
    }

    static func migratePendingHeight(from oldUser: String, to newUser: String) {
        let from = oldUser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let to = newUser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !from.isEmpty, !to.isEmpty, from != to else { return }
        let pending = pendingHeight(for: from)
        guard pending > 0 else { return }
        let existing = pendingHeight(for: to)
        if pending > existing {
            UserDefaults.standard.set(pending, forKey: key(for: to))
        }
        clear(for: from)
    }

    @discardableResult
    static func flush(api: GameAPI, sync: SyncClient?, user: String? = nil) async -> Bool {
        let u = (user ?? ArcadeOfflinePointsQueue.userKey())
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !u.isEmpty else { return false }
        let pending = pendingHeight(for: u)
        guard pending > 0 else { return false }

        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_snake_jump",
                action: "game_over",
                payload: ["height": pending]
            )
            await MainActor.run {
                ArcadePointsBridge.applyToGlobalWallet(res, sync: sync)
            }
            clear(for: u)
            return true
        } catch {
            return false
        }
    }
}
