import Foundation
import Combine

@MainActor
public final class TransfersViewModel: ObservableObject {
    // MARK: - Published state

    /// Purchase Orders — vendor_orders placed by IM to restock from vendors
    @Published public var vendorOrders: [VendorOrder] = []
    /// Pending boutique requests awaiting Accept/Reject decision
    @Published public var pendingRequests: [ProductRequest] = []
    /// Pick Lists — approved boutique requests ready to be physically picked & dispatched
    @Published public var pickLists: [ProductRequest] = []
    /// Shipments Out — shipments dispatched from this warehouse
    @Published public var shipmentsOut: [Shipment] = []
    /// Brand-scoped vendor list for PO creation
    @Published public var brandVendors: [Vendor] = []
    /// Brand-scoped products for PO creation
    @Published public var brandProducts: [Product] = []
    /// Cached warehouse stock qty per productId
    @Published public var stockAvailability: [UUID: Int] = [:]

    @Published public var lastGeneratedASN: String? = nil
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil

    public init() {}

    // MARK: - Load All

    public func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Parallel fetches
            async let pendingFetch  = RequestService.shared.fetchPendingRequests()
            async let pickFetch     = RequestService.shared.fetchApprovedPickLists()
            async let shipFetch     = RequestService.shared.fetchShipmentsForCurrentWarehouse()
            async let poFetch       = RequestService.shared.fetchVendorOrdersForCurrentWarehouse()
            async let vendorFetch   = RequestService.shared.fetchVendorsForCurrentInventoryManager()
            async let productFetch  = fetchBrandProducts()

            pendingRequests = try await pendingFetch
            pickLists       = try await pickFetch
            shipmentsOut    = try await shipFetch
            vendorOrders    = try await poFetch
            brandVendors    = try await vendorFetch
            brandProducts   = await productFetch
            errorMessage    = nil
        } catch {
            errorMessage = error.localizedDescription
            print("TransfersViewModel.loadData error: \(error)")
        }
    }

    private func fetchBrandProducts() async -> [Product] {
        do {
            return try await RequestService.shared.fetchProductsForCurrentInventoryManager()
        } catch {
            print("fetchBrandProducts error: \(error)")
            return []
        }
    }

    // MARK: - Stock Check

    /// Returns true if warehouse has enough stock to fulfil the requested quantity.
    public func checkWarehouseStock(for request: ProductRequest) async -> Bool {
        guard let productId = request.productId else { return false }
        do {
            let qty = try await RequestService.shared.warehouseStockForProduct(productId: productId)
            stockAvailability[productId] = qty
            return qty >= request.requestedQuantity
        } catch {
            print("Stock check error: \(error)")
            return false
        }
    }

    // MARK: - Accept Request (Step 1)

    /// Updates status to 'approved' — moves request to Pick Lists.
    public func acceptRequest(request: ProductRequest) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await RequestService.shared.updateRequestStatus(id: request.id, status: "approved")
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Ship with ASN (Step 2 — from Pick Lists)

    /// Creates the shipment with full ASN details. Returns the generated ASN number.
    @discardableResult
    public func shipRequest(
        request: ProductRequest,
        carrier: String,
        trackingNumber: String,
        estimatedDelivery: String,
        notes: String
    ) async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            let asn = try await RequestService.shared.createShipmentWithASN(
                requestId: request.id,
                storeId: request.storeId,
                carrier: carrier,
                trackingNumber: trackingNumber,
                estimatedDelivery: estimatedDelivery,
                notes: notes
            )
            // Mark request as shipped
            try await RequestService.shared.updateRequestStatus(id: request.id, status: "shipped")
            // Decrement warehouse stock
            if let productId = request.productId {
                try await decrementWarehouseStock(productId: productId, deductQuantity: request.requestedQuantity)
            }
            lastGeneratedASN = asn
            await loadData()
            return asn
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Reject Request

    public func rejectRequest(request: ProductRequest, reason: String = "Rejected by Inventory Manager") async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await RequestService.shared.updateRequestStatus(
                id: request.id,
                status: "rejected",
                rejectReason: reason
            )
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase Orders

    /// Creates a real PO in the vendor_orders table.
    public func createPurchaseOrder(vendorId: UUID, productId: UUID, quantity: Int, notes: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await RequestService.shared.createPurchaseOrder(
                vendorId: vendorId,
                productId: productId,
                quantity: quantity,
                notes: notes
            )
            await loadData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Marks a PO as received — stock will be added manually or via a separate flow.
    public func markPOReceived(order: VendorOrder) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await RequestService.shared.updateVendorOrderStatus(id: order.id, status: "received")
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func decrementWarehouseStock(productId: UUID, deductQuantity: Int) async throws {
        // Resolve the warehouse this IM manages
        let warehouseId = try await resolveWarehouseId()

        // Decrement via WarehouseService (handles upsert safely)
        try await WarehouseService.shared.decrementStock(
            warehouseId: warehouseId,
            productId: productId,
            by: deductQuantity
        )

        // Auto-reorder if stock after decrement is critically low
        let remaining = try await WarehouseService.shared.stockQuantity(
            warehouseId: warehouseId,
            productId: productId
        )
        if remaining < 5 {
            print("⚠️ Stock < 5 for product \(productId) — auto-creating vendor reorder")
            try await RequestService.shared.createVendorOrder(quantity: 20)
        }
    }

    private func resolveWarehouseId() async throws -> UUID {
        let userId = try await SupabaseManager.shared.client.auth.session.user.id
        struct Row: Decodable {
            let warehouseId: UUID
            enum CodingKeys: String, CodingKey { case warehouseId = "warehouse_id" }
        }
        let rows: [Row] = try await SupabaseManager.shared.client
            .from("inventory_managers")
            .select("warehouse_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let id = rows.first?.warehouseId else {
            throw NSError(domain: "TransfersViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No warehouse assigned to this inventory manager."])
        }
        return id
    }
}
