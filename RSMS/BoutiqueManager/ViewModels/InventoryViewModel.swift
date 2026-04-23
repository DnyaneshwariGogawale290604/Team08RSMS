import Foundation
import SwiftUI
import Combine

@MainActor
public class InventoryViewModel: ObservableObject {
    @Published public var inventoryList: [InventoryProduct] = []
    @Published public var activeAlerts: [StockAlert] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    // Maps inventory_id -> StoreInventory for update operations
    private var rawInventory: [UUID: StoreInventory] = [:]
    private var resolvedAlertIds: Set<UUID> = []

    @Published public var orderedProductIds: Set<UUID> = []
    @Published public var notificationMessage: String?

    public init() {}

    /// Places an order to the inventory manager
    public func orderStock(productId: UUID, quantity: Int) {
        isLoading = true
        Task {
            do {
                try await DataService.shared.createStockRequest(productId: productId, quantity: quantity)
                self.orderedProductIds.insert(productId)
                self.notificationMessage = "Order placed successfully!"
                self.isLoading = false
            } catch {
                self.notificationMessage = "Failed to place order."
                self.isLoading = false
                print("orderStock error: \(error)")
            }
        }
    }

    public func fetchInventoryAndAlerts() {
        isLoading = true
        errorMessage = nil

        Task {
            // Step 1: Try store-scoped fetch; fall back to all rows on any error
            let dbInventory: [StoreInventory]
            do {
                dbInventory = try await DataService.shared.fetchInventoryForCurrentStore()
                print("[InventoryVM] store-scoped rows: \(dbInventory.count)")
            } catch {
                print("[InventoryVM] store-scoped fetch failed (\(error)), falling back to all rows")
                do {
                    dbInventory = try await DataService.shared.fetchInventory()
                    print("[InventoryVM] all-store fallback rows: \(dbInventory.count)")
                } catch {
                    self.errorMessage = "Failed to load inventory. (\(error.localizedDescription))"
                    self.isLoading = false
                    print("[InventoryVM] fallback also failed: \(error)")
                    return
                }
            }

            rawInventory = Dictionary(uniqueKeysWithValues: dbInventory.map { ($0.id, $0) })
            
            let baselines = (try? await DataService.shared.fetchInventoryBaselineForCurrentStore()) ?? []

            // Step 2: Build product lookup using ALL brand products (not just is_active)
            var productLookup: [UUID: Product] = [:]
            do {
                let products = try await DataService.shared.fetchAllProductsForCurrentBrand()
                for p in products { productLookup[p.id] = p }
                print("[InventoryVM] product lookup size: \(productLookup.count)")
            } catch {
                // Try active-only as secondary fallback
                if let products = try? await DataService.shared.fetchProducts() {
                    for p in products { productLookup[p.id] = p }
                }
                print("[InventoryVM] product lookup fallback size: \(productLookup.count)")
            }

            // Step 3: Merge — loop over ALL products, defaulting to 0 stock if no inventory row exists
            let merged = Array(productLookup.values).map { product -> InventoryProduct in
                let baselineItem = baselines.first { $0.productId == product.id }
                let currentQty = baselineItem?.currentQuantity ?? 0
                
                return InventoryProduct(
                    id: baselineItem?.id ?? product.id, // we fall back to product.id so Identifiable works
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
            // Sort: low stock first, then alphabetically
            self.inventoryList = merged.sorted {
                if $0.isLowStock != $1.isLowStock { return $0.isLowStock }
                return $0.name < $1.name
            }

            let requests = (try? await DataService.shared.fetchProductRequestsForCurrentStore()) ?? []

            // Step 4: Build alerts
            self.activeAlerts = self.inventoryList
                .filter { $0.isLowStock && !resolvedAlertIds.contains($0.id) }
                .map { product in
                    let relatedRequest = requests.first { $0.productId == product.productId }
                    var status = relatedRequest?.status
                    if self.orderedProductIds.contains(product.productId) && status == nil {
                        status = "pending"
                    }
                    
                    return StockAlert(
                        id: product.id,
                        productId: product.productId,
                        message: "\(product.name) is low on stock (\(product.stockQuantity) left).",
                        isResolved: false,
                        priority: product.stockQuantity == 0 ? .critical : .medium,
                        requestStatus: status,
                        rejectionReason: relatedRequest?.rejectionReason
                    )
                }

            let healthyIds = Set(self.inventoryList.filter { !$0.isLowStock }.map { $0.id })
            resolvedAlertIds.subtract(healthyIds)

            self.isLoading = false
        }
    }

    public func resolveAlert(id: UUID) {
        resolvedAlertIds.insert(id)
        activeAlerts.removeAll { $0.id == id }
    }

    public func toggleProductAvailability(product: InventoryProduct) {
        let newQty = product.enabledInStore ? 0 : product.baselineQuantity
        Task {
            do {
                // If it's a new item, updateInventory might fail if the row doesn't exist, but typically updateInventory relies on inventoryId being the actual DB id or product id.
                // Uses product id instead of inventory ID (as it was deleted from dbInventory)
                try await DataService.shared.updateInventory(productId: product.productId, newQuantity: newQty)
                self.fetchInventoryAndAlerts()
            } catch {
                self.errorMessage = "Failed to update. (\(error.localizedDescription))"
            }
        }
    }
}
