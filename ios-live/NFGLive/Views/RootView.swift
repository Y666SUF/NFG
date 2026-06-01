import SwiftUI

struct RootView: View {
    @EnvironmentObject private var client: LiveCasterClient

    var body: some View {
        TabView {
            LiveFeedView()
                .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }

            SpeechControlsView()
                .tabItem { Label("Voice", systemImage: "waveform") }

            SpotifyPanelView()
                .tabItem { Label("Music", systemImage: "music.note") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
    }
}

/// Connection + TikTok live status pill reused on several screens.
struct StatusBar: View {
    @EnvironmentObject private var client: LiveCasterClient

    var body: some View {
        HStack(spacing: 10) {
            connectionPill
            tiktokPill
            Spacer()
            if let viewers = client.tiktok.viewerCount, client.tiktok.isLive {
                Label("\(viewers)", systemImage: "eye.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var connectionPill: some View {
        let online = client.connection == .online
        return Label(client.connection.label, systemImage: online ? "wifi" : "wifi.slash")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(online ? Theme.success : Theme.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.panel))
            .overlay(Capsule().stroke(Theme.border))
    }

    private var tiktokPill: some View {
        let live = client.tiktok.isLive
        let handle = client.tiktok.uniqueId.isEmpty ? "" : "@\(client.tiktok.uniqueId)"
        return HStack(spacing: 5) {
            Circle()
                .fill(live ? Theme.danger : Theme.muted)
                .frame(width: 7, height: 7)
            Text(live ? "LIVE \(handle)" : (handle.isEmpty ? client.tiktok.label : "\(client.tiktok.label) \(handle)"))
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(live ? Theme.text : Theme.muted)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(live ? Theme.danger.opacity(0.18) : Theme.panel))
        .overlay(Capsule().stroke(live ? Theme.danger.opacity(0.5) : Theme.border))
    }
}
