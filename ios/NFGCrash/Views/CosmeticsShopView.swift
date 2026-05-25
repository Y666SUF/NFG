import SwiftUI

struct CosmeticsShopView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingId: String?

    private var catalog: CosmeticsShopCatalog? { sync.cosmeticsCatalog }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                previewCard
                if !PlayerSession.isLoggedIn {
                    linkRequiredBanner
                } else if sync.isLoadingCosmeticsShop && catalog == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else {
                    nameFxSection
                    statusIconsSection
                    vaultCatalogSection
                }
                if let msg = sync.cosmeticsPurchaseMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NFGTheme.accent2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                if let err = sync.cosmeticsShopError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(NFGTheme.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .background(NFGTheme.background.ignoresSafeArea())
        .navigationTitle("Display shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await sync.refreshCosmeticsShop() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(sync.isLoadingCosmeticsShop)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await sync.refreshWallet()
                await sync.refreshCosmeticsShop()
            }
        }
    }

    private var linkRequiredBanner: some View {
        Text("Link TikTok on live to buy name FX and status icons (same as !namefx and !buy on stream).")
            .font(.system(size: 13))
            .foregroundStyle(NFGTheme.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIEW")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            HStack(spacing: 8) {
            VaultBadgeIcon(
                badgeId: catalog?.equippedBadge ?? sync.wallet.nameBadge,
                size: 28
            )
                NameStyledText(
                    name: sync.wallet.displayName.isEmpty ? "Your name" : sync.wallet.displayName,
                    styleId: catalog?.equippedStyle ?? sync.wallet.nameStyle,
                    font: .system(size: 22, weight: .bold)
                )
            }
            Text("Balance: \(sync.liveBalance.formatted()) pts")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
            Text("Owned items equip free — same account on live & app.")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
            Text("Live: !namefx · !buy · !icons")
                .font(.system(size: 10))
                .foregroundStyle(NFGTheme.muted.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private var nameFxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Name FX", subtitle: "Same as !namefx on live")
            let styles = catalog?.nameStyles ?? []
            if styles.isEmpty {
                emptyCatalogHint
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(styles) { item in
                        nameFxTile(item)
                    }
                }
            }
        }
    }

    private func nameFxTile(_ item: NameStyleShopItem) -> some View {
        let equipped = (catalog?.equippedStyle ?? sync.wallet.nameStyle).lowercased() == item.id.lowercased()
        let isDefault = item.id.lowercased() == "none"
        let owned = isDefault || catalog?.ownedStyleSet.contains(item.id.lowercased()) == true
            || sync.wallet.ownedNameStyles.map { $0.lowercased() }.contains(item.id.lowercased())
        let busy = purchasingId == "style:\(item.id)"
        let actionLabel: String = {
            if equipped { return "Equipped" }
            if isDefault { return "Clear" }
            return owned ? "Equip" : "Buy"
        }()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.icon ?? "")
                    .font(.system(size: 22))
                Spacer()
                if equipped {
                    statusChip("ON", color: NFGTheme.accent2)
                } else if owned && !isDefault {
                    statusChip("OWNED", color: NFGTheme.gold)
                }
            }
            NameStyledText(
                name: item.resolvedLabel,
                styleId: item.id,
                font: .system(size: 13, weight: .bold)
            )
            if isDefault {
                Text("Free")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
            } else if owned && !equipped {
                Text("Owned — equip free")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(NFGTheme.accent2)
            } else {
                Text("\(item.cost.formatted()) pts")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
            }
            Button {
                Task { await buyStyle(item) }
            } label: {
                Group {
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        Text(actionLabel)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(equipped ? NFGTheme.muted : (owned ? NFGTheme.accent2 : NFGTheme.accent))
            .disabled(!PlayerSession.isLoggedIn || busy || equipped)
        }
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(equipped ? NFGTheme.accent.opacity(0.5) : NFGTheme.border)
        )
    }

    private var statusIconsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Status icons", subtitle: "Same as !buy on live")
            let badges = catalog?.nameBadges ?? []
            if badges.isEmpty {
                emptyCatalogHint
            } else {
                ForEach(badges) { badge in
                    statusIconRow(badge)
                }
            }
        }
    }

    private func statusIconRow(_ badge: NameBadgeShopItem) -> some View {
        let equipped = (catalog?.equippedBadge ?? sync.wallet.nameBadge).lowercased() == badge.id.lowercased()
        let owned = catalog?.ownedBadgeSet.contains(badge.id.lowercased()) ?? sync.wallet.ownedBadges.map { $0.lowercased() }.contains(badge.id.lowercased())
        let busy = purchasingId == "badge:\(badge.id)"
        return HStack(spacing: 12) {
            VaultBadgeIcon(badgeId: badge.id, size: 44)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(badge.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NFGTheme.text)
                Text("Tier \(badge.tier) · \(badge.cost.formatted()) pts")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
                if owned && !equipped {
                    Text("Owned — equip free")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NFGTheme.accent2)
                }
            }
            Spacer(minLength: 4)
            Button {
                Task { await buyBadge(badge) }
            } label: {
                Group {
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        Text(equipped ? "On" : (owned ? "Equip" : "Buy"))
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(equipped ? NFGTheme.muted : NFGTheme.gold)
            .disabled(!PlayerSession.isLoggedIn || busy || equipped)
        }
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(equipped ? NFGTheme.gold.opacity(0.45) : NFGTheme.border)
        )
    }

    private var vaultCatalogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Vault catalog", subtitle: "What !icons shows on stream")
            Text("Browse tiers before you buy. Purchasing still uses points like !buy.")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
        }
    }

    private var emptyCatalogHint: some View {
        Text("Shop catalog unavailable — update the game server (mobile-cosmetics.js) and pull on your PC.")
            .font(.system(size: 12))
            .foregroundStyle(NFGTheme.muted)
    }

    private func statusChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.22))
            .clipShape(Capsule())
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NFGTheme.text)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
        }
    }

    private func badgeShort(_ badgeId: String) -> String? {
        PlayerCosmeticStyle.badgeShort(for: badgeId, catalog: catalog?.nameBadges ?? [])
    }

    private func buyStyle(_ item: NameStyleShopItem) async {
        purchasingId = "style:\(item.id)"
        defer { purchasingId = nil }
        await sync.purchaseNameStyle(item.id)
    }

    private func buyBadge(_ badge: NameBadgeShopItem) async {
        purchasingId = "badge:\(badge.id)"
        defer { purchasingId = nil }
        await sync.purchaseNameBadge(badge.id)
    }
}
