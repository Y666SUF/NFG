import Foundation

struct JumpShopItem: Decodable, Identifiable, Hashable {
    var id: String
    var name: String?
    var cost: Int?
    var fill: String?
    var ring: String?
    var desc: String?
    var owned: Bool?
    var equipped: Bool?
}

enum JumpShopCatalog {
    static let defaultSkinId = "classic"

    static let catalog: [JumpShopItem] = [
        JumpShopItem(id: "classic", name: "Classic", cost: 0, fill: "#596ff2", ring: "#f2c733", desc: "House chip — always in rotation", owned: true, equipped: true),
        JumpShopItem(id: "neon_cyan", name: "Neon Dynasty", cost: 1_000_000, fill: "#22d3ee", ring: "#06b6d4", desc: "Vegas neon high-limit circle"),
        JumpShopItem(id: "solar_gold", name: "Solar Sovereign", cost: 3_500_000, fill: "#fbbf24", ring: "#fef08a", desc: "Golden jackpot sovereign"),
        JumpShopItem(id: "violet_void", name: "Violet Voidlord", cost: 6_000_000, fill: "#a855f7", ring: "#e879f9", desc: "VIP lounge purple chip"),
        JumpShopItem(id: "emerald", name: "Emerald Elite", cost: 8_500_000, fill: "#34d399", ring: "#a7f3d0", desc: "Roulette-table elite felt"),
        JumpShopItem(id: "crimson", name: "Crimson Overlord", cost: 11_000_000, fill: "#ef4444", ring: "#fca5a5", desc: "High-roller crimson bust"),
        JumpShopItem(id: "ghost", name: "Ghost Phantom", cost: 13_500_000, fill: "#f8fafc", ring: "#94a3b8", desc: "Phantom whale chip"),
        JumpShopItem(id: "nfg_fire", name: "NFG Inferno", cost: 15_000_000, fill: "#ff6b35", ring: "#ffd700", desc: "Official NFG casino flame"),
    ]

    static var fallback: [JumpShopItem] {
        withOwnership(equippedId: defaultSkinId, ownedSkins: [defaultSkinId])
    }

    static func withOwnership(equippedId: String, ownedSkins: Set<String>) -> [JumpShopItem] {
        catalog.map { item in
            var copy = item
            let owned = ownedSkins.contains(item.id) || (item.cost ?? 0) == 0
            copy.owned = owned
            copy.equipped = item.id == equippedId
            return copy
        }
    }

    static func merged(serverItems: [JumpShopItem]?, equippedId: String, ownedSkins: [String]) -> [JumpShopItem] {
        if let serverItems, !serverItems.isEmpty {
            let owned = Set(ownedSkins)
            return serverItems.map { item in
                var copy = item
                if copy.owned == nil { copy.owned = owned.contains(item.id) || (item.cost ?? 0) == 0 }
                if copy.equipped == nil { copy.equipped = item.id == equippedId }
                return copy
            }
        }
        return withOwnership(equippedId: equippedId, ownedSkins: Set(ownedSkins))
    }

    static func cosmetics(for skinId: String) -> (fill: String, ring: String)? {
        guard let item = catalog.first(where: { $0.id == skinId }) else { return nil }
        return (item.fill ?? "#596ff2", item.ring ?? "#f2c733")
    }
}

struct JumpVsPlayer: Identifiable, Hashable {
    var id: String
    var displayName: String?
    var height: Int?
    var skinId: String?
    var fill: String?
    var ring: String?
    var sessionPoints: Int?
    var eliminated: Bool?
}

struct JumpVsOpponent: Identifiable, Hashable {
    var id: String
    var height: Int
    var skinId: String?
    var fill: String?
    var ring: String?
    var sessionPoints: Int
    var eliminated: Bool
}

struct JumpVsSnapshot: Hashable {
    var phase: String
    var players: [JumpVsPlayer]
    var countdownSeconds: Int
    var matchSeed: Int?
    var matchId: String?
    var eliminated: Bool
    var opponents: [JumpVsOpponent]
    var pot: Int
    var winnerId: String?
}

struct JumpGhostOpponent: Identifiable, Hashable {
    var id: String
    var fill: String
    var ring: String
    var x: Double
    var worldY: Double
}
