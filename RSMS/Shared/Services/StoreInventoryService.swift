import Foundation
import Supabase
import PostgREST

public final class StoreInventoryService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = StoreInventoryService()
    nonisolated(unsafe) private let client = SupabaseManager.shared.client
    
    private init() {}
    
    // In many setups, joining `products(*)` works directly if foreign keys are standard. 
    // Otherwise we fetch separately in ViewModel or rely on an RPC. 
    // Here we provide the base fetch for baselines:
    public func fetchBaselines(forStore storeId: UUID) async throws -> [StoreInventoryBaseline] {
        return try await client
            .from("store_inventory_baseline")
            .select()
            .eq("store_id", value: storeId)
            .execute()
            .value
    }
    
    public func assignProducts(storeId: UUID, items: [(productId: UUID, quantity: Int)]) async throws {
        struct BaselineInsertPayload: Encodable {
            let store_id: UUID
            let product_id: UUID
            let baseline_quantity: Int
            let current_quantity: Int
        }
        
        struct InventoryInsertPayload: Encodable {
            let store_id: UUID
            let product_id: UUID
            let quantity: Int
            let updated_at: String
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        let baselinePayloads = items.map {
            BaselineInsertPayload(
                store_id: storeId,
                product_id: $0.productId,
                baseline_quantity: $0.quantity,
                current_quantity: $0.quantity
            )
        }
        
        let inventoryPayloads = items.map {
            InventoryInsertPayload(
                store_id: storeId,
                product_id: $0.productId,
                quantity: $0.quantity,
                updated_at: now
            )
        }
        
        // Insert into both tables
        try await client
            .from("store_inventory_baseline")
            .insert(baselinePayloads)
            .execute()
            
        try await client
            .from("store_inventory")
            .insert(inventoryPayloads)
            .execute()
    }
    
    public func updateBaselineQuantity(baselineId: UUID, quantity: Int) async throws {
        struct UpdatePayload: Encodable {
            let baselineQuantity: Int
            enum CodingKeys: String, CodingKey {
                case baselineQuantity = "baseline_quantity"
            }
        }
        
        try await client
            .from("store_inventory_baseline")
            .update(UpdatePayload(baselineQuantity: quantity))
            .eq("baseline_id", value: baselineId)
            .execute()
    }
    
    public func removeBaseline(baselineId: UUID) async throws {
        try await client
            .from("store_inventory_baseline")
            .delete()
            .eq("baseline_id", value: baselineId)
            .execute()
    }
    
    public func fetchCurrentInventory(forStore storeId: UUID) async throws -> [StoreInventory] {
        return try await client
            .from("store_inventory")
            .select()
            .eq("store_id", value: storeId)
            .execute()
            .value
    }
}
