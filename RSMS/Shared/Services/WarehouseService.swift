import Foundation
import Supabase
import PostgREST

public final class WarehouseService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = WarehouseService()
    nonisolated(unsafe) private let client = SupabaseManager.shared.client
    
    private init() {}
    
    public func fetchWarehouses() async throws -> [Warehouse] {
        let brandId = try await fetchCurrentCorporateAdminBrandId()
        return try await client
            .from("warehouses")
            .select()
            .eq("brand_id", value: brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchWarehouse(id: UUID) async throws -> Warehouse {
        try await client
            .from("warehouses")
            .select()
            .eq("warehouse_id", value: id)
            .single()
            .execute()
            .value
    }
    
    public func fetchInventoryManagers(forWarehouse warehouseId: UUID) async throws -> [InventoryManagerRecord] {
        try await client
            .from("inventory_managers")
            .select("user_id, warehouse_id, corporate_admin_id, created_at, users(*)")
            .eq("warehouse_id", value: warehouseId)
            .execute()
            .value
    }
    
    public func createWarehouse(_ warehouse: Warehouse) async throws {
        let brandId = try await fetchCurrentCorporateAdminBrandId()

        struct WarehouseInsert: Encodable {
            let warehouseId: UUID
            let name: String
            let location: String
            let address: String?
            let status: String?
            let brandId: UUID

            enum CodingKeys: String, CodingKey {
                case warehouseId = "warehouse_id"
                case name
                case location
                case address
                case status
                case brandId = "brand_id"
            }
        }

        try await client
            .from("warehouses")
            .insert(
                WarehouseInsert(
                    warehouseId: warehouse.id,
                    name: warehouse.name,
                    location: warehouse.location,
                    address: warehouse.address,
                    status: warehouse.status,
                    brandId: brandId
                )
            )
            .execute()
    }
    
    public func assignInventoryManager(warehouseId: UUID, managerId: UUID) async throws {
        struct ManagerUpdate: Encodable {
            let inventoryManagerId: UUID
            enum CodingKeys: String, CodingKey {
                case inventoryManagerId = "inventory_manager_id"
            }
        }
        try await client
            .from("warehouses")
            .update(ManagerUpdate(inventoryManagerId: managerId))
            .eq("warehouse_id", value: warehouseId)
            .execute()
    }

    public func updateWarehouseStatus(id: UUID, status: String) async throws {
        struct StatusUpdate: Encodable {
            let status: String
        }
        try await client
            .from("warehouses")
            .update(StatusUpdate(status: status))
            .eq("warehouse_id", value: id)
            .execute()
    }

    // MARK: - Warehouse Inventory

    /// Returns the quantity of a specific product in a given warehouse.
    public func stockQuantity(warehouseId: UUID, productId: UUID) async throws -> Int {
        struct StockRow: Decodable {
            let quantity: Int
            enum CodingKeys: String, CodingKey { case quantity }
        }
        let rows: [StockRow] = try await client
            .from("warehouse_inventory")
            .select("quantity")
            .eq("warehouse_id", value: warehouseId)
            .eq("product_id", value: productId)
            .limit(1)
            .execute()
            .value
        return rows.first?.quantity ?? 0
    }

    /// Decrements warehouse stock by `quantity` after a shipment is dispatched.
    public func decrementStock(warehouseId: UUID, productId: UUID, by quantity: Int) async throws {
        let current = try await stockQuantity(warehouseId: warehouseId, productId: productId)
        let newQty = max(0, current - quantity)
        struct StockUpsert: Encodable {
            let warehouseId: UUID
            let productId: UUID
            let quantity: Int
            enum CodingKeys: String, CodingKey {
                case warehouseId = "warehouse_id"
                case productId   = "product_id"
                case quantity
            }
        }
        try await client
            .from("warehouse_inventory")
            .upsert(
                StockUpsert(warehouseId: warehouseId, productId: productId, quantity: newQty),
                onConflict: "warehouse_id,product_id"
            )
            .execute()
    }

    /// Fetch all inventory rows for a given warehouse (with product join).
    public func fetchInventory(warehouseId: UUID) async throws -> [WarehouseInventoryRow] {
        return try await client
            .from("warehouse_inventory")
            .select("*, products(*)")
            .eq("warehouse_id", value: warehouseId)
            .execute()
            .value
    }

    private func fetchCurrentCorporateAdminBrandId() async throws -> UUID {
        struct CorporateAdminBrandRow: Decodable {
            let brandId: UUID

            enum CodingKeys: String, CodingKey {
                case brandId = "brand_id"
            }
        }

        let currentUserId = try await client.auth.session.user.id

        let rows: [CorporateAdminBrandRow] = try await client
            .from("corporate_admins")
            .select("brand_id")
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value

        guard let brandId = rows.first?.brandId else {
            throw WarehouseServiceContextError.missingCorporateAdminContext
        }

        return brandId
    }
}

private enum WarehouseServiceContextError: LocalizedError {
    case missingCorporateAdminContext

    var errorDescription: String? {
        switch self {
        case .missingCorporateAdminContext:
            return "Only corporate admins can create stores and warehouses."
        }
    }
}

// MARK: - WarehouseInventoryRow

/// One row from the `warehouse_inventory` table, optionally joined with `products`.
public struct WarehouseInventoryRow: Identifiable, Decodable, Hashable, Sendable {
    public var id: UUID
    public var warehouseId: UUID
    public var productId: UUID?
    public var quantity: Int
    public var product: Product?

    enum CodingKeys: String, CodingKey {
        case id          = "inventory_id"
        case warehouseId = "warehouse_id"
        case productId   = "product_id"
        case quantity
        case product     = "products"
    }
}
