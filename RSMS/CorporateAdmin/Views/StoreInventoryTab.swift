import SwiftUI

public struct StoreInventoryTab: View {
    let storeId: UUID
    @StateObject private var viewModel: StoreInventoryMonitorViewModel
    
    public init(storeId: UUID) {
        self.storeId = storeId
        self._viewModel = StateObject(wrappedValue: StoreInventoryMonitorViewModel(storeId: storeId))
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
                            StatCard(title: "Total", value: viewModel.totalProducts, color: .appPrimaryText)
                            StatCard(title: "Low Stock", value: viewModel.lowStockCount, color: .yellow)
                            StatCard(title: "Urgent", value: viewModel.criticalStockCount, color: .red)
                        }
                        
                        // Filters
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Search by product...", text: $viewModel.searchText)
                                    .font(.system(size: 15))
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                            .onChange(of: viewModel.searchText) { _ in viewModel.applyFilters() }
                            
                            pickerView
                        }
                        
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
        .background(Color.brandOffWhite.ignoresSafeArea())
        .task {
            await viewModel.loadData()
        }
    }

    private var pickerView: some View {
        HStack(spacing: 0) {
            let statuses = ["All", "Low", "Critical", "Healthy"]
            ForEach(0..<statuses.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        switch index {
                        case 0: viewModel.filterStatus = nil
                        case 1: viewModel.filterStatus = .low
                        case 2: viewModel.filterStatus = .critical
                        case 3: viewModel.filterStatus = .healthy
                        default: break
                        }
                        viewModel.applyFilters()
                    }
                }) {
                    let isSelected = (index == 0 && viewModel.filterStatus == nil) ||
                                    (index == 1 && viewModel.filterStatus == .low) ||
                                    (index == 2 && viewModel.filterStatus == .critical) ||
                                    (index == 3 && viewModel.filterStatus == .healthy)
                    
                    Text(statuses[index])
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
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
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

struct InventoryMonitorCard: View {
    let item: InventoryStatusItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    Text(item.product.category)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 6, height: 6)
                    Text(item.status.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(item.status.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(item.status.color.opacity(0.1))
                .clipShape(Capsule())
            }
            
            Divider().background(Color.gray.opacity(0.1))
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPECTED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Text("\(item.baseline)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTUAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    Text("\(item.current)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(item.status == .healthy ? .green : (item.status == .critical ? .red : .black))
                }
                
                Spacer()
                
                Button(action: {
                    // Future integration
                }) {
                    Text("Restock")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(item.status == .healthy ? Color.gray : Color.black)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}
