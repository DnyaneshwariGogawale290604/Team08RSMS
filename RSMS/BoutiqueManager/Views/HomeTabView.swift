import SwiftUI

// MARK: - Main Dashboard View

public struct HomeTabView: View {
    @EnvironmentObject var dashboardVM: BoutiqueDashboardViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel
    @State private var stockAlertsExpanded = false

    public var body: some View {
        NavigationView {
            ZStack {
                BoutiqueTheme.offWhite.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if dashboardVM.isLoading && dashboardVM.summary == nil {
                            DashboardSkeleton()
                        } else if let summary = dashboardVM.summary {
                            SalesTargetCard(summary: summary)
                                .transition(.opacity.combined(with: .move(edge: .top)))

                            QuickStatsRow(summary: summary)

                            if !dashboardVM.weeklyRevenue.isEmpty {
                                WeeklyRevenueCard(data: dashboardVM.weeklyRevenue)
                            }

                            if !dashboardVM.topProducts.isEmpty {
                                TopProductsCard(products: dashboardVM.topProducts)
                            }

                            if dashboardVM.staffPerformance.count >= 1 {
                                StaffSpotlightCard(staffList: dashboardVM.staffPerformance)
                            }

                            LowStockDropdownCard(
                                alerts: dashboardVM.activeAlerts,
                                alertCount: summary.activeAlertsCount,
                                isExpanded: $stockAlertsExpanded
                            )



                        } else if let error = dashboardVM.errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.largeTitle).foregroundColor(BoutiqueTheme.error)
                                Text(error).font(.subheadline)
                                    .foregroundColor(BoutiqueTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                Button("Retry") { dashboardVM.loadDashboardData() }
                                    .foregroundColor(BoutiqueTheme.textPrimary)
                            }.padding(40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .animation(.easeInOut(duration: 0.35), value: dashboardVM.summary != nil)
                }
                .refreshable { await dashboardVM.loadDashboardDataAsync() }
            }
            .navigationTitle("Dashboard")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BoutiqueProfileButton()
                }
            }
            .onAppear {
                if dashboardVM.summary == nil { dashboardVM.loadDashboardData() }
            }
        }
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let summary: DashboardSummary

    var body: some View {
        HStack(spacing: 10) {
            QuickStatCard(
                icon: "bag.fill",
                label: "Orders Today",
                value: "\(summary.todayOrderCount)",
                color: BoutiqueTheme.primary
            )
            QuickStatCard(
                icon: "chart.bar.fill",
                label: "Avg Order",
                value: formatCurrency(summary.todayAvgOrderValue),
                color: Color(hex: "#7C5C3A")
            )
            QuickStatCard(
                icon: "exclamationmark.triangle.fill",
                label: "Low Stock",
                value: "\(summary.activeAlertsCount)",
                color: summary.activeAlertsCount > 0 ? BoutiqueTheme.error : BoutiqueTheme.primary
            )
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_000 { return "₹\(Int(v/1000))K" }
        return "₹\(Int(v))"
    }
}

