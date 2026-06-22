import Foundation

/// Saves in-progress NFG Blocks board locally (mirrors web localStorage).
enum BlocksLocalStore {
    private static let keyPrefix = "nfg.blocks.board.v1"

    static func save(_ board: BlocksEngine.BoardState, user: String) {
        let key = normalized(user)
        guard !key.isEmpty else { return }
        if let data = try? JSONEncoder().encode(board) {
            UserDefaults.standard.set(data, forKey: storageKey(key))
        }
    }

    static func load(user: String, level: Int) -> BlocksEngine.BoardState? {
        let key = normalized(user)
        guard !key.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey(key)),
              var board = try? JSONDecoder().decode(BlocksEngine.BoardState.self, from: data) else {
            return nil
        }
        board.level = max(1, level)
        board.linesTarget = BlocksEngine.linesTarget(for: board.level)
        return board
    }

    static func clear(user: String) {
        let key = normalized(user)
        guard !key.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: storageKey(key))
    }

    private static func normalized(_ user: String) -> String {
        user.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func storageKey(_ user: String) -> String {
        "\(keyPrefix).\(user)"
    }
}
