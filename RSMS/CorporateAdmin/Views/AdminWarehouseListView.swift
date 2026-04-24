import SwiftUI

public struct AdminWarehouseListView: View {
    @ObservedObject var viewModel: WarehouseViewModel
    @Binding var showingAddWarehouse: Bool
    
    @State private var selectedFilter: WarehouseFilter = .all

    enum WarehouseFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
        case maintenance = "Maintenance"
    }

    private var filteredWarehouses: [Warehouse] {
        let activeWarehouses = viewModel.warehouses.filter { ($0.status ?? "active").lowercased() != "inactive" }
        switch selectedFilter {
        case .all: return activeWarehouses
        case .active: return activeWarehouses.filter { ($0.status ?? "active").lowercased() == "active" }
        case .inactive: return activeWarehouses.filter { ($0.status ?? "").lowercased() == "inactive" }
        case .maintenance: return activeWarehouses.filter { ($0.status ?? "").lowercased().contains("maintenance") }
        }
    }

    private var archivedWarehouses: [Warehouse] {
        viewModel.warehouses.filter { ($0.status ?? "").lowercased() == "inactive" }
    }

    public var body: some View {
        ZStack {
            CatalogTheme.background.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.warehouses.isEmpty {
                LoadingView(message: "Loading Warehouses...")
            } else {
                VStack(spacing: 0) {
                    filterChips
                    
                    if viewModel.warehouses.isEmpty {
                        EmptyStateView(
                            icon: "building.2.fill",
                            title: "No Warehouses",
                            message: "Your warehouses will appear here."
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 24) {
                                ForEach(filteredWarehouses) { warehouse in
                                    AdminWarehouseCard(warehouse: warehouse, viewModel: viewModel)
                                }

                                if !archivedWarehouses.isEmpty && selectedFilter == .all {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Text("Archived Warehouses")
                                            .font(.system(size: 18, weight: .bold, design: .serif))
                                            .foregroundColor(CatalogTheme.secondaryText)
                                            .padding(.horizontal, 4)
                                        
                                        ForEach(archivedWarehouses) { warehouse in
                                            AdminWarehouseCard(warehouse: warehouse, viewModel: viewModel)
                                                .opacity(0.7)
                                        }
                                    }
                                    .padding(.top, 10)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                        }
                        .refreshable { await viewModel.fetchWarehouses() }
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WarehouseFilter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedFilter == filter ? CatalogTheme.primary : CatalogTheme.surface)
                            .foregroundColor(selectedFilter == filter ? .white : CatalogTheme.deepAccent)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

public struct AdminWarehouseCard: View {
    let warehouse: Warehouse
    @ObservedObject var viewModel: WarehouseViewModel
    
    public var body: some View {
        NavigationLink(destination: WarehouseDetailView(viewModel: viewModel, warehouse: warehouse)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(warehouse.name)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                        Text(warehouse.location)
                            .font(.subheadline)
                            .foregroundColor(CatalogTheme.secondaryText)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        statusBadge(for: warehouse.status ?? "active")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(CatalogTheme.mutedText)
                    }
                }

                Rectangle()
                    .fill(CatalogTheme.divider)
                    .frame(height: 1)

                if let address = warehouse.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13))
                        .foregroundColor(CatalogTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CatalogTheme.cardCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func statusBadge(for status: String) -> some View {
        let isActive = status.lowercased() == "active"
        let bgColor: Color = isActive ? CatalogTheme.surface : CatalogTheme.inactiveBadge
        let fgColor: Color = isActive ? CatalogTheme.primary : CatalogTheme.inactiveBadgeText

        Text(status.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bgColor)
            .foregroundColor(fgColor)
            .clipShape(Capsule())
    }
}
