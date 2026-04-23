import SwiftUI

public struct AdminStoreListView: View {
    @ObservedObject var viewModel: StoreViewModel
    @Binding var showingAddStore: Bool
    @State private var storePendingDelete: Store?
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.stores.isEmpty {
                LoadingView(message: "Loading Stores...")
            } else if viewModel.stores.isEmpty {
                EmptyStateView(
                    icon: "storefront",
                    title: "No Stores",
                    message: "Your stores will appear here."
                )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.stores) { store in
                            AdminStoreCard(
                                viewModel: viewModel,
                                store: store,
                                onDelete: { storePendingDelete = store }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .background(CatalogTheme.background)
                .refreshable { await viewModel.fetchStores() }
            }
        }
        .alert("Delete Store?", isPresented: Binding(
            get: { storePendingDelete != nil },
            set: { if !$0 { storePendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { storePendingDelete = nil }
            Button("Delete", role: .destructive) {
                guard let storeId = storePendingDelete?.id else { return }
                storePendingDelete = nil
                Task { await viewModel.deleteStore(storeId: storeId) }
            }
        } message: {
            Text("This will permanently remove the store.")
        }
    }
}

public struct AdminStoreCard: View {
    @ObservedObject var viewModel: StoreViewModel
    public let store: Store
    public let onDelete: () -> Void
    
    public init(viewModel: StoreViewModel, store: Store, onDelete: @escaping () -> Void) {
        self.viewModel = viewModel
        self.store = store
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text(store.location)
                        .font(.subheadline)
                        .foregroundColor(CatalogTheme.secondaryText)
                }
                Spacer()
                statusBadge(for: store.status ?? "active")
            }

            Rectangle()
                .fill(CatalogTheme.divider)
                .frame(height: 1)

            // Sales metrics
            VStack(alignment: .leading, spacing: 12) {
                let performance = viewModel.storePerformance[store.id] ?? 0.0

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sales Target")
                            .font(.caption)
                            .foregroundColor(CatalogTheme.mutedText)
                        Text(salesTargetText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(CatalogTheme.deepAccent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Performance")
                            .font(.caption)
                            .foregroundColor(CatalogTheme.mutedText)
                        Text(String(format: "₹%.2f", performance))
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(CatalogTheme.primary)
                    }
                }

                if let target = store.salesTarget, target > 0 {
                    let progress = min(1.0, performance / target)
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(CatalogTheme.surface)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(CatalogTheme.primary)
                                    .frame(width: geo.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text(String(format: "%.1f%% achieved", progress * 100))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CatalogTheme.mutedText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                NavigationLink(destination: StoreDetailView(viewModel: viewModel, store: store)) {
                    Text("Manage")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(CatalogTheme.deepAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
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

    private var salesTargetText: String {
        guard let target = store.salesTarget else { return "₹0.00" }
        return String(format: "₹%.2f", target)
    }
    
    @ViewBuilder
    private func statusBadge(for status: String) -> some View {
        let isActive = status.lowercased() == "active"
        let isMaintenance = status.lowercased().contains("maintenance")
        let bgColor: Color = isActive ? CatalogTheme.surface : Color(hex: "#F0E0E0")
        let fgColor: Color = isActive ? CatalogTheme.primary : CatalogTheme.deepAccent

        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bgColor)
            .foregroundColor(fgColor)
            .clipShape(Capsule())
    }
}
