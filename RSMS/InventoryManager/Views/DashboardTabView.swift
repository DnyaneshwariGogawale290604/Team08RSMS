import SwiftUI

public struct DashboardTabView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @Binding var selectedTab: Int // To navigate to Tab 2 (PO) or Tab 3 (Items)
    @Binding var prefilledSKUMagic: String? // Pass state to Transfers/PO tab
    @Binding var categoryFilterMagic: String? // Pass state to Items tab

    public init(selectedTab: Binding<Int>, prefilledSKUMagic: Binding<String?>, categoryFilterMagic: Binding<String?>) {
        self._selectedTab = selectedTab
        self._prefilledSKUMagic = prefilledSKUMagic
        self._categoryFilterMagic = categoryFilterMagic
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Four Metric Cards
                        HStack(spacing: 12) {
                            metricCard(title: "Total SKUs", value: "\(viewModel.totalSKUs)", icon: "shippingbox", color: .blue)
                            metricCard(title: "Available", value: "\(viewModel.availableCount)", icon: "checkmark.circle.fill", color: .green)
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            metricCard(title: "Pending Req", value: "\(viewModel.pendingRequests.count)", icon: "clock.fill", color: .orange)
                            metricCard(title: "Active POs", value: "\(viewModel.activePurchaseOrderCount)", icon: "shippingbox.circle.fill", color: .blue)
                        }
                        .padding(.horizontal)
                        
                        // 2. Items Stock Cards
                        itemsSection()
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadDashboardData()
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.appPrimaryText)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.appSecondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func itemsSection() -> some View {
        let items = viewModel.availableStockRows
        
        VStack(alignment: .leading, spacing: 10) {
            Text("Items Stock Levels")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
                .padding(.horizontal)
            
            ForEach(items, id: \.id) { item in
                Button(action: {
                    if let category = item.product?.category, !category.isEmpty {
                        categoryFilterMagic = category
                    } else {
                        categoryFilterMagic = "General"
                    }
                    selectedTab = 2 // Assuming Tab 2 is Items
                }) {
                    itemCard(for: item)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func itemCard(for item: InventoryDashboardViewModel.AvailableStockRow) -> some View {
        let count = item.quantity
        let target = max(item.product?.reorderPoint ?? 5, 1)
        let percent = min(Double(count) / Double(target), 1.0)
        let statusColor: Color = percent >= 1.0 ? .green : (percent >= 0.5 ? .orange : .red)
        let statusBadge: String = percent >= 1.0 ? "Good" : (percent >= 0.5 ? "Low" : "Very Low")
        let productName = item.product?.name ?? "Unknown Item"
        
        // Check if this product has an active vendor order
        let hasActiveOrder = viewModel.orderedProductIds.contains(item.productId)
        
        VStack(spacing: 8) {
            HStack {
                Text(productName).font(.subheadline.bold()).foregroundColor(.appPrimaryText)
                Spacer()
                if hasActiveOrder {
                    Text("Order Placed")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                Text(statusBadge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.appBorder)
                    RoundedRectangle(cornerRadius: 4).fill(statusColor)
                        .frame(width: max(geometry.size.width * percent, 0))
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("\(count) items available").font(.caption2).foregroundColor(.appSecondaryText)
                Spacer()
                Text("Target \(target)")
                    .font(.caption2)
                    .foregroundColor(.appSecondaryText)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal)
    }

}
