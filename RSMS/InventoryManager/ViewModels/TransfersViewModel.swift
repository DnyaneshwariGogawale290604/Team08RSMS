import Foundation
import Combine

@MainActor
public final class TransfersViewModel: ObservableObject {
    @Published public var vendorOrders: [VendorOrder] = []
    @Published public var pickLists: [ProductRequest] = []
    @Published public var shipmentsOut: [Shipment] = []
    @Published public var isLoading = false
    
    public init() {}
    
    public func loadData() async {
        isLoading = true
        do {
            vendorOrders = try await RequestService.shared.fetchAllVendorOrders()
            // Pick lists are approved or pending requests
            pickLists = try await RequestService.shared.fetchAllRequests()
            shipmentsOut = try await RequestService.shared.fetchAllShipments()
        } catch {
            print("Failed to fetch transfers: \(error)")
        }
        isLoading = false
    }
    
    public func acceptRequest(request: ProductRequest) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1. Update request status to approved
            try await RequestService.shared.updateRequestStatus(id: request.id, status: "approved")
            
            // 2. Create a shipment in transit
            try await RequestService.shared.createShipmentForRequest(requestId: request.id, storeId: request.storeId)
            
            // 3. Decrement warehouse stock
            if let productId = request.productId {
                try await decrementWarehouseStock(productId: productId, deductQuantity: request.requestedQuantity)
            }
            
            // Reload data to reflect changes
            await loadData()
        } catch {
            print("Failed to accept request: \(error)")
        }
    }
    
    public func rejectRequest(request: ProductRequest, reason: String = "Rejected by Inventory Manager") async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await RequestService.shared.updateRequestStatus(id: request.id, status: "rejected", rejectReason: reason)
            await loadData()
        } catch {
            print("Failed to reject request: \(error)")
        }
    }
    
    private func decrementWarehouseStock(productId: UUID, deductQuantity: Int) async throws {
        // Fetch global inventory rows for this product
        let inventoryRows = try await DataService.shared.fetchInventory()
        let productRows = inventoryRows.filter { $0.productId == productId }
        
        // We assume the first row with enough stock, or simply the first row, represents the main warehouse pool in this MVP
        guard let mainRow = productRows.first, let currentQty = mainRow.quantity as Int? else {
            print("No inventory row found to decrement for product \(productId)")
            return
        }
        
        let newQuantity = max(0, currentQty - deductQuantity)
        
        // Update the baseline for this store/product
        try await DataService.shared.updateInventory(productId: productId, newQuantity: newQuantity)
        
        // If it falls below a threshold (e.g., 5), automatically place a Vendor Order
        if newQuantity < 5 {
            // Order 20 more units from vendor
            print("Stock fell below 5! Auto-generating Vendor Order for product \(productId)")
            try await RequestService.shared.createVendorOrder(quantity: 20)
        }
    }
}
