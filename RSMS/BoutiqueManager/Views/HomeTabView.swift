import SwiftUI

public struct HomeTabView: View {
    @EnvironmentObject var dashboardVM: BoutiqueDashboardViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel

    public var body: some View {
        NavigationView {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if dashboardVM.isLoading && dashboardVM.summary == nil {
                            // Skeleton shimmer while first load
                            DashboardSkeleton()
                        } else if let summary = dashboardVM.summary {
                            // Sales Card
                            SalesTargetCard(summary: summary)
                                .transition(.opacity.combined(with: .move(edge: .top)))

                            // Low Stock Section
                            if summary.activeAlertsCount > 0 {
                                VStack(spacing: 8) {
                                    HStack {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(Theme.error)
                                                .font(.system(size: 11))
                                            Text("LOW STOCK ALERTS")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(Theme.textSecondary)
                                                .tracking(1)
                                        }
                                        Spacer()
                                        Text("\(summary.activeAlertsCount) item\(summary.activeAlertsCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.error)
                                    }

                                    ForEach(dashboardVM.activeAlerts) { alert in
                                        AlertRow(alert: alert)
                                    }
                                }
                                .transition(.opacity)
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.primary)
                                    Text("All stock levels are healthy")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.surface)
                                .cornerRadius(20)
                                .transition(.opacity)
                            }
                            
                            // Today's Appointments Section
                            VStack(spacing: 8) {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(Theme.textPrimary)
                                            .font(.system(size: 11))
                                        Text("TODAY'S APPOINTMENTS")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Theme.textSecondary)
                                            .tracking(1)
                                    }
                                    Spacer()
                                    if dashboardVM.todayAppointments.count > 0 {
                                        Text("\(dashboardVM.todayAppointments.count)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                
                                if dashboardVM.todayAppointments.isEmpty {
                                    HStack(spacing: 10) {
                                        Image(systemName: "calendar.badge.minus")
                                            .foregroundColor(Theme.textSecondary)
                                        Text("No appointments scheduled for today")
                                            .font(.subheadline)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.textSecondary.opacity(0.08))
                                    .cornerRadius(20)
                                    .transition(.opacity)
                                } else {
                                    ForEach(dashboardVM.todayAppointments) { appt in
                                        AppointmentCard(appointment: appt)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .transition(.opacity)

                        } else if let error = dashboardVM.errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(Theme.error)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                Button("Retry") { dashboardVM.loadDashboardData() }
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textPrimary)
                            }
                            .padding(40)
                        }
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.35), value: dashboardVM.summary != nil)
                    .animation(.easeInOut(duration: 0.25), value: dashboardVM.isLoading)
                }
                // Subtle refresh indicator when reloading with existing data
                .refreshable {
                    await dashboardVM.loadDashboardDataAsync()
                }
            }
            .navigationTitle("Dashboard")
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
                            .font(.title2)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
            .onAppear {
                // Only load if no data yet; use refresh to force reload
                if dashboardVM.summary == nil {
                    dashboardVM.loadDashboardData()
                }
            }
        }
    }
}

// MARK: - Shimmer Skeleton

struct DashboardSkeleton: View {
    @State private var shimmerOffset: CGFloat = -300

    var body: some View {
        VStack(spacing: 20) {
            // Sales card skeleton
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
            .background(Theme.beige)
            .cornerRadius(20)

            // Alert rows skeleton
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 14) {
                    ShimmerCircle(size: 36)
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerBar(width: 140, height: 12)
                        ShimmerBar(width: 80, height: 10)
                    }
                    Spacer()
                    ShimmerBar(width: 40, height: 20)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Theme.beige)
                .cornerRadius(20)
            }
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
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Theme.border.opacity(0.4),
                Theme.border.opacity(0.9),
                Theme.border.opacity(0.4)
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
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Theme.border.opacity(0.4),
                Theme.border.opacity(0.9),
                Theme.border.opacity(0.4)
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
                Circle()
                    .fill(Theme.surface)
                    .frame(width: 36, height: 36)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.primary)
                    .font(.system(size: 13))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                Text(alert.category.isEmpty ? "General" : alert.category)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(alert.stockQuantity)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primary)
                Text("left")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.beige)
        .cornerRadius(20)
    }
}

// MARK: - Sales Target Card

struct SalesTargetCard: View {
    let summary: DashboardSummary

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S SALES")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)
                        .tracking(1.2)
                    Text(formatCurrency(summary.dailyRevenue))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
                let percent = summary.targetRevenue > 0
                    ? min(max(summary.dailyRevenue / summary.targetRevenue, 0), 1)
                    : 0
                ZStack {
                    Circle()
                        .stroke(Theme.border, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(percent))
                        .stroke(Theme.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8), value: percent)
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(width: 72, height: 72)
            }

            Divider().background(Theme.border)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(formatCurrency(summary.targetRevenue))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                let gap = max(summary.targetRevenue - summary.dailyRevenue, 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(formatCurrency(gap))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(gap == 0 ? Theme.success : Theme.error)
                }
            }
        }
        .padding(20)
        .background(Theme.beige)
        .cornerRadius(20)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

struct AlertsCard: View {
    let count: Int
    var body: some View { EmptyView() }
}



