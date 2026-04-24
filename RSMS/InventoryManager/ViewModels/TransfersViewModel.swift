import Foundation
import Combine

@MainActor
public final class TransfersViewModel: ObservableObject {
    @Published public var vendorOrders: [VendorOrder] = []
    @Published public var pickLists: [ProductRequest] = []       // All requests (pending + approved)
    @Published public var shipmentsOut: [Shipment] = []           // Warehouse-scoped shipments
    @Published public var brandVendors: [Vendor] = []             // Brand-scoped vendor list
    @Published public var stockAvailability: [UUID: Int] = [:]    // productId → warehouse qty
    @Published public var lastGeneratedASN: String? = nil
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil

    public init() {}

    // MARK: - Load

    public func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let requestsFetch = RequestService.shared.fetchRequestsForCurrentWarehouse()
            async let shipmentsFetch = RequestService.shared.fetchShipmentsForCurrentWarehouse()
            async let vendorOrdersFetch = RequestService.shared.fetchAllVendorOrders()
            async let vendorsFetch = RequestService.shared.fetchVendorsForCurrentInventoryManager()

            pickLists = try await requestsFetch
            shipmentsOut = try await shipmentsFetch
            vendorOrders = try await vendorOrdersFetch
            brandVendors = try await vendorsFetch
        } catch {
            errorMessage = error.localizedDescription
            print("TransfersViewModel.loadData error: \(error)")
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

    // MARK: - Accept (Step 1)

    /// Only updates the status to 'approved'. Does NOT auto-ship.
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

    // MARK: - Ship with ASN (Step 2)

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

    // MARK: - Reject

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

    // MARK: - Private Helpers

    private func decrementWarehouseStock(productId: UUID, deductQuantity: Int) async throws {
        let inventoryRows = try await DataService.shared.fetchInventory()
        let productRows = inventoryRows.filter { $0.productId == productId }
        guard let mainRow = productRows.first else {
            print("No inventory row found for product \(productId)")
            return
        }
        let newQuantity = max(0, mainRow.quantity - deductQuantity)
        try await DataService.shared.updateInventory(productId: productId, newQuantity: newQuantity)

        if newQuantity < 5 {
            print("Stock fell below 5! Auto-generating Vendor Order for product \(productId)")
            try await RequestService.shared.createVendorOrder(quantity: 20)
        }
    }
}
