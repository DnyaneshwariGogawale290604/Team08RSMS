import Foundation
import SwiftUI
import Combine

public enum StockStatus: String, CaseIterable, Identifiable {
    case healthy = "Healthy"
    case low = "Low Stock"
    case critical = "Urgent Stock"
    
    public var id: String { self.rawValue }
    
    public var color: Color {
        switch self {
        case .healthy: return .green
        case .low: return .yellow
        case .critical: return .red
        }
    }
}

public struct InventoryStatusItem: Identifiable, Hashable, Sendable {
    public var id: UUID { product.id }
    public var product: Product
    public var baseline: Int
    public var current: Int
    
    public var status: StockStatus {
        if current >= baseline {
            return .healthy
        } else if current > 0 && current < baseline {
            // Let's define Low as >0 and <baseline, or we can use percentage basis.
            // E.G. current >= baseline * 0.2
            let ratio = Double(current) / Double(baseline)
            return ratio >= 0.25 ? .low : .critical
        } else {
            return .critical
        }
    }
}

@MainActor
public final class StoreInventoryMonitorViewModel: ObservableObject {
    @Published public var allItems: [InventoryStatusItem] = []
    @Published public var filteredItems: [InventoryStatusItem] = []
    
    @Published public var searchText: String = ""
    @Published public var filterStatus: StockStatus? = nil
    @Published public var filterCategory: String? = nil
    
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    public let storeId: UUID
    nonisolated(unsafe) private let inventoryService = StoreInventoryService.shared
    nonisolated(unsafe) private let productService = ProductService.shared
    
    public init(storeId: UUID) {
        self.storeId = storeId
    }
    
    public func loadData() async {
        isLoading = true
        do {
            async let baselinesTask = inventoryService.fetchBaselines(forStore: storeId)
            async let currentInventoryTask = inventoryService.fetchCurrentInventory(forStore: storeId)
            async let productsTask = productService.fetchProducts()
            
            let (baselines, currents, allProducts) = try await (baselinesTask, currentInventoryTask, productsTask)
            
            var items: [InventoryStatusItem] = []
            
            // Map the arrays together based on `productId`
            let activeBaselines = baselines.filter { $0.baselineQuantity > 0 }
            
            for baseline in activeBaselines {
                if let matchedProd = allProducts.first(where: { $0.id == baseline.productId }) {
                    let matchingCurrent = currents.first(where: { $0.productId == matchedProd.id })?.quantity ?? 0
                    
                    items.append(InventoryStatusItem(
                        product: matchedProd,
                        baseline: baseline.baselineQuantity,
                        current: matchingCurrent
                    ))
                }
            }
            
            self.allItems = items
            self.applyFilters()
            self.errorMessage = nil
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func applyFilters() {
        var results = allItems
        
        if !searchText.isEmpty {
            results = results.filter { $0.product.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let status = filterStatus {
            results = results.filter { $0.status == status }
        }
        
        if let category = filterCategory {
            results = results.filter { $0.product.category == category }
        }
        
        // Sort alphabetically or smartly
        results.sort { $0.product.name < $1.product.name }
        
        self.filteredItems = results
    }
    
    public var totalProducts: Int { allItems.count }
    public var lowStockCount: Int { allItems.filter { $0.status == .low }.count }
    public var criticalStockCount: Int { allItems.filter { $0.status == .critical }.count }
}
