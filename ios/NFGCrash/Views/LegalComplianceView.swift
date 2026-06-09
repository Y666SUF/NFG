import SwiftUI

struct LegalComplianceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    group(
                        title: "Entertainment only",
                        body: """
                        NFG Crash is a companion app for a TikTok LIVE crash game. Points are for fun and leaderboard competition with viewers — not real money. There is no cash-out, no withdrawals, and no real-money gambling in this app. Interact with the stream, place virtual bets, and see who can earn the most points.
                        """
                    )

                    group(
                        title: "Points & purchases",
                        body: """
                        Points are virtual play credits for fun and leaderboard competition on the live stream. There is no cash-out or real-money redemption in this app. If paid point packs are added later, they will use Apple In-App Purchase only.
                        """
                    )

                    group(
                        title: "Advertising",
                        body: """
                        Optional rewarded video ads may be shown to earn in-game points. Ads are provided by Google AdMob. You can limit ad tracking in iOS Settings → Privacy & Security → Tracking.
                        """
                    )

                    group(
                        title: "TikTok account",
                        body: """
                        Linking your account requires posting a verification comment from your TikTok account while live. The app does not accept manually entered usernames for betting or wallet access.
                        """
                    )

                    group(
                        title: "Age",
                        body: "Recommended for users 17 and older due to simulated betting mechanics."
                    )

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy Policy")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(NFGTheme.text)
                                Text("Full policy — also required on your website for App Store")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NFGTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(NFGTheme.muted)
                        }
                        .padding(14)
                        .background(NFGTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("Legal & compliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func group(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: NFGSpacing.sm) {
            Text(title.uppercased())
                .font(NFGFont.eyebrow(11))
                .tracking(1.4)
                .foregroundStyle(NFGTheme.accent2)
            Text(body)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md)
    }
}
