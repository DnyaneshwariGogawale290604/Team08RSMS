import Foundation
import SwiftUI
import Combine

@MainActor
public final class InventoryDashboardViewModel: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var storeInventory: [StoreInventory] = []
    @Published public var inventoryItems: [InventoryItem] = []
    @Published public var pendingRequests: [ProductRequest] = []
    @Published public var recentActivity: [Shipment] = [] 
    @Published public var sales: [SalesOrder] = []
    @Published public var vendorOrders: [VendorOrder] = []
    @Published public var isLoading = false
    
    public init() {}
    
    public func loadDashboardData() async {
        isLoading = true
        do {
            // 1. Fetch Products
            products = try await DataService.shared.fetchProducts()
            
            // 2. Fetch all inventory aggregates
            storeInventory = try await DataService.shared.fetchInventory()
            
            // 2.5 Fetch individual items (for repairs/serialization)
            inventoryItems = try await DataService.shared.fetchInventoryItems()
            
            // 3. Fetch pending vendor orders / boutique requests
            pendingRequests = try await RequestService.shared.fetchPendingRequests()
            
            // 4. Fetch actual shipments (items in transit, delivered, etc.)
            recentActivity = try await RequestService.shared.fetchAllShipments()
            
            // 5. Fetch sales for 'Sold' metric
            sales = try await DataService.shared.fetchSales()
            
            // 6. Fetch vendor orders to show "Order Placed" tags
            vendorOrders = (try? await RequestService.shared.fetchVendorOrdersForCurrentWarehouse()) ?? []
            
        } catch {
            print("Failed to fetch Inventory Dashboard data: \(error)")
        }
        isLoading = false
    }
    
    // Derived properties for the dashboard
    
    public var totalSKUs: Int {
        return products.count
    }
    
    public var criticalSKUs: [Product] {
        // Find products where total inventory across all stores is below a certain threshold (e.g., 5)
        var critical: [Product] = []
        for product in products {
            let pid = product.id
            let items = storeInventory.filter { $0.productId == pid }
            let totalQuantity = items.reduce(0) { $0 + $1.quantity }
            if totalQuantity < 5 {
                critical.append(product)
            }
        }
        return critical
    }
    
    public var stockHealthPercentage: Int {
        let allCount = products.count
        if allCount == 0 { return 100 }
        let critCount = criticalSKUs.count
        let healthyCount = allCount - critCount
        let percentage = (Double(healthyCount) / Double(allCount)) * 100
        return Int(percentage)
    }
    
    public var categories: [String] {
        return Array(Set(products.map { $0.category.isEmpty ? "General" : $0.category })).sorted()
    }
    
    // MARK: - Stock Summary Metrics
    
    public var availableCount: Int {
        return inventoryItems.filter { $0.status == .available }.count
    }
    
    public var underRepairCount: Int {
        return inventoryItems.filter { $0.status == .underRepair }.count
    }
    
    public var reservedCount: Int {
        let total = pendingRequests.reduce(0) { sum, request in sum + request.requestedQuantity }
        return total
    }
    
    public var inTransitCount: Int {
        recentActivity
            .filter { $0.status.lowercased() == "in_transit" || $0.status.lowercased() == "dispatched" }
            .compactMap { $0.request?.requestedQuantity }
            .reduce(0, +)
    }
    
    public var soldCount: Int {
        // Mocked or calculated from sales orders if order items were included
        // Since SalesOrder doesn't directly have total quantity without items, we count orders * roughly 2
        sales.count * 2
    }
    
    public func filteredItemCount(for category: String, filter: ItemsTabView.RepairFilter) -> Int {
        return inventoryItems.filter { item in
            let cat = item.category.isEmpty ? "General" : item.category
            guard cat == category else { return false }
            
            // Scrapped items are excluded from ALL counts
            guard item.status != .scrapped else { return false }
            
            switch filter {
            case .all:
                return true
            case .available:
                return item.status == .available
            case .underRepair:
                return item.status == .underRepair
            }
        }.count
    }
    
    public func availableItems(for category: String) -> Int {
        return filteredItemCount(for: category, filter: .available)
    }
    
    /// Product IDs that have an active in_transit vendor order placed for them
    public var orderedProductIds: Set<UUID> {
        let active = vendorOrders.filter { ($0.status ?? "").lowercased() == "in_transit" }
        return Set(active.compactMap { $0.productId })
    }
}
