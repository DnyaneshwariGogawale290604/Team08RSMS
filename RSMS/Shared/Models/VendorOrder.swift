import Foundation

public struct VendorOrder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var requestId: UUID?
    public var vendorId: UUID?
    public var productId: UUID?
    public var quantity: Int?
    public var status: String?
    public var notes: String?
    public var createdAt: Date?

    // Virtual relations
    public var request: ProductRequest?
    public var vendor: Vendor?
    public var product: Product?

    enum CodingKeys: String, CodingKey {
        case id = "vendor_order_id"
        case requestId = "request_id"
        case vendorId = "vendor_id"
        case productId = "product_id"
        case quantity
        case status
        case notes
        case createdAt = "created_at"
        case request = "product_requests"
        case vendor = "vendors"
        case product = "products"
    }
}
