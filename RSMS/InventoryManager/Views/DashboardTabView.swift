import SwiftUI

public struct DashboardTabView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @StateObject private var exceptionEngine = ExceptionEngine.shared
    @Binding var selectedTab: Int
    @Binding var prefilledSKUMagic: String?
    @Binding var categoryFilterMagic: String?
    @Binding var repairFilter: ItemsTabView.RepairFilter
    public var onAccountTapped: (() -> Void)? = nil

    @State private var showExceptions = false

    private let statColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

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
                dashboardBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection
                        quickStatsSection
                        itemsStockLevelsSection
                        exceptionsHandlingSummarySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await viewModel.loadDashboardData()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    InventoryManagerProfileButton()
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
            .onReceive(NotificationCenter.default.publisher(for: .inventoryManagerDataDidChange)) { _ in
                Task {
                    await viewModel.loadDashboardData()
                }
            }
        }
    }

    private var dashboardBackground: some View {
        LinearGradient(
            colors: [
                Color.appBackground,
                Color.luxurySurface.opacity(0.55),
                Color.appBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                heroMetricPill(value: "\(viewModel.totalSKUs)", label: "tracked SKUs")
                heroMetricPill(value: "\(viewModel.stockHealthPercentage)%", label: "stock health")
                heroMetricPill(value: "\(exceptionEngine.exceptions.count)", label: "active issues")
            }

            HStack(spacing: 12) {
                Button {
                    selectedTab = 2
                } label: {
                    Label("Open Workflows", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.luxuryDeepAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                }

                Text("\(viewModel.inTransitShipmentCount) shipments and \(viewModel.inTransitOrderCount) vendor orders are currently moving.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color.luxuryDeepAccent, Color.appAccent, Color(hex: "#8F6B70")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
    }

    @ViewBuilder
    private func heroMetricPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.white)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var quickStatsSection: some View {
        dashboardSection(title: "Quick Stats", subtitle: "Live operational counts with direct shortcuts into action screens.") {
            LazyVGrid(columns: statColumns, spacing: 14) {
                statButton(
                    title: "Available",
                    subtitle: "Ready to allocate",
                    value: "\(viewModel.availableCount)",
                    icon: "checkmark.circle.fill",
                    accent: Color.green,
                    action: {
                        categoryFilterMagic = nil
                        repairFilter = .available
                        selectedTab = 3
                    }
                )

                statButton(
                    title: "In Transit",
                    subtitle: "Shipments & orders",
                    value: "\(viewModel.inTransitCount)",
                    icon: "box.truck.fill",
                    accent: Color.blue,
                    action: {
                        selectedTab = 2
                    }
                )

                statButton(
                    title: "Pending",
                    subtitle: "Requested items",
                    value: "\(viewModel.pendingItemCount)",
                    icon: "clock.fill",
                    accent: Color.orange,
                    action: {
                        selectedTab = 1
                    }
                )

                statButton(
                    title: "Active POs",
                    subtitle: "Open purchase qty",
                    value: "\(viewModel.activePOItemCount)",
                    icon: "shippingbox.fill",
                    accent: Color.appAccent,
                    action: {
                        selectedTab = 2
                    }
                )

                statButton(
                    title: "Repairs",
                    subtitle: "Needs servicing",
                    value: "\(viewModel.repairCount)",
                    icon: "wrench.and.screwdriver.fill",
                    accent: Color.orange,
                    action: {
                        categoryFilterMagic = nil
                        repairFilter = .underRepair
                        selectedTab = 3
                    }
                )

                statButton(
                    title: "Missing Scan",
                    subtitle: "Follow-up needed",
                    value: "\(viewModel.missingScanCount)",
                    icon: "exclamationmark.triangle.fill",
                    accent: Color.appBrown,
                    action: {
                        categoryFilterMagic = nil
                        repairFilter = .missingScan
                        selectedTab = 3
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func statButton(
        title: String,
        subtitle: String,
        value: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(0.14))
                            .frame(width: 42, height: 42)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accent)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appSecondaryText.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(Color.appPrimaryText)

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.appPrimaryText)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
            .background(Color.appCard.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.appBorder.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.08), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var itemsStockLevelsSection: some View {
        dashboardSection(title: "Items Stock Levels", subtitle: "Category-level availability against reorder targets.") {
            VStack(spacing: 14) {
                ForEach(viewModel.categories, id: \.self) { category in
                    Button(action: {
                        categoryFilterMagic = category
                        repairFilter = .available
                        selectedTab = 3
                    }) {
                        categoryCard(for: category)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
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
        let statusBadge = percent >= 1.0 ? "Good" : (percent >= 0.5 ? "Low" : "Very Low")

        let categoryProductIds = viewModel.products
            .filter { ($0.category.isEmpty ? "General" : $0.category) == category }
            .map { $0.id }
        let hasActiveOrder = categoryProductIds.contains(where: { viewModel.orderedProductIds.contains($0) })

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(category)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(Color.appPrimaryText)

                    Text("\(count) available of target \(categoryTarget)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.appSecondaryText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    if hasActiveOrder {
                        stockBadge(text: "Order Placed", color: .blue)
                    }
                    stockBadge(text: statusBadge, color: statusColor)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appBorder.opacity(0.6))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [statusColor.opacity(0.75), statusColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geometry.size.width * percent, 10))
                    }
                }
                .frame(height: 9)

                HStack {
                    Text(percent >= 1 ? "Fully covered" : "Needs replenishment")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)

                    Spacer()

                    Text("\(Int(percent * 100))% of target")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appSecondaryText)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appBorder.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: statusColor.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    @ViewBuilder
    private func stockBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var exceptionsHandlingSummarySection: some View {
        dashboardSection(title: "Reconciliation Queue", subtitle: "Exception traffic that needs review before stock stays clean.") {
            Button(action: { showExceptions = true }) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red.opacity(exceptionEngine.exceptions.isEmpty ? 0.1 : 0.16))
                                .frame(width: 48, height: 48)

                            Image(systemName: exceptionEngine.exceptions.isEmpty ? "checkmark.shield.fill" : "shield.lefthalf.filled.badge.exclamationmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(exceptionEngine.exceptions.isEmpty ? .green : .red)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active Exceptions")
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundColor(Color.appPrimaryText)

                            Text(exceptionEngine.exceptions.isEmpty ? "Everything looks reconciled right now." : "\(exceptionEngine.exceptions.count) issues require attention across scans, shortages, or damage.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.appSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appSecondaryText)
                    }

                    HStack(spacing: 8) {
                        if exceptionEngine.missingCount > 0 {
                            ExceptionBadge(count: exceptionEngine.missingCount, color: .red, label: "Missing")
                        }
                        if exceptionEngine.mismatchCount > 0 {
                            ExceptionBadge(count: exceptionEngine.mismatchCount, color: .orange, label: "Mismatch")
                        }
                        if exceptionEngine.duplicateCount > 0 {
                            ExceptionBadge(count: exceptionEngine.duplicateCount, color: .yellow, label: "Duplicate")
                        }
                        if exceptionEngine.damagedCount > 0 {
                            ExceptionBadge(count: exceptionEngine.damagedCount, color: .red, label: "Damaged")
                        }
                        if exceptionEngine.shortageCount > 0 {
                            ExceptionBadge(count: exceptionEngine.shortageCount, color: .orange, label: "Shortage")
                        }
                        if exceptionEngine.exceptions.isEmpty {
                            stockBadge(text: "No blockers", color: .green)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.appBorder.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private func dashboardSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(Color.appPrimaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.appSecondaryText)
            }

            content()
        }
    }
}

struct ExceptionBadge: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.appPrimaryText)

            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.appPrimaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
