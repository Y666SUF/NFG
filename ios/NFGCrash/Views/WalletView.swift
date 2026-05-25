import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @StateObject private var adCoordinator = RewardedAdCoordinator()
    @State private var showLegal = false

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
                        showLegal = true
                    } label: {
                        Text("Legal & compliance")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NFGTheme.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
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
                }
            }
            .sheet(isPresented: $showLegal) {
                LegalComplianceView()
            }
        }
    }

    private var rewardedAdCard: some View {
        let status = sync.rewardedAdStatus
        let amount = status?.rewardAmount ?? AdMobConfig.rewardPoints
        let canClaim = status?.effectivelyCanClaim ?? true
        let cooldown = status?.effectiveCooldownSeconds ?? 0
        let today = status?.claimsToday ?? 0
        let isUnlimited = status?.isEffectivelyUnlimited ?? AdMobConfig.rewardedAdsUnlimited
        let reason = status?.reason

        return VStack(alignment: .leading, spacing: NFGSpacing.sm) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(NFGTheme.gold.opacity(0.22)).frame(width: 28, height: 28)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(NFGTheme.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("FREE POINTS")
                        .font(NFGFont.eyebrow(11))
                        .tracking(1.4)
                        .foregroundStyle(NFGTheme.gold)
                    Text("Watch a short ad to earn \(amount.formatted()) pts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                }
            }

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
                        ProgressView().tint(.black)
                    }
                    Text(buttonTitle(
                        canClaim: canClaim,
                        cooldown: cooldown,
                        amount: amount,
                        reason: reason
                    ))
                }
            }
            .buttonStyle(NFGPrimaryButtonStyle(
                tintGradient: NFGTheme.goldGradient,
                glowColor: NFGTheme.gold,
                isDisabled: !sync.canTapRewardedAdButton
            ))
            .disabled(!sync.canTapRewardedAdButton)
        }
        .nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md, borderColor: NFGTheme.gold.opacity(0.35), glow: NFGTheme.gold.opacity(0.08))
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
        HStack(spacing: NFGSpacing.md) {
            ZStack {
                Circle()
                    .fill(NFGTheme.logoGradient)
                    .frame(width: 52, height: 52)
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .frame(width: 52, height: 52)
                Text(String(sync.wallet.displayName.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(red: 236/255, green: 72/255, blue: 153/255).opacity(0.55), radius: 10, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(sync.wallet.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("@\(sync.wallet.user)")
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
                HStack(spacing: 6) {
                    NFGChip(text: "Lv \(sync.wallet.level)", tint: NFGTheme.accent2)
                    Text(sync.wallet.rank)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.accent2)
                    if sync.wallet.superFan {
                        NFGChip(text: "SUPER FAN", icon: "star.fill", tint: NFGTheme.gold)
                    }
                }
            }
            Spacer()
        }
        .nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md)
    }

    private var balanceCard: some View {
        VStack(spacing: NFGSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("CURRENT BALANCE")
                    .font(NFGFont.eyebrow(11))
                    .tracking(1.4)
            }
            .foregroundStyle(NFGTheme.accent2.opacity(0.85))

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(sync.wallet.balance.formatted())")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(NFGTheme.accent2)
                    .shadow(color: NFGTheme.accent2.opacity(0.4), radius: 12)
                    .contentTransition(.numericText(value: Double(sync.wallet.balance)))
                Text("pts")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(NFGTheme.accent2.opacity(0.6))
            }

            HStack(spacing: 4) {
                Image(systemName: "infinity")
                    .font(.system(size: 10, weight: .bold))
                Text("All-time: \(sync.wallet.allTime.formatted()) pts")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NFGSpacing.xl)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 30/255, green: 41/255, blue: 59/255),
                        NFGTheme.panel2,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [NFGTheme.accent2.opacity(0.18), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: NFGRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.lg)
                .strokeBorder(NFGTheme.accent2.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: NFGTheme.accent2.opacity(0.18), radius: 16, y: 6)
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
        VStack(alignment: .leading, spacing: NFGSpacing.sm) {
            NFGSectionHeader(title: "Inventory", icon: "shippingbox.fill")
            Text("Same powerups as !balance on TikTok live")
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted.opacity(0.8))

            HStack(spacing: NFGSpacing.sm) {
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
        VStack(spacing: NFGSpacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text("\(count)")
                .font(NFGFont.numeric(24, weight: .heavy))
                .foregroundStyle(NFGTheme.text)
                .contentTransition(.numericText(value: Double(count)))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NFGSpacing.md)
        .nfgCard(radius: NFGRadius.md, padding: 0, borderColor: tint.opacity(0.28))
    }
}
