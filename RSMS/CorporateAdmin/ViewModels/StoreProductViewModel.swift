import Foundation
import Combine

@MainActor
public final class StoreProductViewModel: ObservableObject {
    @Published public var assignedProducts: [StoreBaselineWithProduct] = []
    @Published public var availableGlobalProducts: [Product] = []
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
            async let productsTask = productService.fetchProducts()
            
            let (baselines, allProducts) = try await (baselinesTask, productsTask)
            self.availableGlobalProducts = allProducts
            
            // Join them in memory for UI presentation
            var joined: [StoreBaselineWithProduct] = []
            for baseline in baselines {
                if let matchedProd = allProducts.first(where: { $0.id == baseline.productId }) {
                    joined.append(StoreBaselineWithProduct(baseline: baseline, product: matchedProd))
                }
            }
            self.assignedProducts = joined
            self.errorMessage = nil
            
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func addSelectedProducts(_ products: [(product: Product, quantity: Int)]) async -> Bool {
        guard !products.isEmpty else { return false }
        
        isLoading = true
        do {
            let items = products.map { (productId: $0.product.id, quantity: $0.quantity) }
            try await inventoryService.assignProducts(storeId: storeId, items: items)
            await loadData()
            isLoading = false
            return true
        } catch {
            print("Add Products Failed: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    public func updateQuantity(baselineId: UUID, newQuantity: Int) async {
        do {
            try await inventoryService.updateBaselineQuantity(baselineId: baselineId, quantity: newQuantity)
            
            // Optimistically update UI
            if let index = assignedProducts.firstIndex(where: { $0.id == baselineId }) {
                assignedProducts[index].baseline.baselineQuantity = newQuantity
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    public func removeProduct(baselineId: UUID) async {
        do {
            try await inventoryService.removeBaseline(baselineId: baselineId)
            assignedProducts.removeAll(where: { $0.id == baselineId })
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
