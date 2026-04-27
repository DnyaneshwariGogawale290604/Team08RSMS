import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var adminViewModel = AdminViewModel()
    @StateObject private var storeViewModel = StoreViewModel()
    @StateObject private var productViewModel = ProductViewModel()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @ObservedObject private var engine = InventoryEngine.shared

    @State private var showingApprovalDialog = false
    @State private var selectedDemand: Transfer? = nil
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
                    VStack(alignment: .leading, spacing: 20) {

                        // Gross Sales vs Target Card
                        grossSalesCard


                        if adminViewModel.isLoading || storeViewModel.isLoading || productViewModel.isLoading {
                            LoadingView(message: "Refreshing dashboard...")
                                .frame(height: 160)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white)
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white)
                                )
                        }
                        
                        // Category-wise Sales Breakdown
                        categorySalesCard

                        // Top Performing Stores
                        topPerformingStoresCard

                        // IM-3 & IM-4: Pending Approvals
                        let pendingVendorOrders = engine.demands.filter { $0.type == .vendor && $0.status == .pending }
                        if !pendingVendorOrders.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Action Required: Pending Approvals")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                                
                                ForEach(pendingVendorOrders) { demand in
                                    approvalAlertCard(for: demand)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Dashboard")
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
                    engine.processAdminDecision(demandId: demand.id, isApproved: true, reason: approvalReason.isEmpty ? "Approved" : approvalReason)
                    approvalReason = ""
                })
                Button("Reject", role: .destructive, action: {
                    engine.processAdminDecision(demandId: demand.id, isApproved: false, reason: approvalReason.isEmpty ? "Rejected due to policy limitations" : approvalReason)
                    approvalReason = ""
                })
                Button("Cancel", role: .cancel, action: {
                    approvalReason = ""
                })
            } message: { demand in
                Text("Process PO: \(demand.orderId) for \(demand.items.first?.quantity ?? 0)x \(demand.items.first?.productName ?? "Items")")
            }
        }
    }

    // MARK: - Gross Sales vs Target Card

    private var grossSalesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CatalogTheme.surface)
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CatalogTheme.primary)
                }

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

            // Revenue / Target / Remaining row
            HStack(spacing: 0) {
                salesMetricColumn(
                    label: "Revenue",
                    value: formatCurrency(dashboardViewModel.grossSales),
                    color: CatalogTheme.primary
                )

                Spacer()

                Rectangle()
                    .fill(CatalogTheme.divider)
                    .frame(width: 1, height: 44)

                Spacer()

                salesMetricColumn(
                    label: "Target",
                    value: formatCurrency(dashboardViewModel.totalTarget),
                    color: CatalogTheme.secondaryText
                )

                Spacer()

                Rectangle()
                    .fill(CatalogTheme.divider)
                    .frame(width: 1, height: 44)

                Spacer()

                salesMetricColumn(
                    label: "Remaining",
                    value: formatCurrency(dashboardViewModel.remainingTarget),
                    color: CatalogTheme.deepAccent
                )
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Achievement")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)
                    Spacer()
                    Text(String(format: "%.1f%%", dashboardViewModel.achievementPercentage * 100))
                        .font(.caption.bold())
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CatalogTheme.surface)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [CatalogTheme.primary.opacity(0.8), CatalogTheme.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(dashboardViewModel.achievementPercentage, 1.0), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func salesMetricColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
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

    private var categorySalesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CatalogTheme.surface)
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CatalogTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sales by Category")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text("Revenue distribution across categories")
                        .font(.caption)
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
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundColor(CatalogTheme.mutedText)
                        Text("No sales data available")
                            .font(.subheadline)
                            .foregroundColor(CatalogTheme.secondaryText)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                let maxSales = dashboardViewModel.categorySales.first?.totalSales ?? 1
                let totalAllCategories = dashboardViewModel.categorySales.reduce(0) { $0 + $1.totalSales }

                // Overall gross sales summary
                HStack {
                    Text("Total Gross Sales")
                        .font(.subheadline)
                        .foregroundColor(CatalogTheme.secondaryText)
                    Spacer()
                    Text(formatCurrency(totalAllCategories))
                        .font(.subheadline.bold())
                        .foregroundColor(CatalogTheme.deepAccent)
                }
                .padding(.bottom, 4)

                ForEach(dashboardViewModel.categorySales) { item in
                    VStack(spacing: 6) {
                        HStack {
                            Text(item.category)
                                .font(.subheadline)
                                .foregroundColor(CatalogTheme.secondaryText)
                                .lineLimit(1)
                            Spacer()
                            Text(formatCurrency(item.totalSales))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(CatalogTheme.deepAccent)

                            if totalAllCategories > 0 {
                                Text(String(format: "%.0f%%", (item.totalSales / totalAllCategories) * 100))
                                    .font(.caption2)
                                    .foregroundColor(CatalogTheme.mutedText)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(CatalogTheme.surface)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(categoryColor(for: item.category))
                                    .frame(width: geo.size.width * (item.totalSales / maxSales), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
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
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(CatalogTheme.surface)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "crown.fill")
                        .foregroundColor(CatalogTheme.primary)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Performing Stores")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(.primary)
                    Text("Ranked by sales completed this month")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                Spacer()

                if dashboardViewModel.isTopStoresLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if dashboardViewModel.topPerformingStores.isEmpty && !dashboardViewModel.isTopStoresLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "storefront")
                            .font(.title2)
                            .foregroundColor(CatalogTheme.secondaryText)
                        Text("No data for current month")
                            .font(.subheadline)
                            .foregroundColor(CatalogTheme.secondaryText)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(Array(dashboardViewModel.topPerformingStores.prefix(5).enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.bold())
                            .foregroundColor(index == 0 ? CatalogTheme.deepAccent : CatalogTheme.secondaryText)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.store.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(CatalogTheme.primaryText)
                            Text(item.store.location)
                                .font(.caption2)
                                .foregroundColor(CatalogTheme.secondaryText)
                        }

                        Spacer()

                        Text(formatCurrency(item.totalSales))
                            .font(.subheadline.bold())
                            .foregroundColor(CatalogTheme.primary)
                    }
                    .padding(.vertical, 8)

                    if index < min(4, dashboardViewModel.topPerformingStores.count - 1) {
                        Divider()
                            .background(CatalogTheme.divider)
                    }
                }
            }
        }
        .padding(16)
        .appCardChrome()
    }

    private func categoryColor(for category: String) -> Color {
        let colors: [Color] = [
            CatalogTheme.primary,
            CatalogTheme.deepAccent,
            Color(hex: "#8C6A6E"),
            Color(hex: "#BFAAAA"),
            Color(hex: "#A08888"),
            Color(hex: "#7A5C60"),
            Color(hex: "#C4B0B0"),
            Color(hex: "#5C3C40")
        ]
        let hash = abs(category.hashValue)
        return colors[hash % colors.count]
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
    private func approvalAlertCard(for demand: Transfer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(CatalogTheme.deepAccent)
                    Text("Vendor Order: \(demand.orderId)")
                        .font(.subheadline.bold())
                        .foregroundColor(CatalogTheme.primaryText)
                }

                Text("\(demand.items.first?.quantity ?? 0)x \(demand.items.first?.productName ?? "")")
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

struct AdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AdminDashboardView(sessionViewModel: SessionViewModel())
    }
}

