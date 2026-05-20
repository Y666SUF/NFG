import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit
#endif

/// Presents a rewarded ad (AdMob when SDK is linked, short placeholder otherwise).
@MainActor
final class RewardedAdCoordinator: ObservableObject {
    @Published var showSimulatedAd = false
    @Published var lastLoadError: String?

    private var simulatedContinuation: CheckedContinuation<Bool, Never>?

    func watchAdForReward() async -> Bool {
        #if canImport(GoogleMobileAds)
        return await presentGoogleRewardedAd()
        #else
        return await presentSimulatedAd()
        #endif
    }

    func finishSimulatedAd(watched: Bool) {
        showSimulatedAd = false
        simulatedContinuation?.resume(returning: watched)
        simulatedContinuation = nil
    }

    private func presentSimulatedAd() async -> Bool {
        await withCheckedContinuation { continuation in
            simulatedContinuation = continuation
            showSimulatedAd = true
        }
    }

    #if canImport(GoogleMobileAds)
    private func presentGoogleRewardedAd() async -> Bool {
        lastLoadError = nil
        return await withCheckedContinuation { continuation in
            RewardedAd.load(with: AdMobConfig.rewardedAdUnitID, request: Request()) { ad, error in
                Task { @MainActor [weak self] in
                    if let error {
                        self?.lastLoadError = error.localizedDescription
                        continuation.resume(returning: false)
                        return
                    }
                    guard let ad else {
                        self?.lastLoadError = "Ad not available. Try again in a moment."
                        continuation.resume(returning: false)
                        return
                    }
                    guard let presenter = Self.topViewController() else {
                        self?.lastLoadError = "Could not present ad."
                        continuation.resume(returning: false)
                        return
                    }
                    var earnedReward = false
                    var resumed = false
                    ad.fullScreenContentDelegate = RewardedAdDelegateBox {
                        guard !resumed else { return }
                        resumed = true
                        continuation.resume(returning: earnedReward)
                    }
                    ad.present(from: presenter) {
                        earnedReward = true
                    }
                }
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            guard let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
                  var top = window.rootViewController else { continue }
            while let presented = top.presentedViewController { top = presented }
            return top
        }
        return nil
    }
    #endif
}

#if canImport(GoogleMobileAds)
private final class RewardedAdDelegateBox: NSObject, FullScreenContentDelegate {
    let onDismiss: () -> Void
    init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { onDismiss() }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { onDismiss() }
}
#endif

struct SimulatedRewardedAdView: View {
    @ObservedObject var coordinator: RewardedAdCoordinator
    @State private var secondsLeft = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Rewarded ad (test)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Add Google Mobile Ads SDK for real ads.\nSee ADMOB-SETUP.md in the project.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NFGTheme.muted)
                    .padding(.horizontal, 24)
                Text("\(secondsLeft)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.accent)
                Button("Skip") {
                    coordinator.finishSimulatedAd(watched: false)
                }
                .foregroundStyle(NFGTheme.muted)
            }
        }
        .onAppear {
            secondsLeft = 3
            Task {
                for _ in 0..<3 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run { secondsLeft = max(0, secondsLeft - 1) }
                }
                await MainActor.run {
                    coordinator.finishSimulatedAd(watched: true)
                }
            }
        }
    }
}
