import Combine
import Foundation
import UIKit

/// Connects to the Windows backend (via the Cloudflare tunnel) and:
///  - receives live TikTok events over the shared WebSocket (`live_comment`,
///    `live_gift`, `live_join`, `live_song_request`) and feeds them to TTS,
///  - polls `/api/mobile/status` for TikTok live state,
///  - polls `/api/spotify/status` for now-playing + queue,
///  - lets the host manually queue a track from the app.
@MainActor
final class LiveCasterClient: ObservableObject {
    let speech: SpeechManager

    @Published private(set) var connection: ConnectionState = .offline
    @Published private(set) var events: [LiveEvent] = []
    @Published private(set) var tiktok: TikTokLiveStatus = .unknown
    @Published private(set) var spotify: SpotifyStatus = .empty
    @Published var lastActionMessage: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession = .shared
    private var pollTimer: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var shouldStayConnected = false
    private var knownIds = Set<String>()

    private let maxEvents = 200

    init(speech: SpeechManager) {
        self.speech = speech
    }

    // MARK: - Lifecycle

    func start() {
        shouldStayConnected = true
        connect()
        startPolling()
    }

    func stop() {
        shouldStayConnected = false
        reconnectWorkItem?.cancel()
        pollTimer?.invalidate()
        pollTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connection = .offline
    }

