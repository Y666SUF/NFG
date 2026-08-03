import Foundation

/// Persists the last known wallet (balance + steal charges) so the app stays playable when the server is down.
enum LocalWalletStore {
    private static let keyPrefix = "nfg.localWallet.v1."

    static func userKey() -> String {
        let linked = AuthStore.verifiedUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !linked.isEmpty { return linked }
        let session = PlayerSession.tiktokUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !session.isEmpty { return session }
        return AuthStore.deviceId.lowercased()
    }

    static func save(_ wallet: PlayerWallet, user: String? = nil) {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty, !wallet.user.isEmpty || wallet.balance > 0 || wallet.inventory.stealCharges > 0 else { return }
        guard let data = try? JSONEncoder().encode(wallet) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(for: key))
    }

    static func load(user: String? = nil) -> PlayerWallet? {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey(for: key)),
              let wallet = try? JSONDecoder().decode(PlayerWallet.self, from: data) else {
            return nil
        }
        return wallet
    }

    static func clear(user: String? = nil) {
        let key = normalized(user ?? userKey())
        guard !key.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: storageKey(for: key))
    }

    /// Moves cached wallet when an app guest links TikTok.
    static func migrate(from oldUser: String, to newUser: String) {
        let from = normalized(oldUser)
        let to = normalized(newUser)
        guard !from.isEmpty, !to.isEmpty, from != to else { return }
        guard let wallet = load(user: from) else { return }
        save(wallet, user: to)
        clear(user: from)
    }

    private static func normalized(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func storageKey(for user: String) -> String {
        "\(keyPrefix)\(user)"
    }
}
