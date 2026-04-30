import SwiftUI

public struct AdminStoreListView: View {
    @ObservedObject var viewModel: StoreViewModel
    @Binding var showingAddStore: Bool
    @State private var storePendingArchive: Store?
    
    private var filteredStores: [Store] {
        viewModel.stores.filter { ($0.status ?? "active").lowercased() != "inactive" }
    }

    private var archivedStores: [Store] {
        viewModel.stores.filter { ($0.status ?? "").lowercased() == "inactive" }
    }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.stores.isEmpty {
                LoadingView(message: "Loading Stores...")
            } else {
                if viewModel.stores.isEmpty {
                    EmptyStateView(
                        icon: "storefront",
                        title: "No Stores",
                        message: "Your stores will appear here."
                    )
                } else {
                    LazyVStack(spacing: 24) {
                        // Active/Filtered Section
                        ForEach(filteredStores) { store in
                            AdminStoreCard(
                                viewModel: viewModel,
                                store: store,
                                onArchive: { storePendingArchive = store }
                            )
                        }

                        // Archived Section
                        if !archivedStores.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Temporarily Unavailable Stores")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.secondaryText)
                                    .padding(.horizontal, 4)
                                
                                ForEach(archivedStores) { store in
                                    AdminStoreCard(
                                        viewModel: viewModel,
                                        store: store,
                                        onArchive: { storePendingArchive = store }
                                    )
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
        .alert("Archive Store?", isPresented: Binding(
            get: { storePendingArchive != nil },
            set: { if !$0 { storePendingArchive = nil } }
        )) {
            Button("Cancel", role: .cancel) { storePendingArchive = nil }
            Button("Archive", role: .destructive) {
                guard let storeId = storePendingArchive?.id else { return }
                storePendingArchive = nil
                Task { await viewModel.archiveStore(storeId: storeId) }
            }
        } message: {
            Text("This will mark the store as inactive.")
        }
    }

}

public struct AdminStoreCard: View {
    @ObservedObject var viewModel: StoreViewModel
    public let store: Store
    public let onArchive: () -> Void
    
    public init(viewModel: StoreViewModel, store: Store, onArchive: @escaping () -> Void) {
        self.viewModel = viewModel
        self.store = store
        self.onArchive = onArchive
    }
    
    public var body: some View {
        NavigationLink(destination: StoreDetailView(viewModel: viewModel, store: store)) {
            VStack(alignment: .leading, spacing: 16) {
                // Header row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.name)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                        Text(store.location)
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
                
                // Sales metrics
                HStack(alignment: .center) {
                    let performance = viewModel.storePerformance[store.id] ?? 0.0
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sales Performance")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(CatalogTheme.mutedText)
                        Text(String(format: "₹%.2f", performance))
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primary)
                    }
                    
                    Spacer()
                    
                    if let target = store.salesTarget, target > 0 {
                        let progress = min(1.0, performance / target)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Achievement")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundColor(CatalogTheme.mutedText)
                            Text(String(format: "%.1f%%", progress * 100))
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.deepAccent)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CatalogTheme.cardCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var salesTargetText: String {
        guard let target = store.salesTarget else { return "₹0.00" }
        return String(format: "₹%.2f", target)
    }
    
    
}
