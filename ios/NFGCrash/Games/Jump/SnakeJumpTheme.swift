import SwiftUI
import UIKit

enum SnakeJumpTheme {
    static let skyTop = UIColor(red: 5 / 255, green: 8 / 255, blue: 16 / 255, alpha: 1)
    static let skyMid = UIColor(red: 10 / 255, green: 18 / 255, blue: 32 / 255, alpha: 1)
    static let skyBottom = UIColor(red: 7 / 255, green: 11 / 255, blue: 20 / 255, alpha: 1)
    static let climbGreen = UIColor(red: 74 / 255, green: 222 / 255, blue: 128 / 255, alpha: 1)
    static let climbGold = UIColor(red: 251 / 255, green: 191 / 255, blue: 36 / 255, alpha: 1)
    static let movingBlue = UIColor(red: 56 / 255, green: 189 / 255, blue: 248 / 255, alpha: 1)
    static let deadlyRose = UIColor(red: 251 / 255, green: 113 / 255, blue: 133 / 255, alpha: 1)
    static let crumbleAmber = UIColor(red: 251 / 255, green: 191 / 255, blue: 36 / 255, alpha: 1)
    static let defaultFill = UIColor(red: 89 / 255, green: 111 / 255, blue: 242 / 255, alpha: 1)
    static let defaultRing = UIColor(red: 242 / 255, green: 199 / 255, blue: 51 / 255, alpha: 1)

    static func platformColor(kind: String) -> UIColor {
        switch kind {
        case "deadly": return deadlyRose
        case "crumble": return crumbleAmber
        case "moving": return movingBlue
        default: return climbGreen
        }
    }

    static func uiColor(hex: String?, fallback: UIColor) -> UIColor {
        guard let hex, !hex.isEmpty else { return fallback }
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt64(raw, radix: 16) else { return fallback }
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static func swiftColor(hex: String?, fallback: Color) -> Color {
        guard let hex, !hex.isEmpty else { return fallback }
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt64(raw, radix: 16) else { return fallback }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
