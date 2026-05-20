import Foundation

/// Baked-in game server (change here for new builds — not exposed in the app UI).
enum GameServerConfig {
    /// Cloudflare Tunnel → Windows game PC (port 3847 behind the tunnel).
    static let serverURL = "https://y666suf.com"

    static var mobileStatusURL: String {
        "\(serverURL)/api/mobile/status"
    }

    /// WebSocket uses TLS when API is HTTPS (Cloudflare expects `wss://`).
    static var webSocketURL: String {
        guard var comp = URLComponents(string: serverURL) else { return serverURL }
        comp.scheme = "wss"
        return comp.string ?? serverURL
    }
}
