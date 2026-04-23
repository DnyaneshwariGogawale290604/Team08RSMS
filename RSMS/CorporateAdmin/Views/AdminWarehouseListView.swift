import SwiftUI

public struct AdminWarehouseListView: View {
    @ObservedObject var viewModel: WarehouseViewModel
    @Binding var showingAddWarehouse: Bool
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.warehouses.isEmpty {
                LoadingView(message: "Loading Warehouses...")
            } else if viewModel.warehouses.isEmpty {
                EmptyStateView(
                    icon: "building.2.fill",
                    title: "No Warehouses",
                    message: "Your warehouses will appear here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.warehouses) { warehouse in
                            AdminWarehouseCard(warehouse: warehouse, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
                .refreshable { await viewModel.fetchWarehouses() }
            }
        }
    }
}

public struct AdminWarehouseCard: View {
    let warehouse: Warehouse
    @ObservedObject var viewModel: WarehouseViewModel
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Name, Location and Toggle
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(warehouse.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CatalogTheme.primaryText)

                    Text(warehouse.location)
                        .font(.subheadline)
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                Spacer()

                HStack(spacing: 8) {
                    let isActive = warehouse.status == "active"
                    Text(isActive ? "Active" : "Inactive")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(isActive ? CatalogTheme.primary : CatalogTheme.deepAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isActive ? CatalogTheme.surface : Color(hex: "#F0E0E0"))
                        .clipShape(Capsule())

                    Toggle("", isOn: Binding(
                        get: { warehouse.status == "active" },
                        set: { _ in
                            Task {
                                await viewModel.toggleWarehouseStatus(warehouseId: warehouse.id, currentStatus: warehouse.status)
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: CatalogTheme.primary))
                    .scaleEffect(0.7)
                }
            }

            Rectangle()
                .fill(CatalogTheme.divider)
                .frame(height: 1)

            // Actions
            HStack(spacing: 12) {
                NavigationLink(destination: WarehouseDetailView(viewModel: viewModel, warehouse: warehouse)) {
                    Text("Manage")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(CatalogTheme.deepAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: {
                    // Delete action if needed
                }) {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(CatalogTheme.deepAccent)
                        .background(CatalogTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CatalogTheme.divider, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}
