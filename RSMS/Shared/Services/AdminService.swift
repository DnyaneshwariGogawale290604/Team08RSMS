import Foundation
import Supabase
import PostgREST

public final class AdminService: @unchecked Sendable {
    public static let shared = AdminService()

    private let client = SupabaseManager.shared.client
    private let adminClient: SupabaseClient

    private init() {
        self.adminClient = SupabaseClient(
            supabaseURL: SupabaseConfiguration.projectURL,
            supabaseKey: SupabaseConfiguration.serviceRoleKey
        )
    }

    public func fetchBoutiqueManagers() async throws -> [BoutiqueManagerRecord] {
        let context = try await fetchCurrentCorporateAdminContext()
        return try await client
            .from("boutique_managers")
            .select("user_id, store_id, corporate_admin_id, created_at, users(*), stores(*)")
            .eq("corporate_admin_id", value: context.userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchInventoryManagers() async throws -> [InventoryManagerRecord] {
        let context = try await fetchCurrentCorporateAdminContext()
        return try await client
            .from("inventory_managers")
            .select("user_id, warehouse_id, corporate_admin_id, created_at, users(*), warehouses(*)")
            .eq("corporate_admin_id", value: context.userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchStores() async throws -> [Store] {
        let context = try await fetchCurrentCorporateAdminContext()
        return try await client
            .from("stores")
            .select()
            .eq("brand_id", value: context.brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchWarehouses() async throws -> [Warehouse] {
        let context = try await fetchCurrentCorporateAdminContext()
        return try await client
            .from("warehouses")
            .select()
            .eq("brand_id", value: context.brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchVendors() async throws -> [Vendor] {
        let context = try await fetchCurrentCorporateAdminContext()
        return try await client
            .from("vendors")
            .select()
            .eq("brand_id", value: context.brandId)
            .order("name", ascending: true)
            .execute()
            .value
    }

    public func fetchProductsForCurrentBrand() async throws -> [Product] {
        let context = try await fetchCurrentCorporateAdminContext()
        return try await client
            .from("products")
            .select()
            .eq("brand_id", value: context.brandId)
            .order("name", ascending: true)
            .execute()
            .value
    }

    public func fetchVendorProductIds(vendorId: UUID) async throws -> Set<UUID> {
        struct VendorProductRow: Decodable {
            let productId: UUID

            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
            }
        }

        let rows: [VendorProductRow] = try await client
            .from("vendor_products")
            .select("product_id")
            .eq("vendor_id", value: vendorId)
            .execute()
            .value

        return Set(rows.map(\.productId))
    }

    public func createVendor(name: String, contactInfo: String?, productIds: Set<UUID>) async throws {
        let context = try await fetchCurrentCorporateAdminContext()

        struct VendorInsert: Encodable {
            let name: String
            let contactInfo: String?
            let brandId: UUID

            enum CodingKeys: String, CodingKey {
                case name
                case contactInfo = "contact_info"
                case brandId = "brand_id"
            }
        }

        let created: [Vendor] = try await adminClient
            .from("vendors")
            .insert(
                VendorInsert(
                    name: name,
                    contactInfo: contactInfo,
                    brandId: context.brandId
                )
            )
            .select()
            .limit(1)
            .execute()
            .value

        guard let vendor = created.first else {
            throw StaffCreationError.vendorCreationFailed
        }

        try await syncVendorProducts(vendorId: vendor.id, selectedProductIds: productIds)
    }

    public func syncVendorProducts(vendorId: UUID, selectedProductIds: Set<UUID>) async throws {
        let existingIds = try await fetchVendorProductIds(vendorId: vendorId)
        let toAdd = selectedProductIds.subtracting(existingIds)
        let toRemove = existingIds.subtracting(selectedProductIds)

        if !toRemove.isEmpty {
            for productId in toRemove {
                try await adminClient
                    .from("vendor_products")
                    .delete()
                    .eq("vendor_id", value: vendorId)
                    .eq("product_id", value: productId)
                    .execute()
            }
        }

        if !toAdd.isEmpty {
            struct VendorProductInsert: Encodable {
                let vendorId: UUID
                let productId: UUID

                enum CodingKeys: String, CodingKey {
                    case vendorId = "vendor_id"
                    case productId = "product_id"
                }
            }

            let payload = toAdd.map { VendorProductInsert(vendorId: vendorId, productId: $0) }
            try await adminClient
                .from("vendor_products")
                .insert(payload)
                .execute()
        }
    }

    public func createStaffMember(_ request: StaffCreationRequest) async throws {
        let context = try await fetchCurrentCorporateAdminContext()
        try await validateAssignment(for: request, corporateAdminBrandId: context.brandId)

        let authUser = try await adminClient.auth.admin.createUser(
            attributes: AdminUserAttributes(
                email: request.email,
                emailConfirm: true,
                id: request.employeeId.uuidString,
                password: request.password,
                phone: request.phone,
                phoneConfirm: true,
                userMetadata: [
                    "name": .string(request.name),
                    "role": .string(request.role.rawValue)
                ]
            )
        )

        do {
            try await insertUserProfile(
                userId: request.employeeId,
                name: request.name,
                email: request.email,
                phone: request.phone,
                brandId: context.brandId
            )

            switch request.role {
            case .boutiqueManager:
                guard let storeId = request.storeId else {
                    throw StaffCreationError.missingAssignment("Store")
                }
                try await insertBoutiqueManager(
                    userId: request.employeeId,
                    storeId: storeId,
                    corporateAdminId: context.userId
                )

            case .inventoryManager:
                guard let warehouseId = request.warehouseId else {
                    throw StaffCreationError.missingAssignment("Warehouse")
                }
                try await insertInventoryManager(
                    userId: request.employeeId,
                    warehouseId: warehouseId,
                    corporateAdminId: context.userId
                )

            case .vendor:
                throw StaffCreationError.invalidStaffRoleForAuthCreation
            }
        } catch {
            try? await adminClient.auth.admin.deleteUser(id: authUser.id)
            throw error
        }
    }

    public func deleteStaffMember(userId: UUID, role: StaffRoleTab) async throws {
        // 1. Delete from role table
        let table = role == .boutiqueManager ? "boutique_managers" : "inventory_managers"
        try await adminClient
            .from(table)
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 2. Delete from users profile table
        try await adminClient
            .from("users")
            .delete()
            .eq("user_id", value: userId)
            .execute()

        // 3. Delete from Auth
        try await adminClient.auth.admin.deleteUser(id: userId)
    }

    public func deleteVendor(vendorId: UUID) async throws {
        // 1. Delete linked products
        try await adminClient
            .from("vendor_products")
            .delete()
            .eq("vendor_id", value: vendorId)
            .execute()

        // 2. Delete vendor
        try await adminClient
            .from("vendors")
            .delete()
            .eq("id", value: vendorId)
            .execute()
    }

    public func updateStaffMember(userId: UUID, name: String, email: String, phone: String) async throws {
        // 1. Update Auth
        try await adminClient.auth.admin.updateUserById(
            userId,
            attributes: AdminUserAttributes(
                email: email,
                phone: phone,
                userMetadata: ["name": .string(name)]
            )
        )

        // 2. Update users table
        struct UserUpdate: Encodable {
            let name: String
            let email: String
            let phone: String
        }

        try await adminClient
            .from("users")
            .update(UserUpdate(name: name, email: email, phone: phone))
            .eq("user_id", value: userId)
            .execute()
    }

    public func updateVendor(vendorId: UUID, name: String, contactInfo: String?) async throws {
        struct VendorUpdate: Encodable {
            let name: String
            let contactInfo: String?

            enum CodingKeys: String, CodingKey {
                case name
                case contactInfo = "contact_info"
            }
        }

        try await adminClient
            .from("vendors")
            .update(VendorUpdate(name: name, contactInfo: contactInfo))
            .eq("id", value: vendorId)
            .execute()
    }

    public func fetchCurrentCorporateAdminContext() async throws -> CorporateAdminContext {
        let currentUserId = try await client.auth.session.user.id

        let rows: [CorporateAdminContext] = try await client
            .from("corporate_admins")
            .select("user_id, brand_id")
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            throw StaffCreationError.missingCorporateAdmin
        }

        return row
    }

    /// Fetches gross sales (sum of all sales_orders.total_amount) and total target (sum of stores.sales_target)
    /// across all stores belonging to the admin's brand.
    public func fetchGrossSalesAndTarget() async throws -> (grossSales: Double, totalTarget: Double) {
        let context = try await fetchCurrentCorporateAdminContext()

        // 1. Fetch all store IDs and their sales_target for this brand
        struct StoreTargetRow: Decodable {
            let storeId: UUID
            let salesTarget: Double?

            enum CodingKeys: String, CodingKey {
                case storeId = "store_id"
                case salesTarget = "sales_target"
            }
        }

        let storeRows: [StoreTargetRow] = try await client
            .from("stores")
            .select("store_id, sales_target")
            .eq("brand_id", value: context.brandId)
            .execute()
            .value

        let totalTarget = storeRows.compactMap { $0.salesTarget }.reduce(0, +)
        let storeIds = storeRows.map { $0.storeId }

        guard !storeIds.isEmpty else {
            return (grossSales: 0, totalTarget: totalTarget)
        }

        // 2. Fetch all sales orders across those stores
        struct OrderAmountRow: Decodable {
            let totalAmount: Double?

            enum CodingKeys: String, CodingKey {
                case totalAmount = "total_amount"
            }
        }

        let orderRows: [OrderAmountRow] = try await client
            .from("sales_orders")
            .select("total_amount")
            .in("store_id", values: storeIds.map { $0.uuidString })
            .execute()
            .value

        let grossSales = orderRows.compactMap { $0.totalAmount }.reduce(0, +)

        return (grossSales: grossSales, totalTarget: totalTarget)
    }

    /// Fetches category-wise sales breakdown across all stores belonging to the admin's brand.
    /// Uses order_items joined with products (for category) and sales_orders (for store filtering).
    public func fetchCategoryWiseSales(for storeId: UUID? = nil) async throws -> [CategorySales] {
        let context = try await fetchCurrentCorporateAdminContext()

        // 1. Get store IDs for the brand
        let storeIds: [UUID]
        if let storeId = storeId {
            storeIds = [storeId]
        } else {
            struct StoreIdRow: Decodable {
                let storeId: UUID
                enum CodingKeys: String, CodingKey { case storeId = "store_id" }
            }
            let storeRows: [StoreIdRow] = try await client
                .from("stores")
                .select("store_id")
                .eq("brand_id", value: context.brandId)
                .execute()
                .value
            storeIds = storeRows.map { $0.storeId }
        }
        
        guard !storeIds.isEmpty else { return [] }

        // 2. Fetch order_items with product category, filtered by stores via sales_orders
        struct OrderItemWithCategory: Decodable {
            let quantity: Int?
            let priceAtPurchase: Double?
            let products: ProductCategoryRow?

            enum CodingKeys: String, CodingKey {
                case quantity
                case priceAtPurchase = "price_at_purchase"
                case products
            }
        }

        struct ProductCategoryRow: Decodable {
            let category: String?
        }

        // Get all order IDs for selected stores
        struct OrderIdRow: Decodable {
            let orderId: UUID
            enum CodingKeys: String, CodingKey { case orderId = "order_id" }
        }

        let orderIdRows: [OrderIdRow] = try await client
            .from("sales_orders")
            .select("order_id")
            .in("store_id", values: storeIds.map { $0.uuidString })
            .execute()
            .value

        let orderIds = orderIdRows.map { $0.orderId }
        guard !orderIds.isEmpty else { return [] }

        // Fetch order items with product category
        let items: [OrderItemWithCategory] = try await client
            .from("order_items")
            .select("quantity, price_at_purchase, products(category)")
            .in("order_id", values: orderIds.map { $0.uuidString })
            .execute()
            .value

        // 3. Aggregate by category
        var categoryMap: [String: Double] = [:]
        for item in items {
            let category = item.products?.category ?? "Uncategorized"
            let amount = (item.priceAtPurchase ?? 0) * Double(item.quantity ?? 1)
            categoryMap[category, default: 0] += amount
        }

        return categoryMap.map { CategorySales(category: $0.key, totalSales: $0.value) }
            .sorted { $0.totalSales > $1.totalSales }
    }

    public func fetchTopPerformingStores() async throws -> [StorePerformance] {
        _ = try await fetchCurrentCorporateAdminContext()
        
        // 1. Fetch all stores for this brand
        let stores = try await fetchStores()
        let storeIds = stores.map { $0.id }
        
        guard !storeIds.isEmpty else { return [] }
        
        // 2. Fetch sales for current month
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let formatter = ISO8601DateFormatter()
        let startOfMonthString = formatter.string(from: startOfMonth)
        
        struct OrderRow: Decodable {
            let storeId: UUID
            let totalAmount: Double?
            
            enum CodingKeys: String, CodingKey {
                case storeId = "store_id"
                case totalAmount = "total_amount"
            }
        }
        
        let orderRows: [OrderRow] = try await client
            .from("sales_orders")
            .select("store_id, total_amount")
            .in("store_id", values: storeIds.map { $0.uuidString })
            .gte("created_at", value: startOfMonthString)
            .execute()
            .value
            
        // 3. Aggregate
        var salesMap: [UUID: Double] = [:]
        for row in orderRows {
            salesMap[row.storeId, default: 0] += row.totalAmount ?? 0
        }
        
        return stores.map { store in
            StorePerformance(
                store: store,
                totalSales: salesMap[store.id] ?? 0,
                target: store.salesTarget ?? 0
            )
        }.sorted { $0.achievementPercentage > $1.achievementPercentage }
    }

    private func validateAssignment(for request: StaffCreationRequest, corporateAdminBrandId: UUID) async throws {
        switch request.role {
        case .boutiqueManager:
            guard let storeId = request.storeId else {
                throw StaffCreationError.missingAssignment("Store")
            }

            struct StoreBrandRow: Decodable {
                let brandId: UUID?

                enum CodingKeys: String, CodingKey {
                    case brandId = "brand_id"
                }
            }

            let rows: [StoreBrandRow] = try await client
                .from("stores")
                .select("brand_id")
                .eq("store_id", value: storeId)
                .limit(1)
                .execute()
                .value

            guard let brandId = rows.first?.brandId else {
                throw StaffCreationError.missingBrand("The selected store is not linked to a brand.")
            }

            guard brandId == corporateAdminBrandId else {
                throw StaffCreationError.storeBrandMismatch
            }

        case .inventoryManager:
            guard let warehouseId = request.warehouseId else {
                throw StaffCreationError.missingAssignment("Warehouse")
            }

            struct WarehouseBrandRow: Decodable {
                let brandId: UUID?

                enum CodingKeys: String, CodingKey {
                    case brandId = "brand_id"
                }
            }

            let rows: [WarehouseBrandRow] = try await client
                .from("warehouses")
                .select("brand_id")
                .eq("warehouse_id", value: warehouseId)
                .limit(1)
                .execute()
                .value

            guard let brandId = rows.first?.brandId else {
                throw StaffCreationError.missingBrand("The selected warehouse is not linked to a brand.")
            }

            guard brandId == corporateAdminBrandId else {
                throw StaffCreationError.warehouseBrandMismatch
            }

            struct WarehouseAssignmentRow: Decodable {
                let userId: UUID

                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                }
            }

            let assignedRows: [WarehouseAssignmentRow] = try await client
                .from("inventory_managers")
                .select("user_id")
                .eq("warehouse_id", value: warehouseId)
                .limit(1)
                .execute()
                .value

            if !assignedRows.isEmpty {
                throw StaffCreationError.warehouseAlreadyAssigned
            }

        case .vendor:
            return
        }
    }

    private func insertUserProfile(
        userId: UUID,
        name: String,
        email: String,
        phone: String,
        brandId: UUID
    ) async throws {
        struct UserInsert: Encodable {
            let userId: UUID
            let name: String
            let email: String
            let phone: String
            let brandId: UUID

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case name
                case email
                case phone
                case brandId = "brand_id"
            }
        }

        try await adminClient
            .from("users")
            .insert(UserInsert(userId: userId, name: name, email: email, phone: phone, brandId: brandId))
            .execute()
    }

    private func insertBoutiqueManager(userId: UUID, storeId: UUID, corporateAdminId: UUID) async throws {
        struct BoutiqueManagerInsert: Encodable {
            let userId: UUID
            let storeId: UUID
            let corporateAdminId: UUID

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case storeId = "store_id"
                case corporateAdminId = "corporate_admin_id"
            }
        }

        try await adminClient
            .from("boutique_managers")
            .insert(BoutiqueManagerInsert(userId: userId, storeId: storeId, corporateAdminId: corporateAdminId))
            .execute()
    }

    private func insertInventoryManager(userId: UUID, warehouseId: UUID, corporateAdminId: UUID) async throws {
        struct InventoryManagerInsert: Encodable {
            let userId: UUID
            let warehouseId: UUID
            let corporateAdminId: UUID

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case warehouseId = "warehouse_id"
                case corporateAdminId = "corporate_admin_id"
            }
        }

        try await adminClient
            .from("inventory_managers")
            .insert(InventoryManagerInsert(userId: userId, warehouseId: warehouseId, corporateAdminId: corporateAdminId))
            .execute()
    }

    public func fetchProductStocks() async throws -> [UUID: Int] {
        let stores = try await fetchStores()
        let storeIds = stores.map { $0.id }
        
        struct InventoryRow: Decodable {
            let productId: UUID
            let quantity: Int
            
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case quantity
            }
        }
        
        var stocks: [UUID: Int] = [:]
        
        if !storeIds.isEmpty {
            let storeInventories: [InventoryRow] = try await client
                .from("store_inventory")
                .select("product_id, quantity")
                .in("store_id", values: storeIds.map { $0.uuidString })
                .execute()
                .value
            
            for row in storeInventories {
                stocks[row.productId, default: 0] += row.quantity
            }
        }
        
        let warehouses = try await fetchWarehouses()
        let warehouseIds = warehouses.map { $0.id }
        
        if !warehouseIds.isEmpty {
            let warehouseInventories: [InventoryRow] = try await client
                .from("warehouse_inventory")
                .select("product_id, quantity")
                .in("warehouse_id", values: warehouseIds.map { $0.uuidString })
                .execute()
                .value
                
            for row in warehouseInventories {
                stocks[row.productId, default: 0] += row.quantity
            }
        }
        
        return stocks
    }
}

public struct CorporateAdminContext: Codable, Sendable {
    public let userId: UUID
    public let brandId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case brandId = "brand_id"
    }
}

public enum StaffCreationError: LocalizedError {
    case invalidEmployeeId
    case missingAssignment(String)
    case missingCorporateAdmin
    case missingBrand(String)
    case storeBrandMismatch
    case warehouseBrandMismatch
    case warehouseAlreadyAssigned
    case vendorCreationFailed
    case invalidStaffRoleForAuthCreation

    public var errorDescription: String? {
        switch self {
        case .invalidEmployeeId:
            return "Employee ID must be a valid UUID."
        case .missingAssignment(let label):
            return "\(label) is required."
        case .missingCorporateAdmin:
            return "No corporate admin record was found for the selected brand."
        case .missingBrand(let message):
            return message
        case .storeBrandMismatch:
            return "Selected store belongs to a different brand."
        case .warehouseBrandMismatch:
            return "Selected warehouse belongs to a different brand."
        case .warehouseAlreadyAssigned:
            return "This warehouse already has an inventory manager assigned."
        case .vendorCreationFailed:
            return "Unable to create vendor. Please try again."
        case .invalidStaffRoleForAuthCreation:
            return "Vendors are created in the Vendor segment, not as staff users."
        }
    }
}
