import Foundation
import Combine
import UIKit

@MainActor
public final class ProductViewModel: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    nonisolated(unsafe) private let service = ProductService.shared

    public init() {}

    public func fetchProducts() async {
        isLoading = true
        do {
            print("VIEWMODEL FETCH PRODUCTS: calling service")
            async let productsTask = service.fetchProducts()
            async let stocksTask = AdminService.shared.fetchProductStocks()
            
            var fetchedProducts = try await productsTask
            let stocks = try await stocksTask
            
            for i in 0..<fetchedProducts.count {
                fetchedProducts[i].stockQuantity = stocks[fetchedProducts[i].id] ?? 0
            }
            
            // Sort by stock status: Urgent > Low > Remaining
            self.products = fetchedProducts.sorted { p1, p2 in
                let s1 = p1.stockStatus
                let s2 = p2.stockStatus
                
                if s1 != s2 {
                    return s1 < s2
                }
                return p1.name < p2.name
            }
            
            print("VIEWMODEL FETCH PRODUCTS COUNT:", products.count)
            errorMessage = nil
        } catch {
            print("VIEWMODEL FETCH PRODUCTS ERROR:", error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @discardableResult
    public func addProduct(_ product: Product, image: UIImage?) async -> Bool {
        await addProduct(product, image: image, variants: [])
    }

    @discardableResult
    public func addProduct(_ product: Product, image: UIImage?, variants: [ProductVariantDraftInput]) async -> Bool {
        isLoading = true
        do {
            let newProduct = try await service.addProduct(product, image: image, variants: variants)
            products.insert(newProduct, at: 0)
            errorMessage = nil
            isLoading = false
            return true
        } catch {
            print("ERROR:", error)
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    @discardableResult
    public func updateProduct(_ product: Product) async -> Bool {
        isLoading = true
        do {
            try await service.updateProduct(product)
            if let index = products.firstIndex(where: { $0.id == product.id }) {
                products[index] = product
            }
            errorMessage = nil
            isLoading = false
            return true
        } catch {
            print("ERROR:", error)
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    @discardableResult
    public func updateProduct(_ product: Product, variants: [ProductVariantDraftInput]) async -> Bool {
        isLoading = true
        do {
            try await service.updateProduct(product, variants: variants)
            if let index = products.firstIndex(where: { $0.id == product.id }) {
                var updatedProduct = product
                updatedProduct.variants = variants.map {
                    ProductVariant(
                        id: $0.id,
                        productId: product.id,
                        name: $0.name,
                        imageUrls: $0.existingImageUrls,
                        infoText: $0.infoText
                    )
                }
                products[index] = updatedProduct
            }
            await fetchProducts()
            errorMessage = nil
            isLoading = false
            return true
        } catch {
            print("ERROR:", error)
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    public func toggleActiveStatus(for product: Product) async {
        do {
            let newStatus = !(product.isActive ?? true)
            try await service.toggleProductActiveStatus(productId: product.id, isActive: newStatus)
            if let index = products.firstIndex(where: { $0.id == product.id }) {
                products[index].isActive = newStatus
            }
        } catch {
            print("ERROR:", error)
            errorMessage = error.localizedDescription
        }
    }
}
