import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @StateObject private var adCoordinator = RewardedAdCoordinator()
    @State private var showLegal = false
    @State private var showAdSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if sync.isLoadingWallet && sync.wallet.user.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        headerCard
                        balanceCard
                        storeSection
                        rewardedAdCard
                        statusRow
                        inventorySection
                    }

                    if let err = sync.walletError {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(NFGTheme.danger)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        showAdSetup = true
                    } label: {
                        Text("Ads & IAP setup (diagnostics)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NFGTheme.accent2)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        showLegal = true
                    } label: {
                        Text("Legal & compliance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NFGTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("My Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await sync.refreshWallet() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(sync.isLoadingWallet)
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: $adCoordinator.showSimulatedAd) {
                SimulatedRewardedAdView(coordinator: adCoordinator)
            }
            .onAppear {
                Task {
                    await sync.refreshWallet()
                    if sync.connectionStatus == "Offline" {
                        sync.connect()
                    }
                    await sync.refreshRewardedAdStatus()
                    await sync.refreshStoreProducts()
                }
            }
            .sheet(isPresented: $showLegal) {
                LegalComplianceView()
                    .environmentObject(sync)
            }
            .navigationDestination(isPresented: $showAdSetup) {
                AdSetupDiagnosticsView()
                    .environmentObject(sync)
            }
        }
    }

    private var storeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundStyle(NFGTheme.accent2)
                Text("Buy points")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
            }

            Text("Virtual play credits for the live crash game. Apple In-App Purchase only.")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)

            if sync.storeIsTestMode && AppDistribution.allowsDevTestStore {
                Text("Dev test mode — no real charge. Set NFG_ALLOW_TEST_STORE=1 on server.")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NFGTheme.gold)
            }

            if let skErr = StoreKitService.shared.loadError, !sync.storeIsTestMode {
                Text(skErr)
                    .font(.system(size: 10))
                    .foregroundStyle(NFGTheme.danger)
            }

            ForEach(sync.storeProducts) { product in
                Button {
                    Task { await sync.purchaseStoreProduct(product) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.displayTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NFGTheme.text)
                            Text(
                                StoreKitService.shared.displayPrice(
                                    for: product.id,
                                    fallback: product.priceLabel
                                )
                            )
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(NFGTheme.muted)
                        }
                        Spacer()
                        if sync.isPurchasingStore {
                            ProgressView()
                        } else {
                            Text("Buy")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .padding(12)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!PlayerSession.isLoggedIn || sync.isPurchasingStore)
            }

            if let msg = sync.storePurchaseMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(msg.contains("+") ? NFGTheme.accent2 : NFGTheme.danger)
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.accent2.opacity(0.35)))
    }

    private var rewardedAdCard: some View {
        let status = sync.rewardedAdStatus
        let amount = status?.rewardAmount ?? AdMobConfig.rewardPoints
        let canClaim = status?.effectivelyCanClaim ?? true
        let cooldown = status?.effectiveCooldownSeconds ?? 0
        let today = status?.claimsToday ?? 0
        let isUnlimited = status?.isEffectivelyUnlimited ?? AdMobConfig.rewardedAdsUnlimited
        let reason = status?.reason

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(NFGTheme.gold)
                Text("Free points")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
            }

            Text("Watch a short ad to earn \(amount.formatted()) pts.")
                .font(.system(size: 12))
                .foregroundStyle(NFGTheme.muted)

            if today > 0, isUnlimited {
                Text("\(today) ad\(today == 1 ? "" : "s") watched today")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
            }

            if status == nil, sync.connectionStatus == "Online" {
                Text("Could not load ad limits from server — you can still try watching an ad.")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
            } else if !canClaim, cooldown > 0 {
                Text(rewardedAdBlockedHint(cooldown: cooldown))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NFGTheme.gold.opacity(0.9))
            }

            if let banner = sync.rewardedAdBanner {
                Text(banner)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(banner.contains("+") ? NFGTheme.accent2 : NFGTheme.danger)
            }

            Button {
                Task { await sync.watchRewardedAdAndClaim(using: adCoordinator) }
            } label: {
                HStack {
                    if sync.isClaimingRewardedAd {
                        ProgressView().tint(.white)
                    }
                    Text(buttonTitle(
                        canClaim: canClaim,
                        cooldown: cooldown,
                        amount: amount,
                        reason: reason
                    ))
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(sync.canTapRewardedAdButton ? NFGTheme.gold : NFGTheme.muted)
            .disabled(!sync.canTapRewardedAdButton)
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.gold.opacity(0.35)))
    }

    private func buttonTitle(canClaim: Bool, cooldown: Int, amount: Int, reason: String?) -> String {
        if !PlayerSession.isLoggedIn {
            return "Link TikTok on live first"
        }
        if !canClaim {
            if cooldown > 0 {
                let min = cooldown / 60
                let sec = cooldown % 60
                return min > 0 ? "Wait \(min)m \(sec)s" : "Wait \(sec)s"
            }
            return "Ad reward not available"
        }
        return "Watch ad for \(amount.formatted()) pts"
    }

    private func rewardedAdBlockedHint(cooldown: Int) -> String {
        let min = max(1, (cooldown + 59) / 60)
        let sec = cooldown % 60
        if min >= 1, sec > 0 {
            return "Next ad reward in about \(min)m \(sec)s."
        }
        return "Next ad reward in \(cooldown)s."
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(NFGTheme.logoGradient)
                    .frame(width: 48, height: 48)
                Text(String(sync.wallet.displayName.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(sync.wallet.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                Text("@\(sync.wallet.user)")
                    .font(.system(size: 13))
                    .foregroundStyle(NFGTheme.muted)
                HStack(spacing: 6) {
                    Text("Lv \(sync.wallet.level)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    Text(sync.wallet.rank)
                        .font(.system(size: 11, weight: .medium))
                    if sync.wallet.superFan {
                        Text("SUPER FAN")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(NFGTheme.gold.opacity(0.25))
                            .clipShape(Capsule())
                            .foregroundStyle(NFGTheme.gold)
                    }
                }
                .foregroundStyle(NFGTheme.accent2)
            }
            Spacer()
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("CURRENT BALANCE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NFGTheme.muted)
            Text("\(sync.wallet.balance.formatted()) pts")
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
            Text("All-time: \(sync.wallet.allTime.formatted()) pts")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 30/255, green: 41/255, blue: 59/255),
                    NFGTheme.panel2,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.accent2.opacity(0.35)))
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            if sync.wallet.shieldActive {
                statusPill(
                    title: "Shield",
                    detail: "\(sync.wallet.shieldSecondsLeft)s left",
                    color: NFGTheme.accent
                )
            }
            if sync.wallet.jetLockActive {
                statusPill(
                    title: "Jet lock",
                    detail: "\(sync.wallet.jetLockSecondsLeft)s",
                    color: NFGTheme.danger
                )
            }
            if !sync.wallet.shieldActive && !sync.wallet.jetLockActive {
                Text("No active shield or jet lock")
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statusPill(title: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(detail)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(NFGTheme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.35)))
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVENTORY")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            Text("Same powerups as !balance on TikTok live")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted.opacity(0.8))

            HStack(spacing: 10) {
                inventoryTile(
                    icon: "bolt.fill",
                    label: "Steal",
                    count: sync.wallet.inventory.stealCharges,
                    tint: NFGTheme.gold
                )
                inventoryTile(
                    icon: "shield.slash.fill",
                    label: "Break shield",
                    count: sync.wallet.inventory.shieldBreakCharges,
                    tint: NFGTheme.danger
                )
                inventoryTile(
                    icon: "airplane",
                    label: "Jet lock",
                    count: sync.wallet.inventory.jetLockCharges,
                    tint: NFGTheme.accent
                )
            }
        }
    }

    private func inventoryTile(icon: String, label: String, count: Int, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(NFGTheme.text)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
    }
}
