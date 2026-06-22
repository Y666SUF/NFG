import Foundation

/// Persists NFG Jump circle shop ownership locally (works offline before server sync).
enum JumpShopLocalStore {
    private static let ownedKey = "nfg.jump.shop.owned"
    private static let equippedKey = "nfg.jump.shop.equipped"

    struct Snapshot {
        var owned: Set<String>
        var equipped: String
    }

    static func load(for user: String) -> Snapshot {
        let key = normalized(user)
        guard !key.isEmpty else {
            return Snapshot(owned: [JumpShopCatalog.defaultSkinId], equipped: JumpShopCatalog.defaultSkinId)
        }
        let owned = Set(UserDefaults.standard.stringArray(forKey: ownedStorageKey(key)) ?? [JumpShopCatalog.defaultSkinId])
        let equipped = UserDefaults.standard.string(forKey: equippedStorageKey(key)) ?? JumpShopCatalog.defaultSkinId
        var merged = owned
        merged.insert(JumpShopCatalog.defaultSkinId)
        let safeEquipped = merged.contains(equipped) ? equipped : JumpShopCatalog.defaultSkinId
        return Snapshot(owned: merged, equipped: safeEquipped)
    }

    static func save(ownedIds: Set<String>, equippedId: String, for user: String) {
        let key = normalized(user)
        guard !key.isEmpty else { return }
        var owned = ownedIds
        owned.insert(JumpShopCatalog.defaultSkinId)
        let equipped = owned.contains(equippedId) ? equippedId : JumpShopCatalog.defaultSkinId
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
