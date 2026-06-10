import Foundation

/// Bundled NFG Rush ship shop — works offline / before server sync.
enum VaultRunShopCatalog {
    static let defaultShipId = "classic"

    static func defaultItems(equippedId: String = defaultShipId, ownedIds: Set<String> = [defaultShipId]) -> [VaultRunShipItem] {
        catalog.map { item in
            VaultRunShipItem(
                id: item.id,
                name: item.name,
                cost: item.cost,
                hull: item.hull,
                cockpit: item.cockpit,
                trail: item.trail,
                style: item.style,
                desc: item.desc,
                owned: ownedIds.contains(item.id) || item.cost == 0,
                equipped: item.id == equippedId
            )
        }
    }

    static func withOwnership(equippedId: String, ownedIds: Set<String>) -> [VaultRunShipItem] {
        defaultItems(equippedId: equippedId, ownedIds: ownedIds.union([defaultShipId]))
    }

    static func cosmetics(for shipId: String) -> (hull: String, cockpit: String, trail: String, style: String)? {
        catalog.first(where: { $0.id == shipId }).map { ($0.hull, $0.cockpit, $0.trail, $0.style) }
    }

    static func trailTier(for shipId: String) -> Int {
        switch shipId {
        case "neon_streak": return 1
        case "solar_flare": return 2
        case "violet_nebula": return 3
        case "emerald_comet": return 4
        case "crimson_blaze": return 5
        case "ghost_void": return 6
        case "nfg_ignition": return 7
        default: return 0
        }
    }

    private static let catalog: [(id: String, name: String, cost: Int, hull: String, cockpit: String, trail: String, style: String, desc: String)] = [
        ("classic", "Star Scout", 0, "#62b8f8", "#35e0ff", "#22d3ee", "scout", "Default cyan scout · ion trail"),
        ("neon_streak", "Neon Streak", 1_000_000, "#22d3ee", "#67e8f9", "#06b6d4", "fighter", "Radiant fighter hull · cyan exhaust"),
        ("solar_flare", "Solar Flare", 3_500_000, "#fbbf24", "#fef08a", "#f59e0b", "interceptor", "Golden interceptor · solar trail"),
        ("violet_nebula", "Violet Nebula", 6_000_000, "#a855f7", "#e879f9", "#c084fc", "scout", "Purple nebula scout · violet wake"),
        ("emerald_comet", "Emerald Comet", 8_500_000, "#34d399", "#a7f3d0", "#10b981", "fighter", "Emerald fighter · comet trail"),
        ("crimson_blaze", "Crimson Blaze", 11_000_000, "#ef4444", "#fca5a5", "#f97316", "interceptor", "Crimson interceptor · blaze trail"),
        ("ghost_void", "Ghost Void", 13_500_000, "#e2e8f0", "#94a3b8", "#cbd5e1", "phantom", "Phantom hull · ghost wake"),
        ("nfg_ignition", "NFG Ignition", 15_000_000, "#ff6b35", "#ffd700", "#fb923c", "inferno", "Official NFG inferno · ultimate trail"),
    ]
}