struct QuickStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(BoutiqueTheme.textPrimary)
                .padding(.top, 4)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(BoutiqueTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Weekly Revenue Chart

struct WeeklyRevenueCard: View {
    let data: [DailySalesData]
    @State private var selectedTimeframe = 0

    private var displayData: [DailySalesData] {
        if selectedTimeframe == 0 {
            return data
        } else if selectedTimeframe == 1 {
            // Mock Monthly data
            return [
                DailySalesData(dayLabel: "W1", amount: 200000, isToday: false),
                DailySalesData(dayLabel: "W2", amount: 250000, isToday: false),
                DailySalesData(dayLabel: "W3", amount: 150000, isToday: false),
                DailySalesData(dayLabel: "W4", amount: 300000, isToday: true)
            ]
        } else {
            // Mock Yearly data
            return [
                DailySalesData(dayLabel: "Q1", amount: 800000, isToday: false),
                DailySalesData(dayLabel: "Q2", amount: 1200000, isToday: false),
                DailySalesData(dayLabel: "Q3", amount: 900000, isToday: false),
                DailySalesData(dayLabel: "Q4", amount: 1500000, isToday: true)
            ]
        }
    }

    private var maxAmount: Double { displayData.map(\.amount).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                DashSectionHeader(icon: nil, title: "Revenue")
                Spacer()
                Picker("Timeframe", selection: $selectedTimeframe) {
                    Text("Weekly").tag(0)
                    Text("Monthly").tag(1)
                    Text("Yearly").tag(2)
                }
                .pickerStyle(MenuPickerStyle())
                .font(.subheadline)
                .accentColor(BoutiqueTheme.primary)
            }

            HStack(alignment: .bottom, spacing: selectedTimeframe == 0 ? 8 : 16) {
                ForEach(displayData.indices, id: \.self) { i in
                    let day = displayData[i]
                    let isCurrent = selectedTimeframe == 0 ? day.isToday : (i == displayData.count - 1)
                    VStack(spacing: 4) {
                        if day.amount > 0 {
                            Text(shortCurrency(day.amount))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(BoutiqueTheme.textSecondary)
                        }
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isCurrent ? BoutiqueTheme.primary : BoutiqueTheme.primary.opacity(0.3))
                            .frame(height: max(4, 80 * CGFloat(day.amount / max(maxAmount, 1))))
                        Text(day.dayLabel)
                            .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? BoutiqueTheme.primary : BoutiqueTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.6), value: day.amount)
                }
            }
            .frame(height: 110)

            HStack {
                Circle().fill(BoutiqueTheme.primary).frame(width: 8, height: 8)
                Text(selectedTimeframe == 0 ? "Today" : "Current").font(.caption2).foregroundColor(BoutiqueTheme.textSecondary)
                Circle().fill(BoutiqueTheme.primary.opacity(0.3)).frame(width: 8, height: 8).padding(.leading, 8)
                Text("Previous").font(.caption2).foregroundColor(BoutiqueTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func shortCurrency(_ v: Double) -> String {
        if v >= 1_00_000 { return "₹\(String(format: "%.1f", v/1_00_000))L" }
        if v >= 1_000 { return "₹\(Int(v/1000))K" }
        return "₹\(Int(v))"
    }
}

// MARK: - Top Products Chart

struct TopProductsCard: View {
    let products: [ProductSalesData]

    private var maxUnits: Int { products.map(\.unitsSold).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashSectionHeader(icon: nil, title: "Top Selling Products")

            HStack(alignment: .top, spacing: 20) {
                // Left: Custom Pie Chart
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                    
                    ForEach(Array(products.enumerated()), id: \.1.id) { index, product in
                        PieSliceView(
                            startAngle: angle(for: index),
                            endAngle: angle(for: index + 1),
                            color: pieColor(for: index)
                        )
                    }
                }
                .frame(width: 100, height: 100)
                
                // Right: Legend
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(products.enumerated()), id: \.1.id) { index, product in
                        HStack(alignment: .top) {
                            Circle()
                                .fill(pieColor(for: index))
                                .frame(width: 10, height: 10)
                                .padding(.top, 3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(BoutiqueTheme.textPrimary)
                                    .lineLimit(2)
                                Text("\(product.unitsSold) units")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(BoutiqueTheme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private var totalUnits: Int {
        max(products.map(\.unitsSold).reduce(0, +), 1)
    }
    
    private func angle(for index: Int) -> Angle {
        if index == 0 { return .zero }
        let precedingUnits = products.prefix(index).map(\.unitsSold).reduce(0, +)
        let fraction = Double(precedingUnits) / Double(totalUnits)
        return .degrees(fraction * 360)
    }
    
    private func pieColor(for index: Int) -> Color {
        let opacities: [Double] = [1.0, 0.7, 0.5, 0.3, 0.2]
        return BoutiqueTheme.primary.opacity(opacities[index % opacities.count])
    }
}

struct PieSliceView: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let center = CGPoint(x: width / 2, y: height / 2)
                let radius = min(width, height) / 2
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: Angle(degrees: startAngle.degrees - 90),
                    endAngle: Angle(degrees: endAngle.degrees - 90),
                    clockwise: false
                )
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

// MARK: - Staff Spotlight

struct StaffSpotlightCard: View {
    let staffList: [StaffPerformanceData]

    private var top: StaffPerformanceData? { staffList.first }
    private var bottom: StaffPerformanceData? { staffList.count > 1 ? staffList.last : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashSectionHeader(icon: nil, title: "Staff Performance")
            HStack(spacing: 10) {
                if let star = top {
                    StaffPerformanceCard(staff: star, isStar: true)
                }
                if let low = bottom {
                    StaffPerformanceCard(staff: low, isStar: false)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct StaffPerformanceCard: View {
    let staff: StaffPerformanceData
    let isStar: Bool

    private var accentColor: Color { isStar ? BoutiqueTheme.primary : BoutiqueTheme.error }
    private var bgColor: Color { isStar ? BoutiqueTheme.primary.opacity(0.07) : BoutiqueTheme.error.opacity(0.06) }
    private var medalIcon: String { isStar ? "medal.fill" : "arrow.down.circle.fill" }
    private var roleLabel: String { isStar ? "Star Performer" : "Needs Support" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: medalIcon)
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                Text(roleLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
            }

            Text(staff.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(BoutiqueTheme.textPrimary)
                .lineLimit(1)

            Text("EMP-\(staff.id.uuidString.prefix(6).uppercased())")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(BoutiqueTheme.textSecondary)
                .padding(.bottom, 2)

            Text(formatCurrency(staff.totalSales))
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(accentColor)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text(staff.avgRating > 0 ? String(format: "%.1f", staff.avgRating) : "—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(BoutiqueTheme.textSecondary)
                Text("·")
                    .foregroundColor(BoutiqueTheme.textSecondary)
                Text("\(staff.orderCount) orders")
                    .font(.system(size: 11))
                    .foregroundColor(BoutiqueTheme.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .cornerRadius(12)
    }

    private func formatCurrency(_ v: Double) -> String {
        if v >= 1_00_000 { return "₹\(String(format: "%.1f", v/1_00_000))L" }
        if v >= 1_000 { return "₹\(Int(v/1000))K" }
        return "₹\(Int(v))"
    }
}

// MARK: - Low Stock Dropdown

struct LowStockDropdownCard: View {
    let alerts: [InventoryProduct]
    let alertCount: Int
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible, tappable)
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 6) {
                        Text("Low Stock Alerts")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                            .tracking(1)
                    }
                    Spacer()
                    if alertCount > 0 {
                        Text("\(alertCount) item\(alertCount == 1 ? "" : "s")")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(BoutiqueTheme.error)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(BoutiqueTheme.error.opacity(0.1))
                            .cornerRadius(8)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(BoutiqueTheme.textSecondary)
                        .padding(.leading, 6)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expandable content
            if isExpanded {
                Divider().padding(.horizontal, 16)
                if alerts.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(BoutiqueTheme.primary)
                        Text("All stock levels are healthy")
                            .font(.subheadline)
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(alerts) { alert in
                            AlertRow(alert: alert)
                        }
                    }
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}



// MARK: - Shared Section Header

struct DashSectionHeader: View {
    let icon: String?
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            if let iconName = icon {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(BoutiqueTheme.primary)
            }
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)
        }
    }
}

// MARK: - Shimmer Skeleton

struct DashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerBar(width: 100, height: 12)
                        ShimmerBar(width: 160, height: 32)
                    }
                    Spacer()
                    ShimmerCircle(size: 72)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerBar(width: 50, height: 10)
                        ShimmerBar(width: 90, height: 16)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        ShimmerBar(width: 60, height: 10)
                        ShimmerBar(width: 80, height: 16)
                    }
                }
            }
            .padding(20)
            .background(BoutiqueTheme.beige)
            .cornerRadius(20)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBar(width: .infinity, height: 72)
                        .cornerRadius(14)
                }
            }

            ShimmerBar(width: .infinity, height: 160).cornerRadius(16)
            ShimmerBar(width: .infinity, height: 140).cornerRadius(16)
        }
    }
}

