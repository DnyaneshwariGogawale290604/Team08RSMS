import Foundation
import Supabase
import PostgREST

public final class RequestService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = RequestService()
    nonisolated(unsafe) private let client = SupabaseManager.shared.client
    
    private init() {}
    
    public func fetchPendingRequests() async throws -> [ProductRequest] {
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .eq("status", value: "pending")
            .execute()
            .value
    }
    
    public func fetchAllRequests() async throws -> [ProductRequest] {
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    public func fetchAllShipments() async throws -> [Shipment] {
        return try await client
            .from("shipments")
            .select("*, product_requests(*, products(*))")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    public func fetchAllVendorOrders() async throws -> [VendorOrder] {
        return try await client
            .from("vendor_orders")
            .select("*, product_requests(*, products(*))")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    public func createVendorOrder(quantity: Int) async throws {
        struct VendorOrderInsert: Encodable {
            let quantity: Int
            let status: String
            
            enum CodingKeys: String, CodingKey {
                case quantity
                case status
            }
        }
        
        let payload = VendorOrderInsert(quantity: quantity, status: "pending")
        
        try await client
            .from("vendor_orders")
            .insert(payload)
            .execute()
    }
    
    public func updateRequestStatus(id: UUID, status: String, rejectReason: String? = nil) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let rejectReason: String?
            enum CodingKeys: String, CodingKey {
                case status
                case rejectReason = "reject_reason"
            }
        }
        
        let payload = StatusUpdate(status: status, rejectReason: rejectReason)
        
        try await client
            .from("product_requests")
            .update(payload)
            .eq("request_id", value: id)
            .execute()
    }
    
    public func createShipmentForRequest(requestId: UUID, storeId: UUID?) async throws {
        struct ShipmentInsert: Encodable {
            let requestId: UUID
            let destinationStoreId: UUID?
            let status: String
            
            enum CodingKeys: String, CodingKey {
                case requestId = "request_id"
                case destinationStoreId = "destination_store_id"
                case status
            }
        }
        
        let payload = ShipmentInsert(
            requestId: requestId,
            destinationStoreId: storeId,
            status: "in_transit"
        )
        
        try await client
            .from("shipments")
            .insert(payload)
            .execute()
    }
}
