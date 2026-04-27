import SwiftUI

public struct DashboardView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    public var onAccountTapped: (() -> Void)? = nil
    
    public init(onAccountTapped: (() -> Void)? = nil) {
        self.onAccountTapped = onAccountTapped
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Stock Summary Cards
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Stock Summary")
                                .font(.headline)
                                .foregroundColor(CatalogTheme.primaryText)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                statCard(title: "Available", value: "\(viewModel.availableCount)", icon: "checkmark.circle.fill", color: .green)
                                statCard(title: "In Transit", value: "\(viewModel.inTransitCount)", icon: "box.truck.fill", color: .blue)
                                statCard(title: "Pending Req", value: "\(viewModel.pendingRequests.count)", icon: "clock.fill", color: .orange)
                                statCard(title: "Active POs", value: "\(viewModel.activePurchaseOrderCount)", icon: "shippingbox.circle.fill", color: .blue)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 16)
                        
                        // Items Stock Levels
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Items Stock Levels")
                                .font(.headline)
                                .foregroundColor(CatalogTheme.primaryText)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.categories, id: \.self) { category in
                                categoryCard(for: category)
                            }
                        }
                        
                    }
                    .padding(.bottom, 20)
                }
                .refreshable { 
                    await viewModel.loadDashboardData()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let onAccountTapped = onAccountTapped {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onAccountTapped) {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadDashboardData()
            }
        }
    }
    
    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .padding(10)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(CatalogTheme.primaryText)
                
            Text(title)
                .font(.subheadline)
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .padding(16)
        .appCardChrome()
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
        
        // Check if any product in this category has an active vendor order
        let categoryProductIds = viewModel.products
            .filter { ($0.category.isEmpty ? "General" : $0.category) == category }
            .map { $0.id }
        let hasActiveOrder = categoryProductIds.contains(where: { viewModel.orderedProductIds.contains($0) })
        
        VStack(spacing: 8) {
            HStack {
                Text(category).font(.subheadline.bold()).foregroundColor(CatalogTheme.primaryText)
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
                Text("\(count) items available").font(.caption2).foregroundColor(CatalogTheme.secondaryText)
                Spacer()
                Text("Target \(categoryTarget)")
                    .font(.caption2)
                    .foregroundColor(CatalogTheme.secondaryText)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal)
    }

}
