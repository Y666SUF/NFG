import Foundation
import StoreKit

enum StoreKitPurchaseError: LocalizedError {
    case productNotFound
    case cancelled
    case pending
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "This product is not available in the App Store yet."
        case .cancelled: return "Purchase cancelled."
        case .pending: return "Purchase is pending approval."
        case .notAvailable: return "In-app purchases are not available on this device."
        }
    }
}

/// StoreKit 2 purchases for NFG Crash point packs.
@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    @Published private(set) var appleProducts: [Product] = []
    @Published private(set) var loadError: String?
    @Published private(set) var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    func loadProducts(ids: [String]) async {
        guard !ids.isEmpty else {
            appleProducts = []
            return
        }
        do {
            appleProducts = try await Product.products(for: Set(ids))
            loadError = appleProducts.isEmpty
                ? "No App Store products loaded. Create consumables in App Store Connect matching: \(ids.joined(separator: ", "))."
                : nil
        } catch {
            loadError = error.localizedDescription
            appleProducts = []
        }
    }

    func displayPrice(for productId: String, fallback: String) -> String {
        appleProducts.first(where: { $0.id == productId })?.displayPrice ?? fallback
    }

    func purchase(
        productId: String,
        verifyOnServer: @escaping (_ productId: String, _ transactionId: String, _ signedInfo: String) async throws -> StorePurchaseResponse
    ) async throws -> StorePurchaseResponse {
        guard let product = appleProducts.first(where: { $0.id == productId }) else {
            throw StoreKitPurchaseError.productNotFound
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            let txnId = String(transaction.id)
            let signed = String(data: transaction.jsonRepresentation, encoding: .utf8) ?? ""
            let response = try await verifyOnServer(transaction.productID, txnId, signed)
            await transaction.finish()
            return response
        case .userCancelled:
            throw StoreKitPurchaseError.cancelled
        case .pending:
            throw StoreKitPurchaseError.pending
        @unknown default:
            throw StoreKitPurchaseError.notAvailable
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
        }
    }
}
