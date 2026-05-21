import SwiftUI
import AppTrackingTransparency

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// In-app checklist for AdMob + server rewarded-ad setup (Wallet → Ads & IAP setup).
struct AdSetupDiagnosticsView: View {
    @EnvironmentObject private var sync: SyncClient
    @StateObject private var adCoordinator = RewardedAdCoordinator()
    @State private var sdkLinked = false
    @State private var attStatus = "Unknown"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerBlock
                configBlock
                serverBlock
                checklistBlock
                testAdBlock
                iapBlock
                docsBlock
            }
            .padding(16)
        }
        .background(NFGTheme.background.ignoresSafeArea())
        .navigationTitle("Ads & IAP setup")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $adCoordinator.showSimulatedAd) {
            SimulatedRewardedAdView(coordinator: adCoordinator)
        }
        .onAppear {
            #if canImport(GoogleMobileAds)
            sdkLinked = true
            #endif
            attStatus = trackingAuthLabel()
            Task {
                await sync.refreshRewardedAdStatus()
                await sync.refreshStoreProducts()
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use this screen to confirm rewarded ads and in-app purchases before TestFlight.")
                .font(.system(size: 13))
                .foregroundStyle(NFGTheme.muted)
            Text("Server: \(PlayerSession.serverBaseURL)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
        }
    }

    private var configBlock: some View {
        diagSection(title: "AdMob config (app)") {
            row("App ID", AdMobConfig.applicationID, ok: AdMobConfig.applicationID.hasPrefix("ca-app-pub-"))
            row("Rewarded unit", AdMobConfig.rewardedAdUnitID, ok: AdMobConfig.rewardedAdUnitID.contains("/"))
            row("Reward points", "\(AdMobConfig.rewardPoints.formatted())", ok: true)
            row("Google Mobile Ads SDK", sdkLinked ? "Linked" : "Not linked — simulated ad only", ok: sdkLinked)
            row("ATT status", attStatus, ok: true)
        }
    }

    private var serverBlock: some View {
        diagSection(title: "Rewarded ad API (server)") {
            let status = sync.rewardedAdStatus
            row("Connection", sync.connectionStatus, ok: sync.connectionStatus == "Online")
            row(
                "GET /api/mobile/rewarded-ad/status",
                status != nil ? "OK" : (sync.rewardedAdBanner ?? "Failed or not deployed"),
                ok: status != nil
            )
            if let status {
                row("Can claim", status.effectivelyCanClaim ? "Yes" : "No", ok: status.effectivelyCanClaim)
                row("Reward amount", "\(status.rewardAmount ?? AdMobConfig.rewardPoints)", ok: true)
                row("Cooldown", "\(status.effectiveCooldownSeconds ?? 0)s", ok: true)
            }
            row(
                "POST /api/mobile/rewarded-ad/claim",
                "Called after ad completes",
                ok: status != nil
            )
        }
    }

    private var checklistBlock: some View {
        diagSection(title: "What you need for ads to work") {
            bullet("AdMob account + app `com.nfg.crash` approved")
            bullet("Payment profile in AdMob (to get paid)")
            bullet("PC server running with `mobile-rewarded-ad.js` on port 3847")
            bullet("Public URL `https://y666suf.com` (Cloudflare tunnel)")
            bullet("User linked TikTok (`!link`) before claim credits points")
            bullet("App Store Connect: “Contains ads” = Yes")
        }
    }

    private var testAdBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TEST REWARDED AD")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NFGTheme.muted)

            Button {
                Task { await sync.watchRewardedAdAndClaim(using: adCoordinator) }
            } label: {
                HStack {
                    if sync.isClaimingRewardedAd { ProgressView().tint(.white) }
                    Text("Watch test ad + claim on server")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(NFGTheme.gold)
            .disabled(!PlayerSession.isLoggedIn || sync.isClaimingRewardedAd)

            if !PlayerSession.isLoggedIn {
                Text("Link TikTok on live first to test claim.")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.danger)
            }
            if let banner = sync.rewardedAdBanner {
                Text(banner)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(banner.contains("+") ? NFGTheme.accent2 : NFGTheme.danger)
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private var iapBlock: some View {
        diagSection(title: "In-app purchases") {
            row("StoreKit products loaded", "\(StoreKitService.shared.appleProducts.count) / 3", ok: !StoreKitService.shared.appleProducts.isEmpty)
            row("Server test store", sync.storeIsTestMode ? "Enabled (dev)" : "Disabled — Apple IAP only", ok: true)
            row("Verify endpoint", "POST /api/mobile/store/verify-purchase", ok: true)
            bullet("App Store Connect → consumables: `points_10k`, `points_50k`, `points_100k`")
            bullet("Agreements, Tax, and Banking must be active in ASC")
            bullet("Sandbox tester account for TestFlight IAP tests")
        }
    }

    private var docsBlock: some View {
        Text("See `ios/ADMOB-SETUP.md` and `ios/TESTFLIGHT-SETUP.md` in the repo.")
            .font(.system(size: 11))
            .foregroundStyle(NFGTheme.muted)
    }

    private func diagSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func row(_ label: String, _ value: String, ok: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? NFGTheme.accent2 : NFGTheme.danger)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.text)
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
            }
            Spacer(minLength: 0)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(NFGTheme.gold)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(NFGTheme.muted)
        }
    }

    private func trackingAuthLabel() -> String {
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized: return "Authorized"
            case .denied: return "Denied"
            case .restricted: return "Restricted"
            case .notDetermined: return "Not asked yet"
            @unknown default: return "Unknown"
            }
        }
        return "N/A (iOS < 14)"
    }
}
