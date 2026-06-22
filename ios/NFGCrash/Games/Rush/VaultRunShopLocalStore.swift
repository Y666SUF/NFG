import Foundation

/// Persists NFG Rush ship shop ownership locally (per TikTok user).
enum VaultRunShopLocalStore {
    private static let ownedKey = "nfg.vault.shop.owned"
    private static let equippedKey = "nfg.vault.shop.equipped"

    struct Snapshot {
        var owned: Set<String>
        var equipped: String
    }

    static func load(for user: String) -> Snapshot {
        let key = normalized(user)
        guard !key.isEmpty else {
            return Snapshot(owned: [VaultRunShopCatalog.defaultShipId], equipped: VaultRunShopCatalog.defaultShipId)
        }
        let owned = Set(UserDefaults.standard.stringArray(forKey: ownedStorageKey(key)) ?? [VaultRunShopCatalog.defaultShipId])
        let equipped = UserDefaults.standard.string(forKey: equippedStorageKey(key)) ?? VaultRunShopCatalog.defaultShipId
        var merged = owned
        merged.insert(VaultRunShopCatalog.defaultShipId)
        let safeEquipped = merged.contains(equipped) ? equipped : VaultRunShopCatalog.defaultShipId
        return Snapshot(owned: merged, equipped: safeEquipped)
    }

    static func save(ownedIds: Set<String>, equippedId: String, for user: String) {
        let key = normalized(user)
        guard !key.isEmpty else { return }
        var owned = ownedIds
        owned.insert(VaultRunShopCatalog.defaultShipId)
        let equipped = owned.contains(equippedId) ? equippedId : VaultRunShopCatalog.defaultShipId
        UserDefaults.standard.set(Array(owned).sorted(), forKey: ownedStorageKey(key))
        UserDefaults.standard.set(equipped, forKey: equippedStorageKey(key))
    }

    static func recordPurchase(itemId: String, for user: String) {
        var snap = load(for: user)
        snap.owned.insert(itemId)
        save(ownedIds: snap.owned, equippedId: itemId, for: user)
    }

    static func recordEquip(itemId: String, for user: String) {
        var snap = load(for: user)
        guard snap.owned.contains(itemId) else { return }
        save(ownedIds: snap.owned, equippedId: itemId, for: user)
    }

    private static func normalized(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func ownedStorageKey(_ user: String) -> String {
        "\(ownedKey).\(user)"
    }

    private static func equippedStorageKey(_ user: String) -> String {
        "\(equippedKey).\(user)"
    }
}
