import SwiftUI

struct LiveFeedView: View {
    @EnvironmentObject private var client: LiveCasterClient
    @EnvironmentObject private var speech: SpeechManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBar()
                speakingBar
                feedList
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Live Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { client.clearFeed() } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Theme.muted)
                }
            }
        }
    }

    private var speakingBar: some View {
        HStack(spacing: 12) {
            Button {
                speech.isEnabled.toggle()
                if !speech.isEnabled { speech.stopAll() }
            } label: {
                Label(speech.isEnabled ? "Voice on" : "Voice off",
                      systemImage: speech.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(speech.isEnabled ? AnyShapeStyle(Theme.logoGradient)
                                                          : AnyShapeStyle(Theme.panel))
                    )
            }

            if speech.isSpeaking {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    if speech.pendingCount > 1 {
                        Text("\(speech.pendingCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(Theme.accent)

                Button("Skip") { speech.skipCurrent() }
                    .font(.system(size: 12, weight: .bold))
                    .tint(Theme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var feedList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if client.events.isEmpty {
                        emptyState
                    }
                    ForEach(client.events) { event in
                        FeedRow(event: event).id(event.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: client.events.count) { _, _ in
                if let last = client.events.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(Theme.muted)
            Text("Waiting for live chat…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("When you go live on TikTok as @\(client.tiktok.uniqueId.isEmpty ? "your account" : client.tiktok.uniqueId), comments will appear here and be read aloud.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 60)
    }
}

private struct FeedRow: View {
    let event: LiveEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                    if event.superFan {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.warning)
                    }
                    Spacer()
                    Text(event.at, style: .time)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.muted.opacity(0.7))
                }
                Text(bodyText)
                    .font(.system(size: 14, weight: event.kind == .comment ? .regular : .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nfgCard(padding: 11)
    }

    private var bodyText: String {
        switch event.kind {
        case .comment: return event.text
        case .gift: return event.detail ?? event.text
        case .join: return "joined the live"
        case .song: return event.detail ?? event.text
        case .system: return event.text
        }
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: 26, height: 26)
            .background(Circle().fill(iconColor.opacity(0.16)))
    }

    private var symbol: String {
        switch event.kind {
        case .comment: return "bubble.left.fill"
        case .gift: return "gift.fill"
        case .join: return "person.fill.badge.plus"
        case .song: return "music.note"
        case .system: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch event.kind {
        case .comment: return Theme.accent
        case .gift: return Theme.warning
        case .join: return Theme.accent2
        case .song: return Theme.success
        case .system: return Theme.muted
        }
    }

    private var nameColor: Color {
        event.superFan ? Theme.warning : Theme.accent
    }
}
