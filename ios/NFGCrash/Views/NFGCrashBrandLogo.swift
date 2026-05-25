import SwiftUI
import UIKit

/// Full app wordmark. Uses the `AppLogo` asset when available, otherwise
/// falls back to a styled sticker-style "NFG Crash" wordmark with a chibi rocket
/// glyph so the brand always reads — even in fresh installs / clean builds.
struct NFGCrashBrandLogo: View {
    var height: CGFloat = 52

    var body: some View {
        Group {
            if UIImage(named: "AppLogo") != nil {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(Color.clear)
            } else if let icon = UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                wordmarkFallback
            }
        }
        .frame(height: height)
        .accessibilityLabel("NFG Crash")
    }

    private var wordmarkFallback: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NFGTheme.logoGradient)
                    .frame(width: height * 0.95, height: height * 0.95)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                Image(systemName: "paperplane.fill")
                    .font(.system(size: height * 0.42, weight: .black))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-32))
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            }
            .shadow(color: NFGTheme.logoGradient.opacityShadow, radius: 8, y: 3)

            VStack(alignment: .leading, spacing: -2) {
                Text("NFG")
                    .font(.system(size: height * 0.46, weight: .black, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                Text("CRASH")
                    .font(.system(size: height * 0.32, weight: .heavy, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(NFGTheme.accent)
            }
        }
    }
}

// Tiny helper so we can put a soft shadow on a gradient logo.
private extension LinearGradient {
    var opacityShadow: Color { Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255).opacity(0.5) }
}
