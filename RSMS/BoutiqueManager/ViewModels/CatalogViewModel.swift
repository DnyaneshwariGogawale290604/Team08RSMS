import Foundation
import SwiftUI
import Combine

@MainActor
class CatalogViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = "" {
        didSet { applySearch() }
    }
    @Published var selectedCategory: String? = nil {
        didSet { applySearch() }
    }
    
    var categories: [String] {
        let cats = products.compactMap { $0.category }.filter { !$0.isEmpty }
        return Array(Set(cats)).sorted()
    }
    
    init() {}
    
    func fetchProducts() {
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
