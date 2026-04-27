import SwiftUI

public struct StoreInventoryTab: View {
    let storeId: UUID
    @StateObject private var viewModel: StoreInventoryMonitorViewModel
    
    public init(storeId: UUID) {
        self.storeId = storeId
        self._viewModel = StateObject(wrappedValue: StoreInventoryMonitorViewModel(storeId: storeId))
    }
    
    private var availableCategories: [String] {
        Array(Set(viewModel.allItems.map { $0.product.category })).sorted()
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.allItems.isEmpty {
                LoadingView(message: "Loading Live Inventory...")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Smart Insights
                        HStack(spacing: 12) {
                            StatCard(title: "Total", value: viewModel.totalProducts, color: CatalogTheme.primaryText)
                            StatCard(title: "Low Stock", value: viewModel.lowStockCount, color: .yellow)
                            StatCard(title: "Urgent", value: viewModel.criticalStockCount, color: .red)
                        }
                        
                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search by product...", text: $viewModel.searchText)
                                .font(.system(size: 15, design: .serif))
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                        .onChange(of: viewModel.searchText) { _ in viewModel.applyFilters() }
                        
                        // Category Filters
                        categoryFilters
                        
                        // Inventory List
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredItems) { item in
                                InventoryMonitorCard(item: item)
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await viewModel.loadData() }
            }
        }
        .background(Color.clear)
        .task {
            await viewModel.loadData()
        }
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "All", isSelected: viewModel.filterCategory == nil) {
                    viewModel.filterCategory = nil
                    viewModel.applyFilters()
                }
                
                ForEach(availableCategories, id: \.self) { category in
                    categoryChip(title: category, isSelected: viewModel.filterCategory == category) {
                        viewModel.filterCategory = category
                        viewModel.applyFilters()
                    }
                }
            }
        }
    }
    
    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .serif))
                .foregroundColor(isSelected ? .white : CatalogTheme.deepAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? CatalogTheme.primary : CatalogTheme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subcomponents

struct StatCard: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.secondaryText)
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

struct InventoryMonitorCard: View {
    let item: InventoryStatusItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text(item.product.category)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(CatalogTheme.secondaryText)
                }
                Spacer()
                
                Text("Qty: \(item.current)")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}
