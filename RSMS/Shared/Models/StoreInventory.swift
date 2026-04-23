import Foundation

public struct StoreInventory: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var storeId: UUID?    // nullable in DB schema
    public var productId: UUID?  // nullable in DB schema
    public var quantity: Int

    enum CodingKeys: String, CodingKey {
        case id = "inventory_id"
        case storeId = "store_id"
        case productId = "product_id"
        case quantity
    }

    // Custom decoder: quantity can also be null in the DB
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self, forKey: .id)
        storeId   = try? c.decodeIfPresent(UUID.self, forKey: .storeId) ?? nil
        productId = try? c.decodeIfPresent(UUID.self, forKey: .productId) ?? nil
        if let q = try? c.decodeIfPresent(Int.self, forKey: .quantity) {
            quantity = q
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .quantity), let q = Int(s) {
            quantity = q
        } else {
            quantity = 0
        }
    }
}