struct ShimmerBar: View {
    let width: CGFloat
    let height: CGFloat
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(shimmerGradient)
            .frame(width: width == .infinity ? nil : width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                BoutiqueTheme.border.opacity(0.4),
                BoutiqueTheme.border.opacity(0.9),
                BoutiqueTheme.border.opacity(0.4)
            ]),
            startPoint: UnitPoint(x: phase - 0.5, y: 0),
            endPoint: UnitPoint(x: phase + 0.5, y: 0)
        )
    }
}

struct ShimmerCircle: View {
    let size: CGFloat
    @State private var phase: CGFloat = 0

    var body: some View {
        Circle()
            .fill(shimmerGradient)
            .frame(width: size, height: size)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                BoutiqueTheme.border.opacity(0.4),
                BoutiqueTheme.border.opacity(0.9),
                BoutiqueTheme.border.opacity(0.4)
            ]),
            startPoint: UnitPoint(x: phase - 0.5, y: 0),
            endPoint: UnitPoint(x: phase + 0.5, y: 0)
        )
    }
}

// MARK: - Alert Row

struct AlertRow: View {
    let alert: InventoryProduct

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(BoutiqueTheme.surface).frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(BoutiqueTheme.primary)
                    .font(.system(size: 13))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.name)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(BoutiqueTheme.textPrimary)
                Text(alert.category.isEmpty ? "General" : alert.category)
                    .font(.caption2).foregroundColor(BoutiqueTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(alert.stockQuantity)")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(BoutiqueTheme.primary)
                Text("left").font(.caption2).foregroundColor(BoutiqueTheme.textSecondary)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(BoutiqueTheme.beige)
        .cornerRadius(12)
    }
}

