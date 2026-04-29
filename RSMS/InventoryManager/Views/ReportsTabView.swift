import SwiftUI
import Charts

// MARK: - Reports Tab View

public struct ReportsTabView: View {
    @StateObject private var vm = ReportsViewModel()

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Group {
                    if vm.isLoading && vm.inventoryItems.isEmpty {
                        loadingState
                    } else if let err = vm.errorMessage {
                        errorState(err)
                    } else {
                        reportContent
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
            .task { await vm.fetchData() }
            .refreshable { await vm.fetchData() }
        }
    }

    // ─── Loading ─────────────────────────────────────────────────────────────────

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color.appAccent)
            Text("Loading Analytics…")
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
        }
    }

    // ─── Error ───────────────────────────────────────────────────────────────────

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text("Couldn't Load Reports")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text(message)
                .font(.caption)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await vm.fetchData() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
            }
        }
    }

    // ─── Main Content ────────────────────────────────────────────────────────────

    private var reportContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                healthBanner
                shrinkOverviewSection
                scanComplianceSection
                certificationComplianceSection
                varianceSection
                shrinkTrendSection
                categoryShrinkSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    // ─── Health Banner ────────────────────────────────────────────────────────────

    private var healthBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.appBorder, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.healthScore) / 100)
                    .stroke(vm.healthColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: vm.healthScore)
                VStack(spacing: 1) {
                    Text("\(vm.healthScore)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.appPrimaryText)
                    Text("/ 100")
                        .font(.system(size: 10))
                        .foregroundColor(.appSecondaryText)
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("Inventory Health")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                Text(vm.healthLabel)
                    .font(.title2.weight(.bold))
                    .foregroundColor(vm.healthColor)
                Text("\(vm.totalItemsCount) items · \(vm.totalShrinkLast7Days) loss events this week")
                    .font(.caption2)
                    .foregroundColor(.appSecondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // ─── Shrink Overview ─────────────────────────────────────────────────────────

    private var shrinkOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSectionHeader(title: "Shrink Overview", systemImage: "shield.lefthalf.filled")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ReportKPICard(
                    title: "Shrink Rate",
                    value: String(format: "%.1f%%", vm.shrinkPercentage),
                    systemImage: "chart.pie.fill",
                    tint: .red,
                    subtitle: "\(vm.lostItemsCount) of \(vm.totalItemsCount) items"
                )
                ReportKPICard(
                    title: "Lost Items",
                    value: "\(vm.lostItemsCount)",
                    systemImage: "exclamationmark.shield.fill",
                    tint: .orange,
                    subtitle: "\(vm.scrappedCount) scrapped · \(vm.confirmedMissingCount) missing"
                )
                ReportKPICard(
                    title: "Under Repair",
                    value: "\(vm.underRepairCount)",
                    systemImage: "wrench.and.screwdriver.fill",
                    tint: Color.appAccent,
                    subtitle: "Active repair tickets"
                )
                ReportKPICard(
                    title: "Recovered",
                    value: "\(vm.recoveredCount)",
                    systemImage: "arrow.uturn.left.circle.fill",
                    tint: .green,
                    subtitle: "Previously missing, found"
                )
            }
        }
    }

    // ─── Scan Compliance ─────────────────────────────────────────────────────────

    private var scanComplianceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSectionHeader(title: "Scan Compliance", systemImage: "clock.badge.checkmark")

            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: CGFloat(vm.compliancePercentage / 100))
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: vm.compliancePercentage)
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", vm.compliancePercentage))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.appPrimaryText)
                        Text("compliant")
                            .font(.system(size: 10))
                            .foregroundColor(.appSecondaryText)
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 14) {
                    ReportComplianceRow(label: "Within 48h SLA", count: vm.compliantCount, color: Color.appAccent)
                    ReportComplianceRow(label: "Overdue", count: vm.overdueCount, color: .orange)
                    Divider()
                    HStack {
                        Text("Total Trackable")
                            .font(.caption2)
                            .foregroundColor(.appSecondaryText)
                        Spacer()
                        Text("\(vm.compliantCount + vm.overdueCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.appPrimaryText)
                    }
                }
            }
            .padding(20)
            .background(Color.appCard)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    // ─── Certification Compliance ───────────────────────────────────────────────

    private var certificationComplianceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSectionHeader(title: "Certification Compliance", systemImage: "checkmark.seal.fill")

            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.appBorder, lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: CGFloat(vm.certCompliancePercentage / 100))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: vm.certCompliancePercentage)
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", vm.certCompliancePercentage))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.appPrimaryText)
                        Text("verified")
                            .font(.system(size: 10))
                            .foregroundColor(.appSecondaryText)
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 14) {
                    ReportComplianceRow(label: "Verified", count: vm.verifiedCount, color: .green)
                    ReportComplianceRow(label: "Pending", count: vm.certPendingCount, color: .orange)
                    ReportComplianceRow(label: "Expired/Failed", count: vm.certFailedCount, color: .red)
                    Divider()
                    HStack {
                        Text("Total Items")
                            .font(.caption2)
                            .foregroundColor(.appSecondaryText)
                        Spacer()
                        Text("\(vm.totalItemsCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.appPrimaryText)
                    }
                }
            }
            .padding(20)
            .background(Color.appCard)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }


    // ─── Variance Report ─────────────────────────────────────────────────────────

    private var varianceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSectionHeader(title: "Variance Report", systemImage: "arrow.left.arrow.right.square")

            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    ReportVarianceMetric(label: "Expected", value: "\(vm.expectedCount)", color: .appPrimaryText)
                    Divider().frame(height: 40)
                    ReportVarianceMetric(label: "Scanned", value: "\(vm.actualScannedCount)", color: .appPrimaryText)
                    Divider().frame(height: 40)
                    ReportVarianceMetric(
                        label: "Variance",
                        value: vm.varianceCount == 0 ? "—"
                            : (vm.varianceCount > 0 ? "+\(vm.varianceCount)" : "\(vm.varianceCount)"),
                        color: vm.varianceCount == 0 ? .green : (vm.varianceCount > 0 ? .red : .orange)
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: varianceIcon)
                        .font(.caption)
                        .foregroundColor(varianceBannerColor)
                    Text(varianceInsightText)
                        .font(.caption)
                        .foregroundColor(varianceBannerColor)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(varianceBannerColor.opacity(0.08))
                .cornerRadius(10)
            }
            .padding(20)
            .background(Color.appCard)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    private var varianceInsightText: String {
        if vm.varianceCount == 0 { return "All expected items have been scanned. Great compliance!" }
        if vm.varianceCount > 0  { return "\(vm.varianceCount) expected item(s) not yet scanned within SLA." }
        return "Overage: \(abs(vm.varianceCount)) more item(s) scanned than expected."
    }
    private var varianceIcon: String {
        vm.varianceCount == 0 ? "checkmark.seal.fill"
            : (vm.varianceCount > 0 ? "exclamationmark.triangle.fill" : "info.circle.fill")
    }
    private var varianceBannerColor: Color {
        vm.varianceCount == 0 ? .green : (vm.varianceCount > 0 ? .red : .orange)
    }

    // ─── Shrink Trend ─────────────────────────────────────────────────────────────

    private var shrinkTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSectionHeader(title: "Shrink Trend · 7 Days", systemImage: "chart.xyaxis.line")

            VStack(spacing: 0) {
                let allZero = vm.shrinkTrendData.allSatisfy { $0.count == 0 }
                if allZero {
                    ReportEmptyPlaceholder(
                        systemImage: "checkmark.seal",
                        message: "No shrink incidents in the last 7 days"
                    )
                } else {
                    Chart {
                        ForEach(vm.shrinkTrendData) { point in
                            AreaMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Incidents", point.count)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.25), Color.red.opacity(0.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Incidents", point.count)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Incidents", point.count)
                            )
                            .foregroundStyle(Color.red)
                            .symbolSize(36)
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Color.appBorder)
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Color.appBorder)
                            AxisValueLabel()
                                .foregroundStyle(Color.appSecondaryText)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.appCard)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    // ─── Category Breakdown ───────────────────────────────────────────────────────

    private var categoryShrinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReportSectionHeader(title: "Category Breakdown", systemImage: "square.grid.2x2")

            VStack(spacing: 0) {
                if vm.categoryShrinkData.isEmpty {
                    ReportEmptyPlaceholder(
                        systemImage: "tray",
                        message: "No shrink data to break down by category"
                    )
                } else {
                    VStack(spacing: 14) {
                        ForEach(vm.categoryShrinkData) { item in
                            ReportCategoryShrinkRow(
                                item: item,
                                maxCount: vm.categoryShrinkData.first?.count ?? 1
                            )
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.appCard)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Private Supporting Views

private struct ReportSectionHeader: View {
    let title      : String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appAccent)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.appPrimaryText)
        }
    }
}

private struct ReportKPICard: View {
    let title      : String
    let value      : String
    let systemImage: String
    let tint       : Color
    let subtitle   : String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.appPrimaryText)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appPrimaryText)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.appSecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

private struct ReportComplianceRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
            Spacer()
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.appPrimaryText)
        }
    }
}

private struct ReportVarianceMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReportCategoryShrinkRow: View {
    let item    : ReportsViewModel.CategoryShrink
    let maxCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appPrimaryText)
                Spacer()
                Text("\(item.count) item\(item.count == 1 ? "" : "s")")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.appSecondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appBorder)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appAccent)
                        .frame(
                            width: maxCount > 0
                                ? geo.size.width * CGFloat(item.count) / CGFloat(maxCount)
                                : 0,
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.6), value: item.count)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct ReportEmptyPlaceholder: View {
    let systemImage: String
    let message    : String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(Color.appBorder)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Preview
struct ReportsTabView_Previews: PreviewProvider {
    static var previews: some View { ReportsTabView() }
}
