import Foundation

struct LastBetSpec: Codable, Equatable {
    var amountText: String
    var cashout: Double
}

enum LastBetStore {
    private static let key = "nfg.lastSuccessfulBet"

    static func save(amountText: String, cashout: Double) {
        let cleaned = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cashout >= 1.05 else { return }
        let spec = LastBetSpec(amountText: cleaned, cashout: cashout)
        if let data = try? JSONEncoder().encode(spec) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> LastBetSpec? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let spec = try? JSONDecoder().decode(LastBetSpec.self, from: data) else {
            return nil
        }
        return spec
    }
}
