import Foundation
import SwiftUI
import Combine

@MainActor
public final class InventoryDashboardViewModel: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var storeInventory: [StoreInventory] = []
    @Published public var pendingRequests: [ProductRequest] = []
    @Published public var recentActivity: [Shipment] = [] 
    @Published public var sales: [SalesOrder] = []
    @Published public var isLoading = false
    
    public init() {}
    
    public func loadDashboardData() async {
        isLoading = true
        do {
            // 1. Fetch Products
            products = try await DataService.shared.fetchProducts()
            
            // 2. Fetch all inventory (Inventory Manager needs global view)
            storeInventory = try await DataService.shared.fetchInventory()
            
            // 3. Fetch pending vendor orders / boutique requests
            pendingRequests = try await RequestService.shared.fetchPendingRequests()
            
            // 4. Fetch actual shipments (items in transit, delivered, etc.)
            recentActivity = try await RequestService.shared.fetchAllShipments()
            
            // 5. Fetch sales for 'Sold' metric
            sales = try await DataService.shared.fetchSales()
            
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
        let total = storeInventory.reduce(0) { sum, item in sum + item.quantity }
        return total
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
    
    public func availableItems(for category: String) -> Int {
        let categoryProducts = products.filter { ($0.category.isEmpty ? "General" : $0.category) == category }
        let categoryProductIds = Set(categoryProducts.map { $0.id })
        
        let totalQuantity = storeInventory
            .filter { inventory in
                if let pid = inventory.productId {
                    return categoryProductIds.contains(pid)
                }
                return false
            }
            .reduce(0) { $0 + $1.quantity }
        
        return totalQuantity
    }
}
