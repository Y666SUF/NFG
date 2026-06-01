import Foundation

/// Connection config for the NFG Live caster app.
///
/// The backend lives on the Windows PC and is exposed through the Cloudflare
/// tunnel at `https://y666suf.com` (Node server on port 3847 behind the tunnel).
/// The MacBook only builds this UI — all TikTok scraping + Spotify queueing
/// happens on the PC.
enum AppConfig {
    static let defaultServerURL = "https://y666suf.com"

    private static let serverKey = "nfglive.serverURL"

    /// User-overridable server base URL (Settings screen). Defaults to the tunnel.
    static var serverURL: String {
        get {
            let stored = UserDefaults.standard.string(forKey: serverKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let stored, !stored.isEmpty { return stored }
            return defaultServerURL
        }
        set {
            var raw = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.hasSuffix("/") { raw.removeLast() }
            UserDefaults.standard.set(raw, forKey: serverKey)
        }
    }

    static var baseURL: URL? {
        var raw = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasSuffix("/") { raw.removeLast() }
        if !raw.hasPrefix("http") { raw = "https://\(raw)" }
        return URL(string: raw)
    }

    static var webSocketURL: URL? {
        guard let base = baseURL,
              var comp = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        comp.scheme = (comp.scheme == "https") ? "wss" : "ws"
        return comp.url
    }

    static func apiURL(_ path: String) -> URL? {
        let p = path.hasPrefix("/") ? path : "/\(path)"
        return baseURL?.appendingPathComponent(String(p.dropFirst()))
    }

    /// Label sent with host-initiated Spotify queue requests from the app.
    static let hostRequestLabel = "Host (app)"
}
