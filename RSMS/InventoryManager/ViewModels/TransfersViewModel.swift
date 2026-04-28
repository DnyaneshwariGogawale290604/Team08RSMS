import Foundation
import Combine
import SwiftUI
import Supabase
import PostgREST
import Auth

extension Notification.Name {
    static let inventoryManagerDataDidChange = Notification.Name("InventoryManagerDataDidChange")
}

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
            let allPickLists = try await pickFetch
            let allShipments = try await shipFetch
            
            let shippedRequestIds = Set(allShipments.map { $0.requestId })
            pickLists       = allPickLists.filter { !shippedRequestIds.contains($0.id) }
            shipmentsOut    = allShipments
            vendorOrders    = try await poFetch
            brandVendors    = try await vendorFetch
            brandProducts   = await productFetch
            stockAvailability = [:]
            errorMessage    = nil
        } catch is CancellationError {
            // SwiftUI can cancel the in-flight refresh when the tab lifecycle
            // changes. Preserve the last successful data instead of surfacing
            // a transient error alert.
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
            NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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
            lastGeneratedASN = asn
            // Decrement warehouse stock (non-fatal — RLS may block this in dev)
            if let productId = request.productId {
                do {
                    try await decrementWarehouseStock(productId: productId, deductQuantity: request.requestedQuantity)
                } catch {
                    print("⚠️ Stock decrement skipped (RLS or network): \(error.localizedDescription)")
                }
            }
            await loadData()
            NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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
            NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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
            NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func receiveVendorOrder(
        order: VendorOrder,
        quantityReceived: Int,
        condition: GoodsReceivedNote.GRNCondition,
        notes: String
    ) async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            let grn = try await RequestService.shared.createVendorGRN(
                vendorOrderId: order.id,
                quantityReceived: quantityReceived,
                condition: condition,
                notes: notes
            )

            try await registerReceivedVendorItems(
                for: order,
                quantityReceived: quantityReceived,
                grnNumber: grn
            )
            
            await loadData()
            NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
            return grn
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Private Helpers

    private func registerReceivedVendorItems(
        for order: VendorOrder,
        quantityReceived: Int,
        grnNumber: String
    ) async throws {
        guard quantityReceived > 0 else { return }

        guard let productId = order.product?.id ?? order.productId else {
            throw NSError(
                domain: "TransfersViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Product not found on this vendor order."]
            )
        }

        let warehouseId = try await resolveWarehouseId()
        let batchId = try await DataService.shared.ensureBatchForVendorOrder(
            vendorOrderId: order.id,
            productId: productId,
            quantity: quantityReceived,
            warehouseId: warehouseId
        )

        let batchToken = String(batchId.uuidString.prefix(8)).uppercased()
        let grnToken = grnNumber.replacingOccurrences(of: "GRN-", with: "").uppercased()
        let batchNumber = "BATCH-\(batchToken)"
        let productName = order.product?.name ?? "Unknown Product"
        let category = {
            let raw = order.product?.category ?? ""
            return raw.isEmpty ? "General" : raw
        }()

        var insertedCount = 0

        for index in 0..<quantityReceived {
            let sequence = String(format: "%03d", index + 1)
            let item = InventoryItem(
                id: "RFID-\(batchToken)-\(sequence)",
                serialId: "SN-\(grnToken)-\(sequence)",
                productId: productId,
                batchNo: batchNumber,
                certificateId: nil,
                productName: productName,
                category: category,
                location: "Warehouse",
                status: .available
            )

            try await DataService.shared.insertInventoryItem(item: item)
            insertedCount += 1
        }

        if insertedCount > 0 {
            try await WarehouseService.shared.incrementStock(
                warehouseId: warehouseId,
                productId: productId,
                by: insertedCount
            )
        }
    }

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
        
        // Use dynamic Reorder Point (ROP) and Reorder Quantity (ROQ)
        if let product = brandProducts.first(where: { $0.id == productId }) {
            let rop = product.reorderPoint ?? 5
            let roq = product.reorderQuantity ?? 20
            
            if remaining <= rop {
                print("⚠️ Stock \(remaining) <= ROP \(rop) for product \(productId) — auto-creating vendor reorder")
                // Pick the first vendor available for this brand
                if let vendorId = brandVendors.first?.id {
                    try await RequestService.shared.createVendorOrder(productId: productId, vendorId: vendorId, quantity: roq)
                } else {
                    print("❌ No vendor available to place auto-reorder")
                }
            }
        }
    }

    public func resolveWarehouseId() async throws -> UUID {
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
