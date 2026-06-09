import SwiftUI

/// Logo + LIVE + round phase (in-app count lives in the nav bar toolbar).
struct GameTopPresenceBar: View {
    let liveStatus: TikTokLiveStatus
    var phase: GamePhase = .idle

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                NFGCrashBrandLogo(height: 36)
                    .shadow(color: NFGTheme.accent.opacity(0.35), radius: 6, y: 2)

                TikTokLiveBadge(
                    status: liveStatus,
                    showInAppCount: false,
                    compact: false,
                    prominent: true
                )
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)

            NFGPhaseBadge(phase: phase)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}
