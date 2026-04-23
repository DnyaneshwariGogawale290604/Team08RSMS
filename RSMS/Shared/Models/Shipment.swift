import Foundation

public struct Shipment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var requestId: UUID?
    public var batchId: UUID?
    public var sourceWarehouseId: UUID?
    public var destinationStoreId: UUID?
    public var status: String
    public var createdAt: Date?
    
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
        case request = "product_requests" // Assuming default PostgREST relation name
    }
}
