import SwiftUI

public struct StoreListView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var storeViewModel = StoreViewModel()
    @StateObject private var warehouseViewModel = WarehouseViewModel()
    @State private var selectedTab: LocationTab = .stores
    
    @State private var showingAddStore = false
    @State private var showingAddWarehouse = false
    
    enum LocationTab: String, CaseIterable {
        case stores = "Stores"
        case warehouses = "Warehouses"
    }
    
    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    AppSegmentedControl(
                        options: [
                            AppSegmentedOption(id: LocationTab.stores, title: "Stores"),
                            AppSegmentedOption(id: LocationTab.warehouses, title: "Warehouses")
                        ],
                        selection: $selectedTab
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    if selectedTab == .stores {
                        AdminStoreListView(viewModel: storeViewModel, showingAddStore: $showingAddStore)
                    } else {
                        AdminWarehouseListView(viewModel: warehouseViewModel, showingAddWarehouse: $showingAddWarehouse)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Infrastructure")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        if selectedTab == .stores {
                            showingAddStore = true
                        } else {
                            showingAddWarehouse = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CatalogTheme.primaryText)
                    }

                    CorporateAdminProfileButton(sessionViewModel: sessionViewModel)
                }
            }
            .onAppear {
                // Ensure title is restored when returning from details
                // Standard navigationTitle handles this, but explicit refresh can help with some SwiftUI bugs
            }
            .task {
                await storeViewModel.fetchStores()
                await warehouseViewModel.fetchWarehouses()
            }

            .sheet(isPresented: $showingAddStore) {
                StoreFormView(viewModel: storeViewModel)
            }
            .sheet(isPresented: $showingAddWarehouse) {
                WarehouseFormView(viewModel: warehouseViewModel)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Infrastructure")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)

            Text("Manage and oversee your brand's physical locations")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
