import SwiftUI

public struct StoreOverviewTab: View {
    @ObservedObject private var viewModel: StoreViewModel
    private let store: Store
    private let refreshStore: () async -> Void

    @State private var editingTarget = ""
    @State private var isEditing = false

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
        .background(CatalogTheme.background)
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
                Spacer()
                Button(action: {
                    Task { await handleTargetAction() }
                }) {
                    Text(isEditing ? "Save" : "Edit Target")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(CatalogTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CatalogTheme.surface)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 20) {
                if isEditing {
                    TextField("Enter target amount", text: $editingTarget)
                        .keyboardType(.decimalPad)
                        .padding(14)
                        .background(CatalogTheme.surface)
                        .cornerRadius(12)
                        .font(.system(size: 15))
                } else {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sales Target")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(CatalogTheme.secondaryText)
                            Text(formattedCurrency(store.salesTarget ?? 0))
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Rectangle()
                            .fill(CatalogTheme.divider)
                            .frame(width: 1, height: 40)
                            .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Current Sales")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(CatalogTheme.secondaryText)
                            let performance = viewModel.storePerformance[store.id] ?? 0
                            Text(formattedCurrency(performance))
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !isEditing, let target = store.salesTarget, target > 0 {
                    let performance = viewModel.storePerformance[store.id] ?? 0
                    let progress = min(1.0, performance / target)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Progress to Target")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(CatalogTheme.secondaryText)
                            Spacer()
                            Text(String(format: "%.1f%%", progress * 100))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(CatalogTheme.primary)
                        }
                        
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(CatalogTheme.surface)
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(CatalogTheme.primary)
                                .frame(width: max(8, (UIScreen.main.bounds.width - 72) * CGFloat(progress)), height: 8)
                        }
                        
                        Text(progress >= 1.0 ? "Target Achieved! Excellent performance." : "Keep pushing to reach the monthly goal.")
                            .font(.system(size: 12))
                            .foregroundColor(progress >= 1.0 ? Color.green : CatalogTheme.mutedText)
                            .italic()
                    }
                    .padding(.top, 4)
                }
            }
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
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(CatalogTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
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

    private func handleTargetAction() async {
        if isEditing {
            let cleaned = editingTarget.replacingOccurrences(of: "₹", with: "").replacingOccurrences(of: ",", with: "")
            if let target = Double(cleaned) {
                await viewModel.updateStoreTarget(storeId: store.id, target: target)
                await refreshStore()
            }
        } else {
            editingTarget = String(format: "%.0f", store.salesTarget ?? 0)
        }
        isEditing.toggle()
    }

    private func displayValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Not available" : trimmed
    }
}
