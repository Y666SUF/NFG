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

    /// Merge server shop state with bundled casino runner catalog (names + colors).
    static func merged(
        serverItems: [VaultRunShipItem]?,
        equippedId: String,
        ownedIds: Set<String>
    ) -> [VaultRunShipItem] {
        let owned = ownedIds.union([defaultShipId])
        let catalog = defaultItems(equippedId: equippedId, ownedIds: owned)
        guard let serverItems, !serverItems.isEmpty else { return catalog }
        return catalog.map { local in
            let remote = serverItems.first(where: { $0.id == local.id })
            return VaultRunShipItem(
                id: local.id,
                name: local.name,
                cost: remote?.cost ?? local.cost,
                hull: local.hull,
                cockpit: local.cockpit,
                trail: local.trail,
                style: local.style,
                desc: local.desc,
                owned: remote?.owned ?? local.owned,
                equipped: remote?.equipped == true || local.id == equippedId
            )
        }
    }

    static func applyRunnerCosmetics(
        shipId: String,
        to hull: inout String,
        cockpit: inout String,
        trail: inout String,
        style: inout String
    ) {
        guard let cosmetics = cosmetics(for: shipId) else { return }
        hull = cosmetics.hull
        cockpit = cosmetics.cockpit
        trail = cosmetics.trail
        style = cosmetics.style
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
        ("classic", "Classic Dealer", 0, "#1a6b4a", "#f5c842", "#e8b020", "scout", "Green vest · gold trim · classic chip trail"),
        ("neon_streak", "Neon Streak", 1_000_000, "#0d4d38", "#67e8f9", "#06b6d4", "fighter", "Teal dealer suit · cyan chip wake"),
        ("solar_flare", "Gold Rush", 3_500_000, "#b8860b", "#fef08a", "#f59e0b", "interceptor", "Gold vest · solar chip trail"),
        ("violet_nebula", "Royal Flush", 6_000_000, "#5b21b6", "#e879f9", "#c084fc", "scout", "Purple velvet runner · violet chips"),
        ("emerald_comet", "Emerald Stack", 8_500_000, "#047857", "#a7f3d0", "#10b981", "fighter", "Emerald felt suit · green chip trail"),
        ("crimson_blaze", "Crimson Bet", 11_000_000, "#b91c1c", "#fca5a5", "#f97316", "interceptor", "Red casino jacket · blaze chips"),
        ("ghost_void", "Ghost Chip", 13_500_000, "#e2e8f0", "#94a3b8", "#cbd5e1", "phantom", "Silver phantom · ghost chip wake"),
        ("nfg_ignition", "NFG Jackpot", 15_000_000, "#ff6b35", "#ffd700", "#fb923c", "inferno", "Official NFG jackpot runner · ultimate trail"),
    ]
}
