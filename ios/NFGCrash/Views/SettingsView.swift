import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @State private var showUnlinkConfirm = false
    @State private var isUnlinking = false
    @State private var unlinkError: String?
    @State private var showLegal = false
    @State private var chatBannerNotificationsEnabled = AppPreferences.chatBannerNotificationsEnabled

    private var accountLabel: String {
        let name = AuthStore.verifiedDisplayName
        let user = AuthStore.verifiedUserId
        if !name.isEmpty, name != user { return "\(name) (@\(user))" }
        return user.isEmpty ? "—" : "@\(user)"
    }

    private var accountKind: String {
        AuthStore.isAppReviewDemo ? "App Review demo" : "TikTok (live verified)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    accountSection
                    notificationsSection
                    switchAccountSection
                    aboutSection
                }
                .padding(20)
            }
            .background(NFGTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Switch account?",
                isPresented: $showUnlinkConfirm,
                titleVisibility: .visible
            ) {
                Button("Unlink and return to sign-in", role: .destructive) {
                    Task { await unlinkAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(unlinkConfirmMessage)
            }
            .sheet(isPresented: $showLegal) {
                LegalComplianceView()
                    .environmentObject(sync)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var unlinkConfirmMessage: String {
        if AuthStore.isAppReviewDemo {
            return "You will return to the sign-in screen. You can use App Review sign-in again or link a real TikTok account with !link while live."
        }
        return "You will return to the TikTok link screen. Use !link on live to sign in with the same or a different TikTok account."
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signed in as")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NFGTheme.muted)
            Text(accountLabel)
                .font(.title3.bold())
                .foregroundStyle(NFGTheme.text)
            Text(accountKind)
                .font(.caption)
                .foregroundStyle(NFGTheme.accent2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
                .foregroundStyle(NFGTheme.text)

            Toggle(isOn: $chatBannerNotificationsEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chat message banners")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NFGTheme.text)
                    Text("Shows new app chat at the top while you play (in-app only, not push).")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
            }
            .tint(NFGTheme.accent)
            .onChange(of: chatBannerNotificationsEnabled) { _, enabled in
                AppPreferences.chatBannerNotificationsEnabled = enabled
                if !enabled {
                    sync.dismissChatBanner()
                }
            }
        }
        .padding(14)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
    }

    private var switchAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .foregroundStyle(NFGTheme.text)

            Text("Unlink this account to link another TikTok (comment !link on live), or switch from App Review demo to a real account.")
                .font(.caption)
                .foregroundStyle(NFGTheme.muted)

            if let unlinkError {
                Text(unlinkError)
                    .font(.caption)
                    .foregroundStyle(NFGTheme.danger)
            }

            Button(role: .destructive) {
                showUnlinkConfirm = true
            } label: {
                HStack {
                    if isUnlinking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Unlink account & switch…")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(NFGTheme.danger)
            .disabled(isUnlinking)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other")
                .font(.headline)
                .foregroundStyle(NFGTheme.text)

            Button {
                showLegal = true
            } label: {
                Label("Legal & compliance", systemImage: "doc.text")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(NFGTheme.accent2)

            Text("Server: \(PlayerSession.serverBaseURL)")
                .font(.caption2)
                .foregroundStyle(NFGTheme.muted)
            Text("App build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?") — UI + entries fix")
                .font(.caption2)
                .foregroundStyle(NFGTheme.accent2.opacity(0.85))
        }
    }

    @MainActor
    private func unlinkAccount() async {
        isUnlinking = true
        unlinkError = nil
        defer { isUnlinking = false }

        await sync.signOut()
        dismiss()
    }
}
