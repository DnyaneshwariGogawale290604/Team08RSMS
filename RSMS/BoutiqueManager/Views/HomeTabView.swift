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

                            AppointmentsSectionCard(appointments: dashboardVM.todayAppointments)

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
                    Menu {
                        Button(role: .destructive, action: {
                            Task { await sessionViewModel.signOut() }
                        }) {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2).foregroundColor(BoutiqueTheme.textPrimary)
                    }
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
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(BoutiqueTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
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

    private var maxAmount: Double { data.map(\.amount).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashSectionHeader(icon: "chart.bar.xaxis", title: "Weekly Revenue")

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data) { day in
                    VStack(spacing: 4) {
                        if day.amount > 0 {
                            Text(shortCurrency(day.amount))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(BoutiqueTheme.textSecondary)
                        }
                        RoundedRectangle(cornerRadius: 6)
                            .fill(day.isToday ? BoutiqueTheme.primary : BoutiqueTheme.primary.opacity(0.3))
                            .frame(height: max(4, 80 * CGFloat(day.amount / max(maxAmount, 1))))
                        Text(day.dayLabel)
                            .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                            .foregroundColor(day.isToday ? BoutiqueTheme.primary : BoutiqueTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.6), value: day.amount)
                }
            }
            .frame(height: 110)

            HStack {
                Circle().fill(BoutiqueTheme.primary).frame(width: 8, height: 8)
                Text("Today").font(.caption2).foregroundColor(BoutiqueTheme.textSecondary)
                Circle().fill(BoutiqueTheme.primary.opacity(0.3)).frame(width: 8, height: 8).padding(.leading, 8)
                Text("Previous days").font(.caption2).foregroundColor(BoutiqueTheme.textSecondary)
            }
        }
        .padding(16)
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
            DashSectionHeader(icon: "star.fill", title: "Top Selling Products")

            ForEach(Array(products.enumerated()), id: \.1.id) { index, product in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("#\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index == 0 ? BoutiqueTheme.primary : BoutiqueTheme.textSecondary)
                            .frame(width: 22, alignment: .leading)
                        Text(product.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(BoutiqueTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(product.unitsSold) units")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(BoutiqueTheme.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(BoutiqueTheme.primary.opacity(0.1))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == 0 ? BoutiqueTheme.primary : BoutiqueTheme.primary.opacity(0.55))
                                .frame(
                                    width: geo.size.width * CGFloat(product.unitsSold) / CGFloat(max(maxUnits, 1)),
                                    height: 6
                                )
                                .animation(.easeOut(duration: 0.7).delay(Double(index) * 0.1), value: product.unitsSold)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Staff Spotlight

struct StaffSpotlightCard: View {
    let staffList: [StaffPerformanceData]

    private var top: StaffPerformanceData? { staffList.first }
    private var bottom: StaffPerformanceData? { staffList.count > 1 ? staffList.last : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashSectionHeader(icon: "person.2.fill", title: "Staff Performance")
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
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(alertCount > 0 ? BoutiqueTheme.error : BoutiqueTheme.primary)
                            .font(.system(size: 18))
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Appointments Section

struct AppointmentsSectionCard: View {
    let appointments: [Appointment]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashSectionHeader(icon: "calendar", title: "Today's Appointments")

            if appointments.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(BoutiqueTheme.textSecondary)
                    Text("No appointments scheduled for today")
                        .font(.subheadline)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BoutiqueTheme.textSecondary.opacity(0.07))
                .cornerRadius(12)
            } else {
                ForEach(appointments) { appt in
                    AppointmentCard(appointment: appt)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Shared Section Header

struct DashSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(BoutiqueTheme.primary)
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
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Sales")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text(formatCurrency(summary.dailyRevenue))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(BoutiqueTheme.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                let percent = summary.targetRevenue > 0
                    ? min(max(summary.dailyRevenue / summary.targetRevenue, 0), 1) : 0
                ZStack {
                    Circle().stroke(BoutiqueTheme.border, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(percent))
                        .stroke(BoutiqueTheme.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: percent)
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(BoutiqueTheme.textPrimary)
                }
                .frame(width: 72, height: 72)
            }
            Divider().background(BoutiqueTheme.border)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target").font(.caption).foregroundColor(BoutiqueTheme.textSecondary)
                    Text(formatCurrency(summary.targetRevenue))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(BoutiqueTheme.textPrimary)
                }
                Spacer()
                let gap = max(summary.targetRevenue - summary.dailyRevenue, 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining").font(.caption).foregroundColor(BoutiqueTheme.textSecondary)
                    Text(formatCurrency(gap))
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(gap == 0 ? BoutiqueTheme.success : BoutiqueTheme.error)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}

struct AlertsCard: View {
    let count: Int
    var body: some View { EmptyView() }
}
