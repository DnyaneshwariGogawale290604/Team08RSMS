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
                                statCard(title: "Reserved", value: "\(viewModel.reservedCount)", icon: "lock.fill", color: .orange)
                                statCard(title: "In Transit", value: "\(viewModel.inTransitCount)", icon: "box.truck.fill", color: .blue)
                                statCard(title: "Sold", value: "\(viewModel.soldCount)", icon: "cart.fill", color: .gray)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 16)
                        
                        // Recent Transfers
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Recent Transfers")
                                    .font(.headline)
                                    .foregroundColor(CatalogTheme.primaryText)
                                Spacer()
                                NavigationLink("View All", destination: TransfersTabView(selectedTab: .constant(1), prefilledSKUMagic: .constant(nil as String?)))
                                    .font(.subheadline)
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal)
                            
                            if viewModel.recentActivity.isEmpty {
                                EmptyStateView(icon: "arrow.left.arrow.right", title: "No Transfers", message: "No active transfers running.")
                            } else {
                                ForEach(viewModel.recentActivity.prefix(3), id: \.id) { shipment in
                                    transferRow(for: shipment)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
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
                        
                        // Low Stock Alerts
                        let criticals = viewModel.criticalSKUs
                        if !criticals.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("LOW STOCK ALERTS")
                                    Spacer()
                                    Text("\(criticals.count) items")
                                }
                                .font(.caption.bold())
                                .foregroundColor(Color(red: 0.6, green: 0.45, blue: 0.45))
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                VStack(spacing: 12) {
                                    ForEach(criticals, id: \.id) { product in
                                        let items = viewModel.storeInventory.filter { $0.productId == product.id }
                                        let qty = items.reduce(0) { $0 + $1.quantity }
                                        alertCard(product: product, quantity: qty)
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                            .background(Color(red: 0.97, green: 0.94, blue: 0.93))
                            .cornerRadius(20)
                            .padding(.horizontal)
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
    private func transferRow(for shipment: Shipment) -> some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(shipment.request?.product?.name ?? "Order ID: \(shipment.id.uuidString.prefix(6))")
                        .font(.subheadline.bold())
                        .foregroundColor(CatalogTheme.primaryText)
                    Spacer()
                    Text(shipment.status.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.appAccent.opacity(0.16))
                        .foregroundColor(.appAccent)
                        .cornerRadius(6)
                }
                Text("To: Store")
                    .font(.caption)
                    .foregroundColor(CatalogTheme.secondaryText)
            }
        }
    }
    
    @ViewBuilder
    private func categoryCard(for category: String) -> some View {
        let count = viewModel.availableItems(for: category)
        let percent = min(Double(count) / 10.0, 1.0)
        let statusColor: Color = percent > 0.5 ? .green : (percent > 0.2 ? .orange : .red)
        let statusBadge: String = percent > 0.5 ? "Good" : (percent > 0.2 ? "Low" : "Very Low")
        
        VStack(spacing: 8) {
            HStack {
                Text(category).font(.subheadline.bold()).foregroundColor(CatalogTheme.primaryText)
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
                Text("\(count) items available").font(.caption2).foregroundColor(CatalogTheme.secondaryText)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundColor(CatalogTheme.secondaryText)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func alertCard(product: Product, quantity: Int) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.88, green: 0.8, blue: 0.78))
                    .frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.3))
                    .font(.subheadline)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.black.opacity(0.85))
                Text(product.category.isEmpty ? "General" : product.category)
                    .font(.caption)
                    .foregroundColor(Color.black.opacity(0.5))
            }
            
            Spacer()
            
            // Quantity
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(quantity)")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.2))
                Text("left")
                    .font(.caption2)
                    .foregroundColor(Color.black.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
