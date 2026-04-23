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
                    // Luxury pill segmented control
                    HStack(spacing: 0) {
                        ForEach(LocationTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selectedTab = tab
                                }
                            }) {
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTab == tab ? .white : CatalogTheme.deepAccent)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(
                                        Group {
                                            if selectedTab == tab {
                                                Capsule(style: .continuous)
                                                    .fill(CatalogTheme.primary)
                                                    .padding(4)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Capsule(style: .continuous).fill(CatalogTheme.surface))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    
                    if selectedTab == .stores {
                        AdminStoreListView(viewModel: storeViewModel, showingAddStore: $showingAddStore)
                    } else {
                        AdminWarehouseListView(viewModel: warehouseViewModel, showingAddWarehouse: $showingAddWarehouse)
                    }
                }
            }
            .navigationTitle("Infrastructure")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        if selectedTab == .stores {
                            showingAddStore = true
                        } else {
                            showingAddWarehouse = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: AppTheme.toolbarButtonSize, height: AppTheme.toolbarButtonSize)
                            .background(Circle().fill(CatalogTheme.deepAccent))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
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
