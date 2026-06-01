import AVFoundation
import Combine
import SwiftUI

/// On-device text-to-speech for live chat. Uses `AVSpeechSynthesizer` (free,
/// offline, plays through the car/Bluetooth speaker even with the screen off
/// thanks to the `audio` background mode). While speaking it ducks other audio
/// (e.g. Spotify) and restores it when the queue drains.
@MainActor
final class SpeechManager: NSObject, ObservableObject {
    // Persisted settings
    @AppStorage("speech.enabled") var isEnabled = true
    @AppStorage("speech.readComments") var readComments = true
    @AppStorage("speech.readGifts") var readGifts = true
    @AppStorage("speech.readJoins") var readJoins = false
    @AppStorage("speech.readSongRequests") var readSongRequests = true
    @AppStorage("speech.speakUsernames") var speakUsernames = true
    @AppStorage("speech.duckMusic") var duckMusic = true
    @AppStorage("speech.rate") var rate: Double = 0.5
    @AppStorage("speech.pitch") var pitch: Double = 1.0
    @AppStorage("speech.voiceId") var voiceIdentifier = ""
    /// Skip very short / spammy messages (characters).
    @AppStorage("speech.minLength") var minMessageLength: Int = 1
    /// Drop messages that are only emojis / symbols.
    @AppStorage("speech.skipEmojiOnly") var skipEmojiOnly = true

    @Published private(set) var isSpeaking = false
    @Published private(set) var pendingCount = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var sessionActive = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    /// Reads an event aloud if the relevant toggle is on.
    func speak(event: LiveEvent) {
        guard isEnabled else { return }
        let phrase: String?
        switch event.kind {
        case .comment:
            guard readComments else { return }
            phrase = commentPhrase(name: event.displayName, message: event.text)
        case .gift:
            guard readGifts else { return }
            phrase = giftPhrase(name: event.displayName, detail: event.detail ?? event.text)
        case .join:
            guard readJoins else { return }
            phrase = "\(cleanName(event.displayName)) joined"
        case .song:
            guard readSongRequests else { return }
            phrase = event.text
        case .system:
            phrase = event.text
        }
        guard let phrase, !phrase.isEmpty else { return }
        enqueue(phrase)
    }

    /// Speaks an arbitrary line (used for the "Test voice" button).
    func enqueue(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        activateSessionIfNeeded()

        let utterance = AVSpeechUtterance(string: text)
        if !voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        // Map 0...1 slider onto Apple's min...max range.
        let minR = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maxR = Double(AVSpeechUtteranceMaximumSpeechRate)
        utterance.rate = Float(minR + (maxR - minR) * max(0, min(1, rate)))
        utterance.pitchMultiplier = Float(max(0.5, min(2.0, pitch)))
        utterance.postUtteranceDelay = 0.15

        pendingCount += 1
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func test() {
        enqueue("This is your live voice. New comments will be read out loud.")
    }

    /// Stops the current utterance and clears the queue.
    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingCount = 0
        isSpeaking = false
        deactivateSession()
    }

    /// Skips just the current utterance; the rest of the queue continues.
    func skipCurrent() {
        synthesizer.stopSpeaking(at: .word)
    }

    // MARK: - Filtering helpers

    /// Returns true if a comment should be spoken given the spam filters.
    func shouldSpeakComment(_ message: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= max(1, minMessageLength) else { return false }
        if skipEmojiOnly, isEmojiOrSymbolOnly(trimmed) { return false }
        return true
    }

    private func commentPhrase(name: String, message: String) -> String? {
        let msg = strippedForSpeech(message)
        guard !msg.isEmpty else { return nil }
        if speakUsernames {
            return "\(cleanName(name)) says \(msg)"
        }
        return msg
    }

    private func giftPhrase(name: String, detail: String) -> String {
        if speakUsernames {
            return "\(cleanName(name)) sent \(detail)"
        }
        return "Gift: \(detail)"
    }

    private func cleanName(_ name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
        return n.isEmpty ? "Someone" : n
    }

    /// Removes URLs and collapses whitespace so the voice doesn't read links.
    private func strippedForSpeech(_ text: String) -> String {
        var s = text
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = detector.stringByReplacingMatches(in: s, range: range, withTemplate: " link ")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isEmojiOrSymbolOnly(_ text: String) -> Bool {
        let stripped = text.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        return stripped.isEmpty
    }

    // MARK: - Audio session

    private func activateSessionIfNeeded() {
        guard !sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            let options: AVAudioSession.CategoryOptions = duckMusic
                ? [.duckOthers]
                : [.mixWithOthers]
            try session.setCategory(.playback, mode: .spokenAudio, options: options)
            try session.setActive(true)
            sessionActive = true
        } catch {
            // Non-fatal — speech may still play in the foreground.
        }
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        sessionActive = false
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceDidEnd() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceDidEnd() }
    }

    private func utteranceDidEnd() {
        pendingCount = max(0, pendingCount - 1)
        if pendingCount == 0 && !synthesizer.isSpeaking {
            isSpeaking = false
            // Un-duck music once the backlog is read.
            deactivateSession()
        }
    }
}
