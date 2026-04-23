import Foundation
import SwiftUI
import Combine

@MainActor
public class CatalogViewModel: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var filteredProducts: [Product] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var searchText = "" {
        didSet { applySearch() }
    }
    @Published public var selectedCategory: String? = nil {
        didSet { applySearch() }
    }
    
    public var categories: [String] {
        let cats = products.compactMap { $0.category }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted()
    }
    
    public init() {}
    
    public func fetchProducts() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetched = try await DataService.shared.fetchAllProductsForCurrentBrand()
                self.products = fetched
                self.applySearch()
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load catalog. (\(error.localizedDescription))"
                self.isLoading = false
                print("Catalog fetch error: \(error)")
            }
        }
    }
    
    private func applySearch() {
        var result = products

        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.sku ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        filteredProducts = result
    }
}
