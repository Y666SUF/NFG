import SwiftUI

/// Logo + LIVE top-left; in-app strip stretches right showing join alerts then online count.
struct GameTopPresenceBar: View {
    let liveStatus: TikTokLiveStatus
    let activeAppUsers: Int
    let showInAppCount: Bool
    var activityAnnouncement: PresenceActivityAnnouncement? = nil
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

            if showInAppCount {
                InAppUsersStretchView(
                    count: activeAppUsers,
                    activityAnnouncement: activityAnnouncement
                )
            } else {
                Spacer(minLength: 0)
            }

            NFGPhaseBadge(phase: phase)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}