// MARK: - Sales Target Card

struct SalesTargetCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Gross Sales vs Target")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)
            
            HStack(spacing: 24) {
                // Left: Circular Progress
                let percent = summary.targetRevenue > 0
                    ? min(max(summary.dailyRevenue / summary.targetRevenue, 0), 1) : 0
                
                ZStack {
                    Circle()
                        .stroke(BoutiqueTheme.primary.opacity(0.15), lineWidth: 16)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(percent))
                        .stroke(BoutiqueTheme.primary, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: percent)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(percent * 100))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(BoutiqueTheme.textPrimary)
                        
                        Text("ACHIEVED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(BoutiqueTheme.textSecondary)
                    }
                }
                .frame(width: 150, height: 150)
                
                Spacer()
                
                // Right: List
                VStack(alignment: .leading, spacing: 20) {
                    let gap = max(summary.targetRevenue - summary.dailyRevenue, 0)
                    
                    TargetStatRow(icon: "indianrupeesign", isFilled: true, value: formatCurrencyShort(summary.dailyRevenue), label: "Current Sales")
                    
                    TargetStatRow(icon: "target", isFilled: false, value: formatCurrencyShort(summary.targetRevenue), label: "Total Target")
                    
                    TargetStatRow(icon: "arrow.right", isFilled: true, value: formatCurrencyShort(gap), label: "Remaining")
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func formatCurrencyShort(_ value: Double) -> String {
        if value >= 1_00_000 {
            return String(format: "₹%.1f L", value / 1_00_000)
        } else if value >= 1_000 {
            return String(format: "₹%.1f K", value / 1_000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}

struct TargetStatRow: View {
    let icon: String
    let isFilled: Bool
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isFilled {
                    Circle().fill(BoutiqueTheme.primary).frame(width: 24, height: 24)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(BoutiqueTheme.textSecondary)
                }
            }
            .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(BoutiqueTheme.textPrimary)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(BoutiqueTheme.textSecondary)
            }
        }
    }
}

struct AlertsCard: View {
    let count: Int
    var body: some View { EmptyView() }
}
