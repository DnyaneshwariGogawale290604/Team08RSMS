import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
public final class InventoryDashboardViewModel: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var warehouseInventory: [WarehouseInventoryRow] = []
    @Published public var inventoryItems: [InventoryItem] = []
    @Published public var pendingRequests: [ProductRequest] = []
    @Published public var recentActivity: [Shipment] = []
    @Published public var vendorOrders: [VendorOrder] = []
    @Published public var isLoading = false
    
    public init() {}
    
    @Published public var storeInventory: [StoreInventory] = []
    @Published public var sales: [SalesOrder] = []
    
    public func loadDashboardData() async {
        isLoading = true
        
        // 1. Fetch Products
        do {
            products = try await DataService.shared.fetchAllProductsForCurrentBrand()
        } catch {
            print("Failed to fetch products: \(error)")
        }
        
        // 2. Fetch all inventory aggregates
        do {
            storeInventory = try await DataService.shared.fetchInventory()
        } catch {
            print("Failed to fetch store inventory: \(error)")
        }
        
        // 2.5 Fetch individual items (for repairs/serialization)
        do {
            inventoryItems = try await DataService.shared.fetchInventoryItems()
        } catch {
            print("Failed to fetch inventory items: \(error)")
        }
        
        // 3. Fetch pending vendor orders / boutique requests
        do {
            pendingRequests = try await RequestService.shared.fetchPendingRequests()
        } catch {
            print("Failed to fetch pending requests: \(error)")
        }
        
        // 4. Fetch actual shipments (items in transit, delivered, etc.)
        do {
            recentActivity = try await RequestService.shared.fetchAllShipments()
        } catch {
            print("Failed to fetch recent activity: \(error)")
        }
        
        // 5. Fetch sales for 'Sold' metric
        do {
            sales = try await DataService.shared.fetchSales()
        } catch {
            print("Failed to fetch sales: \(error)")
        }
        
        // 6. Fetch vendor orders to show "Order Placed" tags
        do {
            vendorOrders = (try? await RequestService.shared.fetchVendorOrdersForCurrentWarehouse()) ?? []
        } catch {
            print("Failed to fetch vendor orders: \(error)")
        }
        
        isLoading = false
    }
    
    // Derived properties for the dashboard
    
    public var totalSKUs: Int {
        return products.count
    }
    
    public var criticalSKUs: [Product] {
        var critical: [Product] = []
        for product in products {
            let pid = product.id
            let item = warehouseInventory.first { $0.productId == pid }
            let totalQuantity = item?.quantity ?? 0
            let rop = product.reorderPoint ?? 5
            if totalQuantity <= rop {
                critical.append(product)
            }
        }
        return critical
    }
    
    public var stockHealthPercentage: Int {
        let allCount = warehouseInventory.count
        if allCount == 0 { return 100 }
        let critCount = criticalSKUs.count
        let healthyCount = allCount - critCount
        let percentage = (Double(healthyCount) / Double(allCount)) * 100
        return Int(percentage)
    }
    
    public var categories: [String] {
        let productCats = products.map { $0.category.isEmpty ? "General" : $0.category }
        let itemCats = inventoryItems.map { $0.category.isEmpty ? "General" : $0.category }
        return Array(Set(productCats + itemCats)).sorted()
    }
    
    public var locations: [String] {
        let locs = Array(Set(inventoryItems.map { $0.location })).filter { !$0.isEmpty }.sorted()
        return locs.isEmpty ? ["Warehouse"] : locs
    }
    
    // MARK: - Stock Summary Metrics
    
    public var availableCount: Int {
        return warehouseInventory.reduce(0) { $0 + $1.quantity }
    }
    
    public var underRepairCount: Int {
        return 0 // Warehouses don't track under repair items directly in RSMS
    }

    public var inTransitCount: Int {
        recentActivity
            .filter { $0.status.lowercased() == "in_transit" || $0.status.lowercased() == "dispatched" }
            .compactMap { $0.request?.requestedQuantity }
            .reduce(0, +)
    }

    public var activePurchaseOrderCount: Int {
        vendorOrders.filter {
            let status = ($0.status ?? "").lowercased()
            return status == "pending" || status == "in_transit"
        }.count
    }
    
    public func filteredItemCount(for category: String, filter: ItemsTabView.RepairFilter) -> Int {
        return inventoryItems.filter { item in
            let cat = item.category.isEmpty ? "General" : item.category
            guard cat == category else { return false }
            
            guard item.status != .scrapped else { return false }
            
            switch filter {
            case .all: return true
            case .available: return item.status == .available
            case .underRepair: return item.status == .underRepair
            }
        }.count
    }
    
    public func availableItems(for category: String) -> Int {
        return warehouseInventory.filter { row in
            let cat = row.product?.category.isEmpty == true ? "General" : (row.product?.category ?? "General")
            return cat == category
        }.reduce(0) { $0 + $1.quantity }
    }
    
    /// Product IDs that have an active in_transit vendor order placed for them
    public var orderedProductIds: Set<UUID> {
        let active = vendorOrders.filter { ($0.status ?? "").lowercased() == "in_transit" }
        return Set(active.compactMap { $0.productId })
    }
}
