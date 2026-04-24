import Foundation

public struct Shipment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var requestId: UUID?
    public var batchId: UUID?
    public var sourceWarehouseId: UUID?
    public var destinationStoreId: UUID?
    public var status: String
    public var createdAt: Date?

    // ASN & Carrier Details (populated when IM ships)
    public var asnNumber: String?
    public var carrier: String?
    public var trackingNumber: String?
    public var estimatedDelivery: String? // ISO date string "YYYY-MM-DD"
    public var notes: String?

    // GRN back-reference (populated after boutique receives)
    public var hasGRN: Bool?

    // Virtual relations from Supabase joins
    public var request: ProductRequest?

    enum CodingKeys: String, CodingKey {
        case id = "shipment_id"
        case requestId = "request_id"
        case batchId = "batch_id"
        case sourceWarehouseId = "source_warehouse_id"
        case destinationStoreId = "destination_store_id"
        case status
        case createdAt = "created_at"
        case asnNumber = "asn_number"
        case carrier
        case trackingNumber = "tracking_number"
        case estimatedDelivery = "estimated_delivery"
        case notes
        case hasGRN = "has_grn"
        case request = "product_requests"
    }
}
