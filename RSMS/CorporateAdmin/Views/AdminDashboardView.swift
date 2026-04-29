import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var adminViewModel = AdminViewModel()
    @StateObject private var storeViewModel = StoreViewModel()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @ObservedObject private var engine = InventoryEngine.shared

    @State private var showingApprovalDialog = false
    @State private var selectedDemand: VendorOrder? = nil
    @State private var approvalReason: String = ""

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    private var activeProductCount: Int {
        productViewModel.products.filter { $0.isActive ?? true }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Summary Section (Graphical)
                        grossSalesCard

                        if adminViewModel.isLoading || storeViewModel.isLoading || productViewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView("Updating...")
                                    .tint(CatalogTheme.primary)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                        }
                        
                        // Category Insights (Moved Up)
                        categorySalesCard
                        
                        // Performance Analytics (Moved Down)
                        topPerformingStoresCard

                        // Actionable Alerts
                        let pendingVendorOrders = adminViewModel.pendingVendorOrders
                        if !pendingVendorOrders.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(CatalogTheme.primary)
                                    Text("Pending Approvals")
                                        .font(.system(size: 20, weight: .bold, design: .serif))
                                        .foregroundColor(CatalogTheme.primaryText)
                                }
                                
                                ForEach(pendingVendorOrders) { demand in
                                    approvalAlertCard(for: demand)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    CorporateAdminProfileButton(sessionViewModel: sessionViewModel)
                }
            }
            .refreshable {
                await refreshData()
            }
            .task {
                await refreshData()
            }
            // Dialog for processing approval/rejection
            .alert("Process Vendor Order", isPresented: $showingApprovalDialog, presenting: selectedDemand) { demand in
                TextField("Add Reason (Optional)", text: $approvalReason)
                Button("Approve", action: {
                    Task {
                        await adminViewModel.approveVendorOrder(id: demand.id)
                        approvalReason = ""
                    }
                })
                Button("Reject", role: .destructive, action: {
                    Task {
                        await adminViewModel.rejectVendorOrder(id: demand.id, reason: approvalReason.isEmpty ? "Rejected due to policy limitations" : approvalReason)
                        approvalReason = ""
                    }
                })
                Button("Cancel", role: .cancel, action: {
                    approvalReason = ""
                })
            } message: { demand in
                Text("Process PO for \(demand.quantity ?? 0)x \(demand.product?.name ?? "Items")")
            }
        }
    }

    // MARK: - Gross Sales vs Target Card

    private var grossSalesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Gross Sales vs Target")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
                
                Spacer()

                if dashboardViewModel.isSalesLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(CatalogTheme.primary)
                }
            }

            HStack(spacing: 24) {
                // Achievement Ring
                ActivityRingView(progress: dashboardViewModel.totalTarget > 0 ? dashboardViewModel.grossSales / dashboardViewModel.totalTarget : 0)
                    .frame(width: 140, height: 140)
                
                VStack(alignment: .leading, spacing: 16) {
                    salesMetricRow(
                        label: "Current Sales",
                        value: formatCurrency(dashboardViewModel.grossSales),
                        color: CatalogTheme.primary,
                        icon: "indianrupeesign.circle.fill"
                    )
                    
                    salesMetricRow(
                        label: "Total Target",
                        value: formatCurrency(dashboardViewModel.totalTarget),
                        color: CatalogTheme.secondaryText,
                        icon: "target"
                    )
                    
                    salesMetricRow(
                        label: "Remaining",
                        value: formatCurrency(dashboardViewModel.remainingTarget),
                        color: CatalogTheme.deepAccent,
                        icon: "arrow.right.circle.fill"
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func salesMetricRow(label: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(CatalogTheme.secondaryText)
            }
        }
    }


    private func formatCurrency(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "₹%.1f Cr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "₹%.1f L", value / 100_000)
        } else if value >= 1_000 {
            return String(format: "₹%.1f K", value / 1_000)
        } else {
            return String(format: "₹%.0f", value)
        }
    }

    // MARK: - Metric Card

    // MARK: - Category-wise Sales Card

    @State private var selectedStore: StorePerformance? = nil

    private var categorySalesCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sales by Category")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text("Revenue distribution across categories")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                Spacer()

                if dashboardViewModel.isCategoryLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(CatalogTheme.primary)
                }
            }

            if dashboardViewModel.categorySales.isEmpty && !dashboardViewModel.isCategoryLoading {
                emptyDataPlaceholder(icon: "chart.bar.xaxis", message: "No sales data available")
            } else {
                let totalAllCategories = dashboardViewModel.categorySales.reduce(0) { $0 + $1.totalSales }
                
                HStack(spacing: 24) {
                    // Pie Chart
                    CategoryPieChartView(data: dashboardViewModel.categorySales, total: totalAllCategories)
                        .frame(width: 140, height: 140)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(dashboardViewModel.categorySales.prefix(5).enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(categoryColor(at: index))
                                    .frame(width: 8, height: 8)
                                
                                Text(item.category)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(CatalogTheme.primaryText)
                                
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var topPerformingStoresCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Performing Stores")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text("Ranked by target achievement")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                Spacer()

                if dashboardViewModel.isTopStoresLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if dashboardViewModel.topPerformingStores.isEmpty && !dashboardViewModel.isTopStoresLoading {
                emptyDataPlaceholder(icon: "storefront", message: "No data for current month")
            } else {
                // Podium View for Top 3
                StorePodiumView(stores: Array(dashboardViewModel.topPerformingStores.prefix(3))) { store in
                    selectedStore = store
                }
                .padding(.vertical, 10)

                if dashboardViewModel.topPerformingStores.count > 3 {
                    NavigationLink(destination: AllStoresPerformanceView(stores: dashboardViewModel.topPerformingStores)) {
                        HStack {
                            Spacer()
                            Text("Show All Stores")
                                .font(.subheadline.bold())
                                .foregroundColor(CatalogTheme.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(CatalogTheme.primary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(CatalogTheme.surface.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        .sheet(item: $selectedStore) { performance in
            StorePerformanceDetailView(performance: performance)
        }
    }

    @ViewBuilder
    private func emptyDataPlaceholder(icon: String, message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(CatalogTheme.secondaryText)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(CatalogTheme.secondaryText)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private func categoryColor(at index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#6E5155"), // Theme Primary
            Color(hex: "#E67E22"), // Orange
            Color(hex: "#27AE60"), // Green
            Color(hex: "#2980B9"), // Blue
            Color(hex: "#8E44AD"), // Purple
            Color(hex: "#C0392B"), // Red
            Color(hex: "#F1C40F"), // Yellow
            Color(hex: "#16A085")  // Teal
        ]
        return colors[index % colors.count]
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CatalogTheme.surface)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CatalogTheme.primary)
            }

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(CatalogTheme.primaryText)

            Text(title)
                .font(.footnote)
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func approvalAlertCard(for demand: VendorOrder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(CatalogTheme.deepAccent)
                    Text("Vendor Order")
                        .font(.subheadline.bold())
                        .foregroundColor(CatalogTheme.primaryText)
                }

                Text("\(demand.quantity ?? 0)x \(demand.product?.name ?? "")")
                    .font(.footnote)
                    .foregroundColor(CatalogTheme.secondaryText)
            }

            Spacer()

            Button("Review") {
                selectedDemand = demand
                showingApprovalDialog = true
            }
            .font(.caption.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CatalogTheme.surface)
            .foregroundColor(CatalogTheme.deepAccent)
            .clipShape(Capsule())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func refreshData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await adminViewModel.loadInitialData() }
            group.addTask { await storeViewModel.fetchStores() }
            group.addTask { await productViewModel.fetchProducts() }
            group.addTask { await dashboardViewModel.fetchGrossSalesVsTarget() }
            group.addTask { await dashboardViewModel.fetchCategoryWiseSales() }
            group.addTask { await dashboardViewModel.fetchTopPerformingStores() }
        }
    }
}

// MARK: - Subviews

struct GrossSalesPieChartView: View {
    let sales: Double
    let target: Double
    
    var achievementPercentage: Double {
        guard target > 0 else { return 0 }
        return min(sales / target, 1.0)
    }
    
    var body: some View {
        ZStack {
            // Background Circle (Target)
            Circle()
                .fill(CatalogTheme.surface.opacity(0.5))
            
            // Progress Segment (Sales)
            PieSegment(
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + (achievementPercentage * 360))
            )
            .fill(
                LinearGradient(
                    colors: [CatalogTheme.primary, CatalogTheme.deepAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Remaining Segment (if any)
            if achievementPercentage < 1.0 {
                PieSegment(
                    startAngle: .degrees(-90 + (achievementPercentage * 360)),
                    endAngle: .degrees(270)
                )
                .fill(CatalogTheme.surface)
                .opacity(0.5)
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 115, height: 115)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", achievementPercentage * 100))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
                Text("Achieved")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(CatalogTheme.secondaryText)
            }
        }
    }
}

struct CategoryPieChartView: View {
    let data: [CategorySales]
    let total: Double
    
    // Distinct vibrant color palette
    private let distinctColors: [Color] = [
        Color(hex: "#6E5155"), // Theme Primary
        Color(hex: "#E67E22"), // Orange
        Color(hex: "#27AE60"), // Green
        Color(hex: "#2980B9"), // Blue
        Color(hex: "#8E44AD"), // Purple
        Color(hex: "#C0392B"), // Red
        Color(hex: "#F1C40F"), // Yellow
        Color(hex: "#16A085")  // Teal
    ]
    
    var body: some View {
        ZStack {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                PieSegment(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .fill(distinctColors[index % distinctColors.count])
                .overlay(
                    PieSegment(
                        startAngle: startAngle(for: index),
                        endAngle: endAngle(for: index)
                    )
                    .stroke(Color.white, lineWidth: 2)
                )
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 115, height: 115)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            VStack(spacing: 2) {
                Text("Total")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(CatalogTheme.secondaryText)
                Text(formatShortCurrency(total))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
            }
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let proportion = data.prefix(index).reduce(0) { $0 + $1.totalSales } / total
        return .degrees(proportion * 360 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let proportion = data.prefix(index + 1).reduce(0) { $0 + $1.totalSales } / total
        return .degrees(proportion * 360 - 90)
    }
    
    private func formatShortCurrency(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "₹%.1fCr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "₹%.1fL", value / 100_000)
        } else if value >= 1_000 {
            return String(format: "₹%.1fK", value / 1_000)
        } else {
            return String(format: "₹%.0f", value)
        }
    }
}

struct PieSegment: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: rect.width / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}

struct StorePodiumView: View {
    let stores: [StorePerformance]
    let onSelect: (StorePerformance) -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Rank 2
            if stores.count > 1 {
                podiumItem(performance: stores[1], rank: 2, size: 75, color: Color(hex: "#A0A0A0"))
            } else {
                Spacer().frame(width: 75)
            }
            
            // Rank 1
            if stores.count > 0 {
                podiumItem(performance: stores[0], rank: 1, size: 100, color: Color(hex: "#FFD700"))
            } else {
                Spacer().frame(width: 100)
            }
            
            // Rank 3
            if stores.count > 2 {
                podiumItem(performance: stores[2], rank: 3, size: 75, color: Color(hex: "#CD7F32"))
            } else {
                Spacer().frame(width: 75)
            }
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
    
    private func podiumItem(performance: StorePerformance, rank: Int, size: CGFloat, color: Color) -> some View {
        Button(action: { onSelect(performance) }) {
            VStack(spacing: 12) {
                ZStack(alignment: .top) {
                    // Avatar Circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [CatalogTheme.surface, CatalogTheme.surface.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(CatalogTheme.primary.opacity(0.7))
                    }
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Rank Badge
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                        Text("\(rank)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                    }
                    .offset(y: -size * 0.1)
                }
                
                VStack(spacing: 4) {
                    Text(performance.store.name)
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    
                    Text(formatShortCurrency(performance.totalSales))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CatalogTheme.primary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatShortCurrency(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "₹%.2fCr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "₹%.2fL", value / 100_000)
        } else if value >= 1_000 {
            return String(format: "₹%.2fK", value / 1_000)
        } else {
            return String(format: "₹%.0f", value)
        }
    }
}

