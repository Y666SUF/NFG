import Foundation

/// Local fallback if the server store API is not deployed yet.
enum StoreCatalog {
    static let fallbackProducts: [StoreProduct] = [
        StoreProduct(id: "points_10k", points: 10_000, priceLabel: "£1.99", title: "10,000 points"),
        StoreProduct(id: "points_50k", points: 50_000, priceLabel: "£7.99", title: "50,000 points"),
        StoreProduct(id: "points_100k", points: 100_000, priceLabel: "£12.99", title: "100,000 points"),
    ]
}
