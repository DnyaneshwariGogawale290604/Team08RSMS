import Foundation
import SwiftUI
import Combine

@MainActor
public class BoutiqueDashboardViewModel: ObservableObject {
    @Published public var summary: DashboardSummary?
    @Published public var activeAlerts: [InventoryProduct] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public init() {}

    /// Sync wrapper — called from onAppear (only if no data yet)
    public func loadDashboardData() {
        guard !isLoading else { return }
        Task { await loadDashboardDataAsync() }
    }

    /// Async version — also called from pull-to-refresh
    public func loadDashboardDataAsync() async {
        isLoading = true
        errorMessage = nil

        var todayRevenue: Double = 0
        var targetRevenue: Double = 0
        var lowStockItems: [InventoryProduct] = []

        do {
            if let store = try await DataService.shared.fetchCurrentStore() {
                targetRevenue = store.salesTarget ?? 1_500_000
                do {
                    let sales = try await DataService.shared.fetchSales(storeId: store.id)
                    let today = sales.filter { Calendar.current.isDateInToday($0.createdAt) }
                    todayRevenue = today.reduce(0) { $0 + $1.totalAmount }
                } catch {
                    print("Dashboard/Sales: \(error)")
                }
            } else if let store = try await DataService.shared.fetchStores().first {
                targetRevenue = store.salesTarget ?? 1_500_000
                do {
                    let sales = try await DataService.shared.fetchSales(storeId: store.id)
                    let today = sales.filter { Calendar.current.isDateInToday($0.createdAt) }
                    todayRevenue = today.reduce(0) { $0 + $1.totalAmount }
                } catch {
                    print("Dashboard/Sales: \(error)")
                }
            }
        } catch {
            print("Dashboard/Stores: \(error)")
            targetRevenue = 1_500_000
        }

        do {
            let inventory: [StoreInventory]
            do {
                inventory = try await DataService.shared.fetchInventoryForCurrentStore()
            } catch {
                inventory = (try? await DataService.shared.fetchInventory()) ?? []
            }

            let baselines = (try? await DataService.shared.fetchInventoryBaselineForCurrentStore()) ?? []

            var productLookup: [UUID: Product] = [:]
            do {
                let products = try await DataService.shared.fetchAllProductsForCurrentBrand()
                for p in products { productLookup[p.id] = p }
            } catch {
                if let products = try? await DataService.shared.fetchProducts() {
                    for p in products { productLookup[p.id] = p }
                }
            }

            let allInventory = Array(productLookup.values).map { product -> InventoryProduct in
                let baselineItem = baselines.first { $0.productId == product.id }
                let currentQty = baselineItem?.currentQuantity ?? 0
                
                return InventoryProduct(
                    id: baselineItem?.id ?? product.id,
                    productId: product.id,
                    name: product.name,
                    sku: product.sku ?? product.id.uuidString.prefix(8).uppercased().description,
                    category: product.category.isEmpty ? "General" : product.category,
                    price: product.price,
                    stockQuantity: currentQty,
                    baselineQuantity: baselineItem?.baselineQuantity ?? 15,
                    enabledInStore: currentQty > 0
                )
            }
            
            // Sort low stock items so alerts have a stable order
            lowStockItems = allInventory.filter { $0.isLowStock }.sorted { $0.name < $1.name }
        } catch {
            print("Dashboard/Inventory: \(error)")
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            self.summary = DashboardSummary(
                dailyRevenue: todayRevenue,
                targetRevenue: targetRevenue,
                activeAlertsCount: lowStockItems.count
            )
            self.activeAlerts = lowStockItems
            self.isLoading = false
        }
    }
}
