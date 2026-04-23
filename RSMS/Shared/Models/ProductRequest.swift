import Foundation

public struct ProductRequest: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var productId: UUID?
    public var storeId: UUID?
    public var requestedBy: UUID?
    public var requestedQuantity: Int
    public var status: String // enum: pending, approved, rejected
    public var rejectionReason: String?
    public var brandId: UUID?
    public var requestDate: Date
    
    // Virtual relations (filled from joins)
    public var product: Product?
    public var store: Store?
    
    enum CodingKeys: String, CodingKey {
        case id = "request_id"
        case productId = "product_id"
        case storeId = "store_id"
        case requestedBy = "requested_by"
        case requestedQuantity = "quantity"
        case status
        case rejectionReason = "rejection_reason"
        case brandId = "brand_id"
        case requestDate = "created_at"
        case product
        case store
    }
}
