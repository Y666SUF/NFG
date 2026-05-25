import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Last updated: \(TermsOfServiceContent.lastUpdated)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)

                ForEach(TermsOfServiceContent.sections) { section in
                    policySection(title: section.title, body: section.body)
                }

                if let url = URL(string: "https://\(TermsOfServiceContent.websiteHost)/terms") {
                    Link("Also available at https://\(TermsOfServiceContent.websiteHost)/terms", destination: url)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NFGTheme.accent)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .background(NFGTheme.background.ignoresSafeArea())
        .navigationTitle("Terms of Service")
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
