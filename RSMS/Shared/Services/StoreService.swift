import Foundation
import Supabase
import PostgREST

public final class StoreService: @unchecked Sendable {
    public static let shared = StoreService()
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    public func fetchStores() async throws -> [Store] {
        let brandId = try await fetchCurrentCorporateAdminBrandId()
        return try await client
            .from("stores")
            .select()
            .eq("brand_id", value: brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchStore(id: UUID) async throws -> Store {
        try await client
            .from("stores")
            .select()
            .eq("store_id", value: id)
            .single()
            .execute()
            .value
    }
    
    public func createStore(_ store: Store) async throws {
        let brandId = try await fetchCurrentCorporateAdminBrandId()

        struct StoreInsert: Encodable {
            let storeId: UUID
            let name: String
            let location: String
            let brandId: UUID
            let salesTarget: Double?
            let openingDate: String?
            let status: String?
            let address: String?

            enum CodingKeys: String, CodingKey {
                case storeId = "store_id"
                case name
                case location
                case brandId = "brand_id"
                case salesTarget = "sales_target"
                case openingDate = "opening_date"
                case status
                case address
            }
        }

        try await client
            .from("stores")
            .insert(
                StoreInsert(
                    storeId: store.id,
                    name: store.name,
                    location: store.location,
                    brandId: brandId,
                    salesTarget: store.salesTarget,
                    openingDate: store.openingDate,
                    status: store.status,
                    address: store.address
                )
            )
            .execute()
    }
    
    public func updateStoreTarget(id: UUID, target: Double) async throws {
        struct TargetUpdate: Encodable {
            let salesTarget: Double
            enum CodingKeys: String, CodingKey {
                case salesTarget = "sales_target"
            }
        }
        try await client
            .from("stores")
            .update(TargetUpdate(salesTarget: target))
            .eq("store_id", value: id)
            .execute()
    }

    public func deleteStore(id: UUID) async throws {
        try await client
            .from("stores")
            .delete()
            .eq("store_id", value: id)
            .execute()
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
            throw ServiceContextError.missingCorporateAdminContext
        }

        return brandId
    }

    public func fetchBoutiqueManagers(forStore storeId: UUID) async throws -> [BoutiqueManagerRecord] {
        try await client
            .from("boutique_managers")
            .select("user_id, store_id, corporate_admin_id, created_at, users(*)")
            .eq("store_id", value: storeId)
            .execute()
            .value
    }

    public func fetchSalesAssociates(forStore storeId: UUID) async throws -> [SalesAssociateRecord] {
        try await client
            .from("sales_associates")
            .select("user_id, store_id, boutique_manager_id, created_at, users(*)")
            .eq("store_id", value: storeId)
            .execute()
            .value
    }

    public func fetchStoreSalesPerformance(storeId: UUID) async throws -> Double {
        struct OrderRow: Decodable {
            let totalAmount: Double?
            enum CodingKeys: String, CodingKey {
                case totalAmount = "total_amount"
            }
        }

        let rows: [OrderRow] = try await client
            .from("sales_orders")
            .select("total_amount")
            .eq("store_id", value: storeId)
            .execute()
            .value

        return rows.compactMap { $0.totalAmount }.reduce(0, +)
    }
}

private enum ServiceContextError: LocalizedError {
    case missingCorporateAdminContext

    var errorDescription: String? {
        switch self {
        case .missingCorporateAdminContext:
            return "Only corporate admins can create stores and warehouses."
        }
    }
}
