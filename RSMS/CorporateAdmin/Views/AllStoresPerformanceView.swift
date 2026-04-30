import SwiftUI

struct AllStoresPerformanceView: View {
    let stores: [StorePerformance]

    @State private var selectedStore: StorePerformance? = nil

    private var totalSales: Double {
        stores.reduce(0) { $0 + $1.totalSales }
    }

    private var totalTarget: Double {
        stores.reduce(0) { $0 + $1.target }
    }

    private var averageAchievement: Double {
        guard !stores.isEmpty else { return 0 }
        return stores.reduce(0) { $0 + $1.achievementPercentage } / Double(stores.count)
    }

    private var bestPerformer: StorePerformance? {
        stores.max { $0.achievementPercentage < $1.achievementPercentage }
    }

    var body: some View {
        ZStack {
            CatalogTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Store leaderboard")
                                    .font(BrandFont.display(24, weight: .bold))
                                    .foregroundColor(CatalogTheme.primaryText)
                                Text("\(stores.count) stores ranked by target achievement")
                                    .font(.subheadline)
                                    .foregroundColor(CatalogTheme.secondaryText)
                            }

                            Spacer()
                        }

                        ForEach(Array(stores.enumerated()), id: \.element.id) { index, performance in
                            Button {
                                selectedStore = performance
                            } label: {
                                StorePerformanceRow(performance: performance, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("All Stores")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStore) { performance in
            StorePerformanceDetailView(performance: performance)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Store performance")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(CatalogTheme.secondaryText)
                    .textCase(.uppercase)
            }

            HStack(spacing: 12) {
                summaryMetric(
                    title: "Sales",
                    value: formatShortCurrency(totalSales),
                    detail: "Against \(formatShortCurrency(totalTarget)) target",
                    icon: "indianrupeesign.circle.fill"
                )

                summaryMetric(
                    title: "Average hit rate",
                    value: percentString(averageAchievement),
                    detail: stores.isEmpty ? "No stores yet" : "Across all stores",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }

            if let bestPerformer {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundColor(CatalogTheme.primary)
                        .frame(width: 34, height: 34)
                        .background(CatalogTheme.surface)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Top performer")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(CatalogTheme.secondaryText)
                        Text("\(bestPerformer.store.name) is at \(percentString(bestPerformer.achievementPercentage)) of target")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(CatalogTheme.primaryText)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), CatalogTheme.surface.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, CatalogTheme.surface.opacity(0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private func summaryMetric(title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(CatalogTheme.primary)
                .frame(width: 38, height: 38)
                .background(CatalogTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(value)
                .font(BrandFont.display(22, weight: .bold))
                .foregroundColor(CatalogTheme.primaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(CatalogTheme.primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(CatalogTheme.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

struct StorePerformanceRow: View {
    let performance: StorePerformance
    let rank: Int

    private var progress: Double {
        min(max(performance.achievementPercentage, 0), 1)
    }

    private var achievementPercentText: String {
        "\(Int((performance.achievementPercentage * 100).rounded()))%"
    }

    private var varianceAmount: Double {
        performance.totalSales - performance.target
    }

    private var chipTitle: String {
        switch performance.achievementPercentage {
        case 1.0...:
            return "Above target"
        case 0.8..<1.0:
            return "On track"
        case 0.5..<0.8:
            return "Needs push"
        default:
            return "At risk"
        }
    }

    private var chipColor: Color {
        switch performance.achievementPercentage {
        case 1.0...:
            return Color.green
        case 0.8..<1.0:
            return Color.orange
        case 0.5..<0.8:
            return Color.orange
        default:
            return Color.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(rank <= 3 ? CatalogTheme.primary : CatalogTheme.surface)
                        .frame(width: 42, height: 42)

                    Text("\(rank)")
                        .font(.headline.weight(.bold))
                        .foregroundColor(rank <= 3 ? .white : CatalogTheme.primaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(performance.store.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(CatalogTheme.primaryText)

                    Label(performance.store.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)

                    Text(chipTitle)
                        .font(.caption.weight(.bold))
                        .foregroundColor(chipColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(chipColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(performance.totalSales))
                        .font(BrandFont.display(22, weight: .bold))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text("Target \(formatCurrency(performance.target))")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Achievement")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(CatalogTheme.secondaryText)
                    Spacer()
                    Text(achievementPercentText)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(chipColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(CatalogTheme.surface.opacity(0.9))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [chipColor.opacity(0.75), chipColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geometry.size.width * progress, 10))
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 12) {
                insightPill(
                    title: varianceAmount >= 0 ? "Over target" : "Gap left",
                    value: formatCurrency(abs(varianceAmount)),
                    icon: varianceAmount >= 0 ? "arrow.up.right" : "flag.slash"
                )

                insightPill(
                    title: "Tap for details",
                    value: "Category split",
                    icon: "chart.pie.fill"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CatalogTheme.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    private func insightPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(CatalogTheme.primary)
                .frame(width: 28, height: 28)
                .background(CatalogTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(CatalogTheme.secondaryText)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundColor(CatalogTheme.primaryText)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CatalogTheme.background.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
}
