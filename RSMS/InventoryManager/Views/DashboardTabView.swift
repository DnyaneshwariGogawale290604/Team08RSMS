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
                        
                        // 2. Category Stock Cards
                        categoriesSection()
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
    private func categoriesSection() -> some View {
        let categories = viewModel.categories
        
        VStack(alignment: .leading, spacing: 10) {
            Text("Categories")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
                .padding(.horizontal)
            
            ForEach(categories, id: \.self) { category in
                Button(action: {
                    categoryFilterMagic = category
                    selectedTab = 2 // Assuming Tab 2 is Items
                }) {
                    categoryCard(for: category)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func categoryCard(for category: String) -> some View {
        let count = viewModel.availableItems(for: category)
        let categoryProducts = viewModel.products
            .filter { ($0.category.isEmpty ? "General" : $0.category) == category }
        let categoryTarget = max(categoryProducts.reduce(0) { $0 + max($1.reorderPoint ?? 5, 1) }, 1)
        let percent = min(Double(count) / Double(categoryTarget), 1.0)
        let statusColor: Color = percent >= 1.0 ? .green : (percent >= 0.5 ? .orange : .red)
        let statusBadge: String = percent >= 1.0 ? "Good" : (percent >= 0.5 ? "Low" : "Very Low")
        
        VStack(spacing: 8) {
            HStack {
                Text(category).font(.subheadline.bold()).foregroundColor(.appPrimaryText)
                Spacer()
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
                Text("Target \(categoryTarget)")
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
