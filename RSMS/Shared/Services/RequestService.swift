import Foundation
import Supabase
import PostgREST

public final class RequestService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = RequestService()
    nonisolated(unsafe) private let client = SupabaseManager.shared.client

    private init() {}

    // MARK: - Product Requests

    public func fetchAllRequests() async throws -> [ProductRequest] {
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Only approved requests not yet dispatched — shown as Pick Lists for IM to dispatch.
    public func fetchApprovedPickLists() async throws -> [ProductRequest] {
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .eq("status", value: "approved")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Pending requests awaiting IM Accept/Reject — warehouse-brand scoped.
    public func fetchPendingRequests() async throws -> [ProductRequest] {
        do {
            let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
            struct WarehouseBrand: Decodable {
                let brandId: UUID
                enum CodingKeys: String, CodingKey { case brandId = "brand_id" }
            }
            let rows: [WarehouseBrand] = try await client
                .from("warehouses")
                .select("brand_id")
                .eq("warehouse_id", value: warehouseId)
                .limit(1)
                .execute()
                .value
            if let brandId = rows.first?.brandId {
                return try await client
                    .from("product_requests")
                    .select("*, product:products(*), store:stores(*)")
                    .eq("brand_id", value: brandId)
                    .eq("status", value: "pending")
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }
        } catch {
            print("fetchPendingRequests brand resolve error: \(error) — falling back to all pending")
        }
        // Fallback: all pending requests
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches requests scoped to the warehouse managed by the current inventory manager.
    public func fetchRequestsForCurrentWarehouse() async throws -> [ProductRequest] {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        // Requests are brand-level, so we resolve brand_id via the warehouse
        struct WarehouseBrand: Decodable {
            let brandId: UUID
            enum CodingKeys: String, CodingKey { case brandId = "brand_id" }
        }
        let rows: [WarehouseBrand] = try await client
            .from("warehouses")
            .select("brand_id")
            .eq("warehouse_id", value: warehouseId)
            .limit(1)
            .execute()
            .value
        guard let brandId = rows.first?.brandId else {
            return try await fetchAllRequests()
        }
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .eq("brand_id", value: brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func updateRequestStatus(id: UUID, status: String, rejectReason: String? = nil) async throws {
        struct StatusUpdate: Encodable {
            let status: String
            let rejectReason: String?
            enum CodingKeys: String, CodingKey {
                case status
                case rejectReason = "rejection_reason"
            }
        }
        let payload = StatusUpdate(status: status, rejectReason: rejectReason)
        try await client
            .from("product_requests")
            .update(payload)
            .eq("request_id", value: id)
            .execute()
    }


    // MARK: - Shipments (ASN)

    public func fetchAllShipments() async throws -> [Shipment] {
        return try await client
            .from("shipments")
            .select("*, product_requests(*, products(*))")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches shipments dispatched FROM the current inventory manager's warehouse.
    public func fetchShipmentsForCurrentWarehouse() async throws -> [Shipment] {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        return try await client
            .from("shipments")
            .select("*, product_requests(*, products(*))")
            .eq("source_warehouse_id", value: warehouseId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches shipments destined TO the current boutique manager's store.
    public func fetchShipmentsForCurrentBoutiqueStore() async throws -> [Shipment] {
        let storeId = try await resolveCurrentBoutiqueManagerStoreId()
        return try await client
            .from("shipments")
            .select("*, product_requests(*, products(*))")
            .eq("destination_store_id", value: storeId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches all product requests for the current boutique store.
    public func fetchRequestsForCurrentBoutiqueStore() async throws -> [ProductRequest] {
        let storeId = try await resolveCurrentBoutiqueManagerStoreId()
        return try await client
            .from("product_requests")
            .select("*, product:products(*), store:stores(*)")
            .eq("store_id", value: storeId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Creates a shipment with full ASN details. Generates an ASN number automatically.
    public func createShipmentWithASN(
        requestId: UUID,
        storeId: UUID?,
        carrier: String,
        trackingNumber: String,
        estimatedDelivery: String,
        notes: String
    ) async throws -> String {
        let warehouseId = (try? await resolveCurrentInventoryManagerWarehouseId())
        let asnNumber = generateASNNumber()

        struct ShipmentInsert: Encodable {
            let requestId: UUID
            let sourceWarehouseId: UUID?
            let destinationStoreId: UUID?
            let status: String
            let asnNumber: String
            let carrier: String
            let trackingNumber: String
            let estimatedDelivery: String
            let notes: String

            enum CodingKeys: String, CodingKey {
                case requestId = "request_id"
                case sourceWarehouseId = "source_warehouse_id"
                case destinationStoreId = "destination_store_id"
                case status
                case asnNumber = "asn_number"
                case carrier
                case trackingNumber = "tracking_number"
                case estimatedDelivery = "estimated_delivery"
                case notes
            }
        }

        let payload = ShipmentInsert(
            requestId: requestId,
            sourceWarehouseId: warehouseId,
            destinationStoreId: storeId,
            status: "in_transit",
            asnNumber: asnNumber,
            carrier: carrier,
            trackingNumber: trackingNumber,
            estimatedDelivery: estimatedDelivery,
            notes: notes
        )

        try await client
            .from("shipments")
            .insert(payload)
            .execute()

        return asnNumber
    }

    // MARK: - Vendor Orders (Purchase Orders)

    /// Fetches all vendor orders with joined vendor and product data.
    public func fetchAllVendorOrders() async throws -> [VendorOrder] {
        return try await client
            .from("vendor_orders")
            .select("*, vendors(*), products(*)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches vendor orders scoped to the current warehouse's brand.
    public func fetchVendorOrdersForCurrentWarehouse() async throws -> [VendorOrder] {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        struct WarehouseBrand: Decodable {
            let brandId: UUID
            enum CodingKeys: String, CodingKey { case brandId = "brand_id" }
        }
        let rows: [WarehouseBrand] = try await client
            .from("warehouses")
            .select("brand_id")
            .eq("warehouse_id", value: warehouseId)
            .limit(1)
            .execute()
            .value
        guard let brandId = rows.first?.brandId else {
            return try await fetchAllVendorOrders()
        }
        // Vendor orders linked to vendors of the same brand
        return try await client
            .from("vendor_orders")
            .select("*, vendors!inner(*), products(*)")
            .eq("vendors.brand_id", value: brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Creates a real Purchase Order in the vendor_orders table.
    public func createPurchaseOrder(
        vendorId: UUID,
        productId: UUID,
        quantity: Int,
        notes: String
    ) async throws -> VendorOrder {
        struct POInsert: Encodable {
            let vendorId: UUID
            let productId: UUID
            let quantity: Int
            let status: String
            let notes: String
            enum CodingKeys: String, CodingKey {
                case vendorId = "vendor_id"
                case productId = "product_id"
                case quantity
                case status
                case notes
            }
        }
        let payload = POInsert(
            vendorId: vendorId,
            productId: productId,
            quantity: quantity,
            status: "in_transit",
            notes: notes
        )
        let result: VendorOrder = try await client
            .from("vendor_orders")
            .insert(payload)
            .select("*, vendors(*), products(*)")
            .single()
            .execute()
            .value
        return result
    }

    /// Updates a vendor order's status (e.g. pending → received).
    public func updateVendorOrderStatus(id: UUID, status: String) async throws {
        struct StatusUpdate: Encodable {
            let status: String
        }
        try await client
            .from("vendor_orders")
            .update(StatusUpdate(status: status))
            .eq("vendor_order_id", value: id)
            .execute()
    }

    /// Lightweight auto-reorder — used when warehouse stock falls below threshold.
    public func createVendorOrder(productId: UUID, vendorId: UUID, quantity: Int) async throws {
        struct VendorOrderInsert: Encodable {
            let productId: UUID
            let vendorId: UUID
            let quantity: Int
            let status: String
            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case vendorId = "vendor_id"
                case quantity
                case status
            }
        }
        try await client
            .from("vendor_orders")
            .insert(VendorOrderInsert(productId: productId, vendorId: vendorId, quantity: quantity, status: "pending"))
            .execute()
    }

    /// Fetches all pending vendor orders scoped to the corporate admin's brand.
    public func fetchPendingVendorOrdersForAdmin() async throws -> [VendorOrder] {
        let currentUserId = try await client.auth.session.user.id
        struct AdminBrand: Decodable {
            let brandId: UUID
            enum CodingKeys: String, CodingKey { case brandId = "brand_id" }
        }
        let rows: [AdminBrand] = try await client
            .from("corporate_admins")
            .select("brand_id")
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value
        
        guard let brandId = rows.first?.brandId else { return [] }

        return try await client
            .from("vendor_orders")
            .select("*, vendors!inner(*), products(*)")
            .eq("vendors.brand_id", value: brandId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Corporate Admin approves a pending vendor order.
    public func approveVendorOrder(id: UUID) async throws {
        try await updateVendorOrderStatus(id: id, status: "approved")
    }

    // MARK: - Vendors (brand-scoped for Inventory Manager)

    /// Fetches vendors scoped to the brand of the current inventory manager.
    public func fetchVendorsForCurrentInventoryManager() async throws -> [Vendor] {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        struct WarehouseBrand: Decodable {
            let brandId: UUID
            enum CodingKeys: String, CodingKey { case brandId = "brand_id" }
        }
        let rows: [WarehouseBrand] = try await client
            .from("warehouses")
            .select("brand_id")
            .eq("warehouse_id", value: warehouseId)
            .limit(1)
            .execute()
            .value
        guard let brandId = rows.first?.brandId else { return [] }

        return try await client
            .from("vendors")
            .select()
            .eq("brand_id", value: brandId)
            .order("name", ascending: true)
            .execute()
            .value
    }

    /// Fetches products scoped to the brand of the current inventory manager.
    public func fetchProductsForCurrentInventoryManager() async throws -> [Product] {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        struct WarehouseBrand: Decodable {
            let brandId: UUID
            enum CodingKeys: String, CodingKey { case brandId = "brand_id" }
        }
        let rows: [WarehouseBrand] = try await client
            .from("warehouses")
            .select("brand_id")
            .eq("warehouse_id", value: warehouseId)
            .limit(1)
            .execute()
            .value
        guard let brandId = rows.first?.brandId else { return [] }

        return try await client
            .from("products")
            .select()
            .eq("brand_id", value: brandId)
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    // MARK: - GRN (Goods Received Notes)

    public func createGRN(
        shipmentId: UUID,
        requestId: UUID?,
        quantityReceived: Int,
        condition: GoodsReceivedNote.GRNCondition,
        notes: String
    ) async throws -> String {
        let currentUserId = try await client.auth.session.user.id
        let grnNumber = generateGRNNumber()

        struct GRNInsert: Encodable {
            let shipmentId: UUID
            let requestId: UUID?
            let receivedBy: UUID
            let quantityReceived: Int
            let condition: String
            let notes: String
            let grnNumber: String

            enum CodingKeys: String, CodingKey {
                case shipmentId = "shipment_id"
                case requestId = "request_id"
                case receivedBy = "received_by"
                case quantityReceived = "quantity_received"
                case condition
                case notes
                case grnNumber = "grn_number"
            }
        }

        let payload = GRNInsert(
            shipmentId: shipmentId,
            requestId: requestId,
            receivedBy: currentUserId,
            quantityReceived: quantityReceived,
            condition: condition.rawValue,
            notes: notes,
            grnNumber: grnNumber
        )

        try await client
            .from("goods_received_notes")
            .insert(payload)
            .execute()

        // Mark the shipment as delivered
        struct ShipmentStatusUpdate: Encodable {
            let status: String
            let hasGRN: Bool
            enum CodingKeys: String, CodingKey {
                case status
                case hasGRN = "has_grn"
            }
        }
        try await client
            .from("shipments")
            .update(ShipmentStatusUpdate(status: "delivered", hasGRN: true))
            .eq("shipment_id", value: shipmentId)
            .execute()

        return grnNumber
    }

    public func fetchGRNsForCurrentBoutiqueStore() async throws -> [GoodsReceivedNote] {
        let storeId = try await resolveCurrentBoutiqueManagerStoreId()
        // GRNs are linked to shipments; fetch shipments for this store first
        struct ShipmentIdRow: Decodable {
            let id: UUID
            enum CodingKeys: String, CodingKey { case id = "shipment_id" }
        }
        let shipmentRows: [ShipmentIdRow] = try await client
            .from("shipments")
            .select("shipment_id")
            .eq("destination_store_id", value: storeId)
            .execute()
            .value
        let shipmentIds = shipmentRows.map { $0.id }
        guard !shipmentIds.isEmpty else { return [] }

        return try await client
            .from("goods_received_notes")
            .select()
            .in("shipment_id", values: shipmentIds.map { $0.uuidString })
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    public func fetchGRNsForCurrentWarehouse() async throws -> [GoodsReceivedNote] {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        struct ShipmentIdRow: Decodable {
            let id: UUID
            enum CodingKeys: String, CodingKey { case id = "shipment_id" }
        }
        let shipmentRows: [ShipmentIdRow] = try await client
            .from("shipments")
            .select("shipment_id")
            .eq("source_warehouse_id", value: warehouseId)
            .execute()
            .value
        let shipmentIds = shipmentRows.map { $0.id }
        guard !shipmentIds.isEmpty else { return [] }

        return try await client
            .from("goods_received_notes")
            .select()
            .in("shipment_id", values: shipmentIds.map { $0.uuidString })
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Warehouse Stock Check

    /// Returns the current warehouse stock qty for a given product.
    /// Used by IM to verify availability before accepting / dispatching a request.
    public func warehouseStockForProduct(productId: UUID) async throws -> Int {
        let warehouseId = try await resolveCurrentInventoryManagerWarehouseId()
        return try await WarehouseService.shared.stockQuantity(
            warehouseId: warehouseId,
            productId: productId
        )
    }

    // MARK: - Private Helpers

    private func resolveCurrentInventoryManagerWarehouseId() async throws -> UUID {
        let currentUserId = try await client.auth.session.user.id
        struct WarehouseRow: Decodable {
            let warehouseId: UUID
            enum CodingKeys: String, CodingKey { case warehouseId = "warehouse_id" }
        }
        let rows: [WarehouseRow] = try await client
            .from("inventory_managers")
            .select("warehouse_id")
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value
        guard let warehouseId = rows.first?.warehouseId else {
            throw RequestServiceError.noWarehouseAssigned
        }
        return warehouseId
    }

    private func resolveCurrentBoutiqueManagerStoreId() async throws -> UUID {
        let currentUserId = try await client.auth.session.user.id
        struct StoreRow: Decodable {
            let storeId: UUID
            enum CodingKeys: String, CodingKey { case storeId = "store_id" }
        }
        let rows: [StoreRow] = try await client
            .from("boutique_managers")
            .select("store_id")
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value
        guard let storeId = rows.first?.storeId else {
            throw RequestServiceError.noStoreAssigned
        }
        return storeId
    }

    private func generateASNNumber() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 100...999)
        return "ASN-\(timestamp)-\(random)"
    }

    private func generateGRNNumber() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 100...999)
        return "GRN-\(timestamp)-\(random)"
    }
}

public enum RequestServiceError: LocalizedError {
    case noWarehouseAssigned
    case noStoreAssigned

    public var errorDescription: String? {
        switch self {
        case .noWarehouseAssigned:
            return "No warehouse is assigned to the current inventory manager."
        case .noStoreAssigned:
            return "No store is assigned to the current boutique manager."
        }
    }
}
