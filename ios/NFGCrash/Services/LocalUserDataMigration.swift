import Foundation

/// Moves on-device progress from an app-guest account into a linked TikTok account.
enum LocalUserDataMigration {
    static func mergeGuestAccount(from guestUserId: String, into tiktokUserId: String) {
        let from = normalized(guestUserId)
        let to = normalized(tiktokUserId)
        guard !from.isEmpty, !to.isEmpty, from != to else { return }
        guard from.hasPrefix("appuser_") else { return }

        let jumpEarned = NFGJumpLocalEarnedStore.load(for: from) + NFGJumpLocalEarnedStore.load(for: to)
        NFGJumpLocalEarnedStore.set(jumpEarned, for: to)

        let jumpBest = max(NFGJumpPersonalBest.load(for: from), NFGJumpPersonalBest.load(for: to))
        if jumpBest > 0 { NFGJumpPersonalBest.save(for: to, height: jumpBest) }

        let vaultBest = max(NFGVaultRunPersonalBest.load(for: from), NFGVaultRunPersonalBest.load(for: to))
        if vaultBest > 0 { NFGVaultRunPersonalBest.save(for: to, distance: vaultBest) }

        let jumpGuest = JumpShopLocalStore.load(for: from)
        let jumpTikTok = JumpShopLocalStore.load(for: to)
        var jumpOwned = jumpGuest.owned.union(jumpTikTok.owned)
        jumpOwned.insert(JumpShopCatalog.defaultSkinId)
        let jumpEquipped = jumpTikTok.owned.contains(jumpTikTok.equipped) ? jumpTikTok.equipped : jumpGuest.equipped
        JumpShopLocalStore.save(ownedIds: jumpOwned, equippedId: jumpEquipped, for: to)

        let vaultGuest = VaultRunShopLocalStore.load(for: from)
        let vaultTikTok = VaultRunShopLocalStore.load(for: to)
        var vaultOwned = vaultGuest.owned.union(vaultTikTok.owned)
        vaultOwned.insert(VaultRunShopCatalog.defaultShipId)
        let vaultEquipped = vaultTikTok.owned.contains(vaultTikTok.equipped) ? vaultTikTok.equipped : vaultGuest.equipped
        VaultRunShopLocalStore.save(ownedIds: vaultOwned, equippedId: vaultEquipped, for: to)

        clearGuestKeys(from: from)
        ArcadeOfflinePointsQueue.migrateQueue(from: from, to: to)
        JumpPendingRunStore.migratePendingHeight(from: from, to: to)
    }

    private static func normalized(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func clearGuestKeys(from: String) {
        let exactKeys = [
            "nfg_jump_total_earned_\(from)",
            "nfg_jump_personal_best_\(from)",
            "nfg_vault_run_personal_best_\(from)",
            "nfg.jump.shop.owned.\(from)",
            "nfg.jump.shop.equipped.\(from)",
            "nfg.vault.shop.owned.\(from)",
            "nfg.vault.shop.equipped.\(from)",
        ]
        for key in exactKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
