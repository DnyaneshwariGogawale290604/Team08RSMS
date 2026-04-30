import SwiftUI

public struct StoreOverviewTab: View {
    @ObservedObject private var viewModel: StoreViewModel
    private let store: Store
    private let refreshStore: () async -> Void


    public init(
        viewModel: StoreViewModel,
        store: Store,
        refreshStore: @escaping () async -> Void
    ) {
        self.viewModel = viewModel
        self.store = store
        self.refreshStore = refreshStore
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                storeInformationCard
                salesPerformanceCard
            }
            .padding(20)
        }
        .background(Color.clear)
    }

    private var storeInformationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(CatalogTheme.primary)
                Text("Store Information")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
            }

            VStack(spacing: 0) {
                infoRow(title: "Location", value: store.location)
                detailDivider
                infoRow(title: "Address", value: displayValue(store.address))
                detailDivider
                infoRow(title: "Opening Date", value: displayValue(store.openingDate))
                detailDivider
                infoRow(title: "Status", value: displayValue(store.status?.replacingOccurrences(of: "_", with: " ").capitalized))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    private var salesPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(CatalogTheme.primary)
                Text("Sales Performance")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
            }

            AppSegmentedControl(
                options: [
                    AppSegmentedOption(id: "monthly", title: "Monthly"),
                    AppSegmentedOption(id: "yearly", title: "Yearly")
                ],
                selection: $viewModel.selectedTimeRange
            )
            .onChange(of: viewModel.selectedTimeRange) { _ in
                Task { await refreshStore() }
            }

            VStack(alignment: .leading, spacing: 20) {
                let performance = viewModel.storePerformance[store.id] ?? 0
                let target = store.salesTarget ?? 0
                let progress = target > 0 ? performance / target : 0
                let remaining = max(0, target - performance)
                
                HStack(spacing: 24) {
                        // Achievement Ring
                        ActivityRingView(progress: progress)
                            .frame(width: 140, height: 140)
                        
                        Spacer(minLength: 0)
                        
                        // Metrics
                        VStack(alignment: .leading, spacing: 16) {
                            salesMetricRow(
                                title: "Current Sales",
                                value: formatShortCurrency(performance),
                                icon: "indianrupeesign.circle.fill"
                            )
                            
                            salesMetricRow(
                                title: "Total Target",
                                value: formatShortCurrency(target),
                                icon: "target"
                            )
                            
                            salesMetricRow(
                                title: "Remaining",
                                value: formatShortCurrency(remaining),
                                icon: "arrow.right.circle.fill"
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    private var detailDivider: some View {
        Divider()
            .background(CatalogTheme.divider)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 14, design: .serif))
                .foregroundColor(CatalogTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .multilineTextAlignment(.trailing)
                .foregroundColor(CatalogTheme.primaryText)
        }
        .padding(.vertical, 12)
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }

    private func displayValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Not available" : trimmed
    }

    private func salesMetricRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(CatalogTheme.primary)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey(value))
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
                
                Text(LocalizedStringKey(title))
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(CatalogTheme.secondaryText)
            }
        }
    }
