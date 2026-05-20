import Foundation

struct QueuedChat: Codable, Identifiable {
    var id: String
    var message: String
    var userId: String
    var displayName: String
    var createdAt: Date
}

enum OfflineQueue {
    private static let key = "nfg_offline_chat_queue"

    static func load() -> [QueuedChat] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([QueuedChat].self, from: data) else {
            return []
        }
        return items
    }

    static func save(_ items: [QueuedChat]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func enqueue(message: String, userId: String, displayName: String) {
        var items = load()
        items.append(
            QueuedChat(
                id: UUID().uuidString,
                message: message,
                userId: userId,
                displayName: displayName,
                createdAt: Date()
            )
        )
        save(items)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    static var count: Int { load().count }
}
