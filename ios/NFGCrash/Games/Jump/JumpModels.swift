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
    static let fallback: [JumpShopItem] = [
        JumpShopItem(id: "classic", name: "Classic", cost: 0, fill: "#596ff2", ring: "#f2c733", desc: "Default circle", owned: true, equipped: true),
    ]

    static func merged(serverItems: [JumpShopItem]?, equippedId: String, ownedSkins: [String]) -> [JumpShopItem] {
        guard let serverItems, !serverItems.isEmpty else { return fallback }
        let owned = Set(ownedSkins)
        return serverItems.map { item in
            var copy = item
            if copy.owned == nil { copy.owned = owned.contains(item.id) || (item.cost ?? 0) == 0 }
            if copy.equipped == nil { copy.equipped = item.id == equippedId }
            return copy
        }
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
