import Foundation
import Supabase
import PostgREST

public actor DataService {
    public static let shared = DataService()
    private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Stores
    public func fetchStores() async throws -> [Store] {
        return try await client
            .from("stores")
            .select()
            .execute()
            .value
    }

    public func fetchCurrentStore() async throws -> Store? {
        guard let userId = try? await client.auth.session.user.id else {
            return nil
        }
        struct ManagerStoreRow: Decodable { let store_id: UUID }
        let rows: [ManagerStoreRow]? = try? await client
            .from("boutique_managers")
            .select("store_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
            
        if let storeId = rows?.first?.store_id {
            let stores: [Store] = try await client
                .from("stores")
                .select()
                .eq("store_id", value: storeId.uuidString)
                .execute()
                .value
            return stores.first
        }
        return nil
    }

    public func updateStore(store: Store) async throws {
        try await client
            .from("stores")
            .update(store)
            .eq("store_id", value: store.id.uuidString)
            .execute()
    }

    // MARK: - Staff (sales_associates + users table)
    public func fetchStaff() async throws -> [User] {
        guard let userId = try? await client.auth.session.user.id else { return [] }
        struct ManagerStoreRow: Decodable { let store_id: UUID }
        let managerRows: [ManagerStoreRow] = try await client
            .from("boutique_managers")
            .select("store_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let storeId = managerRows.first?.store_id else { return [] }

        struct SalesAssociateRecord: Decodable {
            let user_id: UUID
        }
        let sas: [SalesAssociateRecord] = try await client
            .from("sales_associates")
            .select("user_id")
            .eq("store_id", value: storeId.uuidString)
            .execute()
            .value
            
        let saIds = sas.map { $0.user_id }
        guard !saIds.isEmpty else { return [] }
        
        // Efficiently fetch only the users belonging to this store
        let users: [User] = try await client
            .from("users")
            .select()
            .in("user_id", values: saIds.map { $0.uuidString })
            .execute()
            .value
            
        // Fetch rating and sales metrics from sales_orders
        struct OrderMetric: Decodable {
            let sales_associate_id: UUID?
            let rating_value: Int?
            let total_amount: Double
        }
        
        let orderMetrics: [OrderMetric] = try await client
            .from("sales_orders")
            .select("sales_associate_id, rating_value, total_amount")
            .eq("store_id", value: storeId.uuidString)
            .execute()
            .value
            
        var ratingStats: [UUID: (sum: Int, count: Int)] = [:]
        var salesStats: [UUID: Double] = [:]

        for r in orderMetrics {
            if let saId = r.sales_associate_id {
                if let val = r.rating_value, val >= 1 {
                    let current = ratingStats[saId] ?? (0, 0)
                    ratingStats[saId] = (current.sum + val, current.count + 1)
                }
                salesStats[saId, default: 0] += r.total_amount
            }
        }
            
        return users.map {
            var u = $0
            u.role = .sales
            if let stats = ratingStats[u.id] {
                u.averageRating = Double(stats.sum) / Double(stats.count)
                u.ratingCount = stats.count
            }
            u.totalSales = salesStats[u.id] ?? 0.0
            return u
        }
    }

    public func addStaff(user: User) async throws {
        // Insert only columns that exist in the users table (no role column)
        struct UserInsert: Encodable {
            let user_id: String
            let name: String
            let email: String
            let phone: String?
        }
        let payload = UserInsert(
            user_id: user.id.uuidString,
            name: user.name ?? "",
            email: user.email ?? "",
            phone: user.phone
        )
        try await client
            .from("users")
            .insert(payload)
            .execute()
    }

    public func updateStaff(user: User) async throws {
        struct UserUpdate: Encodable {
            let name: String
            let email: String
            let phone: String?
        }
        let payload = UserUpdate(name: user.name ?? "", email: user.email ?? "", phone: user.phone)
        try await client
            .from("users")
            .update(payload)
            .eq("user_id", value: user.id.uuidString)
            .execute()
    }

    public func deleteStaff(id: UUID) async throws {
        // Delete from sales_associates first to resolve foreign key constraints
        try? await client
            .from("sales_associates")
            .delete()
            .eq("user_id", value: id.uuidString)
            .execute()
            
        try await client
            .from("users")
            .delete()
            .eq("user_id", value: id.uuidString)
            .execute()
    }

    // MARK: - Appointments
    public func fetchAppointments(salesAssociateId: UUID) async throws -> [Appointment] {
        return try await client
            .from("appointments")
            .select("*, customers(*), appointment_products(*, products(*))")
            .eq("sales_associate_id", value: salesAssociateId.uuidString)
            .order("appointment_at", ascending: true)
            .execute()
            .value
    }

    public func fetchTodayAppointmentsForStore(storeId: UUID) async throws -> [Appointment] {
        // Fetch all appointments for the store, then filter for today.
        // (Supabase date filtering can be tricky with timezones, so we filter in Swift for simplicity)
        let allAppointments: [Appointment] = try await client
            .from("appointments")
            .select("*, customers(*), appointment_products(*, products(*))")
            .eq("store_id", value: storeId.uuidString)
            .order("appointment_at", ascending: true)
            .execute()
            .value
        
        let today = Calendar.current
        return allAppointments.filter { appt in
            if let date = appt.appointmentDate {
                return today.isDateInToday(date)
            }
            return false
        }
    }

    // MARK: - Boutique Managers count
    public func fetchBoutiqueManagers() async throws -> [BoutiqueManagerRecord] {
        return try await client
            .from("boutique_managers")
            .select()
            .execute()
            .value
    }

    // MARK: - Products (Catalog)
    private static let productColumns = "product_id,name,brand_id,category,price,sku,making_price,image_url,is_active,size_options,tax,total_price"

    public func fetchProducts() async throws -> [Product] {
        return try await client
            .from("products")
            .select(DataService.productColumns)
            .eq("is_active", value: true)
            .execute()
            .value
    }

    public func fetchProductsForCurrentBrand() async throws -> [Product] {
        let brandId = try await resolveCurrentUserBrandIdOrThrow()
        print("[DataService] fetchProductsForCurrentBrand — brandId: \(brandId)")

        let result: [Product] = try await client
            .from("products")
            .select(DataService.productColumns)
            .eq("brand_id", value: brandId)
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .execute()
            .value
        print("[DataService] fetchProductsForCurrentBrand — fetched \(result.count) products")
        return result
    }

    /// Fetches ALL products for the brand regardless of is_active — used by Catalog tab.
    public func fetchAllProductsForCurrentBrand() async throws -> [Product] {
        let brandId = try await resolveCurrentUserBrandIdOrThrow()
        print("[DataService] fetchAllProductsForCurrentBrand — brandId: \(brandId)")

        let result: [Product] = try await client
            .from("products")
            .select(DataService.productColumns)
            .eq("brand_id", value: brandId)
            .order("name", ascending: true)
            .execute()
            .value
        print("[DataService] fetchAllProductsForCurrentBrand — fetched \(result.count) products")
        return result
    }

    // MARK: - Store Inventory
    private static let inventoryColumns = "inventory_id,store_id,product_id,quantity"

    public func fetchInventory(storeId: UUID? = nil) async throws -> [StoreInventory] {
        var query = client.from("store_inventory").select(DataService.inventoryColumns)
        if let storeId = storeId {
            query = query.eq("store_id", value: storeId.uuidString)
        }
        let result: [StoreInventory] = try await query.execute().value
        print("[DataService] fetchInventory — storeId: \(storeId?.uuidString ?? "all"), rows: \(result.count)")
        return result
    }

    // MARK: - Store Inventory Baseline
    public struct StoreInventoryBaseline: Identifiable, Codable, Hashable, Sendable {
        public var id: UUID
        public var storeId: UUID?
        public var productId: UUID?
        public var baselineQuantity: Int
        public var currentQuantity: Int?

        enum CodingKeys: String, CodingKey {
            case id = "baseline_id"
            case storeId = "store_id"
            case productId = "product_id"
            case baselineQuantity = "baseline_quantity"
            case currentQuantity = "current_quantity"
        }
    }

    public func fetchInventoryBaselineForCurrentStore() async throws -> [StoreInventoryBaseline] {
        guard let userId = try? await client.auth.session.user.id else {
            return []
        }

        struct ManagerStoreRow: Decodable { let store_id: UUID }
        let rows: [ManagerStoreRow]? = try? await client
            .from("boutique_managers")
            .select("store_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        if let storeId = rows?.first?.store_id {
            let baselines: [StoreInventoryBaseline] = try await client
                .from("store_inventory_baseline")
                .select()
                .eq("store_id", value: storeId.uuidString)
                .execute()
                .value
            return baselines
        } else {
            return []
        }
    }

    /// Fetches inventory rows scoped to the current boutique manager's store.
    /// Falls back to all-store rows if the manager record can't be found (e.g. RLS).
    public func fetchInventoryForCurrentStore() async throws -> [StoreInventory] {
        guard let userId = try? await client.auth.session.user.id else {
            return try await fetchInventory()
        }

        struct ManagerStoreRow: Decodable { let store_id: UUID }

        // Use try? so RLS errors silently produce nil instead of throwing
        let rows: [ManagerStoreRow]? = try? await client
            .from("boutique_managers")
            .select("store_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        if let storeId = rows?.first?.store_id {
            print("[DataService] fetchInventoryForCurrentStore — storeId: \(storeId)")
            return try await fetchInventory(storeId: storeId)
        } else {
            print("[DataService] fetchInventoryForCurrentStore — no store found, returning all")
            return try await fetchInventory()
        }
    }

    // MARK: - Staff Ratings
    public func fetchStaffRatings(salesAssociateId: UUID) async throws -> [AssociateRating] {
        struct RatingRow: Decodable {
            let order_id: UUID
            let sales_associate_id: UUID?
            let rating_value: Int?
            let rating_feedback: String?
            let created_at: String?
        }
        let rows: [RatingRow] = try await client
            .from("sales_orders")
            .select("order_id,sales_associate_id,rating_value,rating_feedback,created_at")
            .eq("sales_associate_id", value: salesAssociateId)
            .gte("rating_value", value: 1)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { row in
            guard let ratingVal = row.rating_value else { return nil }
            return AssociateRating(
                id: row.order_id,
                salesAssociateId: row.sales_associate_id ?? salesAssociateId,
                ratingValue: Double(ratingVal),
                feedbackText: row.rating_feedback,
                createdAt: row.created_at
            )
        }
    }

    public func updateInventory(productId: UUID, newQuantity: Int) async throws {
        let store = try await fetchCurrentStore()
        guard let storeId = store?.id else { return }
        
        try await client
            .from("store_inventory_baseline")
            .update(["current_quantity": newQuantity])
            .eq("store_id", value: storeId.uuidString)
            .eq("product_id", value: productId.uuidString)
            .execute()
    }
    
    public func createInventoryItem(productId: UUID, quantity: Int) async throws {
        let stores = try await fetchStores()
        guard let mainStore = stores.first else {
            throw NSError(domain: "DataService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No stores found to add inventory to."])
        }
        
        struct InventoryInsert: Encodable {
            let product_id: UUID
            let store_id: UUID
            let quantity: Int
        }
        
        let payload = InventoryInsert(product_id: productId, store_id: mainStore.id, quantity: quantity)
        try await client.from("store_inventory").insert(payload).execute()
    }
    
    // MARK: - Individual Inventory Items (RFID/Serial)
    public func fetchInventoryItems() async throws -> [InventoryItem] {
        do {
            // Read from the VIEW which nests the active repair ticket as JSON
            let result: [InventoryItem] = try await client
                .from("inventory_items_with_ticket")
                .select()
                .execute()
                .value

            if result.isEmpty {
                return try await generateMockInventoryItems()
            }
            
            return result
        } catch {
            print("Supabase: inventory_items_with_ticket fetch failed, using mock. \(error)")
            return try await generateMockInventoryItems()
        }
    }
    
    /// Called on first launch when inventory_items table is empty.
    /// Seeds one item per product directly into Supabase.
    private func generateMockInventoryItems() async throws -> [InventoryItem] {
        let products = try await fetchProducts()
        var items: [InventoryItem] = []
        for (index, product) in products.enumerated() {
            let item = InventoryItem(
                id: "RFID-\(String(format: "%04d", index + 1))",
                serialId: "SN-\(Int.random(in: 10000...99999))",
                productId: product.id,
                batchNo: "B-\(Calendar.current.component(.year, from: Date()))",
                productName: product.name,
                category: product.category.isEmpty ? "General" : product.category,
                location: "Warehouse",
                status: .available
            )
            items.append(item)
            // Persist to Supabase so next launch reads real data
            try? await insertInventoryItem(item: item)
        }
        return items
    }
    
    public func updateInventoryItem(item: InventoryItem) async throws {
        // 1. Update only the status column (view columns are read-only)
        struct ItemStatusUpdate: Encodable { let status: String }
        try? await client
            .from("inventory_items")
            .update(ItemStatusUpdate(status: item.status.rawValue))
            .eq("id", value: item.id)
            .execute()

        // 2. Upsert the active ticket if one exists
        if let ticket = item.activeTicket {
            struct TicketUpsert: Encodable {
                let id: String; let item_id: String; let issue_type: String
                let description: String; let status: String; let assigned_to: String?
                let eta: String?; let created_at: String; let updated_at: String
            }
            let iso = ISO8601DateFormatter()
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            try? await client.from("repair_tickets").upsert(
                TicketUpsert(
                    id: ticket.id.uuidString, item_id: ticket.itemId,
                    issue_type: ticket.issueType, description: ticket.description,
                    status: ticket.status.rawValue, assigned_to: ticket.assignedTo,
                    eta: ticket.eta.map { df.string(from: $0) },
                    created_at: iso.string(from: ticket.createdAt),
                    updated_at: iso.string(from: ticket.updatedAt)
                )
            ).execute()
        }
    }
    
    public func insertInventoryItem(item: InventoryItem) async throws {
        struct ItemInsert: Encodable {
            let id: String; let serial_id: String; let product_id: String
            let batch_no: String; let certificate_id: String?
            let product_name: String; let category: String
            let location: String; let status: String
        }
        try? await client.from("inventory_items").insert(
            ItemInsert(
                id: item.id, serial_id: item.serialId,
                product_id: item.productId.uuidString, batch_no: item.batchNo,
                certificate_id: item.certificateId, product_name: item.productName,
                category: item.category, location: item.location,
                status: item.status.rawValue
            )
        ).execute()
    }

    /// Called when a repair ticket reaches a terminal state (Completed or Scrapped).
    /// Updates the ticket's status in repair_tickets and the item's status in inventory_items.
    public func finalizeRepairTicket(ticketId: UUID, newStatus: RepairStatus, itemId: String, itemStatus: ItemStatus) async throws {
        // 1. Update the ticket row to the final status
        struct TicketStatusUpdate: Encodable {
            let status: String
            let updated_at: String
        }
        let iso = ISO8601DateFormatter()
        try? await client
            .from("repair_tickets")
            .update(TicketStatusUpdate(status: newStatus.rawValue, updated_at: iso.string(from: Date())))
            .eq("id", value: ticketId.uuidString)
            .execute()

        // 2. Update the item's status
        struct ItemStatusUpdate: Encodable { let status: String }
        try? await client
            .from("inventory_items")
            .update(ItemStatusUpdate(status: itemStatus.rawValue))
            .eq("id", value: itemId)
            .execute()
    }
    
    // MARK: - Repairs
    public func insertRepairTicket(ticket: RepairTicket) async throws {
        try await client
            .from("repair_tickets")
            .insert(ticket)
            .execute()
    }
    
    public func updateRepairTicket(ticket: RepairTicket) async throws {
        try await client
            .from("repair_tickets")
            .update(ticket)
            .eq("id", value: ticket.id)
            .execute()
    }

    // MARK: - Sales Orders
    public func fetchSales(storeId: UUID? = nil) async throws -> [SalesOrder] {
        var query = client.from("sales_orders").select()
        if let storeId = storeId {
            query = query.eq("store_id", value: storeId.uuidString)
        }
        return try await query
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Stock Requests (Notify Inventory Manager)
    public func createStockRequest(productId: UUID, quantity: Int) async throws {
        let session = try await client.auth.session
        let currentUserId = session.user.id
        
        let allManagers: [BoutiqueManagerRecord] = try await client.from("boutique_managers")
            .select().eq("user_id", value: currentUserId.uuidString).execute().value
        
        let actualStoreId: String
        let actualManagerId: String
        if let record = allManagers.first {
            actualStoreId = record.storeId.uuidString
            actualManagerId = record.id.uuidString
        } else {
            let fallbackManagers: [BoutiqueManagerRecord] = try await client.from("boutique_managers").select().limit(1).execute().value
            guard let fallback = fallbackManagers.first else {
                throw NSError(domain: "DataService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No boutique managers configured."])
            }
            actualStoreId = fallback.storeId.uuidString
            actualManagerId = fallback.id.uuidString
        }

        struct StockRequestInsert: Encodable {
            let product_id: String
            let store_id: String
            let requested_by: String
            let quantity: Int
            let status: String
            let brand_id: String?
        }
        
        let brandId = try? await resolveCurrentUserBrandIdOrThrow()
        
        let payload = StockRequestInsert(
            product_id: productId.uuidString,
            store_id: actualStoreId,
            requested_by: actualManagerId,
            quantity: quantity,
            status: "pending",
            brand_id: brandId?.uuidString
        )
        try await client
            .from("product_requests")
            .insert(payload)
            .execute()
    }

    public struct ProductRequestRow: Decodable, Sendable {
        public let requestId: UUID
        public let productId: UUID?
        public let storeId: UUID?
        public let requestedBy: UUID?
        public let quantity: Int?
        public let status: String?
        public let rejectionReason: String?

        enum CodingKeys: String, CodingKey {
            case requestId = "request_id"
            case productId = "product_id"
            case storeId = "store_id"
            case requestedBy = "requested_by"
            case quantity
            case status
            case rejectionReason = "rejection_reason"
        }
    }

    public func fetchProductRequestsForCurrentStore() async throws -> [ProductRequestRow] {
        let store = try await fetchCurrentStore()
        guard let storeId = store?.id else { return [] }

        return try await client
            .from("product_requests")
            .select()
            .eq("store_id", value: storeId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private func resolveCurrentUserBrandIdOrThrow() async throws -> UUID {
        struct UserBrandRow: Decodable {
            let brandId: UUID?

            enum CodingKeys: String, CodingKey {
                case brandId = "brand_id"
            }
        }

        let userId = try await client.auth.session.user.id

        let rows: [UserBrandRow] = try await client
            .from("users")
            .select("brand_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        guard let brandId = rows.first?.brandId else {
            throw DataServiceError.missingCurrentUserBrand
        }

        return brandId
    }
}

private enum DataServiceError: LocalizedError {
    case missingCurrentUserBrand

    var errorDescription: String? {
        switch self {
        case .missingCurrentUserBrand:
            return "Current user is not linked to a brand."
        }
    }
}
