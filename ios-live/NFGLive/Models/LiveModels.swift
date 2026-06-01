import Foundation

/// A single thing that happened on the TikTok live, shown in the feed and
/// optionally read aloud by the speech engine.
struct LiveEvent: Identifiable, Equatable {
    enum Kind: String {
        case comment
        case gift
        case join
        case song
        case system
    }

    let id: String
    let kind: Kind
    let displayName: String
    let userId: String
    let text: String
    let superFan: Bool
    let at: Date

    /// Extra detail used for gift/song rows (e.g. coin count or track name).
    var detail: String?

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        displayName: String,
        userId: String = "",
        text: String,
        superFan: Bool = false,
        detail: String? = nil,
        at: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.userId = userId
        self.text = text
        self.superFan = superFan
        self.detail = detail
        self.at = at
    }
}

/// TikTok live connection status, parsed from `/api/mobile/status`.
struct TikTokLiveStatus: Equatable {
    var uniqueId: String
    var state: String        // disabled | waiting | live | offline
    var isLive: Bool
    var viewerCount: Int?

    static let unknown = TikTokLiveStatus(uniqueId: "", state: "unknown", isLive: false, viewerCount: nil)

    var label: String {
        switch state {
        case "live": return "LIVE"
        case "waiting": return "Waiting for live"
        case "offline": return "Offline"
        case "disabled": return "Bridge off"
        default: return "—"
        }
    }
}

/// Spotify now-playing + queue, parsed from `/api/spotify/status`.
struct SpotifyStatus: Equatable {
    var ok: Bool
    var nowPlaying: String
    var nowPlayingOk: Bool
    var nowPlayingError: String
    var queueOk: Bool
    var queueError: String
    var upcoming: [String]

    static let empty = SpotifyStatus(
        ok: false,
        nowPlaying: "—",
        nowPlayingOk: false,
        nowPlayingError: "",
        queueOk: false,
        queueError: "",
        upcoming: []
    )
}

enum ConnectionState: Equatable {
    case offline
    case connecting
    case online

    var label: String {
        switch self {
        case .offline: return "Offline"
        case .connecting: return "Connecting…"
        case .online: return "Connected"
        }
    }
}

// MARK: - Wire decoders (server JSON)

struct MobileStatusWire: Decodable {
    struct TikTokWire: Decodable {
        var uniqueId: String?
        var state: String?
        var isLive: Bool?
        var viewerCount: Int?
    }
    var tiktokLive: TikTokWire?
}

struct SpotifyStatusWire: Decodable {
    var ok: Bool?
    var nowPlaying: String?
    var nowPlayingOk: Bool?
    var nowPlayingError: String?
    var queueOk: Bool?
    var queueError: String?
    var upcoming: [String]?
}

struct SpotifyQueueResultWire: Decodable {
    var ok: Bool?
    var error: String?
    var requestedBy: String?
    var track: String?
}
