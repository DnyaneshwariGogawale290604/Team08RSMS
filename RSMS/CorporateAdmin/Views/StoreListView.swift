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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
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
                .navigationTitle("Stores")
            }
            .background(CatalogTheme.background)
            .refreshable {
                if selectedTab == .stores {
                    await storeViewModel.fetchStores()
                } else {
                    await warehouseViewModel.fetchWarehouses()
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
}
