import SwiftUI

struct InAppChatBannerView: View {
    let notification: AppChatBannerNotification
    let onDismiss: () -> Void
    let onOpenChat: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Button(action: onOpenChat) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(NFGTheme.logoGradient)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(notification.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NFGTheme.text)
                            .lineLimit(1)
                        if !notification.appLabel.isEmpty {
                            Text(notification.appLabel)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(NFGTheme.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text("now")
                            .font(.system(size: 11))
                            .foregroundStyle(NFGTheme.muted)
                    }
                    Text(notification.message)
                        .font(.system(size: 13))
                        .foregroundStyle(NFGTheme.text.opacity(0.92))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .background(NFGTheme.panel.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NFGTheme.border.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -40 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityLabel("Chat from \(notification.displayName)")
        .accessibilityHint("Opens app chat")
    }
}
