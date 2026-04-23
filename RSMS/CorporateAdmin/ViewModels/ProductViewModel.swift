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
            products = try await service.fetchProducts()
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
        isLoading = true
        do {
            let newProduct = try await service.addProduct(product, image: image)
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
