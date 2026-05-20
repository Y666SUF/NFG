import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: \(PrivacyPolicyContent.lastUpdated)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)

                ForEach(PrivacyPolicyContent.sections) { section in
                    policySection(title: section.title, body: section.body)
                }

                if let url = URL(string: "https://\(PrivacyPolicyContent.websiteHost)/privacy") {
                    Link("Also available at https://\(PrivacyPolicyContent.websiteHost)/privacy", destination: url)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NFGTheme.accent)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .background(NFGTheme.background.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(NFGTheme.text)
            Text(body.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 13))
                .foregroundStyle(NFGTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
