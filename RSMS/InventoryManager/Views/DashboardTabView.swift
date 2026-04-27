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
                            metricCard(title: "Very Low", value: "\(viewModel.criticalSKUs.count)", icon: "exclamationmark.triangle.fill", color: .red)
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            metricCard(title: "Pending Req", value: "\(viewModel.pendingRequests.count)", icon: "clock.fill", color: .orange)
                            metricCard(title: "Stock Health", value: "\(viewModel.stockHealthPercentage)%", icon: "heart.text.square.fill", color: .green)
                        }
                        .padding(.horizontal)

                        // 2. Alerts Section
                        alertsSection()
                        
                        // 3. Category Stock Cards
                        categoriesSection()
                        
                        // 4. Recent Activity
                        activitySection()
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
    private func alertsSection() -> some View {
        let criticals = viewModel.criticalSKUs
        let pending = viewModel.pendingRequests
        
        if !criticals.isEmpty || !pending.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Alerts")
                    .font(.headline)
                    .foregroundColor(.appPrimaryText)
                    .padding(.horizontal)
                
                ForEach(criticals, id: \.id) { product in
                    alertCard(
                        icon: "xmark.octagon.fill",
                        color: .red,
                        title: "Urgent Stock: \(product.name)",
                        message: "Quantity fell below reorder threshold.",
                        action: {
                            prefilledSKUMagic = product.sku ?? product.name
                            selectedTab = 1
                        },
                        buttonText: "Place Vendor Order"
                    )
                }
                
                ForEach(pending, id: \.id) { request in
                    alertCard(icon: "exclamationmark.warning.fill", color: .orange, title: "Pending Approval", message: "Boutique request for \(request.product?.name ?? "a product") requires review.", action: nil, buttonText: "")
                }
            }
        }
    }

    @ViewBuilder
    private func alertCard(icon: String, color: Color, title: String, message: String, action: (() -> Void)?, buttonText: String) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon).foregroundColor(color).font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.bold()).foregroundColor(.appPrimaryText)
                    Text(message).font(.caption).foregroundColor(.appSecondaryText)
                }
                Spacer()
            }
            if let action = action {
                Button(action: action) {
                    Text(buttonText)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(color)
                        .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
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
        
        // Mocking threshold logic (assuming 10 is healthy for now)
        let percent = min(Double(count) / 10.0, 1.0)
        let statusColor: Color = percent > 0.5 ? .green : (percent > 0.2 ? .orange : .red)
        let statusBadge: String = percent > 0.5 ? "Good" : (percent > 0.2 ? "Low" : "Very Low")
        
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
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.appSecondaryText)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func activitySection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                if viewModel.recentActivity.isEmpty {
                    Text("No recent activity.")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                        .padding()
                } else {
                    ForEach(viewModel.recentActivity.prefix(5), id: \.id) { activity in
                        HStack(spacing: 12) {
                            let statusColor: Color = {
                                let s = activity.status.lowercased()
                                if s.contains("transit") || s.contains("dispatch") { return .blue }
                                if s.contains("pending") { return .orange }
                                if s.contains("reject") { return .red }
                                return .green
                            }()
                            
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.request?.product?.name ?? "Shipment")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.appPrimaryText)
                                Text("Status: \(activity.status.capitalized) • ID: \(activity.id.uuidString.prefix(6))")
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                            }
                            Spacer()
                            if let date = activity.createdAt {
                                Text(date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if activity.id != viewModel.recentActivity.prefix(5).last?.id {
                            Divider().background(Color.appBorder)
                        }
                    }
                }
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
            .padding(.horizontal)
        }
    }
}
