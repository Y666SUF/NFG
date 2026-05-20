import SwiftUI
import UIKit

/// Full app wordmark from `AppLogo` asset (same artwork as the app icon).
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
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: height * 0.5, weight: .bold))
                    .foregroundStyle(NFGTheme.accent)
            }
        }
        .frame(height: height)
        .accessibilityLabel("NFG Crash")
    }
}
