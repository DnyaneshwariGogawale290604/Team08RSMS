import SwiftUI

public struct DashboardTabView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @StateObject private var exceptionEngine = ExceptionEngine.shared
    @Binding var selectedTab: Int // To navigate to Tab 1 (Workflows) or Tab 2 (Items)
    @Binding var prefilledSKUMagic: String? // Pass state to Transfers/PO tab
    @Binding var categoryFilterMagic: String? // Pass state to Items tab
    @Binding var repairFilter: ItemsTabView.RepairFilter // Pass state to Items tab for repair filter
    public var onAccountTapped: (() -> Void)? = nil
    
    @State private var showExceptions = false
    
    public init(selectedTab: Binding<Int>, prefilledSKUMagic: Binding<String?>, categoryFilterMagic: Binding<String?>, repairFilter: Binding<ItemsTabView.RepairFilter>, onAccountTapped: (() -> Void)? = nil) {
        self._selectedTab = selectedTab
        self._prefilledSKUMagic = prefilledSKUMagic
        self._categoryFilterMagic = categoryFilterMagic
        self._repairFilter = repairFilter
        self.onAccountTapped = onAccountTapped
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        quickStatsSection
                        itemsStockLevelsSection
                        exceptionsHandlingSummarySection
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let onAccountTapped = onAccountTapped {
                        Button(action: onAccountTapped) {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(Color.appPrimaryText)
                        }
                    }
                }
            }
            .sheet(isPresented: $showExceptions) {
                ExceptionsDashboardView()
            }
            .task {
                await viewModel.loadDashboardData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExceptionResolved"))) { _ in
                Task {
                    await viewModel.loadDashboardData()
                }
            }
        }
    }
    

    @ViewBuilder
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Stats")
                .headingStyle()
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        categoryFilterMagic = nil
                        selectedTab = 3 // Items tab
                    }) {
                        compactStatCard(title: "Available", value: "\(viewModel.availableCount)", icon: "checkmark.circle.fill", color: .green)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        selectedTab = 2 // Workflows tab
                    }) {
                        compactStatCard(title: "In Transit", value: "\(viewModel.inTransitCount)", icon: "box.truck.fill", color: .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        selectedTab = 1 // Requests tab
                    }) {
                        compactStatCard(title: "Pending", value: "\(viewModel.pendingItemCount)", icon: "clock.fill", color: .orange)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        selectedTab = 2 // Workflows tab
                    }) {
                        compactStatCard(title: "Active POs", value: "\(viewModel.activePOItemCount)", icon: "shippingbox.fill", color: .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        categoryFilterMagic = nil
                        repairFilter = .underRepair
                        selectedTab = 3 // Items tab
                    }) {
                        compactStatCard(title: "Repairs", value: "\(viewModel.repairCount)", icon: "wrench.and.screwdriver.fill", color: .orange)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        categoryFilterMagic = nil
                        repairFilter = .missingScan
                        selectedTab = 3 // Items tab
                    }) {
                        compactStatCard(title: "Missing Scan", value: "\(viewModel.missingScanCount)", icon: "exclamationmark.triangle.fill", color: .appBrown)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private func compactStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(Color.appPrimaryText)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .serif))
                .foregroundColor(Color.appSecondaryText)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 120, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(AppTheme.cardCornerRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).stroke(Color.appBorder, lineWidth: 1))
    }
    
    @ViewBuilder
    private var itemsStockLevelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items Stock Levels")
                .headingStyle()
                .padding(.horizontal)
            
            ForEach(viewModel.categories, id: \.self) { category in
                Button(action: {
                    categoryFilterMagic = category
                    selectedTab = 3 // Items tab
                }) {
                    categoryCard(for: category)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var exceptionsHandlingSummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reconciliation Queue")
                .headingStyle()
                .padding(.horizontal)
            
            Button(action: { showExceptions = true }) {
                ReusableCardView {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active Exceptions")
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundColor(Color.appPrimaryText)
                            Text("\(exceptionEngine.exceptions.count) issues require review")
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(Color.appSecondaryText)
                        }
                        Spacer()
                        
                        HStack(spacing: 8) {
                            if exceptionEngine.missingCount > 0 {
                                ExceptionBadge(count: exceptionEngine.missingCount, color: .red)
                            }
                            if exceptionEngine.mismatchCount > 0 {
                                ExceptionBadge(count: exceptionEngine.mismatchCount, color: .orange)
                            }
                            if exceptionEngine.duplicateCount > 0 {
                                ExceptionBadge(count: exceptionEngine.duplicateCount, color: .yellow)
                            }
                            if exceptionEngine.damagedCount > 0 {
                                ExceptionBadge(count: exceptionEngine.damagedCount, color: .red)
                            }
                            if exceptionEngine.shortageCount > 0 {
                                ExceptionBadge(count: exceptionEngine.shortageCount, color: .orange)
                            }
                            
                            if exceptionEngine.exceptions.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
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
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(Color.appPrimaryText)
                
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(Color.appSecondaryText)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(AppTheme.cardCornerRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).stroke(Color.appBorder, lineWidth: 1))
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
                Text(category).font(.system(size: 15, weight: .bold, design: .serif)).foregroundColor(Color.appPrimaryText)
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
                    RoundedRectangle(cornerRadius: 4).fill(Color.appAccent)
                        .frame(width: max(geometry.size.width * percent, 0))
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("\(count) items available").font(.caption2).foregroundColor(Color.appSecondaryText)
                Spacer()
                Text("Target \(categoryTarget)")
                    .font(.caption2)
                    .foregroundColor(Color.appSecondaryText)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(AppTheme.cardCornerRadius)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius).stroke(Color.appBorder, lineWidth: 1))
        .padding(.horizontal)
    }

}

struct ExceptionBadge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}
