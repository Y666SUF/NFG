import Foundation

/// App chat owner / moderators (TikTok user ids, no @).
enum ChatOwnerConfig {
    static let ownerUserIds: Set<String> = ["y666.suf"]

    static func isOwner(_ userId: String) -> Bool {
        let normalized = normalize(userId)
        return !normalized.isEmpty && ownerUserIds.contains(normalized)
    }

    static func isOwnerLinkedAccount() -> Bool {
        isOwner(PlayerSession.tiktokUsername)
    }

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
    }
}
