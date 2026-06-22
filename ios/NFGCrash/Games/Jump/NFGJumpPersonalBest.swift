import Foundation

/// Local NFG Jump best height — survives crashes and syncs with server when online.
enum NFGJumpPersonalBest {
    private static func key(for user: String) -> String {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "nfg_jump_personal_best_\(u.isEmpty ? "guest" : u)"
    }

    static func load(for user: String) -> Int {
        max(0, UserDefaults.standard.integer(forKey: key(for: user)))
    }

    static func save(for user: String, height: Int) {
        let h = max(0, height)
        let k = key(for: user)
        if h > UserDefaults.standard.integer(forKey: k) {
            UserDefaults.standard.set(h, forKey: k)
        }
    }

    static func merged(serverBest: Int, for user: String) -> Int {
        max(max(0, serverBest), load(for: user))
    }
}
