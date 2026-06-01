import AVFoundation
import SwiftUI

struct SpeechControlsView: View {
    @EnvironmentObject private var speech: SpeechManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    masterCard
                    readWhatCard
                    voiceCard
                    filtersCard
                }
                .padding(14)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var masterCard: some View {
        VStack(spacing: 14) {
            Toggle(isOn: $speech.isEnabled) {
                Label("Read chat aloud", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .bold))
            }
            .tint(Theme.accent)
            .onChange(of: speech.isEnabled) { _, on in
                if !on { speech.stopAll() }
            }

            HStack(spacing: 12) {
                Button {
                    speech.test()
                } label: {
                    Label("Test voice", systemImage: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.logoGradient, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button {
                    speech.stopAll()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.text)
                }
            }
        }
        .nfgCard()
    }

    private var readWhatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("What to read")
            Toggle("Comments", isOn: $speech.readComments).tint(Theme.accent)
            Toggle("Gifts", isOn: $speech.readGifts).tint(Theme.accent)
            Toggle("New viewers joining", isOn: $speech.readJoins).tint(Theme.accent)
            Toggle("Song request confirmations", isOn: $speech.readSongRequests).tint(Theme.accent)
            Divider().overlay(Theme.border)
            Toggle("Say the person's name", isOn: $speech.speakUsernames).tint(Theme.accent)
        }
        .font(.system(size: 14, weight: .medium))
        .nfgCard()
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Voice")

            VStack(alignment: .leading, spacing: 6) {
                Text("Voice").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                Picker("Voice", selection: $speech.voiceIdentifier) {
                    Text("Default").tag("")
                    ForEach(speech.availableVoices, id: \.identifier) { voice in
                        Text(voiceLabel(voice)).tag(voice.identifier)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }

            sliderRow(title: "Speed", value: $speech.rate, range: 0...1, format: speedLabel)
            sliderRow(title: "Pitch", value: $speech.pitch, range: 0.5...2.0) {
                String(format: "%.2f", $0)
            }
        }
        .nfgCard()
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Spam filters")
            Toggle("Skip emoji-only messages", isOn: $speech.skipEmojiOnly)
                .tint(Theme.accent)
                .font(.system(size: 14, weight: .medium))
            Stepper(value: $speech.minMessageLength, in: 1...20) {
                Text("Min message length: \(speech.minMessageLength)")
                    .font(.system(size: 14, weight: .medium))
            }
            Text("Links are replaced with the word \"link\" so the voice never reads out URLs.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
        }
        .nfgCard()
    }

    // MARK: helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Theme.muted)
            .kerning(0.8)
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            Slider(value: value, in: range).tint(Theme.accent)
        }
    }

    private func speedLabel(_ v: Double) -> String {
        switch v {
        case ..<0.33: return "Slow"
        case ..<0.66: return "Normal"
        default: return "Fast"
        }
    }

    private func voiceLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = " ⋆"
        case .enhanced: quality = " ⁺"
        default: quality = ""
        }
        return "\(voice.name) (\(voice.language))\(quality)"
    }
}
