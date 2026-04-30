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
    
    private var syncTimer: Timer?
    
    public init() {
        startAutoSync()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    private func startAutoSync() {
        // Automatically refresh every 30 seconds
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                await self?.loadDashboardData()
            }
        }
    }
    
    @Published public var storeInventory: [StoreInventory] = []
    @Published public var sales: [SalesOrder] = []

    public struct AvailableStockRow: Identifiable {
        public let productId: UUID
        public let product: Product?
        public let quantity: Int

        public var id: UUID { productId }
    }
    
    public func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Concurrent fetches for speed
            async let productsFetch = DataService.shared.fetchAllProductsForCurrentBrand()
            async let requestsFetch = RequestService.shared.fetchPendingRequests()
            async let shipmentsFetch = RequestService.shared.fetchShipmentsForCurrentWarehouse()
            async let vendorOrdersFetch = RequestService.shared.fetchVendorOrdersForCurrentWarehouse()
            async let inventoryItemsFetch = DataService.shared.fetchInventoryItemsForCurrentBrand()
            async let salesFetch = DataService.shared.fetchSales()

            products = try await productsFetch
            pendingRequests = try await requestsFetch
            recentActivity = (try? await shipmentsFetch) ?? []
            vendorOrders = (try? await vendorOrdersFetch) ?? []
            inventoryItems = (try? await inventoryItemsFetch) ?? []
            sales = (try? await salesFetch) ?? []

            // Inject time-based missing exceptions (deduplicated)
            let overdue = ExceptionEngine.shared.detectOverdueItems(items: inventoryItems)
            ExceptionEngine.shared.injectTimeBasedExceptions(overdue)
        } catch {
            print("Failed to fetch dashboard data: \(error)")
        }

        // Keep the legacy warehouse_inventory fetch for compatibility with
        // older views, but dashboard stock metrics are derived from
        // inventory_items so they stay in sync with the Items tab.
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
                warehouseInventory = (try? await WarehouseService.shared.fetchInventory(warehouseId: warehouseId)) ?? []
            }
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
            let totalQuantity = availableStockRows.first(where: { $0.productId == pid })?.quantity ?? 0
            let rop = product.reorderPoint ?? 5
            if totalQuantity <= rop {
                critical.append(product)
            }
        }
        return critical
    }
    
    public var stockHealthPercentage: Int {
        let allCount = availableStockRows.count
        if allCount == 0 { return 100 }
        let critCount = criticalSKUs.count
        let healthyCount = allCount - critCount
        return (healthyCount * 100) / allCount
    }
    
    public var repairCount: Int {
        var count = 0
        for item in inventoryItems {
            if item.status == .underRepair {
                count += 1
            }
        }
        return count
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

    public var availableStockRows: [AvailableStockRow] {
        let availableItems = inventoryItems.filter { $0.status == .available }
        let grouped = Dictionary(grouping: availableItems, by: \.productId)

        return grouped.map { productId, items in
            AvailableStockRow(
                productId: productId,
                product: products.first(where: { $0.id == productId }) ?? items.first.flatMap { item in
                    Product(
                        id: productId,
                        name: item.productName,
                        category: item.category,
                        price: 0
                    )
                },
                quantity: items.count
            )
        }
        .sorted { ($0.product?.name ?? "") < ($1.product?.name ?? "") }
    }
    
    public var availableCount: Int {
        inventoryItems.filter { $0.status == .available }.count
    }
    
    public var underRepairCount: Int {
        return 0 // Warehouses don't track under repair items directly in RSMS
    }

    public var inTransitShipmentCount: Int {
        recentActivity.filter { $0.status.lowercased() == "in_transit" }.count
    }

    public var inTransitOrderCount: Int {
        vendorOrders.filter { ($0.status ?? "").lowercased() == "in_transit" }.count
    }

    public var inTransitCount: Int {
        inTransitShipmentCount + inTransitOrderCount
    }

    public var activePurchaseOrderCount: Int {
        vendorOrders.filter {
            let status = ($0.status ?? "").lowercased()
            return status == "pending" || status == "in_transit"
        }.count
    }

    public var pendingItemCount: Int {
        pendingRequests.reduce(0) { $0 + $1.requestedQuantity }
    }
    
    public var missingScanCount: Int {
        inventoryItems.filter { $0.scanStatus == .overdue }.count
    }

    public var activePOItemCount: Int {
        let activeOrders = vendorOrders.filter {
            let status = ($0.status ?? "").lowercased()
            return status == "pending" || status == "in_transit"
        }
        return activeOrders.reduce(0) { $0 + ($1.quantity ?? 0) }
    }


    public func matches(_ item: InventoryItem, filter: ItemsTabView.RepairFilter) -> Bool {
        guard item.status != .scrapped else { return false }

        switch filter {
        case .all:
            return true
        case .available:
            return item.status == .available
        case .underRepair:
            return item.status == .underRepair
        case .missingScan:
            return item.scanStatus == .overdue
        }
    }
    
    public func filteredItemCount(for category: String, filter: ItemsTabView.RepairFilter) -> Int {
        return inventoryItems.filter { item in
            let cat = item.category.isEmpty ? "General" : item.category
            guard cat == category else { return false }

            return matches(item, filter: filter)
        }.count
    }
    
    public func availableItems(for category: String) -> Int {
        inventoryItems.filter { item in
            let cat = item.category.isEmpty ? "General" : item.category
            return item.status == .available && cat == category
        }.count
    }
    
    /// Product IDs that have an active in_transit vendor order placed for them
    public var orderedProductIds: Set<UUID> {
        let active = vendorOrders.filter { ($0.status ?? "").lowercased() == "in_transit" }
        return Set(active.compactMap { $0.productId })
    }
}
