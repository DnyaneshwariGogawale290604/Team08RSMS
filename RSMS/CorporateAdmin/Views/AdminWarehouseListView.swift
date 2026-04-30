import SwiftUI

public struct AdminWarehouseListView: View {
    @ObservedObject var viewModel: WarehouseViewModel
    @Binding var showingAddWarehouse: Bool
    

    private var filteredWarehouses: [Warehouse] {
        viewModel.warehouses.filter { ($0.status ?? "active").lowercased() != "inactive" }
    }

    private var archivedWarehouses: [Warehouse] {
        viewModel.warehouses.filter { ($0.status ?? "").lowercased() == "inactive" }
    }

    public var body: some View {
            if viewModel.isLoading && viewModel.warehouses.isEmpty {
                LoadingView(message: "Loading Warehouses...")
            } else {
                VStack(spacing: 0) {
                    if viewModel.warehouses.isEmpty {
                        EmptyStateView(
                            icon: "building.2.fill",
                            title: "No Warehouses",
                            message: "Your warehouses will appear here."
                        )
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(filteredWarehouses) { warehouse in
                                AdminWarehouseCard(warehouse: warehouse, viewModel: viewModel)
                            }

                            if !archivedWarehouses.isEmpty {
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
                }
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
                            .font(.system(size: 15, design: .serif))
                            .foregroundColor(CatalogTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(CatalogTheme.mutedText)
                }
                
                Rectangle()
                    .fill(CatalogTheme.divider)
                    .frame(height: 1)
                
                if let address = warehouse.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(CatalogTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CatalogTheme.cardCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
            .opacity((warehouse.status ?? "active").lowercased() == "inactive" ? 0.6 : 1.0)
            .grayscale((warehouse.status ?? "active").lowercased() == "inactive" ? 1.0 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
}
