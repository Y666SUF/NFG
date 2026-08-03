import Foundation

/// Lifetime NFG Jump points earned — stored locally per user on device.
enum NFGJumpLocalEarnedStore {
    private static func key(for user: String) -> String {
        let u = user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "nfg_jump_total_earned_\(u.isEmpty ? "guest" : u)"
    }

    static func load(for user: String) -> Int {
        max(0, UserDefaults.standard.integer(forKey: key(for: user)))
    }

    @discardableResult
    static func add(_ points: Int, for user: String) -> Int {
        let add = max(0, points)
        guard add > 0 else { return load(for: user) }
        let k = key(for: user)
        let next = load(for: user) + add
        UserDefaults.standard.set(next, forKey: k)
        return next
    }

    static func set(_ total: Int, for user: String) {
        UserDefaults.standard.set(max(0, total), forKey: key(for: user))
    }
}
