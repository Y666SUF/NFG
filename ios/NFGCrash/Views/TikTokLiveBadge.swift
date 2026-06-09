import SwiftUI

struct TikTokLiveBadge: View {
    let status: TikTokLiveStatus
    var activeAppUsers: Int = 0
    var showInAppCount: Bool = false
    var compact: Bool = false
    var prominent: Bool = false

    @Environment(\.openURL) private var openURL

    private var isTappableLive: Bool {
        status.isOnLive && status.tikTokLiveOpenURL != nil
    }

    var body: some View {
        Group {
            if isTappableLive {
                Button(action: openTikTokLive) {
                    badgeContent
                }
                .buttonStyle(.plain)
            } else {
                badgeContent
            }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isTappableLive ? "Opens your live stream in TikTok" : "")
    }

    private var badgeContent: some View {
        HStack(spacing: compact && !prominent ? 4 : 6) {
            Circle()
                .fill(status.isOnLive ? Color.red : Color.orange.opacity(0.85))
                .frame(width: dotSize, height: dotSize)
                .shadow(color: status.isOnLive ? Color.red.opacity(0.75) : .clear, radius: prominent ? 6 : 4)
            HStack(spacing: 3) {
                Text(status.isOnLive ? "LIVE" : "NOT LIVE")
                    .font(.system(size: labelSize, weight: .bold, design: .rounded))
                    .foregroundStyle(status.isOnLive ? Color.red : NFGTheme.muted)
                if isTappableLive {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: prominent ? 11 : (compact ? 8 : 9), weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            }
            if showInAppCount {
                Text("•")
                    .font(.system(size: compact ? 9 : 11, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
                HStack(spacing: 2) {
                    Image(systemName: "iphone.gen3")
                        .font(.system(size: compact ? 8 : 9, weight: .semibold))
                    Text("\(activeAppUsers)")
                        .font(.system(size: compact ? 10 : 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(NFGTheme.accent)
                .layoutPriority(1)
                .accessibilityLabel(inAppLabel)
            }
        }
        .padding(.horizontal, prominent ? 12 : (compact ? 8 : 10))
        .padding(.vertical, prominent ? 6 : (compact ? 3 : 5))
        .background(
            Capsule()
                .fill(NFGTheme.panel.opacity(prominent ? 1 : 0.95))
                .shadow(color: status.isOnLive && prominent ? Color.red.opacity(0.25) : .clear, radius: 8)
        )
        .overlay(
            Capsule().stroke(
                status.isOnLive ? Color.red.opacity(prominent ? 0.65 : 0.45) : NFGTheme.border,
                lineWidth: prominent ? 1.5 : 1
            )
        )
    }

    private var dotSize: CGFloat {
        if prominent { return 10 }
        return compact ? 6 : 8
    }

    private var labelSize: CGFloat {
        if prominent { return 14 }
        return compact ? 10 : 12
    }

    private func openTikTokLive() {
        guard let url = status.tikTokLiveOpenURL else { return }
        openURL(url)
    }

    private var inAppLabel: String {
        if activeAppUsers == 1 { return "1 in app" }
        return "\(activeAppUsers) in app"
    }

    private var accessibilityText: String {
        let live = status.isOnLive ? "TikTok stream is live, button" : "TikTok stream is not live"
        if showInAppCount {
            return "\(live). \(activeAppUsers) players in the app."
        }
        return live
    }
}
