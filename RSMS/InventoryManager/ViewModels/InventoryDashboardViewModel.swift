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
    
    public func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let productsFetch = DataService.shared.fetchAllProductsForCurrentBrand()
            async let requestsFetch = RequestService.shared.fetchPendingRequests()
            async let shipmentsFetch = RequestService.shared.fetchShipmentsForCurrentWarehouse()
            async let vendorOrdersFetch = RequestService.shared.fetchVendorOrdersForCurrentWarehouse()
            async let inventoryItemsFetch = DataService.shared.fetchInventoryItems()

            let fetchedProducts = try await productsFetch
            let fetchedRequests = try await requestsFetch
            let fetchedShipments = try await shipmentsFetch
            let fetchedVendorOrders = (try? await vendorOrdersFetch) ?? []
            let fetchedItems = try await inventoryItemsFetch

            var fetchedWarehouseInventory: [WarehouseInventoryRow] = []
            if let userId = try? await SupabaseManager.shared.client.auth.session.user.id {
                struct Row: Decodable {
                    let warehouseId: UUID
                    enum CodingKeys: String, CodingKey { case warehouseId = "warehouse_id" }
                }

                if let managerRows: [Row] = try? await SupabaseManager.shared.client
                    .from("inventory_managers")
                    .select("warehouse_id")
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                    .value,
                   let warehouseId = managerRows.first?.warehouseId {
                    fetchedWarehouseInventory = try await WarehouseService.shared.fetchInventory(warehouseId: warehouseId)
                }
            }

            products = fetchedProducts
            pendingRequests = fetchedRequests
            recentActivity = fetchedShipments
            vendorOrders = fetchedVendorOrders
            inventoryItems = fetchedItems
            warehouseInventory = fetchedWarehouseInventory
        } catch {
            print("Failed to fetch Inventory Dashboard data: \(error)")
        }
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
        return Array(Set(products.map { $0.category.isEmpty ? "General" : $0.category })).sorted()
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
