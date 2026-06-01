import SwiftUI

struct SpotifyPanelView: View {
    @EnvironmentObject private var client: LiveCasterClient
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nowPlayingCard
                    requestInfoCard
                    manualQueueCard
                    queueCard
                }
                .padding(14)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await client.refreshSpotify() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(Theme.muted)
                }
            }
            .refreshable { await client.refreshSpotify() }
        }
    }

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Now playing", systemImage: "music.note")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.muted)
                .kerning(0.8)
            Text(client.spotify.nowPlaying)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            if !client.spotify.nowPlayingOk, !client.spotify.nowPlayingError.isEmpty {
                Text(prettyError(client.spotify.nowPlayingError))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard()
    }

    private var requestInfoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.accent2)
            VStack(alignment: .leading, spacing: 3) {
                Text("Viewers request with !song")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("They type  !song <name> <artist>  in your live chat and it queues automatically — no need to touch your phone.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard()
    }

    private var manualQueueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Queue a song yourself")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.muted)
                .kerning(0.8)
            HStack(spacing: 10) {
                TextField("Song name + artist", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .focused($searchFocused)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    .submitLabel(.go)
                    .onSubmit(queue)

                Button(action: queue) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.logoGradient))
                }
                .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            if let msg = client.lastActionMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.muted)
            }
        }
        .nfgCard()
    }

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Up next")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.muted)
                .kerning(0.8)
            if client.spotify.upcoming.isEmpty {
                Text(client.spotify.queueOk ? "Queue is empty." : prettyError(client.spotify.queueError))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(client.spotify.upcoming.enumerated()), id: \.offset) { idx, track in
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.muted)
                            .frame(width: 18)
                        Text(track)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    if idx < client.spotify.upcoming.count - 1 {
                        Divider().overlay(Theme.border)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard()
    }

    private func queue() {
        let q = searchText
        searchText = ""
        searchFocused = false
        Task { await client.queueTrack(q) }
    }

    private func prettyError(_ raw: String) -> String {
        switch raw {
        case "no_active_device": return "Open Spotify and play something so it has an active device."
        case "spotify_not_configured": return "Spotify isn't linked on the PC yet."
        case "queue_list_needs_scope": return "Re-run Spotify auth on the PC for queue access."
        case "queue_forbidden_premium_or_scope": return "Spotify Premium is required to queue."
        default: return raw.replacingOccurrences(of: "_", with: " ")
        }
    }
}
