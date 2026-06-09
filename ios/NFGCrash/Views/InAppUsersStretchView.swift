import SwiftUI

/// In-app count pill — wide nav row (between edge and toolbar buttons) or legacy full-width strip.
struct InAppUsersStretchView: View {
    let count: Int
    var activityAnnouncement: PresenceActivityAnnouncement? = nil
    /// Fills space between screen leading edge and trailing toolbar buttons.
    var wideNavigationBar: Bool = false
    /// Legacy compact leading toolbar chip (prefer `wideNavigationBar`).
    var toolbarChip: Bool = false

    private var isWide: Bool { wideNavigationBar || !toolbarChip }

    var body: some View {
        HStack(spacing: wideNavigationBar ? 8 : (toolbarChip ? 5 : 8)) {
            activityIcon
            labelContent
        }
        .foregroundStyle(primaryForeground)
        .padding(.horizontal, wideNavigationBar ? 12 : (toolbarChip ? 10 : 14))
        .padding(.vertical, wideNavigationBar ? 8 : (toolbarChip ? 6 : 8))
        .frame(maxWidth: isWide ? .infinity : nil, alignment: .leading)
        .frame(minHeight: wideNavigationBar ? 36 : nil)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundGradient)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .fixedSize(horizontal: toolbarChip && !wideNavigationBar, vertical: false)
        .animation(.easeInOut(duration: 0.25), value: activityAnnouncement?.username)
        .animation(.easeInOut(duration: 0.25), value: activityAnnouncement?.kind)
        .animation(.easeInOut(duration: 0.25), value: count)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var labelContent: some View {
        if activityAnnouncement != nil && wideNavigationBar {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(primaryLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(primaryLabel)
                .font(.system(size: toolbarChip ? 12 : 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(wideNavigationBar ? 0.85 : 0.75)
                .frame(maxWidth: isWide ? .infinity : nil, alignment: .leading)
        }
    }

    @ViewBuilder
    private var activityIcon: some View {
        let iconSize: CGFloat = toolbarChip ? 12 : 13
        if let activity = activityAnnouncement {
            switch activity.kind {
            case .joined:
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: toolbarChip ? 13 : 15, weight: .semibold))
                    .foregroundStyle(joinGreen)
            case .left:
                Image(systemName: "xmark")
                    .font(.system(size: toolbarChip ? 9 : 11, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: toolbarChip ? 16 : 18, height: toolbarChip ? 16 : 18)
                    .background(Circle().fill(leaveRed))
            }
        } else {
            Image(systemName: "iphone.gen3")
                .font(.system(size: iconSize, weight: .semibold))
        }
    }

    private var primaryLabel: String {
        guard let activity = activityAnnouncement else {
            return count == 1 ? "1 in app" : "\(count) in app"
        }
        switch activity.kind {
        case .joined:
            return "\(activity.username) joined"
        case .left:
            return "\(activity.username) left"
        }
    }

    private var accessibilityText: String {
        guard let activity = activityAnnouncement else {
            return count == 1 ? "1 player in the app" : "\(count) players in the app"
        }
        switch activity.kind {
        case .joined:
            return "\(activity.username) came online in the app"
        case .left:
            return "\(activity.username) left the app"
        }
    }

    private var joinGreen: Color {
        Color(red: 0.35, green: 0.92, blue: 0.55)
    }

    private var leaveRed: Color {
        NFGTheme.danger
    }

    private var primaryForeground: Color {
        guard let activity = activityAnnouncement else { return NFGTheme.accent2 }
        switch activity.kind {
        case .joined: return joinGreen
        case .left: return leaveRed
        }
    }

    private var backgroundGradient: LinearGradient {
        guard let activity = activityAnnouncement else {
            return LinearGradient(
                colors: [NFGTheme.accent.opacity(0.22), NFGTheme.accent.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        switch activity.kind {
        case .joined:
            return LinearGradient(
                colors: [joinGreen.opacity(0.28), joinGreen.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .left:
            return LinearGradient(
                colors: [leaveRed.opacity(0.28), leaveRed.opacity(0.08)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var borderColor: Color {
        guard let activity = activityAnnouncement else {
            return NFGTheme.accent.opacity(0.45)
        }
        switch activity.kind {
        case .joined: return joinGreen.opacity(0.55)
        case .left: return leaveRed.opacity(0.55)
        }
    }
}

/// Wide nav row: in-app pill + trailing action buttons share one horizontal bar.
struct GameNavigationToolbarRow: View {
    @EnvironmentObject private var sync: SyncClient
    var onWallet: () -> Void
    var onChat: () -> Void
    var onLeaderboard: () -> Void
    var onInAppList: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if sync.presencePillVisible {
                Button(action: onInAppList) {
                    InAppUsersStretchView(
                        count: sync.presencePillCount,
                        activityAnnouncement: sync.presenceJoinAnnouncement,
                        wideNavigationBar: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Players in the app")
                .id(sync.presencePillRevision)
            } else {
                Spacer(minLength: 0)
            }

            HStack(spacing: 14) {
                GameNavToolbarIconButton(systemName: "wallet.pass.fill", label: "Profile and wallet", action: onWallet)
                GameNavToolbarIconButton(systemName: "bubble.left.and.bubble.right.fill", label: "App chat", action: onChat)
                GameNavToolbarIconButton(systemName: "list.number", label: "Leaderboard", action: onLeaderboard)
            }
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

private struct GameNavToolbarIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(NFGTheme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(NFGTheme.panel.opacity(0.9)))
                .overlay(Circle().stroke(NFGTheme.accent.opacity(0.25), lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}
