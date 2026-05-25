import SwiftUI

enum PlayerCosmeticStyle {
    static func normalizedStyle(_ raw: String?) -> String {
        let id = (raw ?? "none").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return id.isEmpty ? "none" : id
    }

    private static let legacyBadgeAliases: [String: String] = [
        "voidmark": "acespades",
        "pulsecore": "chip",
        "prism": "dice",
        "nova": "bullion",
        "eclipse": "lucky7",
        "nebula": "ltc",
        "sovereign": "bitcoin",
        "astral": "ethereum",
        "transcend": "whale",
        "apex": "imperial",
    ]

    static func normalizedBadge(_ raw: String?) -> String {
        let id = (raw ?? "none").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if id.isEmpty || id == "none" { return "none" }
        return legacyBadgeAliases[id] ?? id
    }

    static func badgeShort(for badgeId: String, catalog: [NameBadgeShopItem] = []) -> String? {
        let id = normalizedBadge(badgeId)
        guard id != "none" else { return nil }
        if let hit = catalog.first(where: { $0.id.lowercased() == id }) {
            return hit.short
        }
        return fallbackBadgeShort[id]
    }

    private static let fallbackBadgeShort: [String: String] = [
        "acespades": "A♠",
        "chip": "CH",
        "dice": "DI",
        "bullion": "AU",
        "lucky7": "7",
        "ltc": "Ł",
        "bitcoin": "₿",
        "ethereum": "Ξ",
        "whale": "WV",
        "imperial": "NFG",
    ]

    static func foregroundColors(for styleId: String) -> [Color] {
        switch normalizedStyle(styleId) {
        case "neon":
            return [Color(red: 0.2, green: 1, blue: 0.95), Color(red: 0.45, green: 0.75, blue: 1)]
        case "royal":
            return [NFGTheme.gold, Color(red: 1, green: 0.92, blue: 0.55)]
        case "fire":
            return [Color(red: 1, green: 0.45, blue: 0.1), Color(red: 1, green: 0.2, blue: 0.2)]
        case "ice":
            return [Color(red: 0.75, green: 0.95, blue: 1), Color(red: 0.45, green: 0.75, blue: 1)]
        case "shadow":
            return [Color(red: 0.55, green: 0.5, blue: 0.75), Color(red: 0.35, green: 0.35, blue: 0.45)]
        case "rainbow":
            return [
                Color(red: 1, green: 0.35, blue: 0.55),
                Color(red: 1, green: 0.85, blue: 0.2),
                Color(red: 0.35, green: 0.9, blue: 1),
            ]
        case "pulse":
            return [Color(red: 1, green: 0.35, blue: 0.85), Color(red: 0.65, green: 0.4, blue: 1)]
        case "glitch":
            return [Color(red: 0.95, green: 0.2, blue: 1), Color(red: 0.2, green: 0.95, blue: 1)]
        default:
            return [NFGTheme.text]
        }
    }
}

struct NameStyledText: View {
    let name: String
    var styleId: String = "none"
    var font: Font = .system(size: 14, weight: .semibold)

    private var style: String { PlayerCosmeticStyle.normalizedStyle(styleId) }

    var body: some View {
        if style == "none" {
            Text(name)
                .font(font)
                .foregroundStyle(NFGTheme.text)
        } else {
            Text(name)
                .font(font)
                .foregroundStyle(
                    LinearGradient(
                        colors: PlayerCosmeticStyle.foregroundColors(for: style),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: glowColor.opacity(0.55), radius: style == "shadow" ? 0 : 4)
        }
    }

    private var glowColor: Color {
        PlayerCosmeticStyle.foregroundColors(for: style).first ?? NFGTheme.accent
    }
}

/// PC stream vault badge (SVG from `public/badge-icons.js`).
struct VaultBadgeIcon: View {
    let badgeId: String
    var size: CGFloat = 18

    private var id: String { PlayerCosmeticStyle.normalizedBadge(badgeId) }

    var body: some View {
        if id == "none" {
            EmptyView()
        } else if let asset = VaultBadgeAssets.imageName(for: id) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.58, green: 0.77, blue: 1).opacity(0.3), radius: size > 24 ? 5 : 3)
                .accessibilityLabel(VaultBadgeAssets.label(for: id))
        } else {
            NameBadgeTextFallback(badgeId: badgeId, size: size)
        }
    }
}

/// Text fallback if asset missing (should not happen after sync).
private struct NameBadgeTextFallback: View {
    let badgeId: String
    var size: CGFloat = 18

    var body: some View {
        if let text = PlayerCosmeticStyle.badgeShort(for: badgeId) {
            Text(text)
                .font(.system(size: max(8, size * 0.45), weight: .black, design: .rounded))
                .foregroundStyle(NFGTheme.gold)
                .frame(width: size, height: size)
                .background(NFGTheme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

struct NameBadgePill: View {
    let badgeId: String
    var short: String? = nil
    var compact: Bool = false

    var body: some View {
        VaultBadgeIcon(badgeId: badgeId, size: compact ? 14 : 18)
    }
}

struct PlayerDisplayNameRow: View {
    let name: String
    var styleId: String = "none"
    var badgeId: String = "none"
    var badgeShort: String? = nil
    var nameFont: Font = .system(size: 14, weight: .semibold)
    var compactBadge: Bool = false
    var trailing: () -> AnyView = { AnyView(EmptyView()) }

    var body: some View {
        HStack(spacing: 6) {
            NameBadgePill(badgeId: badgeId, short: badgeShort, compact: compactBadge)
            NameStyledText(name: name, styleId: styleId, font: nameFont)
            trailing()
        }
    }
}

extension PlayerDisplayNameRow {
    init<Trailing: View>(
        name: String,
        styleId: String = "none",
        badgeId: String = "none",
        badgeShort: String? = nil,
        nameFont: Font = .system(size: 14, weight: .semibold),
        compactBadge: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.name = name
        self.styleId = styleId
        self.badgeId = badgeId
        self.badgeShort = badgeShort
        self.nameFont = nameFont
        self.compactBadge = compactBadge
        self.trailing = { AnyView(trailing()) }
    }
}
