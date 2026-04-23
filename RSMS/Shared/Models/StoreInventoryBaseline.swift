import Foundation

public struct StoreInventoryBaseline: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var storeId: UUID
    public var productId: UUID
    public var baselineQuantity: Int

    enum CodingKeys: String, CodingKey {
        case id = "baseline_id"
        case storeId = "store_id"
        case productId = "product_id"
        case baselineQuantity = "baseline_quantity"
    }
}

public struct StoreBaselineWithProduct: Identifiable, Hashable, Sendable {
    public var id: UUID { baseline.id }
    public var baseline: StoreInventoryBaseline
    public var product: Product
}
