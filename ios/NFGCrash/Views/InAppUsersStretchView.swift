import SwiftUI

/// Horizontal strip: join/leave toast with icon, then in-app count.
struct InAppUsersStretchView: View {
    let count: Int
    var activityAnnouncement: PresenceActivityAnnouncement? = nil

    private var showingActivity: Bool {
        activityAnnouncement != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            activityIcon
            Text(primaryLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .foregroundStyle(primaryForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundGradient)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: activityAnnouncement)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var activityIcon: some View {
        if let activity = activityAnnouncement {
            switch activity.kind {
            case .joined:
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(joinGreen)
            case .left:
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(leaveRed))
            }
        } else {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 13, weight: .semibold))
        }
    }

    private var primaryLabel: String {
        guard let activity = activityAnnouncement else {
            return count == 1 ? "1 in app" : "\(count) in app"
        }
        switch activity.kind {
        case .joined:
            return "\(activity.username) came online"
        case .left:
            return "\(activity.username) left the app"
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
