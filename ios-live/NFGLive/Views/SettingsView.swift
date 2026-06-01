import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var client: LiveCasterClient
    @State private var serverURL = AppConfig.serverURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    accountCard
                    serverCard
                    aboutCard
                }
                .padding(14)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TikTok account")
            HStack {
                Text("Connected as")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                Text(client.tiktok.uniqueId.isEmpty ? "—" : "@\(client.tiktok.uniqueId)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.text)
            }
            HStack {
                Text("Status")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                Text(client.tiktok.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(client.tiktok.isLive ? Theme.danger : Theme.muted)
            }
            Text("The account that gets scraped is set on the Windows PC (tiktok.config.json / TIKTOK_USERNAME). The app reads whatever that server is connected to.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard()
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Backend server")
            TextField("https://y666suf.com", text: $serverURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))

            HStack(spacing: 10) {
                Button("Save & reconnect") {
                    AppConfig.serverURL = serverURL
                    serverURL = AppConfig.serverURL
                    client.reconnect()
                }
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Theme.logoGradient, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

                Button("Reset") {
                    AppConfig.serverURL = AppConfig.defaultServerURL
                    serverURL = AppConfig.defaultServerURL
                    client.reconnect()
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Theme.text)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(client.connection == .online ? Theme.success : Theme.muted)
                    .frame(width: 8, height: 8)
                Text(client.connection.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("About")
            Text("NFG Live")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Reads your TikTok live chat aloud and lets viewers queue Spotify songs with !song — hands-free while you stream or drive.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.muted)
            .kerning(0.8)
    }
}
