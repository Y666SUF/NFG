import Foundation

/// Asset names synced from public/badge-icons.js (PC stream vault icons).
enum VaultBadgeAssets {
    static let badgeIds: [String] = [
        "acespades",
        "chip",
        "dice",
        "bullion",
        "lucky7",
        "ltc",
        "bitcoin",
        "ethereum",
        "whale",
        "imperial",
        "crown"
    ]

    static func imageName(for badgeId: String) -> String? {
        switch PlayerCosmeticStyle.normalizedBadge(badgeId) {
        case "acespades": return "VaultBadgeAcespades"
        case "chip": return "VaultBadgeChip"
        case "dice": return "VaultBadgeDice"
        case "bullion": return "VaultBadgeBullion"
        case "lucky7": return "VaultBadgeLucky7"
        case "ltc": return "VaultBadgeLtc"
        case "bitcoin": return "VaultBadgeBitcoin"
        case "ethereum": return "VaultBadgeEthereum"
        case "whale": return "VaultBadgeWhale"
        case "imperial": return "VaultBadgeImperial"
        case "crown": return "VaultBadgeCrown"
        default:
            return nil
        }
    }

    static func label(for badgeId: String) -> String {
        switch PlayerCosmeticStyle.normalizedBadge(badgeId) {
        case "acespades": return "Ace of Spades"
        case "chip": return "Vault Chip"
        case "dice": return "High Roller"
        case "bullion": return "Gold Bullion"
        case "lucky7": return "Lucky Seven"
        case "ltc": return "Litecoin"
        case "bitcoin": return "Crypto Coin"
        case "ethereum": return "Ether Gem"
        case "whale": return "Whale Vault"
        case "imperial": return "NFG Imperial"
        case "crown": return "Royal Vault"
        default:
            return badgeId
        }
    }
}
