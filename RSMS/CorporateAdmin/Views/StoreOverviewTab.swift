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
            VStack(spacing: 20) {
                storeInformationCard
                salesPerformanceCard
            }
            .padding(20)
        }
        .background(Color.brandOffWhite)
    }

    private var storeInformationCard: some View {
        whiteCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Store Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                detailDivider

                infoRow(title: "Location", value: store.location)
                detailDivider
                infoRow(title: "Address", value: displayValue(store.address))
                detailDivider
                infoRow(title: "Opening Date", value: displayValue(store.openingDate))
                detailDivider
                infoRow(title: "Status", value: displayValue(store.status?.replacingOccurrences(of: "_", with: " ").capitalized))
            }
        }
    }

    private var salesPerformanceCard: some View {
        whiteCard {
            VStack(alignment: .leading, spacing: 20) {
                // Sales Target Header
                HStack {
                    Text("Sales Performance")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: {
                        Task { await handleTargetAction() }
                    }) {
                        Text(isEditing ? "Save" : "Edit Target")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }

                detailDivider

                if isEditing {
                    TextField("Enter amount", text: $editingTarget)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(10)
                } else {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formattedCurrency(store.salesTarget ?? 0))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Sales Target")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 1, height: 40)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            let performance = viewModel.storePerformance[store.id] ?? 0
                            Text(formattedCurrency(performance))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Current Sales")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                }

                if !isEditing, let target = store.salesTarget, target > 0 {
                    let performance = viewModel.storePerformance[store.id] ?? 0
                    let progress = min(1.0, performance / target)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        detailDivider
                        
                        HStack {
                            Text("Progress")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.1f%%", progress * 100))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(progress >= 1.0 ? .green : .blue)
                        }
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: progress >= 1.0 ? .green : .blue))
                            .scaleEffect(y: 1.5, anchor: .center)
                            .padding(.vertical, 4)
                        
                        Text(progress >= 1.0 ? "Target Achieved!" : "Keep going to reach the goal")
                            .font(.system(size: 12))
                            .foregroundColor(progress >= 1.0 ? .green : .gray)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func whiteCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    private var detailDivider: some View {
        Divider()
            .background(Color.gray.opacity(0.1))
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.trailing)
                .foregroundColor(.black)
        }
    }

    private func formattedCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        return formatter.string(from: NSNumber(value: value)) ?? "₹0.00"
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
        return trimmed.isEmpty ? "Not set" : trimmed
    }
}
