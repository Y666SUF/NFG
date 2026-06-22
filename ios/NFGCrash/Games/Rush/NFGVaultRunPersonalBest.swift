import Foundation

enum NFGVaultRunPersonalBest {
    private static func key(for user: String) -> String {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "nfg_vault_run_personal_best_\(u.isEmpty ? "guest" : u)"
    }

    static func load(for user: String) -> Int {
        max(0, UserDefaults.standard.integer(forKey: key(for: user)))
    }

    static func save(for user: String, distance: Int) {
        let d = max(0, distance)
        let k = key(for: user)
        if d > UserDefaults.standard.integer(forKey: k) {
            UserDefaults.standard.set(d, forKey: k)
        }
    }

    static func merged(serverBest: Int, for user: String) -> Int {
        max(max(0, serverBest), load(for: user))
    }
}