    /// Re-read server URL from settings and reconnect.
    func reconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connect()
        Task { await refreshAll() }
    }

    // MARK: - WebSocket

    private func connect() {
        guard let url = AppConfig.webSocketURL else {
            connection = .offline
            return
        }
        connection = .connecting
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveLoop()
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handle(message)
                    if self.connection != .online { self.connection = .online }
                    self.receiveLoop()
                case .failure:
                    self.connection = .offline
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldStayConnected else { return }
        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.shouldStayConnected else { return }
            self.connect()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .string(let text): data = text.data(using: .utf8)
        case .data(let blob): data = blob
        @unknown default: data = nil
        }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        let payload = json["payload"] as? [String: Any] ?? [:]

        switch type {
        case "live_comment":
            ingestComment(payload)
        case "live_gift":
            ingestGift(payload)
        case "live_join":
            ingestJoin(payload)
        case "live_song_request":
            ingestSongRequest(payload)
        case "chat_result":
            // Fallback: older PC builds emit Spotify queue results here.
            if (payload["type"] as? String) == "spotify_queue" {
                ingestSongRequest(payload)
                Task { await refreshSpotify() }
            }
        default:
            break
        }
    }

    // MARK: - Event ingestion

    private func ingestComment(_ p: [String: Any]) {
        let displayName = (p["displayName"] as? String) ?? (p["user"] as? String) ?? "Viewer"
        let userId = (p["user"] as? String) ?? (p["userId"] as? String) ?? ""
        let message = (p["message"] as? String ?? p["comment"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        let superFan = (p["superFan"] as? Bool) ?? false
        let event = LiveEvent(
            kind: .comment,
            displayName: displayName,
            userId: userId,
            text: message,
            superFan: superFan
        )
        append(event)
        if speech.shouldSpeakComment(message) {
            speech.speak(event: event)
        }
    }

    private func ingestGift(_ p: [String: Any]) {
        let displayName = (p["displayName"] as? String) ?? (p["user"] as? String) ?? "Viewer"
        let giftName = (p["giftName"] as? String) ?? "a gift"
        let count = (p["giftCount"] as? Int) ?? 1
        let detail = count > 1 ? "\(giftName) x\(count)" : giftName
        let event = LiveEvent(
            kind: .gift,
            displayName: displayName,
            text: "sent \(detail)",
            detail: detail
        )
        append(event)
        speech.speak(event: event)
    }

    private func ingestJoin(_ p: [String: Any]) {
        let displayName = (p["displayName"] as? String) ?? (p["user"] as? String) ?? "Someone"
        let event = LiveEvent(kind: .join, displayName: displayName, text: "joined")
        append(event)
        speech.speak(event: event)
    }

    private func ingestSongRequest(_ p: [String: Any]) {
        let ok = (p["ok"] as? Bool) ?? true
        let requestedBy = (p["requestedBy"] as? String) ?? "Viewer"
        let track = (p["track"] as? String) ?? ""
        let errorText = (p["error"] as? String) ?? ""
        let phrase: String
        let detail: String
        if ok, !track.isEmpty {
            phrase = "Added \(track), requested by \(requestedBy)"
            detail = "✅ \(track)"
        } else if !errorText.isEmpty {
            phrase = "Song request from \(requestedBy) failed"
            detail = "⚠️ \(prettyError(errorText))"
        } else {
            return
        }
        let event = LiveEvent(
            kind: .song,
            displayName: requestedBy,
            text: phrase,
            detail: detail
        )
        append(event)
        speech.speak(event: event)
        Task { await refreshSpotify() }
    }

    private func append(_ event: LiveEvent) {
        guard knownIds.insert(event.id).inserted else { return }
        events.append(event)
        if events.count > maxEvents {
            let drop = events.count - maxEvents
            for r in events.prefix(drop) { knownIds.remove(r.id) }
            events.removeFirst(drop)
        }
    }

    func clearFeed() {
        events.removeAll()
        knownIds.removeAll()
    }

    // MARK: - Polling REST

    private func startPolling() {
        pollTimer?.invalidate()
        Task { await refreshAll() }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
    }

    func refreshAll() async {
        await refreshStatus()
        await refreshSpotify()
    }

    func refreshStatus() async {
        guard let url = AppConfig.apiURL("/api/mobile/status") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            let wire = try JSONDecoder().decode(MobileStatusWire.self, from: data)
            if let t = wire.tiktokLive {
                tiktok = TikTokLiveStatus(
                    uniqueId: t.uniqueId ?? tiktok.uniqueId,
                    state: t.state ?? "unknown",
                    isLive: t.isLive ?? (t.state == "live"),
                    viewerCount: t.viewerCount
                )
            }
        } catch {
            // keep last known
        }
    }

    func refreshSpotify() async {
        guard let url = AppConfig.apiURL("/api/spotify/status") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            let wire = try JSONDecoder().decode(SpotifyStatusWire.self, from: data)
            spotify = SpotifyStatus(
                ok: wire.ok ?? false,
                nowPlaying: wire.nowPlaying ?? "—",
                nowPlayingOk: wire.nowPlayingOk ?? false,
                nowPlayingError: wire.nowPlayingError ?? "",
                queueOk: wire.queueOk ?? false,
                queueError: wire.queueError ?? "",
                upcoming: wire.upcoming ?? []
            )
        } catch {
            // keep last known
        }
    }

    /// Host-initiated queue from the app's search box.
    func queueTrack(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let url = AppConfig.apiURL("/api/spotify/queue") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("nfglive", forHTTPHeaderField: "X-Client-App")
        let body: [String: Any] = ["query": q, "requestedBy": AppConfig.hostRequestLabel]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await session.data(for: req)
            let wire = try JSONDecoder().decode(SpotifyQueueResultWire.self, from: data)
            if wire.ok == true {
                let track = wire.track ?? q
                lastActionMessage = "Queued: \(track)"
                append(LiveEvent(kind: .song, displayName: AppConfig.hostRequestLabel,
                                 text: "Added \(track)", detail: "✅ \(track)"))
            } else {
                lastActionMessage = "Queue failed: \(prettyError(wire.error ?? "unknown"))"
            }
            await refreshSpotify()
        } catch {
            lastActionMessage = "Queue failed: \(error.localizedDescription)"
        }
    }

    private func prettyError(_ raw: String) -> String {
        switch raw {
        case "no_active_device": return "open Spotify on a device first"
        case "spotify_not_configured": return "Spotify not linked on PC"
        case "queue_forbidden_premium_or_scope": return "needs Spotify Premium"
        case "no_results": return "no match found"
        default: return raw.replacingOccurrences(of: "_", with: " ")
        }
    }
}
